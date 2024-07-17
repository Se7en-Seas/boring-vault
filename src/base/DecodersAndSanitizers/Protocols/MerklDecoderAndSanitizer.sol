// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract MerklDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== Merkl ===============================

    error MerklDecoderAndSanitizer__InputLengthMismatch();

    // Distributor contracts can be found here https://app.merkl.xyz/status
    function toggleOnlyOperatorCanClaim(address user) external pure virtual returns (bytes memory sensitiveArguments) {
        sensitiveArguments = abi.encodePacked(user);
    }

    function toggleOperator(address user, address operator)
        external
        pure
        virtual
        returns (bytes memory sensitiveArguments)
    {
        sensitiveArguments = abi.encodePacked(user, operator);
    }

    function claim(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external pure virtual returns (bytes memory sensitiveArguments) {
        // The distributor checks if the lengths match, but we also do it here just in case Distributors are upgraded.
        uint256 usersLength = users.length;
        if (usersLength != tokens.length || usersLength != amounts.length || usersLength != proofs.length) {
            revert MerklDecoderAndSanitizer__InputLengthMismatch();
        }

        for (uint256 i; i < usersLength; ++i) {
            sensitiveArguments = abi.encodePacked(sensitiveArguments, users[i], tokens[i]);
        }
    }
}
