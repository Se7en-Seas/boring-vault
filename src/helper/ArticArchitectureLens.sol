// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BoringVault, ERC20} from "src/base/BoringVault.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

contract ArticArchitectureLens {
    using FixedPointMathLib for uint256;

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

    function previewDeposit(
        ERC20 depositAsset,
        uint256 depositAmount,
        BoringVault boringVault,
        AccountantWithRateProviders accountant
    ) external view returns (uint256 shares) {
        uint8 shareDecimals = boringVault.decimals();

        shares = depositAmount.mulDivDown(10 ** shareDecimals, accountant.getRateInQuote(depositAsset));
    }

    function balanceOf(address account, BoringVault boringVault) external view returns (uint256 shares) {
        shares = boringVault.balanceOf(account);
    }

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

    function exchangeRate(AccountantWithRateProviders accountant) external view returns (uint256 rate) {
        rate = accountant.getRate();
    }
    // Functions check if contract is paused, if deposit asset is good, and if users allowance is good, also user balance

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

    function userUnlockTime(address account, TellerWithMultiAssetSupport teller) external view returns (uint256 time) {
        time = teller.shareUnlockTime(account);
    }
}
