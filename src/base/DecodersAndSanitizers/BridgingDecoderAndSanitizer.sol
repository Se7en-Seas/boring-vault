// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {CCIPDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CCIPDecoderAndSanitizer.sol";
import {ArbitrumNativeBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ArbitrumNativeBridgeDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {StandardBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/StandardBridgeDecoderAndSanitizer.sol";
import {MantleStandardBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/MantleStandardBridgeDecoderAndSanitizer.sol";
import {LineaBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/LineaBridgeDecoderAndSanitizer.sol";
import {ScrollBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ScrollBridgeDecoderAndSanitizer.sol";

contract BridgingDecoderAndSanitizer is
    ArbitrumNativeBridgeDecoderAndSanitizer,
    CCIPDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    StandardBridgeDecoderAndSanitizer,
    MantleStandardBridgeDecoderAndSanitizer,
    LineaBridgeDecoderAndSanitizer,
    ScrollBridgeDecoderAndSanitizer
{
    constructor(address _boringVault) BaseDecoderAndSanitizer(_boringVault) {}

    //============================== HANDLE FUNCTION COLLISIONS ===============================
}
