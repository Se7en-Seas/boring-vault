// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract ScrollBridgeDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== Scroll Native Bridge ===============================

    /// @notice Example deposit TX https://etherscan.io/tx/0xadf2121b495a0f6222219095dd3e116cd7b550c1a1a98ec1a561c9bff323eef9
    /// @notice Example withdraw TX https://scrollscan.com/tx/0xfc81ca5bcba7d43cace50765117ecf9cf9d4f177c2493475171c26a91343f801
    function sendMessage(address _to, uint256, /*_value*/ bytes calldata, /*_message*/ uint256 /*_gasLimit*/ )
        external
        pure
        virtual
        returns (bytes memory sensitiveArguments)
    {
        // Extract sensitive arguments.
        sensitiveArguments = abi.encodePacked(_to);
    }

    /// @notice Example TX ETH https://etherscan.io/tx/0xdb9f80b209b7e56b529c07d74d686eca7f0e5c3962d5bf5d8c554929f69b7016
    /// @notice Example TX ERC20 https://etherscan.io/tx/0x17f8e5674384e70987d5f31b3f9609968117a131ab5d376fcd69f26e2a658b6e
    function relayMessageWithProof(
        address _from,
        address _to,
        uint256, /*_value*/
        uint256, /*_nonce*/
        bytes calldata, /*_message*/
        DecoderCustomTypes.L2MessageProof calldata /*_proof*/
    ) external pure virtual returns (bytes memory sensitiveArguments) {
        // Extract sensitive arguments.
        sensitiveArguments = abi.encodePacked(_from, _to);
    }

    /// @notice Example TX https://etherscan.io/tx/0xa25e6c5dc294f469fbb754f74aa262b61353a5df68671e41bfe48faecd100059
    function depositERC20(address _token, address _to, uint256, /*_amount*/ uint256 /*_gasLimit*/ )
        external
        pure
        virtual
        returns (bytes memory sensitiveArguments)
    {
        // Extract sensitive arguments.
        sensitiveArguments = abi.encodePacked(_token, _to);
    }

    /// @notice Example TX https://scrollscan.com/tx/0xfcc5bdc518524b7f92f0d38dc696662c9a145123211c894b69607368578cc15d
    function withdrawERC20(address _token, address _to, uint256, /*_amount*/ uint256 /*_gasLimit*/ )
        external
        pure
        virtual
        returns (bytes memory sensitiveArguments)
    {
        // Extract sensitive arguments.
        sensitiveArguments = abi.encodePacked(_token, _to);
    }
}
