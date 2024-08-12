// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";

interface DefaultCollateral {
    function balanceOf(address account) external view returns (uint256);
    function withdraw(address recipient, uint256 amount) external;
    function deposit(address recipient, uint256 amount) external;
    function asset() external view returns (ERC20);
    function limit() external view returns (uint256);
    function totalSupply() external view returns (uint256);
}
