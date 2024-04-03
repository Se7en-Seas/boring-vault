// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

interface BalancerVault {
    function flashLoan(address, address[] memory tokens, uint256[] memory amounts, bytes calldata userData) external;
    function swap(
        DecoderCustomTypes.SingleSwap memory singleSwap,
        DecoderCustomTypes.FundManagement memory funds,
        uint256 limit,
        uint256 deadline
    ) external returns (uint256 amountCalculated);
}
