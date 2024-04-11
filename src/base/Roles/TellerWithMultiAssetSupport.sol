// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {WETH} from "@solmate/tokens/WETH.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {BeforeTransferHook} from "src/interfaces/BeforeTransferHook.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {ReentrancyGuard} from "@solmate/utils/ReentrancyGuard.sol";

contract TellerWithMultiAssetSupport is Auth, BeforeTransferHook, ReentrancyGuard {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;
    using SafeTransferLib for WETH;

    // ========================================= CONSTANTS =========================================

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
     * @notice The deposit nonce used to map to a deposit hash.
     */
    uint96 public depositNonce = 1;

    /**
     * @notice After deposits, shares are locked to the msg.sender's address
     *         for `shareLockPeriod`.
     * @dev During this time all trasnfers from msg.sender will revert, and
     *      deposits are refundable.
     */
    uint64 public shareLockPeriod;

    /**
     * @notice Used to pause calls to `deposit` and `depositWithPermit`.
     */
    bool public isPaused;

    /**
     * @dev Maps deposit nonce to keccak256(address receiver, address depositAsset, uint256 depositAmount, uint256 shareAmount, uint256 timestamp, uint256 shareLockPeriod).
     */
    mapping(uint256 => bytes32) public publicDepositHistory;

    mapping(address => uint256) public shareUnlockTime;

    //============================== ERRORS ===============================

    error TellerWithMultiAssetSupport__ShareLockPeriodTooLong();
    error TellerWithMultiAssetSupport__SharesAreLocked();
    error TellerWithMultiAssetSupport__SharesAreUnLocked();
    error TellerWithMultiAssetSupport__BadDepositHash();
    error TellerWithMultiAssetSupport__AssetNotSupported();
    error TellerWithMultiAssetSupport__ZeroAssets();
    error TellerWithMultiAssetSupport__MinimumMintNotMet();
    error TellerWithMultiAssetSupport__MinimumAssetsNotMet();
    error TellerWithMultiAssetSupport__PermitFailedAndAllowanceTooLow();
    error TellerWithMultiAssetSupport__ZeroShares();
    error TellerWithMultiAssetSupport__DualDeposit();
    error TellerWithMultiAssetSupport__Paused();

    //============================== EVENTS ===============================

    event Paused();
    event Unpaused();
    event AssetAdded(address indexed asset);
    event AssetRemoved(address indexed asset);
    event Deposit(
        uint256 indexed nonce,
        address indexed receiver,
        address indexed depositAsset,
        uint256 depositAmount,
        uint256 shareAmount,
        uint256 depositTimestamp,
        uint256 shareLockPeriodAtTimeOfDeposit
    );
    event BulkDeposit(address indexed asset, uint256 depositAmount);
    event BulkWithdraw(address indexed asset, uint256 shareAmount);
    event DepositRefunded(uint256 indexed nonce, bytes32 depositHash, address indexed user);

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
        Auth(_owner, Authority(address(0)))
    {
        vault = BoringVault(payable(_vault));
        ONE_SHARE = 10 ** vault.decimals();
        accountant = AccountantWithRateProviders(_accountant);
        nativeWrapper = WETH(payable(_weth));
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Pause this contract, which prevents future calls to `deposit` and `depositWithPermit`.
     * @dev Callable by MULTISIG_ROLE.
     */
    function pause() external requiresAuth {
        isPaused = true;
        emit Paused();
    }

    /**
     * @notice Unpause this contract, which allows future calls to `deposit` and `depositWithPermit`.
     * @dev Callable by MULTISIG_ROLE.
     */
    function unpause() external requiresAuth {
        isPaused = false;
        emit Unpaused();
    }

    /**
     * @notice Adds this asset as a deposit asset.
     * @dev The accountant must also support pricing this asset, else the `deposit` call will revert.
     * @dev Callable by OWNER_ROLE.
     */
    function addAsset(ERC20 asset) external requiresAuth {
        isSupported[asset] = true;
        emit AssetAdded(address(asset));
    }

    /**
     * @notice Removes this asset as a deposit asset.
     * @dev Callable by OWNER_ROLE.
     */
    function removeAsset(ERC20 asset) external requiresAuth {
        isSupported[asset] = false;
        emit AssetRemoved(address(asset));
    }

    /**
     * @notice Sets the share lock period.
     * @dev This not only locks shares to the user address, but also serves as the pending deposit period, where deposits can be reverted.
     * @dev If a new shorter share lock period is set, users with pending share locks could make a new deposit to receive 1 wei shares,
     *      and have their shares unlock sooner than their original deposit allows. This state would allow for the user deposit to be refunded,
     *      but only if they have not transferred their shares out of there wallet. This is an accepted limitation, and should be known when decreasing
     *      the share lock period.
     * @dev Callable by OWNER_ROLE.
     */
    function setShareLockPeriod(uint64 _shareLockPeriod) external requiresAuth {
        if (_shareLockPeriod > MAX_SHARE_LOCK_PERIOD) revert TellerWithMultiAssetSupport__ShareLockPeriodTooLong();
        shareLockPeriod = _shareLockPeriod;
    }

    // ========================================= BeforeTransferHook FUNCTIONS =========================================

    /**
     * @notice Implement beforeTransfer hook to check if shares are locked.
     */
    function beforeTransfer(address from) external view {
        if (shareUnlockTime[from] >= block.timestamp) revert TellerWithMultiAssetSupport__SharesAreLocked();
    }

    // ========================================= REVERT DEPOSIT FUNCTIONS =========================================

    /**
     * @notice Allows DEPOSIT_REFUNDER_ROLE to revert a pending deposit.
     * @dev Once a deposit share lock period has passed, it can no longer be reverted.
     * @dev It is possible the admin does not setup the BoringVault to call the transfer hook,
     *      but this contract can still be saving share lock state. In the event this happens
     *      deposits are still refundable if the user has not transferred their shares.
     *      But there is no guarantee that the user has not transferred their shares.
     * @dev Callable by STRATEGIST_MULTISIG_ROLE.
     */
    function refundDeposit(
        uint256 nonce,
        address receiver,
        address depositAsset,
        uint256 depositAmount,
        uint256 shareAmount,
        uint256 depositTimestamp,
        uint256 shareLockUpPeriodAtTimeOfDeposit
    ) external requiresAuth {
        if ((block.timestamp - depositTimestamp) > shareLockUpPeriodAtTimeOfDeposit) {
            // Shares are already unlocked, so we can not revert deposit.
            revert TellerWithMultiAssetSupport__SharesAreUnLocked();
        }
        bytes32 depositHash = keccak256(
            abi.encode(
                receiver, depositAsset, depositAmount, shareAmount, depositTimestamp, shareLockUpPeriodAtTimeOfDeposit
            )
        );
        if (publicDepositHistory[nonce] != depositHash) revert TellerWithMultiAssetSupport__BadDepositHash();

        // Delete hash to prevent refund gas.
        delete publicDepositHistory[nonce];

        // If deposit used native asset, send user back wrapped native asset.
        depositAsset = depositAsset == NATIVE ? address(nativeWrapper) : depositAsset;
        // Burn shares and refund assets to receiver.
        vault.exit(receiver, ERC20(depositAsset), depositAmount, receiver, shareAmount);

        emit DepositRefunded(nonce, depositHash, receiver);
    }

    // ========================================= USER FUNCTIONS =========================================

    /**
     * @notice Allows users to deposit into the BoringVault, if this contract is not paused.
     * @dev Publicly callable.
     */
    function deposit(ERC20 depositAsset, uint256 depositAmount, uint256 minimumMint)
        external
        payable
        requiresAuth
        nonReentrant
        returns (uint256 shares)
    {
        if (isPaused) revert TellerWithMultiAssetSupport__Paused();
        if (!isSupported[depositAsset]) revert TellerWithMultiAssetSupport__AssetNotSupported();

        if (address(depositAsset) == NATIVE) {
            if (msg.value == 0) revert TellerWithMultiAssetSupport__ZeroAssets();
            nativeWrapper.deposit{value: msg.value}();
            depositAmount = msg.value;
            shares = depositAmount.mulDivDown(ONE_SHARE, accountant.getRateInQuoteSafe(nativeWrapper));
            if (shares < minimumMint) revert TellerWithMultiAssetSupport__MinimumMintNotMet();
            // `from` is address(this) since user already sent value.
            nativeWrapper.safeApprove(address(vault), depositAmount);
            vault.enter(address(this), nativeWrapper, depositAmount, msg.sender, shares);
        } else {
            if (msg.value > 0) revert TellerWithMultiAssetSupport__DualDeposit();
            shares = _erc20Deposit(depositAsset, depositAmount, minimumMint, msg.sender);
        }

        _afterPublicDeposit(msg.sender, depositAsset, depositAmount, shares, shareLockPeriod);
    }

    /**
     * @notice Allows users to deposit into BoringVault using permit.
     * @dev Publicly callable.
     */
    function depositWithPermit(
        ERC20 depositAsset,
        uint256 depositAmount,
        uint256 minimumMint,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external requiresAuth nonReentrant returns (uint256 shares) {
        if (isPaused) revert TellerWithMultiAssetSupport__Paused();
        if (!isSupported[depositAsset]) revert TellerWithMultiAssetSupport__AssetNotSupported();

        try depositAsset.permit(msg.sender, address(vault), depositAmount, deadline, v, r, s) {}
        catch {
            if (depositAsset.allowance(msg.sender, address(vault)) < depositAmount) {
                revert TellerWithMultiAssetSupport__PermitFailedAndAllowanceTooLow();
            }
        }
        shares = _erc20Deposit(depositAsset, depositAmount, minimumMint, msg.sender);

        _afterPublicDeposit(msg.sender, depositAsset, depositAmount, shares, shareLockPeriod);
    }

    /**
     * @notice Allows on ramp role to deposit into this contract.
     * @dev Does NOT support native deposits.
     * @dev Callable by SOLVER_ROLE.
     */
    function bulkDeposit(ERC20 depositAsset, uint256 depositAmount, uint256 minimumMint, address to)
        external
        requiresAuth
        nonReentrant
        returns (uint256 shares)
    {
        if (!isSupported[depositAsset]) revert TellerWithMultiAssetSupport__AssetNotSupported();

        shares = _erc20Deposit(depositAsset, depositAmount, minimumMint, to);
        emit BulkDeposit(address(depositAsset), depositAmount);
    }

    /**
     * @notice Allows off ramp role to withdraw from this contract.
     * @dev Callable by SOLVER_ROLE.
     */
    function bulkWithdraw(ERC20 withdrawAsset, uint256 shareAmount, uint256 minimumAssets, address to)
        external
        requiresAuth
        returns (uint256 assetsOut)
    {
        if (!isSupported[withdrawAsset]) revert TellerWithMultiAssetSupport__AssetNotSupported();

        if (shareAmount == 0) revert TellerWithMultiAssetSupport__ZeroShares();
        assetsOut = shareAmount.mulDivDown(accountant.getRateInQuoteSafe(withdrawAsset), ONE_SHARE);
        if (assetsOut < minimumAssets) revert TellerWithMultiAssetSupport__MinimumAssetsNotMet();
        vault.exit(to, withdrawAsset, assetsOut, msg.sender, shareAmount);
        emit BulkWithdraw(address(withdrawAsset), shareAmount);
    }

    // ========================================= INTERNAL HELPER FUNCTIONS =========================================

    /**
     * @notice Implements a common ERC20 deposit into BoringVault.
     */
    function _erc20Deposit(ERC20 depositAsset, uint256 depositAmount, uint256 minimumMint, address to)
        internal
        returns (uint256 shares)
    {
        if (depositAmount == 0) revert TellerWithMultiAssetSupport__ZeroAssets();
        shares = depositAmount.mulDivDown(ONE_SHARE, accountant.getRateInQuoteSafe(depositAsset));
        if (shares < minimumMint) revert TellerWithMultiAssetSupport__MinimumMintNotMet();
        vault.enter(msg.sender, depositAsset, depositAmount, to, shares);
    }

    /**
     * @notice Handle share lock logic, and event.
     */
    function _afterPublicDeposit(
        address user,
        ERC20 depositAsset,
        uint256 depositAmount,
        uint256 shares,
        uint256 currentShareLockPeriod
    ) internal {
        shareUnlockTime[user] = block.timestamp + currentShareLockPeriod;

        uint256 nonce = depositNonce;
        publicDepositHistory[nonce] =
            keccak256(abi.encode(user, depositAsset, depositAmount, shares, block.timestamp, currentShareLockPeriod));
        depositNonce++;
        emit Deposit(nonce, user, address(depositAsset), depositAmount, shares, block.timestamp, currentShareLockPeriod);
    }
}
