// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract AeraDecoderAndSanitizer is BaseDecoderAndSanitizer {


    constructor(address _boringVault) BaseDecoderAndSanitizer(_boringVault) {}

    //add the registry to check for whitelisted assets? 
    function deposit(DecoderCustomTypes.AssetValue[] calldata amounts) external pure virtual returns (bytes memory addressesFound) {
        for (uint256 i = 0; i < amounts.length; i++) {
            addressesFound = abi.encodePacked(amounts[i].asset); 
        }
    }

    function withdraw(DecoderCustomTypes.AssetValue[] calldata amounts) external pure virtual returns (bytes memory addressesFound) {
        for (uint256 i = 0; i < amounts.length; i++) {
            addressesFound = abi.encodePacked(amounts[i].asset); 
        }
    }
}
