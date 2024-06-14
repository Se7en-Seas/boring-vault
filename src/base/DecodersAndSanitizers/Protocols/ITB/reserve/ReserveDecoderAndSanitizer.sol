/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.0;

import "../common/ITBContractDecoderAndSanitizer.sol";

abstract contract ReserveDecoderAndSanitizer is ITBContractDecoderAndSanitizer {
    function updatePositionConfig(address _main) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_main);
    }

    function mint(uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function redeem(uint256, uint256[] memory) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function redeemCustom(
        uint256,
        uint48[] memory,
        uint192[] memory,
        address[] memory _expected_tokens_out,
        uint256[] memory
    ) external pure returns (bytes memory addressesFound) {
        for (uint256 i = 0; i < _expected_tokens_out.length; i++) {
            addressesFound = abi.encodePacked(addressesFound, _expected_tokens_out[i]);
        }
    }

    function assemble(uint256, uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function disassemble(uint256, uint256[] memory) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function fullDisassemble(uint256[] memory) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }
}
