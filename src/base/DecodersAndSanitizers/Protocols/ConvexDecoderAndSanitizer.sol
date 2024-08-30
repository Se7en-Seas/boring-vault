// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract ConvexDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== CONVEX ===============================

    function deposit(uint256, uint256, bool) external view virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function withdrawAndUnwrap(uint256, bool) external view virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function getReward(address _addr, bool) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_addr);
    }
}
