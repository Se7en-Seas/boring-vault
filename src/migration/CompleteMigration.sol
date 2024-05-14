// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {BoringVault, ERC20} from "src/base/BoringVault.sol";
import {ERC4626} from "lib/solmate/src/tokens/ERC4626.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

contract CompleteMigration {
    using FixedPointMathLib for uint256;

    constructor(BoringVault bv, ERC4626 v1, AccountantWithRateProviders accountant) {
        // Once all assets have been migrated from v1 to the bv, in order to make the share price identical,
        // v1 must hold the same amount of bv shares, as its total supply.
        uint256 v1TotalSupply = v1.totalSupply();
        uint256 v1BvShares = bv.balanceOf(address(v1));
        uint256 bvTotalSupply = bv.totalSupply();
        uint8 v1Decimals = v1.decimals();
        uint256 startingSharePrice = v1.totalAssets().mulDivDown(10 ** v1Decimals, v1TotalSupply);

        // Require that BoringVault shares are only owned by the v1 contract.
        require(bvTotalSupply == v1BvShares, "TS");

        // Update accountants exchange rate.
        accountant.updateExchangeRate(uint96(startingSharePrice));

        // Update V1's BoringVault share amount to keep share price constant.
        if (v1BvShares < v1TotalSupply) {
            // If v1 has less bv shares than its total supply, mint the difference.
            bv.enter(address(0), ERC20(address(0)), 0, address(v1), v1TotalSupply - v1BvShares);
        } else if (v1BvShares > v1TotalSupply) {
            // If v1 has more bv shares than its total supply, burn the difference.
            bv.exit(address(0), ERC20(address(0)), 0, address(v1), v1BvShares - v1TotalSupply);
        }

        // Make sure that the total supply of v1 matches the bv balance of v1.
        require(v1TotalSupply == bv.balanceOf(address(v1)), "BAL");

        // Make sure share price matches with a +- 1 wei difference.
        uint256 currentSharePrice = v1.totalAssets().mulDivDown(10 ** v1Decimals, v1TotalSupply);
        require(
            (currentSharePrice + 1 == startingSharePrice) || (currentSharePrice - 1 == startingSharePrice)
                || (currentSharePrice == startingSharePrice),
            "SP"
        );
    }
}
