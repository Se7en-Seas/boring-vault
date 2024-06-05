/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.0;

import "../common/ITBContractDecoderAndSanitizer.sol";

abstract contract KarakDecoderAndSanitizer is ITBContractDecoderAndSanitizer {
    function updatePositionConfig(address _underlying, address _vault)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_underlying, _vault);
    }

    function updateVaultSupervisor(address _vault_supervisor) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_vault_supervisor);
    }

    function deposit(uint256, uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function startWithdrawal(uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function completeWithdrawal(uint256, uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function completeNextWithdrawal(uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function completeNextWithdrawals(uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function overrideWithdrawalIndexes(uint256, uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function assemble(uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function disassemble(uint256, uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function fullDisassemble(uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }
}
