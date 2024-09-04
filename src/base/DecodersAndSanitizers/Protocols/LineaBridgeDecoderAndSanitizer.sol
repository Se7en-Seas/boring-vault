// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract LineaBridgeDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== StandardBridge ===============================

    /// @notice Example TX https://etherscan.io/tx/0x6fe5dcbafb6620980ec571cde88e6e651075214a0b698543eb5589e8889d52bd
    /// @notice Set _fee to zero in order to claim funds manually.
    /// @notice When bridging from Linea to mainnet a fee is required, so I think it is best to just allow the strategist
    /// to pick a good fee value and do no sanitation of it.
    function sendMessage(address _to, uint256, /*_fee*/ bytes calldata /*_calldata*/ )
        external
        pure
        virtual
        returns (bytes memory sensitiveArguments)
    {
        // Extract sensitive arguments.
        sensitiveArguments = abi.encodePacked(_to);
    }

    // Bridge ERC20
    // Example TX https://etherscan.io/tx/0x9935e537c51807f4097444399f08b04798dfe2a0f96cbf0b186caa9e8ab9d111
    // Example TX https://lineascan.build/tx/0xa1ed773719a0d17373b5ce2db7c2e8c924eff99865dd0d3cdb4b58f3e9ea5310
    function bridgeToken(address _token, uint256, /*_amount*/ address _recipient)
        external
        pure
        virtual
        returns (bytes memory sensitiveArguments)
    {
        // Extract sensitive arguments.
        sensitiveArguments = abi.encodePacked(_token, _recipient);
    }

    // https://lineascan.build/tx/0xc97c7d28163dc81c5dd5c735d607952959a06a3016bada86484712d4c6cdea3f
    // Used to claim ETH or ERC20s on destination chain, if no fee is provided.
    function claimMessage(
        address _from,
        address _to,
        uint256, /*_fee*/
        uint256, /*_value*/
        address _feeRecipient,
        bytes calldata, /*_calldata*/
        uint256 /*_nonce*/
    ) external pure virtual returns (bytes memory sensitiveArguments) {
        sensitiveArguments = abi.encodePacked(_from, _to, _feeRecipient);
    }

    // Example TX https://etherscan.io/tx/0x9af51fdd89ac1658a480605fad1105f95290420acff3d978f8df847e9e3891b7
    function claimMessageWithProof(DecoderCustomTypes.ClaimMessageWithProofParams calldata _claimMessageWithProof)
        external
        pure
        virtual
        returns (bytes memory sensitiveArguments)
    {
        sensitiveArguments = abi.encodePacked(
            _claimMessageWithProof.from, _claimMessageWithProof.to, _claimMessageWithProof.feeRecipient
        );
    }
}
