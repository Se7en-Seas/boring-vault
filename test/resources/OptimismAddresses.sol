// SPDX-License-Identifier: UNLICENSED
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
    ERC20 public WEETH = ERC20(0x346e03F8Cce9fE01dCB3d0Da3e9D00dC2c0E08f0);
    ERC20 public WSTETH = ERC20(0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb);
    ERC20 public RETH = ERC20(0x9Bcef72be871e61ED4fBbc7630889beE758eb81D);
    ERC20 public WEETH_OFT = ERC20(0x5A7fACB970D094B6C7FF1df0eA68D99E6e73CBFF);

    address public balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    // Chainlink feeds
    address public weETH_ETH_ExchangeRate = 0x72EC6bF88effEd88290C66DCF1bE2321d80502f5;
}
