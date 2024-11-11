// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract WeETHDecoderAndSanitizer is BaseDecoderAndSanitizer {

    constructor(address _boringVault) BaseDecoderAndSanitizer(_boringVault) {}

    //add the registry to check for whitelisted assets? 
    function deposit(address tokenIn, uint256 /*amountIn*/, uint256 /*minAmountOut*/, address referral) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(tokenIn, referral); 
    }
}
