// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;


import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {BTCNMinterDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BTCNMinterDecoderAndSanitizer.sol"; 


contract BTCNFullMinterDecoderAndSanitizer is BTCNMinterDecoderAndSanitizer {
    
    constructor(address _boringVault) BTCNMinterDecoderAndSanitizer(_boringVault) {}
}
