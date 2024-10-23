// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract UsualMoneyDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== Usual Money ===============================

    function mint(uint256 /*amountUsd0*/ ) external pure virtual returns (bytes memory sensitiveArgumentsFound) {
        return sensitiveArgumentsFound;
    }

    function unwrap() external pure virtual returns (bytes memory sensitiveArgumentsFound) {
        return sensitiveArgumentsFound;
    }
}
