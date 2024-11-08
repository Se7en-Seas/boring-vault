// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";

contract BinanceSmartChainAddresses {
    address public deployerAddress = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d;
    address public dev0Address = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b;
    address public dev1Address = 0xf8553c8552f906C19286F21711721E206EE4909E;
    address public liquidPayoutAddress = 0xA9962a5BfBea6918E958DeE0647E99fD7863b95A;

    ERC20 public LBTC = ERC20(0xecAc9C5F704e954931349Da37F60E39f515c11c1);
    ERC20 public WBTC = ERC20(0x0555E30da8f98308EdB960aa94C0Db47230d2B9c);
    ERC20 public WBNB = ERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    address public balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address public uniswapV3NonFungiblePositionManager = 0x7b8A01B39D58278b5DE7e48c8449c9f4F5170613;
}
