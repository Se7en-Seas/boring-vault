// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";

contract BaseAddresses {
    // Liquid Ecosystem
    address public deployerAddress = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d;
    address public dev0Address = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b;
    address public dev1Address = 0xf8553c8552f906C19286F21711721E206EE4909E;
    address public liquidPayoutAddress = 0xA9962a5BfBea6918E958DeE0647E99fD7863b95A;

    // DeFi Ecosystem
    address public ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint64 public mainnetChainSelector = 5009297550715157269;

    ERC20 public USDC = ERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    ERC20 public WETH = ERC20(0x4200000000000000000000000000000000000006);
    ERC20 public WEETH = ERC20(0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A);
    ERC20 public cbBTC = ERC20(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf);
    ERC20 public tBTC = ERC20(0x236aa50979D5f3De3Bd1Eeb40E81137F22ab794b);
    ERC20 public dlcBTC = ERC20(0x12418783e860997eb99e8aCf682DF952F721cF62);
    ERC20 public ETHFI = ERC20(0x6C240DDA6b5c336DF09A4D011139beAAa1eA2Aa2);
    ERC20 public WBTC = ERC20(0x0555E30da8f98308EdB960aa94C0Db47230d2B9c);

    // Standard Bridge.
    address public standardBridge = 0x4200000000000000000000000000000000000010;

    address public balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address public uniswapV3NonFungiblePositionManager = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;

    // Chainlink feeds
    address public weETH_ETH_ExchangeRate = 0x35e9D7001819Ea3B39Da906aE6b06A62cfe2c181;
}
