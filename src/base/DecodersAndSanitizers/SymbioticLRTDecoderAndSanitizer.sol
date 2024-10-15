// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {EtherFiDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EtherFiDecoderAndSanitizer.sol";
import {FraxDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/FraxDecoderAndSanitizer.sol";
import {LidoDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/LidoDecoderAndSanitizer.sol";
import {MantleDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MantleDecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {OneInchDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";
import {SwellDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SwellDecoderAndSanitizer.sol";
import {SymbioticDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SymbioticDecoderAndSanitizer.sol";
import {UniswapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3DecoderAndSanitizer.sol";

contract SymbioticLRTDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    ERC4626DecoderAndSanitizer,
    EtherFiDecoderAndSanitizer,
    FraxDecoderAndSanitizer,
    LidoDecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    MantleDecoderAndSanitizer,
    OneInchDecoderAndSanitizer,
    SwellDecoderAndSanitizer,
    SymbioticDecoderAndSanitizer,
    UniswapV3DecoderAndSanitizer
{
    constructor(address _boringVault, address _uniswapV3NonfungiblePositionManager)
        BaseDecoderAndSanitizer(_boringVault)
        UniswapV3DecoderAndSanitizer(_uniswapV3NonfungiblePositionManager)
    {}

    // //============================== HANDLE FUNCTION COLLISIONS ===============================
    function wrap(uint256)
        external
        pure
        override(EtherFiDecoderAndSanitizer, LidoDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function unwrap(uint256)
        external
        pure
        override(EtherFiDecoderAndSanitizer, LidoDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function deposit()
        external
        pure
        override(EtherFiDecoderAndSanitizer, NativeWrapperDecoderAndSanitizer, SwellDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize or return
        return addressesFound;
    }
}
