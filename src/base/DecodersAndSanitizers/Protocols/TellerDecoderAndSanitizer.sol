// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract TellerDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== Teller ===============================

    function bulkDeposit(address depositAsset, uint256, /*depositAmount*/ uint256, /*minimumMint*/ address to)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(depositAsset, to);
    }

    function bulkWithdraw(address withdrawAsset, uint256, /*shareAmount*/ uint256, /*minimumAssets*/ address to)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(withdrawAsset, to);
    }
}
