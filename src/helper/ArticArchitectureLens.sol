// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BoringVault, ERC20} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
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
        BoringVault boringVault,
        AccountantWithRateProviders accountant,
        ERC20 depositAsset,
        uint256 depositAmount
    ) external view returns (uint256 shares) {
        uint8 shareDecimals = boringVault.decimals();

        shares = depositAmount.mulDivDown(10 ** shareDecimals, accountant.getRateInQuote(depositAsset));
    }

    function balanceOf(address account) external view returns (uint256 shares) {}
    function balanceOfInAssets(address account) external view returns (uint256 assets) {}
    function pendingBalanceOf(address account) external view returns (uint256 shares) {}
    // useful for net value
    function pendingBalanceOfInAssets(address account) external view returns (uint256 assets) {}
    function exchangeRate() external view returns (uint256 rate) {}
    // Functions check if contract is paused, if deposit asset is good, and if users allowance is good, also user balance
    function checkUserDeposit() external view returns (bool) {}
    function checkUserDepositWithPermit() external view returns (bool) {}
    // when user shares are unlocked
    function userUnlockTime() external view returns (uint256) {}
}
