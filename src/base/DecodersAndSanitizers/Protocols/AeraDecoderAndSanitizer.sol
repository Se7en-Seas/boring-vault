// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract AeraDecoderAndSanitizer is BaseDecoderAndSanitizer {


    constructor(address _boringVault) BaseDecoderAndSanitizer(_boringVault) {}

    //add the registry to check for whitelisted assets? 
    function deposit(DecoderCustomTypes.AssetValue calldata amounts) external pure virtual returns (bytes memory addressesFound) {
    
        //in this case, we would want to extract the token address and check it
        return abi.encodePacked(amounts.asset); 
    }

    function withdraw(DecoderCustomTypes.AssetValue calldata amounts) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(amounts.asset);  
    }
}
