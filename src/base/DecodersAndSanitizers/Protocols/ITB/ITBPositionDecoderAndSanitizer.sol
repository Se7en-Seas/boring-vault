/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.0;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

// ITB Decoders
import {AaveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ITB/aave/AaveDecoderAndSanitizer.sol";
import {CurveAndConvexDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ITB/curve_and_convex/CurveAndConvexDecoderAndSanitizer.sol";
import {GearboxDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ITB/gearbox/GearboxDecoderAndSanitizer.sol";
import {SyrupDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ITB/syrup/SyrupDecoderAndSanitizer.sol";

contract ITBPositionDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    AaveDecoderAndSanitizer,
    CurveAndConvexDecoderAndSanitizer,
    GearboxDecoderAndSanitizer,
    SyrupDecoderAndSanitizer
{
    constructor(address _boringVault) BaseDecoderAndSanitizer(_boringVault) {}

    //============================== HANDLE FUNCTION COLLISIONS ===============================
}
