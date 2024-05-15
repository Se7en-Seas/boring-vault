// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {CellarMigrationAdaptor} from "./CellarMigrationAdaptor.sol";

/**
 * This adaptors only job is to use a unique identifer, so that 2 identical positions can be added to the registry.
 */
contract CellarMigrationAdaptor2 is CellarMigrationAdaptor {
    constructor(address _boringVault, address _accountant, address _teller)
        CellarMigrationAdaptor(_boringVault, _accountant, _teller)
    {}

    //============================================ Global Functions ===========================================
    /**
     * @dev Identifier unique to this adaptor for a shared registry.
     * Normally the identifier would just be the address of this contract, but this
     * Identifier is needed during Cellar Delegate Call Operations, so getting the address
     * of the adaptor is more difficult.
     */
    function identifier() public pure override returns (bytes32) {
        return keccak256(abi.encode("Cellar Migration Adaptor 2 V 0.0"));
    }
}
