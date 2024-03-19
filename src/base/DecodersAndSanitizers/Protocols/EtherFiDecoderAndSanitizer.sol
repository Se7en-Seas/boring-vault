// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract EtherFiDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== ETHERFI ===============================

    function deposit() external pure virtual returns (address[] memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function wrap(uint256) external pure virtual returns (address[] memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function unwrap(uint256) external pure virtual returns (address[] memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function requestWithdraw(address _addr, uint256) external pure virtual returns (address[] memory addressesFound) {
        addressesFound = new address[](1);
        addressesFound[0] = _addr;
    }
}
