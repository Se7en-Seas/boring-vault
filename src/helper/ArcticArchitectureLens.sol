pragma solidity 0.8.21;

import {BoringVault, ERC20} from "src/base/BoringVault.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

contract ArcticArchitectureLens {
    using FixedPointMathLib for uint256;

    /**
     * @dev Calculates the total assets held in the BoringVault for a given vault and accountant.
     * @param boringVault The BoringVault contract.
     * @param accountant The AccountantWithRateProviders contract.
     * @return asset The ERC20 asset, `assets` is given in terms of.
     * @return assets The total assets held in the vault.
     */
    function totalAssets(BoringVault boringVault, AccountantWithRateProviders accountant)
        external
        view
        returns (ERC20 asset, uint256 assets)
    {
        uint256 totalSupply = boringVault.totalSupply();
        uint256 rate = accountant.getRate();
        uint8 shareDecimals = boringVault.decimals();
        asset = accountant.base();

        assets = totalSupply.mulDivDown(rate, 10 ** shareDecimals);
    }

    /**
     * @dev Calculates the number of shares that will be received for a given deposit amount in the BoringVault.
     * @param depositAsset The ERC20 asset being deposited.
     * @param depositAmount The amount of the asset being deposited.
     * @param boringVault The BoringVault contract.
     * @param accountant The AccountantWithRateProviders contract.
     * @return shares The number of shares that will be received.
     */
    function previewDeposit(
        ERC20 depositAsset,
        uint256 depositAmount,
        BoringVault boringVault,
        AccountantWithRateProviders accountant
    ) external view returns (uint256 shares) {
        uint8 shareDecimals = boringVault.decimals();

        shares = depositAmount.mulDivDown(10 ** shareDecimals, accountant.getRateInQuote(depositAsset));
    }

    /**
     * @dev Retrieves the balance of shares for a given account in the BoringVault.
     * @param account The address of the account.
     * @param boringVault The BoringVault contract.
     * @return shares The balance of shares for the account.
     */
    function balanceOf(address account, BoringVault boringVault) external view returns (uint256 shares) {
        shares = boringVault.balanceOf(account);
    }

    /**
     * @dev Calculates the balance of a user in terms of asset for a given account in the BoringVault.
     * @param account The address of the account.
     * @param boringVault The BoringVault contract.
     * @param accountant The AccountantWithRateProviders contract.
     * @return assets The balance of assets for the account.
     */
    function balanceOfInAssets(address account, BoringVault boringVault, AccountantWithRateProviders accountant)
        external
        view
        returns (uint256 assets)
    {
        uint256 shares = boringVault.balanceOf(account);
        uint256 rate = accountant.getRate();
        uint8 shareDecimals = boringVault.decimals();

        assets = shares.mulDivDown(rate, 10 ** shareDecimals);
    }

    /**
     * @dev Retrieves the current exchange rate from the AccountantWithRateProviders contract.
     * @param accountant The AccountantWithRateProviders contract.
     * @return rate The current exchange rate.
     */
    function exchangeRate(AccountantWithRateProviders accountant) external view returns (uint256 rate) {
        rate = accountant.getRate();
    }

    /**
     * @dev Checks if a user's deposit meets certain conditions.
     * @param account The address of the user.
     * @param depositAsset The ERC20 asset being deposited.
     * @param depositAmount The amount of the asset being deposited.
     * @param boringVault The BoringVault contract.
     * @param teller The TellerWithMultiAssetSupport contract.
     * @return A boolean indicating if the user's deposit meets the conditions.
     */
    function checkUserDeposit(
        address account,
        ERC20 depositAsset,
        uint256 depositAmount,
        BoringVault boringVault,
        TellerWithMultiAssetSupport teller
    ) external view returns (bool) {
        if (depositAsset.balanceOf(account) < depositAmount) return false;
        if (depositAsset.allowance(account, address(boringVault)) < depositAmount) return false;
        if (teller.isPaused()) return false;
        if (!teller.isSupported(depositAsset)) return false;
        return true;
    }

    /**
     * @dev Checks if a user's deposit (with permit) meets certain conditions.
     * @param account The address of the user.
     * @param depositAsset The ERC20 asset being deposited.
     * @param depositAmount The amount of the asset being deposited.
     * @param teller The TellerWithMultiAssetSupport contract.
     * @return A boolean indicating if the user's deposit meets the conditions.
     */
    function checkUserDepositWithPermit(
        address account,
        ERC20 depositAsset,
        uint256 depositAmount,
        TellerWithMultiAssetSupport teller
    ) external view returns (bool) {
        if (depositAsset.balanceOf(account) < depositAmount) return false;
        if (teller.isPaused()) return false;
        if (!teller.isSupported(depositAsset)) return false;
        return true;
    }

    /**
     * @dev Retrieves the unlock time for a user's shares in the TellerWithMultiAssetSupport contract.
     * @param account The address of the user.
     * @param teller The TellerWithMultiAssetSupport contract.
     * @return time The unlock time for the user's shares.
     */
    function userUnlockTime(address account, TellerWithMultiAssetSupport teller) external view returns (uint256 time) {
        time = teller.shareUnlockTime(account);
    }

    /**
     * @notice Checks if the TellerWithMultiAssetDepositSupport contract is paused.
     */
    function isTellerPaused(TellerWithMultiAssetSupport teller) external view returns (bool) {
        return teller.isPaused();
    }
}
