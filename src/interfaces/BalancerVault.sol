// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

interface BalancerVault {
    function flashLoan(address[] memory tokens, uint256[] memory amounts, bytes calldata userData) external;
}
