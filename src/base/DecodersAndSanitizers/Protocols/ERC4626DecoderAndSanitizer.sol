// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract ERC4626DecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== ERC4626 ===============================

    function deposit(uint256, address receiver) external pure virtual returns (address[] memory addressesFound) {
        addressesFound = new address[](1);
        addressesFound[0] = receiver;
    }

    function mint(uint256, address receiver) external pure virtual returns (address[] memory addressesFound) {
        addressesFound = new address[](1);
        addressesFound[0] = receiver;
    }

    function withdraw(uint256, address receiver, address owner)
        external
        pure
        virtual
        returns (address[] memory addressesFound)
    {
        addressesFound = new address[](2);
        addressesFound[0] = receiver;
        addressesFound[1] = owner;
    }

    function redeem(uint256, address receiver, address owner)
        external
        pure
        virtual
        returns (address[] memory addressesFound)
    {
        addressesFound = new address[](2);
        addressesFound[0] = receiver;
        addressesFound[1] = owner;
    }
}
