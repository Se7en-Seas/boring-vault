// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract SwellDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== SWELL ===============================

    // Call swETH
    function deposit() external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    // Call swEXIT 0x48C11b86807627AF70a34662D4865cF854251663
    function createWithdrawRequest(uint256 /*amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    // Call swEXIT 0x48C11b86807627AF70a34662D4865cF854251663
    function finalizeWithdrawal(uint256 /*tokenId*/ ) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }
}
