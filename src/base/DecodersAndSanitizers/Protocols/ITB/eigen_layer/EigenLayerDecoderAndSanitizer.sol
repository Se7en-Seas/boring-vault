/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.0;

import "../common/ITBContractDecoderAndSanitizer.sol";

abstract contract EigenLayerDecoderAndSanitizer is ITBContractDecoderAndSanitizer {
    function updateStrategyManager(address _strategy_manager) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_strategy_manager);
    }

    function updateDelegationManager(address _delegation_manager) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_delegation_manager);
    }

    function updatePositionConfig(address _liquid_staking, address _underlying, address _delegate_to)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_liquid_staking, _underlying, _delegate_to);
    }

    function delegate() external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
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
