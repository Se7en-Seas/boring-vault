// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {TreehouseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TreehouseDecoderAndSanitizer.sol";

contract OnlyTreehouseDecoderAndSanitizer is TreehouseDecoderAndSanitizer {
    constructor(address _boringVault) BaseDecoderAndSanitizer(_boringVault) {}

    //============================== HANDLE FUNCTION COLLISIONS ===============================
}
