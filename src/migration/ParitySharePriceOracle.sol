// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {ERC4626} from "lib/solmate/src/tokens/ERC4626.sol";

/**
 * @notice This contract is intended to be used to price a Cellar's shares after it has undergone a migration to a BoringVault
 *         using `CellarMigratorWithSharePriceParity`.
 * @dev In order for this parity to be true, the Cellar must have ALL of its TVL in the BoringVault.
 */
contract ParitySharePriceOracle {
    /**
     * @notice The number of decimals of the accountant.
     */
    uint8 public immutable decimals;

    /**
     * @notice The Cellar that was migrated to a BoringVault.
     */
    ERC4626 public immutable target;

    /**
     * @notice The accountant of the BoringVault.
     */
    AccountantWithRateProviders public immutable accountant;

    constructor(address _target, address _accountant) {
        target = ERC4626(_target);
        accountant = AccountantWithRateProviders(_accountant);

        decimals = accountant.decimals();

        // Make sure that the target.asset() and accountant.base() match.
        require(target.asset() == accountant.base(), "ASSET_MISMATCH");
    }

    /**
     * @notice Implement the `getLatest` function Cellar's use during user entry/exit.
     * @dev If the accountant is pausd, then Cellar will revert with an oracle failure.
     */
    function getLatest() external view returns (uint256, uint256, bool) {
        (,,, uint96 answer,,,, bool isPaused,,) = accountant.accountantState();
        return (answer, answer, isPaused);
    }
}
