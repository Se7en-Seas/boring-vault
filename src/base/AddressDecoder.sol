// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {console} from "@forge-std/Test.sol";

contract AddressDecoder {
    bytes32 internal constant HASHED_ARGUMENTS_ADDRESS_UINT256 = keccak256("(address,uint256)");
    bytes32 internal constant HASHED_ARGUMENTS_UINT256_ADDRESS = keccak256("(uint256,address)");

    function decode(string calldata function_signature, bytes calldata raw_data)
        external
        pure
        returns (address[] memory addresses_found)
    {
        // Iterate through string until an open parenthesis is found.
        bytes32 hashed_arguments;
        {
            bytes memory function_signature_bytes = bytes(function_signature);
            uint256 function_signature_length = function_signature_bytes.length;
            bytes1 open_char = bytes1("(");
            for (uint256 i; i < function_signature_length; ++i) {
                if (function_signature_bytes[i] == open_char) {
                    // We found the open char, so save the hashed_arguments.
                    hashed_arguments = keccak256(bytes(function_signature[i:]));
                    break;
                }
            }
            if (hashed_arguments == bytes32(0)) revert("Failed to find arguments");
        }

        if (hashed_arguments == HASHED_ARGUMENTS_ADDRESS_UINT256) {
            addresses_found = new address[](1);
            addresses_found[0] = abi.decode(raw_data, (address));
        } else if (hashed_arguments == HASHED_ARGUMENTS_UINT256_ADDRESS) {
            addresses_found = new address[](1);
            (, addresses_found[0]) = abi.decode(raw_data, (uint256, address));
        }
    }
}
