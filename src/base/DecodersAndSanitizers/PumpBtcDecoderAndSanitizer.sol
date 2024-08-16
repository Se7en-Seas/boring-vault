// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {PumpStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/PumpStakingDecoderAndSanitizer.sol";

contract PumpBtcDecoderAndSanitizer is BaseDecoderAndSanitizer, PumpStakingDecoderAndSanitizer {
    constructor(address _boringVault) BaseDecoderAndSanitizer(_boringVault) {}

    //============================== HANDLE FUNCTION COLLISIONS ===============================
}
