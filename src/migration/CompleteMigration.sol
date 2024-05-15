// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {BoringVault, ERC20} from "src/base/BoringVault.sol";
import {ERC4626} from "lib/solmate/src/tokens/ERC4626.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

contract CompleteMigration {
    using FixedPointMathLib for uint256;

    BoringVault internal immutable boringVault;
    AccountantWithRateProviders internal immutable accountant;
    ERC4626 internal immutable target;
    address internal immutable migrator;

    constructor(BoringVault bv, ERC4626 v1, AccountantWithRateProviders _accountant, address _migrator) {
        boringVault = bv;
        target = v1;
        accountant = _accountant;
        migrator = _migrator;
    }

    function completeMigration(bool checkIfCellarOwnsAllShares) external {
        require(msg.sender == migrator, "MIGRATOR");
        // Once all assets have been migrated from v1 to the bv, in order to make the share price identical,
        // v1 must hold the same amount of bv shares, as its total supply.
        uint256 targetTotalSupply = target.totalSupply();
        uint256 targetBvShares = boringVault.balanceOf(address(target));
        uint8 targetDecimals = target.decimals();
        uint256 startingSharePrice = target.totalAssets().mulDivDown(10 ** targetDecimals, targetTotalSupply);

        // Update accountants exchange rate.
        accountant.updateExchangeRate(uint96(startingSharePrice));

        if (checkIfCellarOwnsAllShares) {
            // Make sure that Cellar owns all shares of the target.
            require(targetBvShares == boringVault.totalSupply(), "SH");
        }

        // Update target's BoringVault share amount to keep share price constant.
        if (targetBvShares < targetTotalSupply) {
            // If target has less bv shares than its total supply, mint the difference.
            boringVault.enter(address(0), ERC20(address(0)), 0, address(target), targetTotalSupply - targetBvShares);
        } else if (targetBvShares > targetTotalSupply) {
            // If target has more bv shares than its total supply, burn the difference.
            boringVault.exit(address(0), ERC20(address(0)), 0, address(target), targetBvShares - targetTotalSupply);
        }

        // Make sure that the total supply of target matches the bv balance of target.
        require(targetTotalSupply == boringVault.balanceOf(address(target)), "BAL");

        // Make sure share price matches with a +- 1 wei difference.
        uint256 currentSharePrice = target.totalAssets().mulDivDown(10 ** targetDecimals, targetTotalSupply);
        require(
            (currentSharePrice + 1 == startingSharePrice) || (currentSharePrice - 1 == startingSharePrice)
                || (currentSharePrice == startingSharePrice),
            "SP"
        );
        selfdestruct(payable(migrator));
    }
}
