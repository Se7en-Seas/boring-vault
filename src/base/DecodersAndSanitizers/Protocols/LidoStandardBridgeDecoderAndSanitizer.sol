// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract LidoStandardBridgeDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== LidoStandardBridge ===============================

    // Example TX https://etherscan.io/tx/0xe0aadcda977fc4479e503331fd96e62802e56dc2b3da5937fca803ddb3a0e00a
    function depositERC20To(
        address _localToken,
        address _remoteToken,
        address _to,
        uint256, /*_amount*/
        uint32, /*_minGasLimit*/
        bytes calldata /*_extraData*/
    ) external pure virtual returns (bytes memory sensitiveArguments) {
        // Extract sensitive arguments.
        sensitiveArguments = abi.encodePacked(_localToken, _remoteToken, _to);
    }

    // Example TX https://basescan.org/tx/0xa7e20d0483542c0a4928a8f6be767a73a827594bbd454d20b5b89400f49f69b5
    function withdrawTo(
        address _localToken,
        address _to,
        uint256, /*_amount*/
        uint32, /*_minGasLimit*/
        bytes calldata /*_extraData*/
    ) external pure virtual returns (bytes memory sensitiveArguments) {
        // Extract sensitive arguments.
        sensitiveArguments = abi.encodePacked(_localToken, _to);
    }

    /// @notice Example TX https://etherscan.io/tx/0xe963547e3b04908794543954c65e051262645863be5d559bcba34755a0b28fb7
    function proveWithdrawalTransaction(
        DecoderCustomTypes.WithdrawalTransaction calldata _tx,
        uint256, /*_l2OutputIndex*/
        DecoderCustomTypes.OutputRootProof calldata, /*_outputRootProof*/
        bytes[] calldata /*_withdrawalProof*/
    ) external pure virtual returns (bytes memory sensitiveArguments) {
        sensitiveArguments = abi.encodePacked(_tx.sender, _tx.target);
    }

    /// @notice Eample TX https://etherscan.io/tx/0x5bb20258a0b151a6acb01f05ea42ee2f51123cba5d51e9be46a5033e675faefe
    function finalizeWithdrawalTransaction(DecoderCustomTypes.WithdrawalTransaction calldata _tx)
        external
        pure
        virtual
        returns (bytes memory sensitiveArguments)
    {
        sensitiveArguments = abi.encodePacked(_tx.sender, _tx.target);
    }
}
