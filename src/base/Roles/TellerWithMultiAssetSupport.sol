// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {AccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {WETH} from "@solmate/tokens/WETH.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {IShareLocker} from "src/interfaces/IShareLocker.sol";
import {console} from "@forge-std/Test.sol";

contract TellerWithMultiAssetSupport is AccessControlDefaultAdminRules, IShareLocker {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;
    using SafeTransferLib for WETH;

    // ========================================= CONSTANTS =========================================

    /**
     * @notice Accounts with this role are allowed to call `bulkDeposit`.
     */
    bytes32 public constant ON_RAMP_ROLE = keccak256("ON_RAMP_ROLE");

    /**
     * @notice Accounts with this role are allowed to call `bulkWithdraw`.
     */
    bytes32 public constant OFF_RAMP_ROLE = keccak256("OFF_RAMP_ROLE"); // bulk user withdraws with no waiting period.

    /**
     * @notice Accounts with this role are allowed to call admin functions.
     */
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE"); // can turn off normal user deposits and withdraws

    bytes32 public constant DEPOSIT_REVERTER_ROLE = keccak256("DEPOSIT_REVERTER_ROLE"); // can revert pending deposits

    /**
     * @notice Native address used to tell the contract to handle native asset deposits.
     */
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /**
     * @notice The maximum possible share lock period.
     */
    uint256 internal constant MAX_SHARE_LOCK_PERIOD = 3 days;

    // ========================================= STATE =========================================

    /**
     * @notice Mapping ERC20s to an isSupported bool.
     */
    mapping(ERC20 => bool) public isSupported;

    /**
     * @notice Used to pause normal user deposits.
     */
    bool public isPaused;

    uint248 public depositNonce = 1;
    // TODO pack this?
    uint64 public shareLockPeriod;

    /**
     * @dev Maps deposit nonce to keccak256(address receiver, address depositAsset, uint256 depositAmount, uint256 shareAmount, uint256 timestamp, uint256 shareLockPeriod).
     */
    mapping(uint256 => bytes32) public publicDepositHistory;

    mapping(address => uint256) public shareUnlockTime;

    //============================== EVENTS ===============================

    event Paused();
    event Unpaused();
    event AssetAdded(address asset);
    event AssetRemoved(address asset);
    event Deposit(
        uint256 nonce,
        address receiver,
        address depositAsset,
        uint256 depositAmount,
        uint256 shareAmount,
        uint256 depositTimestamp,
        uint256 shareLockPeriodAtTimeOfDeposit
    );
    event BulkDeposit(address asset, uint256 depositAmount);
    event BulkWithdraw(address asset, uint256 shareAmount);
    event DepositReverted(uint256 nonce, bytes32 depositHash);

    //============================== IMMUTABLES ===============================

    /**
     * @notice The BoringVault this contract is working with.
     */
    BoringVault public immutable vault;

    /**
     * @notice The AccountantWithRateProviders this contract is working with.
     */
    AccountantWithRateProviders public immutable accountant;

    /**
     * @notice One share of the BoringVault.
     */
    uint256 internal immutable ONE_SHARE;

    /**
     * @notice The native wrapper contract.
     */
    WETH public immutable nativeWrapper;

    constructor(address _owner, address _vault, address _accountant, address _weth)
        AccessControlDefaultAdminRules(3 days, _owner)
    {
        vault = BoringVault(payable(_vault));
        ONE_SHARE = 10 ** vault.decimals();
        accountant = AccountantWithRateProviders(_accountant);
        nativeWrapper = WETH(payable(_weth));
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Pause this contract, which prevents future calls to `deposit`.
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        isPaused = true;
        emit Paused();
    }

    /**
     * @notice Unpause this contract, which allows future calls to `deposit`.
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        isPaused = false;
        emit Unpaused();
    }

    /**
     * @notice Adds this asset as a deposit asset.
     * @dev The accountant must also support pricing this asset, else the `deposit` call will revert.
     */
    function addAsset(ERC20 asset) external onlyRole(ADMIN_ROLE) {
        isSupported[asset] = true;
        emit AssetAdded(address(asset));
    }

    /**
     * @notice Removes this asset as a deposit asset.
     */
    function removeAsset(ERC20 asset) external onlyRole(ADMIN_ROLE) {
        isSupported[asset] = false;
        emit AssetRemoved(address(asset));
    }

    /**
     * @notice Sets the share lock period.
     * @dev This not only locks shares to the user address, but also serves as the pending deposit period, where deposits can be reverted.
     */
    function setShareLockPeriod(uint64 _shareLockPeriod) external onlyRole(ADMIN_ROLE) {
        if (_shareLockPeriod > MAX_SHARE_LOCK_PERIOD) revert("too long");
        shareLockPeriod = _shareLockPeriod;
    }

    // ========================================= ISHARELOCKER FUNCTIONS =========================================

    /**
     * @notice Implement
     */
    function revertIfLocked(address from) external view {
        if (shareUnlockTime[from] <= block.timestamp) revert("share locked");
    }

    // ========================================= REVERT DEPOSIT FUNCTIONS =========================================

    // TODO should we verify share locker contract is set in vault?
    /**
     * @notice Allows DEPOSIT_REVERTER_ROLE to revert a pending deposit.
     * @dev Once a deposit share lock period has passed, it can no longer be reverted.
     */
    function revertDeposit(
        uint256 nonce,
        address receiver,
        address depositAsset,
        uint256 depositAmount,
        uint256 shareAmount,
        uint256 depositTimestamp,
        uint256 shareLockUpPeriodAtTimeOfDeposit
    ) external onlyRole(DEPOSIT_REVERTER_ROLE) {
        if ((block.timestamp - depositTimestamp) > shareLockUpPeriodAtTimeOfDeposit) {
            // Shares are already unlocked, so we can not revert deposit.
            revert("Shares already unlocked");
        }
        bytes32 depositHash = keccak256(
            abi.encode(
                receiver, depositAsset, depositAmount, shareAmount, depositTimestamp, shareLockUpPeriodAtTimeOfDeposit
            )
        );
        if (publicDepositHistory[nonce] != depositHash) revert("invalid deposit");

        // Delete hash to prevent refund gas.
        delete publicDepositHistory[nonce];

        // If deposit used native asset, send user back wrapped native asset.
        depositAsset = depositAsset == NATIVE ? address(nativeWrapper) : depositAsset;
        // Burn shares and refund assets to receiver.
        vault.exit(receiver, ERC20(depositAsset), depositAmount, receiver, shareAmount);

        emit DepositReverted(nonce, depositHash);
    }

    // ========================================= USER FUNCTIONS =========================================

    /**
     * @notice Allows users to deposit into the BoringVault, if this contract is not paused.
     */
    function deposit(ERC20 depositAsset, uint256 depositAmount, uint256 minimumMint)
        public
        payable
        returns (uint256 shares)
    {
        if (isPaused) revert("paused");
        if (!isSupported[depositAsset]) revert("asset not supported");

        if (address(depositAsset) == NATIVE) {
            if (msg.value == 0) revert("zero deposit");
            nativeWrapper.deposit{value: msg.value}();
            depositAmount = msg.value;
            shares = depositAmount.mulDivDown(ONE_SHARE, accountant.getRateInQuoteSafe(nativeWrapper));
            if (shares < minimumMint) revert("minimumMint");
            // `from` is address(this) since user already sent value.
            nativeWrapper.safeApprove(address(vault), depositAmount);
            vault.enter(address(this), nativeWrapper, depositAmount, msg.sender, shares);
        } else {
            if (depositAmount == 0) revert("zero deposit");
            if (msg.value > 0) revert("dual deposit");
            shares = depositAmount.mulDivDown(ONE_SHARE, accountant.getRateInQuoteSafe(depositAsset));
            if (shares < minimumMint) revert("minimumMint");
            vault.enter(msg.sender, depositAsset, depositAmount, msg.sender, shares);
        }

        shareUnlockTime[msg.sender] = block.timestamp + shareLockPeriod;

        uint256 nonce = depositNonce;
        publicDepositHistory[nonce] =
            keccak256(abi.encode(msg.sender, depositAsset, depositAmount, shares, block.timestamp, shareLockPeriod));
        depositNonce++;
        emit Deposit(nonce, msg.sender, address(depositAsset), depositAmount, shares, block.timestamp, shareLockPeriod);
    }

    /**
     * @notice Allows on ramp role to deposit into this contract.
     * @dev Does NOT support native deposits.
     */
    function bulkDeposit(ERC20 depositAsset, uint256 depositAmount, uint256 minimumMint, address to)
        external
        onlyRole(ON_RAMP_ROLE)
        returns (uint256 shares)
    {
        if (depositAmount == 0) revert("zero deposit");
        shares = depositAmount.mulDivDown(ONE_SHARE, accountant.getRateInQuoteSafe(depositAsset));
        if (shares < minimumMint) revert("minimumMint");
        vault.enter(msg.sender, depositAsset, depositAmount, to, shares);
        emit BulkDeposit(address(depositAsset), depositAmount);
    }

    /**
     * @notice Allows off ramp role to withdraw from this contract.
     */
    function bulkWithdraw(ERC20 withdrawAsset, uint256 shareAmount, uint256 minimumAssets, address to)
        external
        onlyRole(OFF_RAMP_ROLE)
        returns (uint256 assetsOut)
    {
        if (shareAmount == 0) revert("zero withdraw");
        assetsOut = shareAmount.mulDivDown(accountant.getRateInQuoteSafe(withdrawAsset), ONE_SHARE);
        if (assetsOut < minimumAssets) revert("minimumAssets");
        vault.exit(to, withdrawAsset, assetsOut, msg.sender, shareAmount);
        emit BulkWithdraw(address(withdrawAsset), shareAmount);
    }

    /**
     * @dev Depositing this way means users can not set a min value out.
     */
    receive() external payable {
        deposit(ERC20(NATIVE), msg.value, 0);
    }
}
