// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract AuraDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== AURA ===============================

    function getReward(address _user, bool) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_user);
    }
}
