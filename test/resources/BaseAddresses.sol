// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";

contract BaseAddresses {
    // Liquid Ecosystem
    address public deployerAddress = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d;
    address public dev0Address = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b;
    address public dev1Address = 0x2322ba43eFF1542b6A7bAeD35e66099Ea0d12Bd1;
    address public liquidPayoutAddress = 0xA9962a5BfBea6918E958DeE0647E99fD7863b95A;

    // DeFi Ecosystem
    address public ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint64 public mainnetChainSelector = 5009297550715157269;

    ERC20 public USDC = ERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    ERC20 public WETH = ERC20(0x4200000000000000000000000000000000000006);
    ERC20 public WEETH = ERC20(0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A);

    // Standard Bridge.
    address public standardBridge = 0x4200000000000000000000000000000000000010;
}
