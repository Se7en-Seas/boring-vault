// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract MorphoBlueDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== MORPHO BLUE ===============================

    function supply(
        DecoderCustomTypes.MarketParams calldata params,
        uint256,
        uint256,
        address onBehalf,
        bytes calldata data
    ) external pure returns (address[] memory addressesFound) {
        // Sanitize raw data
        require(data.length == 0, "callback not supported");
        // Return addresses found
        addressesFound = new address[](5);
        addressesFound[0] = params.loanToken;
        addressesFound[1] = params.collateralToken;
        addressesFound[2] = params.oracle;
        addressesFound[3] = params.irm;
        addressesFound[4] = onBehalf;
    }

    function withdraw(
        DecoderCustomTypes.MarketParams calldata params,
        uint256,
        uint256,
        address onBehalf,
        address receiver
    ) external pure returns (address[] memory addressesFound) {
        // Nothing to sanitize
        // Return addresses found
        addressesFound = new address[](6);
        addressesFound[0] = params.loanToken;
        addressesFound[1] = params.collateralToken;
        addressesFound[2] = params.oracle;
        addressesFound[3] = params.irm;
        addressesFound[4] = onBehalf;
        addressesFound[5] = receiver;
    }

    function borrow(
        DecoderCustomTypes.MarketParams calldata params,
        uint256,
        uint256,
        address onBehalf,
        address receiver
    ) external pure returns (address[] memory addressesFound) {
        addressesFound = new address[](6);
        addressesFound[0] = params.loanToken;
        addressesFound[1] = params.collateralToken;
        addressesFound[2] = params.oracle;
        addressesFound[3] = params.irm;
        addressesFound[4] = onBehalf;
        addressesFound[5] = receiver;
    }

    function repay(
        DecoderCustomTypes.MarketParams calldata params,
        uint256,
        uint256,
        address onBehalf,
        bytes calldata data
    ) external pure returns (address[] memory addressesFound) {
        // Sanitize raw data
        require(data.length == 0, "callback not supported");
        // Return addresses found
        addressesFound = new address[](5);
        addressesFound[0] = params.loanToken;
        addressesFound[1] = params.collateralToken;
        addressesFound[2] = params.oracle;
        addressesFound[3] = params.irm;
        addressesFound[4] = onBehalf;
    }

    function supplyCollateral(
        DecoderCustomTypes.MarketParams calldata params,
        uint256,
        address onBehalf,
        bytes calldata data
    ) external pure returns (address[] memory addressesFound) {
        // Sanitize raw data
        require(data.length == 0, "callback not supported");
        // Return addresses found
        addressesFound = new address[](5);
        addressesFound[0] = params.loanToken;
        addressesFound[1] = params.collateralToken;
        addressesFound[2] = params.oracle;
        addressesFound[3] = params.irm;
        addressesFound[4] = onBehalf;
    }

    function withdrawCollateral(
        DecoderCustomTypes.MarketParams calldata params,
        uint256,
        address onBehalf,
        address receiver
    ) external pure returns (address[] memory addressesFound) {
        // Nothing to sanitize
        // Return addresses found
        addressesFound = new address[](6);
        addressesFound[0] = params.loanToken;
        addressesFound[1] = params.collateralToken;
        addressesFound[2] = params.oracle;
        addressesFound[3] = params.irm;
        addressesFound[4] = onBehalf;
        addressesFound[5] = receiver;
    }
}
