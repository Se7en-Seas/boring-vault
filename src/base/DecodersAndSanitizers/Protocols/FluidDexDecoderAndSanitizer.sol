// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";


abstract contract FluidDexDecoderAndSanitizer is BaseDecoderAndSanitizer {

    function deposit(uint256 /*token0Amt*/, uint256 /*token1Amt*/, uint256 /*minSharesAmt*/, bool /*estimate*/) external pure virtual returns (bytes memory addressesFound) {
        //nothing to sanitize
        return addressesFound; 
    }  

    function withdraw(
        uint256 /*token0Amt*/,
        uint256 /*token1Amt*/,
        uint256 /*maxSharesAmt*/,
        address to
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(to); 
    }

    function borrow(
        uint256 /*token0Amt*/,
        uint256 /*token1Amt*/,
        uint256 /*maxSharesAmt*/,
        address to
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(to); 
    }
    
    function payback(
        uint256 /*token0Amt*/,
        uint256 /*token1Amt*/,
        uint256 /*minSharesAmt*/,
        bool /*estimate*/
    ) external pure virtual returns (bytes memory addressesFound) {
        //nothing to sanitize
        return addressesFound;  
    }
}
