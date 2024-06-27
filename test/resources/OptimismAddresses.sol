// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";

contract OptimismAddresses {
    // Liquid Ecosystem
    address public deployerAddress = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d;
    address public dev0Address = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b;
    address public dev1Address = 0x2322ba43eFF1542b6A7bAeD35e66099Ea0d12Bd1;
    address public liquidPayoutAddress = 0xA9962a5BfBea6918E958DeE0647E99fD7863b95A;

    // DeFi Ecosystem
    address public ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public uniV3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public uniV2Router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public uniswapV3NonFungiblePositionManager = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address public ccipRouter = 0x3206695CaE29952f4b0c22a169725a865bc8Ce0f;

    ERC20 public WETH = ERC20(0x4200000000000000000000000000000000000006);

    address public balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
}
