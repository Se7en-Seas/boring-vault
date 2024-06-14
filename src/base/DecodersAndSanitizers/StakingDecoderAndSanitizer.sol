// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {EtherFiDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EtherFiDecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {LidoDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/LidoDecoderAndSanitizer.sol";
import {SwellDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SwellDecoderAndSanitizer.sol";

contract StakingDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    EtherFiDecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    LidoDecoderAndSanitizer,
    SwellDecoderAndSanitizer
{
    constructor(address _boringVault) BaseDecoderAndSanitizer(_boringVault) {}

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
        override(EtherFiDecoderAndSanitizer, NativeWrapperDecoderAndSanitizer, SwellDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize or return
        return addressesFound;
    }
}
