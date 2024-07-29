// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {VelodromeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/VelodromeDecoderAndSanitizer.sol";

contract AerodromeDecoderAndSanitizer is VelodromeDecoderAndSanitizer {
    constructor(address _boringVault, address _aerodromeNonFungiblePositionManager)
        BaseDecoderAndSanitizer(_boringVault)
        VelodromeDecoderAndSanitizer(_aerodromeNonFungiblePositionManager)
    {}
}
