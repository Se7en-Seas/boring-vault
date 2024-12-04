// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract BTCNMinterDecoderAndSanitizer is BaseDecoderAndSanitizer {

    constructor(address _boringVault) BaseDecoderAndSanitizer(_boringVault){}
    
    function swapExactCollateralForDebt(uint256 /*collateralIn*/, uint256 /*debtOutMin*/, address to, uint256 /*deadline*/) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(to); 
    }

    function swapExactDebtForCollateral(uint256 /*debtIn*/, uint256 /*collateralOutMin*/, address to, uint256 /*deadline*/) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(to); 
    }
}

