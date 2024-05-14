// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {ERC4626} from "lib/solmate/src/tokens/ERC4626.sol";

contract MigrationSharePriceOracle {
    uint8 public constant decimals = 18;
    ERC4626 public immutable target;
    AccountantWithRateProviders public immutable accountant;

    constructor(address _target, address _accountant) {
        target = ERC4626(_target);
        accountant = AccountantWithRateProviders(_accountant);

        // Make sure that the target.asset() and accountant.base() match.
        require(target.asset() == accountant.base(), "ASSET_MISMATCH");
    }

    function getLatest() external view returns (uint256, uint256, bool) {
        (,,, uint96 answer,,,, bool isPaused,,) = accountant.accountantState();
        return (answer, answer, isPaused);
    }
}
