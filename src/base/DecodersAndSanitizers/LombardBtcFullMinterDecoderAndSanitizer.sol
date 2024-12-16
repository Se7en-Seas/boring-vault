// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {LombardBTCMinterDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/LombardBtcMinterDecoderAndSanitizer.sol";

contract LombardBTCFullMinterDecoderAndSanitizer is LombardBTCMinterDecoderAndSanitizer {
    constructor(address _boringVault) BaseDecoderAndSanitizer(_boringVault) {}
}
