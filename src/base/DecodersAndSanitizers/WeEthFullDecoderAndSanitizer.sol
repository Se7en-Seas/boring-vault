// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {WeETHDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/WeEthDecoderAndSanitizer.sol"; 
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract WeETHFullDecoderAndSanitizer is WeETHDecoderAndSanitizer {
    
    constructor(address _boringVault) BaseDecoderAndSanitizer(_boringVault) {}
}
