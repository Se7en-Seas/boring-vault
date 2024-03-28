// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract CreateMerkleRootTest is Test, MainnetAddresses {
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    address public boringVault;
    address public rawDataDecoderAndSanitizer;

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19369928;
        _startFork(rpcKey, blockNumber);

        boringVault = address(1);
        rawDataDecoderAndSanitizer = address(2);
    }

    function testGenerateRenzoStrategistMerkleRoot() external {
        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // uniswap v3
        leafs[0] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 NonFungible Position Manager to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[0].argumentAddresses[0] = uniswapV3NonFungiblePositionManager;
        leafs[1] = ManageLeaf(
            address(EZETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 NonFungible Position Manager to spend ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[1].argumentAddresses[0] = uniswapV3NonFungiblePositionManager;
        leafs[2] = ManageLeaf(
            address(WSTETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 NonFungible Position Manager to spend wstETH",
            rawDataDecoderAndSanitizer
        );
        leafs[2].argumentAddresses[0] = uniswapV3NonFungiblePositionManager;
        leafs[3] = ManageLeaf(
            address(RETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 NonFungible Position Manager to spend rETH",
            rawDataDecoderAndSanitizer
        );
        leafs[3].argumentAddresses[0] = uniswapV3NonFungiblePositionManager;
        leafs[4] = ManageLeaf(
            address(WEETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 NonFungible Position Manager to spend weETH",
            rawDataDecoderAndSanitizer
        );
        leafs[4].argumentAddresses[0] = uniswapV3NonFungiblePositionManager;
        leafs[5] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
            new address[](3),
            "Mint UniswapV3 ezETH wETH position",
            rawDataDecoderAndSanitizer
        );
        leafs[5].argumentAddresses[0] = address(EZETH);
        leafs[5].argumentAddresses[1] = address(WETH);
        leafs[5].argumentAddresses[2] = boringVault;
        leafs[6] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
            new address[](3),
            "Mint UniswapV3 wstETH ezETH position",
            rawDataDecoderAndSanitizer
        );
        leafs[6].argumentAddresses[0] = address(WSTETH);
        leafs[6].argumentAddresses[1] = address(EZETH);
        leafs[6].argumentAddresses[2] = boringVault;
        leafs[7] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
            new address[](3),
            "Mint UniswapV3 rETH ezETH position",
            rawDataDecoderAndSanitizer
        );
        leafs[7].argumentAddresses[0] = address(RETH);
        leafs[7].argumentAddresses[1] = address(EZETH);
        leafs[7].argumentAddresses[2] = boringVault;
        leafs[8] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
            new address[](3),
            "Mint UniswapV3 ezETH weETH position",
            rawDataDecoderAndSanitizer
        );
        leafs[8].argumentAddresses[0] = address(EZETH);
        leafs[8].argumentAddresses[1] = address(WEETH);
        leafs[8].argumentAddresses[2] = boringVault;
        leafs[9] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
            new address[](0),
            "Add liquidity to UniswapV3 position",
            rawDataDecoderAndSanitizer
        );
        leafs[10] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            new address[](0),
            "Remove liquidity from UniswapV3 position",
            rawDataDecoderAndSanitizer
        );
        leafs[11] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "collect((uint256,address,uint128,uint128))",
            new address[](1),
            "Collect from UniswapV3 position",
            rawDataDecoderAndSanitizer
        );
        leafs[11].argumentAddresses[0] = boringVault;

        // morphoblue
        leafs[12] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve MorphoBlue to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[12].argumentAddresses[0] = morphoBlue;
        leafs[13] = ManageLeaf(
            morphoBlue,
            false,
            "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            new address[](5),
            "Supply wETH to ezETH MorphoBlue market",
            rawDataDecoderAndSanitizer
        );
        leafs[13].argumentAddresses[0] = address(WETH);
        leafs[13].argumentAddresses[1] = address(EZETH);
        leafs[13].argumentAddresses[2] = ezEthOracle;
        leafs[13].argumentAddresses[3] = ezEthIrm;
        leafs[13].argumentAddresses[4] = boringVault;
        leafs[14] = ManageLeaf(
            morphoBlue,
            false,
            "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
            new address[](6),
            "Withdraw wETH from ezETH MorphoBlue market",
            rawDataDecoderAndSanitizer
        );
        leafs[14].argumentAddresses[0] = address(WETH);
        leafs[14].argumentAddresses[1] = address(EZETH);
        leafs[14].argumentAddresses[2] = ezEthOracle;
        leafs[14].argumentAddresses[3] = ezEthIrm;
        leafs[14].argumentAddresses[4] = boringVault;
        leafs[14].argumentAddresses[5] = boringVault;

        // renzo staking
        leafs[15] =
            ManageLeaf(restakeManager, true, "depositETH()", new address[](0), "Mint ezETH", rawDataDecoderAndSanitizer);

        // lido support
        leafs[15] = ManageLeaf(
            address(STETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve wstETH to spend stETH",
            rawDataDecoderAndSanitizer
        );
        leafs[15].argumentAddresses[0] = address(WSTETH);
        leafs[16] = ManageLeaf(
            address(STETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve unstETH to spend stETH",
            rawDataDecoderAndSanitizer
        );
        leafs[16].argumentAddresses[0] = address(unstETH);
        leafs[17] = ManageLeaf(
            address(STETH), true, "submit(address)", new address[](1), "Mint stETH", rawDataDecoderAndSanitizer
        );
        leafs[17].argumentAddresses[0] = address(0);
        leafs[18] = ManageLeaf(
            address(WSTETH), false, "wrap(uint256)", new address[](0), "Wrap stETH", rawDataDecoderAndSanitizer
        );
        leafs[19] = ManageLeaf(
            address(WSTETH), false, "unwrap(uint256)", new address[](0), "Unwrap wstETH", rawDataDecoderAndSanitizer
        );
        leafs[20] = ManageLeaf(
            unstETH,
            false,
            "requestWithdrawals(uint256[],address)",
            new address[](1),
            "Request withdrawals from stETH",
            rawDataDecoderAndSanitizer
        );
        leafs[20].argumentAddresses[0] = boringVault;
        leafs[21] = ManageLeaf(
            unstETH,
            false,
            "claimWithdrawal(uint256)",
            new address[](0),
            "Claim stETH withdrawal",
            rawDataDecoderAndSanitizer
        );
        leafs[22] = ManageLeaf(
            unstETH,
            false,
            "claimWithdrawals(uint256[],uint256[])",
            new address[](0),
            "Claim stETH withdrawals",
            rawDataDecoderAndSanitizer
        );

        // balancer V2 and aura
        leafs[23] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer Vault to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[23].argumentAddresses[0] = vault;
        leafs[24] = ManageLeaf(
            address(RETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer Vault to spend ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[24].argumentAddresses[0] = vault;
        leafs[25] = ManageLeaf(
            address(WSTETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer Vault to spend wstETH",
            rawDataDecoderAndSanitizer
        );
        leafs[25].argumentAddresses[0] = vault;
        leafs[25] = ManageLeaf(
            address(RETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer Vault to spend rETH",
            rawDataDecoderAndSanitizer
        );
        leafs[25].argumentAddresses[0] = vault;
        leafs[25] = ManageLeaf(
            address(WEETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer Vault to spend weETH",
            rawDataDecoderAndSanitizer
        );
        leafs[25].argumentAddresses[0] = vault;
        leafs[26] = ManageLeaf(
            address(RSWETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer Vault to spend rswETH",
            rawDataDecoderAndSanitizer
        );
        leafs[26].argumentAddresses[0] = vault;
        leafs[27] = ManageLeaf(
            address(ezETH_weETH_rswETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer ezETH-weETH-rswETH gauge to spend ezETH-weETH-rswETH bpts",
            rawDataDecoderAndSanitizer
        );
        leafs[27].argumentAddresses[0] = ezETH_weETH_rswETH_gauge;
        leafs[28] = ManageLeaf(
            address(ezETH_weETH_rswETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Aura ezETH-weETH-rswETH gauge to spend ezETH-weETH-rswETH bpts",
            rawDataDecoderAndSanitizer
        );
        leafs[28].argumentAddresses[0] = aura_ezETH_weETH_rswETH;
        leafs[29] = ManageLeaf(
            address(ezETH_wETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer ezETH-wETH gauge to spend ezETH-wETH bpts",
            rawDataDecoderAndSanitizer
        );
        leafs[29].argumentAddresses[0] = ezETH_wETH_gauge;
        leafs[30] = ManageLeaf(
            address(ezETH_wETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Aura ezETH-wETH gauge to spend ezETH-wETH bpts",
            rawDataDecoderAndSanitizer
        );
        leafs[30].argumentAddresses[0] = aura_ezETH_wETH;
        leafs[31] = ManageLeaf(
            vault,
            false,
            "joinPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
            new address[](6),
            "Join ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[31].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[31].argumentAddresses[1] = address(boringVault);
        leafs[31].argumentAddresses[2] = address(boringVault);
        leafs[31].argumentAddresses[3] = address(EZETH);
        leafs[31].argumentAddresses[4] = address(WEETH);
        leafs[31].argumentAddresses[5] = address(RSWETH);
        leafs[32] = ManageLeaf(
            ezETH_weETH_rswETH_gauge,
            false,
            "deposit(uint256,address)",
            new address[](1),
            "Deposit ezETH-weETH-rswETH bpts into Balancer gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[32].argumentAddresses[0] = boringVault;
        leafs[33] = ManageLeaf(
            ezETH_weETH_rswETH_gauge,
            false,
            "withdraw(uint256)",
            new address[](0),
            "Withdraw ezETH-weETH-rswETH bpts from Balancer gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[34] = ManageLeaf(
            aura_ezETH_wETH,
            false,
            "deposit(uint256,address)",
            new address[](1),
            "Deposit ezETH-weETH-rswETH bpts into Aura gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[34].argumentAddresses[0] = boringVault;
        leafs[35] = ManageLeaf(
            aura_ezETH_wETH,
            false,
            "withdraw(uint256,address,address)",
            new address[](2),
            "Withdraw ezETH-weETH-rswETH bpts from Aura gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[35].argumentAddresses[0] = boringVault;
        leafs[35].argumentAddresses[1] = boringVault;
        leafs[36] = ManageLeaf(
            vault,
            false,
            "exitPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
            new address[](6),
            "Exit ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[36].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[36].argumentAddresses[1] = address(boringVault);
        leafs[36].argumentAddresses[2] = address(boringVault);
        leafs[36].argumentAddresses[3] = address(EZETH);
        leafs[36].argumentAddresses[4] = address(WEETH);
        leafs[36].argumentAddresses[5] = address(RSWETH);
        leafs[37] = ManageLeaf(
            vault,
            false,
            "joinPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
            new address[](5),
            "Join ezETH-wETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[37].argumentAddresses[0] = address(ezETH_wETH);
        leafs[37].argumentAddresses[1] = address(boringVault);
        leafs[37].argumentAddresses[2] = address(boringVault);
        leafs[37].argumentAddresses[3] = address(EZETH);
        leafs[37].argumentAddresses[4] = address(WETH);
        leafs[38] = ManageLeaf(
            ezETH_wETH_gauge,
            false,
            "deposit(uint256,address)",
            new address[](1),
            "Deposit ezETH-wETH bpts into Balancer gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[38].argumentAddresses[0] = boringVault;
        leafs[39] = ManageLeaf(
            ezETH_wETH_gauge,
            false,
            "withdraw(uint256)",
            new address[](0),
            "Withdraw ezETH-wETH bpts from Balancer gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[40] = ManageLeaf(
            aura_ezETH_wETH,
            false,
            "deposit(uint256,address)",
            new address[](1),
            "Deposit ezETH-wETH bpts into Aura gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[40].argumentAddresses[0] = boringVault;
        leafs[41] = ManageLeaf(
            aura_ezETH_wETH,
            false,
            "withdraw(uint256,address,address)",
            new address[](2),
            "Withdraw ezETH-wETH bpts from Aura gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[41].argumentAddresses[0] = boringVault;
        leafs[41].argumentAddresses[1] = boringVault;
        leafs[42] = ManageLeaf(
            vault,
            false,
            "exitPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
            new address[](5),
            "Exit ezETH-wETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[42].argumentAddresses[0] = address(ezETH_wETH);
        leafs[42].argumentAddresses[1] = address(boringVault);
        leafs[42].argumentAddresses[2] = address(boringVault);
        leafs[42].argumentAddresses[3] = address(EZETH);
        leafs[42].argumentAddresses[4] = address(WETH);
        leafs[43] = ManageLeaf(
            minter,
            false,
            "mint(address)",
            new address[](1),
            "Claim $BAL rewards for ezETH-weETH-rswETH Balancer gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[43].argumentAddresses[0] = address(ezETH_weETH_rswETH_gauge);
        leafs[44] = ManageLeaf(
            minter,
            false,
            "mint(address)",
            new address[](1),
            "Claim $BAL rewards for ezETH-wETH Balancer gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[44].argumentAddresses[0] = address(ezETH_wETH_gauge);
        leafs[45] = ManageLeaf(
            aura_ezETH_weETH_rswETH,
            false,
            "getReward(address,bool)",
            new address[](1),
            "Claim rewards for ezETH-weETH-rswETH Aura gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[45].argumentAddresses[0] = boringVault;
        leafs[46] = ManageLeaf(
            aura_ezETH_wETH,
            false,
            "getReward(address,bool)",
            new address[](1),
            "Claim rewards for ezETH-wETH Aura gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[46].argumentAddresses[0] = boringVault;

        // gearbox
        leafs[47] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Gearbox dWETHV3 to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[47].argumentAddresses[0] = dWETHV3;
        leafs[48] = ManageLeaf(
            dWETHV3,
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Gearbox sdWETHV3 to spend dWETHV3",
            rawDataDecoderAndSanitizer
        );
        leafs[48].argumentAddresses[0] = sdWETHV3;
        leafs[49] = ManageLeaf(
            dWETHV3,
            false,
            "deposit(uint256,address)",
            new address[](1),
            "Deposit into Gearbox dWETHV3",
            rawDataDecoderAndSanitizer
        );
        leafs[49].argumentAddresses[0] = boringVault;
        leafs[50] = ManageLeaf(
            dWETHV3,
            false,
            "withdraw(uint256,address,address)",
            new address[](2),
            "Withdraw from Gearbox dWETHV3",
            rawDataDecoderAndSanitizer
        );
        leafs[50].argumentAddresses[0] = boringVault;
        leafs[50].argumentAddresses[1] = boringVault;
        leafs[51] = ManageLeaf(
            sdWETHV3,
            false,
            "deposit(uint256)",
            new address[](0),
            "Deposit into Gearbox sdWETHV3",
            rawDataDecoderAndSanitizer
        );
        leafs[52] = ManageLeaf(
            sdWETHV3,
            false,
            "withdraw(uint256)",
            new address[](0),
            "Withdraw from Gearbox sdWETHV3",
            rawDataDecoderAndSanitizer
        );
        leafs[53] = ManageLeaf(
            sdWETHV3,
            false,
            "claim()",
            new address[](0),
            "Claim rewards from Gearbox sdWETHV3",
            rawDataDecoderAndSanitizer
        );

        // native wrapper
        leafs[54] = ManageLeaf(
            address(WETH), true, "deposit()", new address[](0), "Wrap ETH for wETH", rawDataDecoderAndSanitizer
        );
        leafs[55] = ManageLeaf(
            address(WETH),
            false,
            "withdraw(uint256)",
            new address[](0),
            "Unwrap wETH for ETH",
            rawDataDecoderAndSanitizer
        );

        // pendle

        // swap with balancer
        // swap with curve
        // swap with uniV3 -> move to other root
        // swap with 1inch -> move to other root

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/TestStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0]);
    }

    function testGenerateMerkleRoot() external {
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        leafs[0] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer Vault to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[0].argumentAddresses[0] = vault;
        leafs[1] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap wETH -> rETH using Balancer",
            rawDataDecoderAndSanitizer
        );
        leafs[1].argumentAddresses[0] = address(rETH_wETH);
        leafs[1].argumentAddresses[1] = address(WETH);
        leafs[1].argumentAddresses[2] = address(RETH);
        leafs[1].argumentAddresses[3] = boringVault;
        leafs[1].argumentAddresses[4] = boringVault;
        leafs[2] = ManageLeaf(
            address(RETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer Vault to spend rETH",
            rawDataDecoderAndSanitizer
        );
        leafs[2].argumentAddresses[0] = vault;
        leafs[3] = ManageLeaf(
            vault,
            false,
            "joinPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
            new address[](5),
            "Join rETH-wETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[3].argumentAddresses[0] = address(rETH_wETH);
        leafs[3].argumentAddresses[1] = boringVault;
        leafs[3].argumentAddresses[2] = boringVault;
        leafs[3].argumentAddresses[3] = address(RETH);
        leafs[3].argumentAddresses[4] = address(WETH);
        leafs[4] = ManageLeaf(
            address(rETH_wETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer rETH-wETH gauge to spend rETH-wETH bpts",
            rawDataDecoderAndSanitizer
        );
        leafs[4].argumentAddresses[0] = rETH_wETH_gauge;
        leafs[5] = ManageLeaf(
            rETH_wETH_gauge,
            false,
            "deposit(uint256,address)",
            new address[](1),
            "Deposit rETH-wETH bpts into Balancer gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[5].argumentAddresses[0] = boringVault;
        leafs[6] = ManageLeaf(
            rETH_wETH_gauge,
            false,
            "withdraw(uint256)",
            new address[](0),
            "Withdraw rETH-wETH bpts from Balancer gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[7] = ManageLeaf(
            address(rETH_wETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Aura rETH-wETH gauge to spend rETH-wETH bpts",
            rawDataDecoderAndSanitizer
        );
        leafs[7].argumentAddresses[0] = aura_reth_weth;
        leafs[8] = ManageLeaf(
            aura_reth_weth,
            false,
            "deposit(uint256,address)",
            new address[](1),
            "Deposit rETH-wETH bpts into Aura gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[8].argumentAddresses[0] = boringVault;
        leafs[9] = ManageLeaf(
            aura_reth_weth,
            false,
            "withdraw(uint256,address,address)",
            new address[](2),
            "Withdraw rETH-wETH bpts from Aura gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[9].argumentAddresses[0] = boringVault;
        leafs[9].argumentAddresses[1] = boringVault;
        leafs[10] = ManageLeaf(
            vault,
            false,
            "exitPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
            new address[](5),
            "Exit rETH-wETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[10].argumentAddresses[0] = address(rETH_wETH);
        leafs[10].argumentAddresses[1] = boringVault;
        leafs[10].argumentAddresses[2] = boringVault;
        leafs[10].argumentAddresses[3] = address(RETH);
        leafs[10].argumentAddresses[4] = address(WETH);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/example.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0]);
    }

    function _generateLeafs(string memory filePath, ManageLeaf[] memory leafs, bytes32 manageRoot) internal {
        if (vm.exists(filePath)) {
            // Need to delete it
            vm.removeFile(filePath);
        }
        vm.writeLine(filePath, "{ metadata: ");
        string[] memory composition = new string[](5);
        composition[0] = "Bytes20(DECODER_AND_SANITIZER_ADDRESS)";
        composition[1] = "Bytes20(TARGET_ADDRESS)";
        composition[2] = "Bytes1(CAN_SEND_VALUE)";
        composition[3] = "Bytes4(TARGET_FUNCTION_SELECTOR)";
        composition[4] = "Bytes{N*20}(ADDRESS_ARGUMENT_0,...,ADDRESS_ARGUMENT_N)";
        string memory metadata = "ManageRoot";
        vm.serializeUint(metadata, "LeafCount", leafs.length);
        vm.serializeString(metadata, "DigestComposition", composition);
        string memory finalMetadata = vm.serializeBytes32(metadata, "ManageRoot", manageRoot);

        vm.writeLine(filePath, finalMetadata);
        vm.writeLine(filePath, ",");
        vm.writeLine(filePath, "leafs: [");

        for (uint256 i; i < leafs.length; ++i) {
            string memory leaf = "leaf";
            vm.serializeAddress(leaf, "TargetAddress", leafs[i].target);
            vm.serializeAddress(leaf, "DecoderAndSanitizerAddress", leafs[i].decoderAndSanitizer);
            vm.serializeBool(leaf, "CanSendValue", leafs[i].canSendValue);
            vm.serializeString(leaf, "FunctionSignature", leafs[i].signature);
            bytes4 sel = bytes4(keccak256(abi.encodePacked(leafs[i].signature)));
            string memory selector = Strings.toHexString(uint32(sel), 4);
            vm.serializeString(leaf, "FunctionSelector", selector);
            bytes memory packedData;
            for (uint256 j; j < leafs[i].argumentAddresses.length; ++j) {
                packedData = abi.encodePacked(packedData, leafs[i].argumentAddresses[j]);
            }
            vm.serializeBytes(leaf, "PackedArgumentAddresses", packedData);
            vm.serializeAddress(leaf, "AddressArguments", leafs[i].argumentAddresses);
            bytes32 digest = keccak256(
                abi.encodePacked(leafs[i].decoderAndSanitizer, leafs[i].target, leafs[i].canSendValue, sel, packedData)
            );
            vm.serializeBytes32(leaf, "LeafDigest", digest);

            string memory finalJson = vm.serializeString(leaf, "Description", leafs[i].description);

            // vm.writeJson(finalJson, filePath);
            vm.writeLine(filePath, finalJson);
            vm.writeLine(filePath, ",");
        }
        vm.writeLine(filePath, "]}");
    }

    // ========================================= HELPER FUNCTIONS =========================================
    struct ManageLeaf {
        address target;
        bool canSendValue;
        string signature;
        address[] argumentAddresses;
        string description;
        address decoderAndSanitizer;
    }

    function _buildTrees(bytes32[][] memory merkleTreeIn) internal pure returns (bytes32[][] memory merkleTreeOut) {
        // We are adding another row to the merkle tree, so make merkleTreeOut be 1 longer.
        uint256 merkleTreeIn_length = merkleTreeIn.length;
        merkleTreeOut = new bytes32[][](merkleTreeIn_length + 1);
        uint256 layer_length;
        // Iterate through merkleTreeIn to copy over data.
        for (uint256 i; i < merkleTreeIn_length; ++i) {
            layer_length = merkleTreeIn[i].length;
            merkleTreeOut[i] = new bytes32[](layer_length);
            for (uint256 j; j < layer_length; ++j) {
                merkleTreeOut[i][j] = merkleTreeIn[i][j];
            }
        }

        uint256 next_layer_length;
        if (layer_length % 2 != 0) {
            next_layer_length = (layer_length + 1) / 2;
        } else {
            next_layer_length = layer_length / 2;
        }
        merkleTreeOut[merkleTreeIn_length] = new bytes32[](next_layer_length);
        uint256 count;
        for (uint256 i; i < layer_length; i += 2) {
            merkleTreeOut[merkleTreeIn_length][count] =
                _hashPair(merkleTreeIn[merkleTreeIn_length - 1][i], merkleTreeIn[merkleTreeIn_length - 1][i + 1]);
            count++;
        }

        if (next_layer_length > 1) {
            // We need to process the next layer of leaves.
            merkleTreeOut = _buildTrees(merkleTreeOut);
        }
    }

    function _generateMerkleTree(ManageLeaf[] memory manageLeafs) internal view returns (bytes32[][] memory tree) {
        uint256 leafsLength = manageLeafs.length;
        bytes32[][] memory leafs = new bytes32[][](1);
        leafs[0] = new bytes32[](leafsLength);
        for (uint256 i; i < leafsLength; ++i) {
            bytes4 selector = bytes4(keccak256(abi.encodePacked(manageLeafs[i].signature)));
            bytes memory rawDigest = abi.encodePacked(
                rawDataDecoderAndSanitizer, manageLeafs[i].target, manageLeafs[i].canSendValue, selector
            );
            uint256 argumentAddressesLength = manageLeafs[i].argumentAddresses.length;
            for (uint256 j; j < argumentAddressesLength; ++j) {
                rawDigest = abi.encodePacked(rawDigest, manageLeafs[i].argumentAddresses[j]);
            }
            leafs[0][i] = keccak256(rawDigest);
        }
        tree = _buildTrees(leafs);
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }

    function _finalizeRequest(uint256 requestId, uint256 amount) internal {
        // Spoof unstEth contract into finalizing our request.
        IWithdrawRequestNft w = IWithdrawRequestNft(withdrawalRequestNft);
        address owner = w.owner();
        vm.startPrank(owner);
        w.updateAdmin(address(this), true);
        vm.stopPrank();

        ILiquidityPool lp = ILiquidityPool(EETH_LIQUIDITY_POOL);

        deal(address(this), amount);
        lp.deposit{value: amount}();
        address admin = lp.etherFiAdminContract();

        vm.startPrank(admin);
        lp.addEthAmountLockedForWithdrawal(uint128(amount));
        vm.stopPrank();

        w.finalizeRequests(requestId);
    }
}

interface IWithdrawRequestNft {
    struct WithdrawRequest {
        uint96 amountOfEEth;
        uint96 shareOfEEth;
        bool isValid;
        uint32 feeGwei;
    }

    function claimWithdraw(uint256 tokenId) external;

    function getRequest(uint256 requestId) external view returns (WithdrawRequest memory);

    function finalizeRequests(uint256 requestId) external;

    function owner() external view returns (address);

    function updateAdmin(address admin, bool isAdmin) external;
}

interface ILiquidityPool {
    function deposit() external payable returns (uint256);

    function requestWithdraw(address recipient, uint256 amount) external returns (uint256);

    function amountForShare(uint256 shares) external view returns (uint256);

    function etherFiAdminContract() external view returns (address);

    function addEthAmountLockedForWithdrawal(uint128 _amount) external;
}
