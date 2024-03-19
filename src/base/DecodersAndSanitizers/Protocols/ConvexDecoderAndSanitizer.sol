// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract ConvexDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== CONVEX ===============================

    function deposit(uint256, uint256, bool) external view virtual returns (address[] memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function withdrawAndUnwrap(uint256, bool) external view virtual returns (address[] memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function getReward(address _addr, bool) external pure virtual returns (address[] memory addressesFound) {
        addressesFound = new address[](1);
        addressesFound[0] = _addr;
    }
}
