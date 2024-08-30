// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";

interface AggregationRouterV5 {
    struct SwapDescription {
        ERC20 srcToken;
        ERC20 dstToken;
        address payable srcReceiver;
        address payable dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
    }

    function swap(address executor, SwapDescription calldata desc, bytes calldata permit, bytes calldata data)
        external
        payable
        returns (uint256 returnAmount, uint256 spentAmount);
}
