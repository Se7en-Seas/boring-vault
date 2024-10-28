/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.0;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

// ITB Decoders
import {ExecutableDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ITB/common/ExecutableDecoderAndSanitizer.sol";
import {WithdrawableDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ITB/common/WithdrawableDecoderAndSanitizer.sol";

contract ITBPositionDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    ExecutableDecoderAndSanitizer,
    WithdrawableDecoderAndSanitizer
{
    constructor() BaseDecoderAndSanitizer(address(0)) {}

    //============================== HANDLE FUNCTION COLLISIONS ===============================
}
