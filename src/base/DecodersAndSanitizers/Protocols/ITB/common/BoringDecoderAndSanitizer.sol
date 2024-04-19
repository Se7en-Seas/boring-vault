// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BoringDecoderAndSanitizer {
    //============================== IMMUTABLES ===============================

    /**
     * @notice The BoringVault contract address.
     */
    address internal immutable boringVault;

    constructor(address _boringVault) {
        boringVault = _boringVault;
    }

    function approve(address spender, uint) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(spender);
    }
}