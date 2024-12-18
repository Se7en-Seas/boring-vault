// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract AeraVaultDecoderAndSanitizer is BaseDecoderAndSanitizer {
    constructor(address _boringVault) BaseDecoderAndSanitizer(_boringVault) {}

    function deposit(DecoderCustomTypes.AssetValue[] calldata amounts)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        for (uint256 i = 0; i < amounts.length; i++) {
            addressesFound = abi.encodePacked(amounts[i].asset);
        }
    }

    function withdraw(DecoderCustomTypes.AssetValue[] calldata amounts)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        for (uint256 i = 0; i < amounts.length; i++) {
            addressesFound = abi.encodePacked(amounts[i].asset);
        }
    }

    function pause() external pure returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function resume() external pure returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
