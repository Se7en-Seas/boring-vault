// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {EigenLayerLSTStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/EigenLayerLSTStakingDecoderAndSanitizer.sol";
import {SwellSimpleStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/SwellSimpleStakingDecoderAndSanitizer.sol";

contract PointFarmingDecoderAndSanitizer is
    EigenLayerLSTStakingDecoderAndSanitizer,
    SwellSimpleStakingDecoderAndSanitizer
{
    constructor(address _boringVault) BaseDecoderAndSanitizer(_boringVault) {}

    //============================== HANDLE FUNCTION COLLISIONS ===============================
}
