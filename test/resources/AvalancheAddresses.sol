// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";

contract AvalancheAddresses {
    // Liquid Ecosystem
    address public deployerAddress = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d;
    address public dev0Address = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b;
    address public dev1Address = 0x2322ba43eFF1542b6A7bAeD35e66099Ea0d12Bd1;
    address public liquidPayoutAddress = 0xA9962a5BfBea6918E958DeE0647E99fD7863b95A;

    // DeFi Ecosystem
    address public ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    // address public uniV3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    // address public uniV2Router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public uniswapV3NonFungiblePositionManager = 0x655C406EBFa14EE2006250925e54ec43AD184f8B;

    ERC20 public USDC = ERC20(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E);
    ERC20 public WETH = ERC20(0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB);
    ERC20 public WAVAX = ERC20(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);
    ERC20 public BTCb = ERC20(0x152b9d0FdC40C096757F570A51E494bd4b943E50);

    address public balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
}
