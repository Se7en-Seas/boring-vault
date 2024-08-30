// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {SymbioticVaultDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/SymbioticVaultDecoderAndSanitizer.sol";

contract SymbioticVaultDecoderAndSanitizerFull is BaseDecoderAndSanitizer, SymbioticVaultDecoderAndSanitizer {
    constructor(address _boringVault) BaseDecoderAndSanitizer(_boringVault) {}

    //============================== HANDLE FUNCTION COLLISIONS ===============================
}
