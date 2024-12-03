// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract SoniceDecoderAndSanitizer is BaseDecoderAndSanitizer {

    function depositBudget(uint256 /*amount*/) external virtual pure returns(bytes memory addressesFound) {
        return addressesFound;
    }
}
