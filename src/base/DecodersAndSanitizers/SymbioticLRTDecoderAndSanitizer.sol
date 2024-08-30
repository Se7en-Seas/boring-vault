// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {UniswapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3DecoderAndSanitizer.sol";
import {SymbioticDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SymbioticDecoderAndSanitizer.sol";
import {EtherFiDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EtherFiDecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {OneInchDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";
import {EigenLayerLSTStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/EigenLayerLSTStakingDecoderAndSanitizer.sol";
import {SwellSimpleStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/SwellSimpleStakingDecoderAndSanitizer.sol";
import {ZircuitSimpleStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ZircuitSimpleStakingDecoderAndSanitizer.sol";
import {FluidFTokenDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/FluidFTokenDecoderAndSanitizer.sol";
import {LidoDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/LidoDecoderAndSanitizer.sol";
import {AaveV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AaveV3DecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";

contract SymbioticLRTDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    UniswapV3DecoderAndSanitizer,
    SymbioticDecoderAndSanitizer,
    EtherFiDecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    OneInchDecoderAndSanitizer,
    SwellSimpleStakingDecoderAndSanitizer,
    ZircuitSimpleStakingDecoderAndSanitizer,
    FluidFTokenDecoderAndSanitizer,
    LidoDecoderAndSanitizer,
    AaveV3DecoderAndSanitizer,
    ERC4626DecoderAndSanitizer
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

    function withdraw(address recipient, uint256 /*amount*/ )
        external
        pure
        override(SymbioticDecoderAndSanitizer, ZircuitSimpleStakingDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(recipient);
    }

    function deposit()
        external
        pure
        override(EtherFiDecoderAndSanitizer, NativeWrapperDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function withdraw(address _token, uint256, /*_amount*/ address _receiver)
        external
        pure
        override(SwellSimpleStakingDecoderAndSanitizer, AaveV3DecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_token, _receiver);
    }
}
