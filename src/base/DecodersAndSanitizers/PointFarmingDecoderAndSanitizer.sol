// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {MantleStandardBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/MantleStandardBridgeDecoderAndSanitizer.sol";
import {ScrollBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ScrollBridgeDecoderAndSanitizer.sol";
import {LineaBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/LineaBridgeDecoderAndSanitizer.sol";
import {StandardBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/StandardBridgeDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";

contract PointFarmingDecoderAndSanitizer is
    StandardBridgeDecoderAndSanitizer,
    LineaBridgeDecoderAndSanitizer,
    MantleStandardBridgeDecoderAndSanitizer,
    ScrollBridgeDecoderAndSanitizer,
    OFTDecoderAndSanitizer
{
    constructor(address _boringVault) BaseDecoderAndSanitizer(_boringVault) {}

    //============================== HANDLE FUNCTION COLLISIONS ===============================
}
