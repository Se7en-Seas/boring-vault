// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract OFTDecoderAndSanitizer is BaseDecoderAndSanitizer {
    error OFTDecoderAndSanitizer__NonZeroMessage();
    error OFTDecoderAndSanitizer__NonZeroOFTCommand();

    //============================== OFT ===============================

    function send(
        DecoderCustomTypes.SendParam calldata _sendParam,
        DecoderCustomTypes.MessagingFee calldata, /*_fee*/
        address _refundAddress
    ) external pure virtual returns (bytes memory sensitiveArguments) {
        // Sanitize Message.
        if (_sendParam.composeMsg.length > 0) {
            revert OFTDecoderAndSanitizer__NonZeroMessage();
        }
        if (_sendParam.oftCmd.length > 0) {
            revert OFTDecoderAndSanitizer__NonZeroOFTCommand();
        }

        sensitiveArguments =
            abi.encodePacked(address(uint160(_sendParam.dstEid)), address(bytes20(_sendParam.to << 96)), _refundAddress);
    }
}
