// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {EtherFiLiquid1} from "src/interfaces/EtherFiLiquid1.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

contract CellarMigrationAdaptor {
    using SafeTransferLib for ERC20;
    using SafeTransferLib for BoringVault;
    using FixedPointMathLib for uint256;

    /**
     * @notice Attempted to specify an external receiver during a Cellar `callOnAdaptor` call.
     */
    error CellarMigrationAdaptor__ExternalReceiverBlocked();

    /**
     * @notice Attempted to deposit to a position where user deposits were not allowed.
     */
    error CellarMigrationAdaptor__UserDepositsNotAllowed();

    /**
     * @notice Attempted to withdraw from a position where user withdraws were not allowed.
     */
    error CellarMigrationAdaptor__UserWithdrawsNotAllowed();

    BoringVault internal immutable boringVault;
    AccountantWithRateProviders internal immutable accountant;
    TellerWithMultiAssetSupport internal immutable teller;

    constructor(address _boringVault, address _accountant, address _teller) {
        boringVault = BoringVault(payable(_boringVault));
        accountant = AccountantWithRateProviders(_accountant);
        teller = TellerWithMultiAssetSupport(payable(_teller));
    }

    //============================================ Global Functions ===========================================
    /**
     * @dev Identifier unique to this adaptor for a shared registry.
     * Normally the identifier would just be the address of this contract, but this
     * Identifier is needed during Cellar Delegate Call Operations, so getting the address
     * of the adaptor is more difficult.
     */
    function identifier() public pure virtual returns (bytes32) {
        return keccak256(abi.encode("Cellar Migration Adaptor V 0.0"));
    }

    //============================================ Implement Base Functions ===========================================
    //==================== Base Function Specification ====================
    // Base functions are functions designed to help the Cellar interact with
    // an adaptor position, strategists are not intended to use these functions.
    // Base functions MUST be implemented in adaptor contracts, even if that is just
    // adding a revert statement to make them uncallable by normal user operations.
    //
    // All view Base functions will be called used normal staticcall.
    // All mutative Base functions will be called using delegatecall.
    //=====================================================================
    /**
     * @notice Function Cellars call to deposit users funds into holding position.
     */
    function deposit(uint256, bytes memory, bytes memory) public virtual {
        revert CellarMigrationAdaptor__UserDepositsNotAllowed();
    }

    /**
     * @notice Function Cellars call to withdraw funds from positions to send to users.
     * @param assets in terms of accountant's base asset
     * @param receiver the address that should receive withdrawn funds
     */
    function withdraw(uint256 assets, address receiver, bytes memory, bytes memory configurationData) public virtual {
        _externalReceiverCheck(receiver);

        bool isLiquid = abi.decode(configurationData, (bool));
        if (!isLiquid) revert CellarMigrationAdaptor__UserWithdrawsNotAllowed();

        uint256 rate = accountant.getRate();

        // We need to divide assets by rate, since Cellar is requesting assets in terms of Base, not the BoringVault Share.
        assets = assets.mulDivDown(10 ** accountant.decimals(), rate);

        // Transfer shares to user.
        boringVault.safeTransfer(receiver, assets);
    }

    /**
     * @notice Function Cellars use to determine `assetOf` balance of an adaptor position.
     * @return assets of the position in terms of `assetOf`
     */
    function balanceOf(bytes memory) public view virtual returns (uint256) {
        uint256 rate = accountant.getRate();
        uint256 assets = boringVault.balanceOf(msg.sender).mulDivDown(rate, 10 ** accountant.decimals());
        return assets;
    }

    /**
     * @notice Functions Cellars use to determine the withdrawable balance from an adaptor position.
     * @dev Debt positions MUST return 0 for their `withdrawableFrom`
     * @notice accepts adaptorData and configurationData
     * @return withdrawable balance of the position in terms of `assetOf`
     */
    function withdrawableFrom(bytes memory, bytes memory configurationData) public view virtual returns (uint256) {
        bool isLiquid = abi.decode(configurationData, (bool));
        if (isLiquid) {
            uint256 rate = accountant.getRate();
            uint256 withdrawable = boringVault.balanceOf(msg.sender).mulDivDown(rate, 10 ** accountant.decimals());
            return withdrawable;
        } else {
            return 0;
        }
    }

    /**
     * @notice Function Cellars use to determine the underlying ERC20 asset of a position.
     * @return the underlying ERC20 asset of a position
     */
    function assetOf(bytes memory) public view virtual returns (ERC20) {
        return accountant.base();
    }

    /**
     * @notice When positions are added to the Registry, this function can be used in order to figure out
     *         what assets this adaptor needs to price, and confirm pricing is properly setup.
     */
    function assetsUsed(bytes memory adaptorData) public view virtual returns (ERC20[] memory assets) {
        assets = new ERC20[](1);
        assets[0] = assetOf(adaptorData);
    }

    /**
     * @notice Functions Registry/Cellars use to determine if this adaptor reports debt values.
     * @dev returns true if this adaptor reports debt values.
     */
    function isDebt() public view virtual returns (bool) {
        return false;
    }

    //============================================ Strategist Functions ===========================================

    /**
     * @notice Allows strategist to perform a bulkDeposit into Teller.
     */
    function deposit(ERC20 depositAsset, uint256 depositAmount, uint256 minimumMint) external {
        depositAmount = _maxAvailable(depositAsset, depositAmount);
        depositAsset.safeApprove(address(boringVault), depositAmount);
        teller.bulkDeposit(depositAsset, depositAmount, minimumMint, address(this));
        _revokeExternalApproval(depositAsset, address(boringVault));
    }

    /**
     * @notice Allows strategist to perform a bulkWithdraw from Teller.
     */
    function withdraw(ERC20 withdrawAsset, uint256 shareAmount, uint256 minimumAssets) external {
        teller.bulkWithdraw(withdrawAsset, shareAmount, minimumAssets, address(this));
    }

    //============================================ Helper Functions ===========================================
    /**
     * @notice Helper function that allows adaptor calls to use the max available of an ERC20 asset
     * by passing in type(uint256).max
     * @param token the ERC20 asset to work with
     * @param amount when `type(uint256).max` is used, this function returns `token`s `balanceOf`
     * otherwise this function returns amount.
     */
    function _maxAvailable(ERC20 token, uint256 amount) internal view virtual returns (uint256) {
        if (amount == type(uint256).max) return token.balanceOf(address(this));
        else return amount;
    }

    /**
     * @notice Helper function that checks if `spender` has any more approval for `asset`, and if so revokes it.
     */
    function _revokeExternalApproval(ERC20 asset, address spender) internal {
        if (asset.allowance(address(this), spender) > 0) asset.safeApprove(spender, 0);
    }

    /**
     * @notice Helper function that validates external receivers are allowed.
     */
    function _externalReceiverCheck(address receiver) internal view {
        if (receiver != address(this) && EtherFiLiquid1(address(this)).blockExternalReceiver()) {
            revert CellarMigrationAdaptor__ExternalReceiverBlocked();
        }
    }
}
