// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {AeraVaultDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AeraVaultDecoderAndSanitizer.sol";

contract AeraVaultFullDecoderAndSanitizer is AeraVaultDecoderAndSanitizer {
    constructor(address _boringVault) AeraVaultDecoderAndSanitizer(_boringVault) {}
}
