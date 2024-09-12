/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.0;

import "../common/ITBContractDecoderAndSanitizer.sol";

abstract contract SyrupDecoderAndSanitizer is ITBContractDecoderAndSanitizer {
    function updatePositionConfig(address _syrup_router, bytes32) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_syrup_router);
    }

    function deposit(uint256, bytes32) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function startWithdrawal(uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function assemble() external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function disassemble(uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function fullDisassemble() external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }
}
