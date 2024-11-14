// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract AaveV3DecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== AAVEV3 ===============================

    function supply(address asset, uint256, address onBehalfOf, uint16)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(asset, onBehalfOf);
    }

    function withdraw(address asset, uint256, address to) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(asset, to);
    }

    function borrow(address asset, uint256, uint256, uint16, address onBehalfOf)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(asset, onBehalfOf);
    }

    function repay(address asset, uint256, uint256, address onBehalfOf)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(asset, onBehalfOf);
    }

    function setUserUseReserveAsCollateral(address asset, bool)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(asset);
    }

    function setUserEMode(uint8) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function claimRewards(address[] calldata /*assets*/, uint256 /*amount*/, address to, address /*reward*/)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(to); 
    }
}
