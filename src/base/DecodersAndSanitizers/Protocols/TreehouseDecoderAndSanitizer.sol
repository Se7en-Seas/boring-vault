// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract TreehouseDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== Treehouse ===============================

    // Example TX: https://etherscan.io/tx/0x1e1f604ae5b9e634213b5bcf952257a5db9e370005b82986e6c6c5449f142a30
    function deposit(address _asset, uint256 /*_amount*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_asset);
    }

    function redeem(uint96 /*_shares*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
