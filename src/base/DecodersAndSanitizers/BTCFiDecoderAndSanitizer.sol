// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {UniswapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3DecoderAndSanitizer.sol";
import {OneInchDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";
import {PendleRouterDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/PendleRouterDecoderAndSanitizer.sol";
import {PumpStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/PumpStakingDecoderAndSanitizer.sol";
import {CornStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/CornStakingDecoderAndSanitizer.sol";

contract BTCFiDecoderAndSanitizer is
    UniswapV3DecoderAndSanitizer,
    OneInchDecoderAndSanitizer,
    PendleRouterDecoderAndSanitizer,
    PumpStakingDecoderAndSanitizer,
    CornStakingDecoderAndSanitizer
{
    constructor(address _boringVault, address _uniswapV3NonFungiblePositionManager)
        BaseDecoderAndSanitizer(_boringVault)
        UniswapV3DecoderAndSanitizer(_uniswapV3NonFungiblePositionManager)
    {}

    //============================== HANDLE FUNCTION COLLISIONS ===============================
}
