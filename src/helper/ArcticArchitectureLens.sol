pragma solidity 0.8.21;

import {BoringVault, ERC20} from "src/base/BoringVault.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {DelayedWithdraw} from "src/base/Roles/DelayedWithdraw.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract ArcticArchitectureLens {
    using FixedPointMathLib for uint256;
    using Address for address;

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
        (bool allowDeposits,,) = teller.assetData(depositAsset);
        if (!allowDeposits) return false;
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
        (bool allowDeposits,,) = teller.assetData(depositAsset);
        if (!allowDeposits) return false;
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

    /**
     */
    function getWithdrawAssetAndWithdrawRequest(ERC20 asset, address account, DelayedWithdraw delayedWithdraw)
        public
        view
        returns (DelayedWithdraw.WithdrawAsset memory withdrawAsset, DelayedWithdraw.WithdrawRequest memory req)
    {
        (
            withdrawAsset.allowWithdraws,
            withdrawAsset.withdrawDelay,
            withdrawAsset.completionWindow,
            withdrawAsset.outstandingShares,
            withdrawAsset.withdrawFee,
            withdrawAsset.maxLoss
        ) = delayedWithdraw.withdrawAssets(asset);
        (req.allowThirdPartyToComplete, req.maxLoss, req.maturity, req.shares, req.exchangeRateAtTimeOfRequest) =
            delayedWithdraw.withdrawRequests(account, asset);
    }

    function getWithdrawAssetAndWithdrawRequests(
        ERC20[] calldata assets,
        address[] calldata accounts,
        DelayedWithdraw delayedWithdraw
    )
        external
        view
        returns (DelayedWithdraw.WithdrawAsset[] memory withdrawAssets, DelayedWithdraw.WithdrawRequest[] memory reqs)
    {
        uint256 assetsLength = assets.length;
        withdrawAssets = new DelayedWithdraw.WithdrawAsset[](assetsLength);
        reqs = new DelayedWithdraw.WithdrawRequest[](assetsLength);

        for (uint256 i = 0; i < assetsLength; i++) {
            (withdrawAssets[i], reqs[i]) = getWithdrawAssetAndWithdrawRequest(assets[i], accounts[i], delayedWithdraw);
        }
    }

    struct PreviewWithdrawResult {
        uint256 assetsOut;
        bool withdrawsNotAllowed;
        bool withdrawNotMatured;
        bool noShares;
        bool maxLossExceeded;
        bool notEnoughAssetsForWithdraw;
    }

    /**
     * @notice Helper function to preview a users withdraw for a specific asset.
     */
    function previewWithdraw(
        ERC20 asset,
        address account,
        BoringVault boringVault,
        AccountantWithRateProviders accountant,
        DelayedWithdraw delayedWithdraw
    ) public view returns (PreviewWithdrawResult memory res) {
        // Not all DelayedWithdraw contracts support pullFundsFromVault,
        // so use staticcall to query it.
        bool pullFundsFromVault = true;
        {
            (bool success, bytes memory result) =
                address(delayedWithdraw).staticcall(abi.encodeWithSignature("pullFundsFromVault()"));
            if (success && !abi.decode(result, (bool))) {
                pullFundsFromVault = false;
            }
        }

        (DelayedWithdraw.WithdrawAsset memory withdrawAsset, DelayedWithdraw.WithdrawRequest memory req) =
            getWithdrawAssetAndWithdrawRequest(asset, account, delayedWithdraw);

        if (!withdrawAsset.allowWithdraws) res.withdrawsNotAllowed = true;

        if (block.timestamp < req.maturity) res.withdrawNotMatured = true;
        if (req.shares == 0) res.noShares = true;

        uint256 currentExchangeRate = accountant.getRateInQuoteSafe(asset);

        uint256 minRate = req.exchangeRateAtTimeOfRequest < currentExchangeRate
            ? req.exchangeRateAtTimeOfRequest
            : currentExchangeRate;
        uint256 maxRate = req.exchangeRateAtTimeOfRequest < currentExchangeRate
            ? currentExchangeRate
            : req.exchangeRateAtTimeOfRequest;

        // If user has set a maxLoss use that, otherwise use the global maxLoss.
        uint16 maxLoss = req.maxLoss > 0 ? req.maxLoss : withdrawAsset.maxLoss;

        // Make sure minRate * maxLoss is greater than or equal to maxRate.
        if (minRate.mulDivDown(1e4 + maxLoss, 1e4) < maxRate) res.maxLossExceeded = true;

        uint256 shares = req.shares;

        if (withdrawAsset.withdrawFee > 0) {
            // Handle withdraw fee.
            uint256 fee = uint256(shares).mulDivDown(withdrawAsset.withdrawFee, 1e4);
            shares -= fee;
        }

        // Calculate assets out.
        res.assetsOut = shares.mulDivDown(minRate, 10 ** boringVault.decimals());

        if (pullFundsFromVault) {
            if (asset.balanceOf(address(boringVault)) < res.assetsOut) {
                res.notEnoughAssetsForWithdraw = true;
            }
        } else {
            if (asset.balanceOf(address(this)) < res.assetsOut) {
                res.notEnoughAssetsForWithdraw = true;
            }
        }
    }

    /**
     * @notice Helper function to preview a multiple users withdraw for multiple assets.
     */
    function previewWithdraws(
        ERC20[] calldata assets,
        address[] calldata accounts,
        BoringVault boringVault,
        AccountantWithRateProviders accountant,
        DelayedWithdraw delayedWithdraw
    ) external view returns (PreviewWithdrawResult[] memory res) {
        uint256 assetsLength = assets.length;
        res = new PreviewWithdrawResult[](assetsLength);

        for (uint256 i = 0; i < assetsLength; i++) {
            res[i] = previewWithdraw(assets[i], accounts[i], boringVault, accountant, delayedWithdraw);
        }
    }
}
