// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";

interface PriceRouter {
    function getValue(ERC20 baseAsset, uint256 amount, ERC20 quoteAsset) external view returns (uint256 value);
}
