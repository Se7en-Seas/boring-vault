/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.0;

import '../common/ITBContractDecoderAndSanitizer.sol';

abstract contract GearboxDecoderAndSanitizer is ITBContractDecoderAndSanitizer {
    function deposit(uint, uint) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function withdrawSupply(uint, uint) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function stake(uint) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function unstake(uint) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }
}
