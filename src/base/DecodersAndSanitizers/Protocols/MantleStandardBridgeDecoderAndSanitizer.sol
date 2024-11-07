// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract MantleStandardBridgeDecoderAndSanitizer is BaseDecoderAndSanitizer {
    /// @notice The mantle bridge closely follows the standard bridge format, but has a couple of breaking changes
    /// that are accounted for using the functions below.
    //============================== MantleStandardBridge ===============================

    function bridgeETHTo(uint256, /*amount*/ address _to, uint32, /*_minGasLimit*/ bytes calldata /*_extraData*/ )
        external
        pure
        virtual
        returns (bytes memory sensitiveArguments)
    {
        // Extract sensitive arguments.
        sensitiveArguments = abi.encodePacked(_to);
    }

    // Example TX https://etherscan.io/tx/0xe1b6ba19b47dadf53f1c67ed0fe7109b0c78bb8c3abb8c9578a9fa789fe725d7
    function proveWithdrawalTransaction(
        DecoderCustomTypes.MantleWithdrawalTransaction calldata _tx,
        uint256, /*_l2OutputIndex*/
        DecoderCustomTypes.OutputRootProof calldata, /*_outputRootProof*/
        bytes[] calldata /*_withdrawalProof*/
    ) external pure virtual returns (bytes memory sensitiveArguments) {
        sensitiveArguments = abi.encodePacked(_tx.sender, _tx.target);
    }

    /// @notice Eample TX https://etherscan.io/tx/0x258c80e4c282fc94ddbec05bf64c602a437a2f26b1d2c14b6d16802ab1de9a11
    function finalizeWithdrawalTransaction(DecoderCustomTypes.MantleWithdrawalTransaction calldata _tx)
        external
        pure
        virtual
        returns (bytes memory sensitiveArguments)
    {
        sensitiveArguments = abi.encodePacked(_tx.sender, _tx.target);
    }
}
