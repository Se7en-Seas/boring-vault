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

contract TellerWithMultiAssetSupport is AccessControlDefaultAdminRules {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;
    // This contract will be in charge of mint and redeem
    // Somm governance will have nothing to do with this one.

    bytes32 public constant ON_RAMP_ROLE = keccak256("ON_RAMP_ROLE"); // bulk user deposits
    bytes32 public constant OFF_RAMP_ROLE = keccak256("OFF_RAMP_ROLE"); // bulk user withdraws with no waiting period.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE"); // can turn off normal user deposits and withdraws
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    BoringVault public immutable vault;
    AccountantWithRateProviders public immutable accountant;
    uint256 internal immutable ONE_SHARE;
    WETH public immutable native_wrapper;

    constructor(address _owner, address _vault, address _accountant, address _weth)
        AccessControlDefaultAdminRules(3 days, _owner)
    {
        vault = BoringVault(payable(_vault));
        ONE_SHARE = 10 ** vault.decimals();
        accountant = AccountantWithRateProviders(_accountant);
        native_wrapper = WETH(payable(_weth));
    }

    // Roles
    // a strategist that can turn off normal user deposits and withdraws, and finalize user withdraws
    // an entity that can do bulk deposit and withdraws with no waiting period, Atomic Queue solver.

    mapping(ERC20 => bool) public is_supported;

    // normal depsits
    bool public is_paused;

    function pause() external onlyRole(ADMIN_ROLE) {
        is_paused = true;
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        is_paused = false;
    }

    function addAsset(ERC20 asset) external onlyRole(ADMIN_ROLE) {
        is_supported[asset] = true;
    }

    function removeAsset(ERC20 asset) external onlyRole(ADMIN_ROLE) {
        is_supported[asset] = false;
    }

    // For user functions add min share out values
    function deposit(ERC20 deposit_asset, uint256 deposit_amount, uint256 minimum_mint, address to)
        public
        payable
        returns (uint256 shares)
    {
        require(!is_paused, "paused");
        require(is_supported[deposit_asset], "asset not supported");

        if (address(deposit_asset) == NATIVE) {
            require(msg.value > 0, "zero deposit");
            native_wrapper.deposit{value: msg.value}();
            deposit_amount = msg.value;
            shares = deposit_amount.mulDivDown(ONE_SHARE, accountant.getRateInQuoteSafe(native_wrapper));
            require(shares > minimum_mint, "minimum_mint");
            // `from` is this address since user already sent value.
            ERC20(address(native_wrapper)).safeApprove(address(vault), deposit_amount);
            vault.enter(address(this), native_wrapper, deposit_amount, to, shares);
        } else {
            require(deposit_amount > 0, "zero deposit");
            require(msg.value == 0, "dual deposit");
            shares = deposit_amount.mulDivDown(ONE_SHARE, accountant.getRateInQuoteSafe(deposit_asset));
            require(shares > minimum_mint, "minimum_mint");
            vault.enter(msg.sender, deposit_asset, deposit_amount, to, shares);
        }
    }

    /**
     * @notice Does NOT support native deposits.
     */
    function bulkDeposit(ERC20 deposit_asset, uint256 deposit_amount, uint256 minimum_mint, address to)
        external
        onlyRole(ON_RAMP_ROLE)
        returns (uint256 shares)
    {
        require(deposit_amount > 0, "zero deposit");
        shares = deposit_amount.mulDivDown(ONE_SHARE, accountant.getRateInQuoteSafe(deposit_asset));
        require(shares > minimum_mint, "minimum_mint");
        vault.enter(msg.sender, deposit_asset, deposit_amount, to, shares);
    }

    function bulkWithdraw(ERC20 withdraw_asset, uint256 share_amount, uint256 minimum_assets, address to)
        external
        onlyRole(OFF_RAMP_ROLE)
        returns (uint256 assets_out)
    {
        require(share_amount > 0, "zero withdraw");
        assets_out = share_amount.mulDivDown(accountant.getRateInQuoteSafe(withdraw_asset), ONE_SHARE);
        require(assets_out > minimum_assets, "minimum_assets");
        vault.exit(to, withdraw_asset, assets_out, msg.sender, share_amount);
    }

    // WARNING depositing this way means users can not set a min value out.
    receive() external payable {
        deposit(ERC20(NATIVE), msg.value, 0, msg.sender);
    }
}
