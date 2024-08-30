// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {CamelotDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CamelotDecoderAndSanitizer.sol";

contract CamelotFullDecoderAndSanitizer is CamelotDecoderAndSanitizer {
    constructor(address _boringVault, address _camelotNonFungiblePositionManager)
        BaseDecoderAndSanitizer(_boringVault)
        CamelotDecoderAndSanitizer(_camelotNonFungiblePositionManager)
    {}

    //============================== HANDLE FUNCTION COLLISIONS ===============================
}
