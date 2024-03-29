// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "forge-std/Script.sol";

/**
 * forge script script/CreateMerkleRoot.s.sol:CreateMerkleRootScript
 */
contract CreateMerkleRootScript is Script, MainnetAddresses {
    using FixedPointMathLib for uint256;

    address public boringVault = address(1);
    address public rawDataDecoderAndSanitizer = address(2);
    address public managerAddress = address(3);

    function setUp() external {}

    function run() external {
        generateAdminRenzoStrategistMerkleRoot();
        generateProductionRenzoStrategistMerkleRoot();
        generateProductionRenzoDexAggregatorMicroManager();
        generateProductionRenzoDexSwapperMicroManager();
    }

    function generateAdminRenzoStrategistMerkleRoot() public {
        ManageLeaf[] memory leafs = new ManageLeaf[](128);

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
            address(EZETH),
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
        leafs[31].argumentAddresses[1] = boringVault;
        leafs[31].argumentAddresses[2] = boringVault;
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
        leafs[36].argumentAddresses[1] = boringVault;
        leafs[36].argumentAddresses[2] = boringVault;
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
        leafs[37].argumentAddresses[1] = boringVault;
        leafs[37].argumentAddresses[2] = boringVault;
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
        leafs[42].argumentAddresses[1] = boringVault;
        leafs[42].argumentAddresses[2] = boringVault;
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
        leafs[56] = ManageLeaf(
            address(EZETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Pendle router to spend ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[56].argumentAddresses[0] = pendleRouter;
        leafs[57] = ManageLeaf(
            pendleEzEthSy,
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Pendle router to spend SY-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[57].argumentAddresses[0] = pendleRouter;
        leafs[58] = ManageLeaf(
            pendleEzEthPt,
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Pendle router to spend PT-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[58].argumentAddresses[0] = pendleRouter;
        leafs[59] = ManageLeaf(
            pendleEzEthYt,
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Pendle router to spend YT-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[59].argumentAddresses[0] = pendleRouter;
        leafs[60] = ManageLeaf(
            pendleEzEthMarket,
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Pendle router to spend LP-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[60].argumentAddresses[0] = pendleRouter;
        leafs[61] = ManageLeaf(
            pendleRouter,
            false,
            "mintSyFromToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            new address[](6),
            "Mint SY-ezETH using ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[61].argumentAddresses[0] = boringVault;
        leafs[61].argumentAddresses[1] = pendleEzEthSy;
        leafs[61].argumentAddresses[2] = address(EZETH);
        leafs[61].argumentAddresses[3] = address(EZETH);
        leafs[61].argumentAddresses[4] = address(0);
        leafs[61].argumentAddresses[5] = address(0);
        leafs[62] = ManageLeaf(
            pendleRouter,
            false,
            "mintPyFromSy(address,address,uint256,uint256)",
            new address[](2),
            "Mint PT-ezETH and YT-ezETH from SY-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[62].argumentAddresses[0] = boringVault;
        leafs[62].argumentAddresses[1] = pendleEzEthYt;
        leafs[63] = ManageLeaf(
            pendleRouter,
            false,
            "swapExactYtForPt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            new address[](2),
            "Swap YT-ezETH for PT-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[63].argumentAddresses[0] = boringVault;
        leafs[63].argumentAddresses[1] = pendleEzEthMarket;
        leafs[64] = ManageLeaf(
            pendleRouter,
            false,
            "swapExactPtForYt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            new address[](2),
            "Swap PT-ezETH for YT-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[64].argumentAddresses[0] = boringVault;
        leafs[64].argumentAddresses[1] = pendleEzEthMarket;
        leafs[65] = ManageLeaf(
            pendleRouter,
            false,
            "addLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
            new address[](2),
            "Mint LP-ezETH using SY-ezETH and PT-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[65].argumentAddresses[0] = boringVault;
        leafs[65].argumentAddresses[1] = pendleEzEthMarket;
        leafs[66] = ManageLeaf(
            pendleRouter,
            false,
            "removeLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
            new address[](2),
            "Burn LP-ezETH for SY-ezETH and PT-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[66].argumentAddresses[0] = boringVault;
        leafs[66].argumentAddresses[1] = pendleEzEthMarket;
        leafs[67] = ManageLeaf(
            pendleRouter,
            false,
            "redeemPyToSy(address,address,uint256,uint256)",
            new address[](2),
            "Burn PT-ezETH and YT-ezETH for SY-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[67].argumentAddresses[0] = boringVault;
        leafs[67].argumentAddresses[1] = pendleEzEthYt;
        leafs[68] = ManageLeaf(
            pendleRouter,
            false,
            "redeemSyToToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            new address[](6),
            "Burn SY-ezETH for ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[68].argumentAddresses[0] = address(boringVault);
        leafs[68].argumentAddresses[1] = pendleEzEthSy;
        leafs[68].argumentAddresses[2] = address(EZETH);
        leafs[68].argumentAddresses[3] = address(EZETH);
        leafs[68].argumentAddresses[4] = address(0);
        leafs[68].argumentAddresses[5] = address(0);

        // flashloans
        leafs[69] = ManageLeaf(
            managerAddress,
            false,
            "flashLoan(address,address[],uint256[],bytes)",
            new address[](2),
            "Flash loan wETH from Balancer",
            rawDataDecoderAndSanitizer
        );
        leafs[69].argumentAddresses[0] = managerAddress;
        leafs[69].argumentAddresses[1] = address(WETH);

        // swap with balancer
        leafs[70] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap ezETH for weETH using ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[70].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[70].argumentAddresses[1] = address(EZETH);
        leafs[70].argumentAddresses[2] = address(WEETH);
        leafs[70].argumentAddresses[3] = address(boringVault);
        leafs[70].argumentAddresses[4] = address(boringVault);
        leafs[71] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap ezETH for rswETH using ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[71].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[71].argumentAddresses[1] = address(EZETH);
        leafs[71].argumentAddresses[2] = address(RSWETH);
        leafs[71].argumentAddresses[3] = address(boringVault);
        leafs[71].argumentAddresses[4] = address(boringVault);
        leafs[72] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap weETH for ezETH using ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[72].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[72].argumentAddresses[1] = address(WEETH);
        leafs[72].argumentAddresses[2] = address(EZETH);
        leafs[72].argumentAddresses[3] = address(boringVault);
        leafs[72].argumentAddresses[4] = address(boringVault);
        leafs[73] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap rswETH for ezETH using ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[73].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[73].argumentAddresses[1] = address(RSWETH);
        leafs[73].argumentAddresses[2] = address(EZETH);
        leafs[73].argumentAddresses[3] = address(boringVault);
        leafs[73].argumentAddresses[4] = address(boringVault);
        leafs[74] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap weETH for rswETH using ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[74].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[74].argumentAddresses[1] = address(WEETH);
        leafs[74].argumentAddresses[2] = address(RSWETH);
        leafs[74].argumentAddresses[3] = address(boringVault);
        leafs[74].argumentAddresses[4] = address(boringVault);
        leafs[75] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap rswETH for weETH using ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[75].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[75].argumentAddresses[1] = address(RSWETH);
        leafs[75].argumentAddresses[2] = address(WEETH);
        leafs[75].argumentAddresses[3] = address(boringVault);
        leafs[75].argumentAddresses[4] = address(boringVault);
        leafs[76] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap ezETH for wETH using ezETH-wETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[76].argumentAddresses[0] = address(ezETH_wETH);
        leafs[76].argumentAddresses[1] = address(EZETH);
        leafs[76].argumentAddresses[2] = address(WETH);
        leafs[76].argumentAddresses[3] = address(boringVault);
        leafs[76].argumentAddresses[4] = address(boringVault);
        leafs[77] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap wETH for ezETH using ezETH-wETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[77].argumentAddresses[0] = address(ezETH_wETH);
        leafs[77].argumentAddresses[1] = address(WETH);
        leafs[77].argumentAddresses[2] = address(EZETH);
        leafs[77].argumentAddresses[3] = address(boringVault);
        leafs[77].argumentAddresses[4] = address(boringVault);

        // swap with curve
        leafs[78] = ManageLeaf(
            address(EZETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve ezETH/wETH pool to spend ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[78].argumentAddresses[0] = ezETH_wETH_Curve_Pool;
        leafs[79] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve ezETH/wETH pool to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[79].argumentAddresses[0] = ezETH_wETH_Curve_Pool;
        leafs[80] = ManageLeaf(
            ezETH_wETH_Curve_Pool,
            false,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            "Swap using Curve ezETH/wETH pool",
            rawDataDecoderAndSanitizer
        );
        leafs[81] = ManageLeaf(
            address(WEETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve weETH/rswETH pool to spend weETH",
            rawDataDecoderAndSanitizer
        );
        leafs[81].argumentAddresses[0] = weETH_rswETH_Curve_Pool;
        leafs[82] = ManageLeaf(
            address(RSWETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve weETH/rswETH pool to spend rswETH",
            rawDataDecoderAndSanitizer
        );
        leafs[82].argumentAddresses[0] = weETH_rswETH_Curve_Pool;
        leafs[83] = ManageLeaf(
            weETH_rswETH_Curve_Pool,
            false,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            "Swap using Curve weETH/rswETH pool",
            rawDataDecoderAndSanitizer
        );
        leafs[84] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve rswETH/wETH pool to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[84].argumentAddresses[0] = rswETH_wETH_Curve_Pool;
        leafs[85] = ManageLeaf(
            address(RSWETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve rswETH/wETH pool to spend rswETH",
            rawDataDecoderAndSanitizer
        );
        leafs[85].argumentAddresses[0] = rswETH_wETH_Curve_Pool;
        leafs[86] = ManageLeaf(
            rswETH_wETH_Curve_Pool,
            false,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            "Swap using Curve rswETH/wETH pool",
            rawDataDecoderAndSanitizer
        );
        leafs[87] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve weETH/wETH pool to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[87].argumentAddresses[0] = weETH_wETH_Curve_LP;
        leafs[88] = ManageLeaf(
            address(WEETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve weETH/wETH pool to spend weETH",
            rawDataDecoderAndSanitizer
        );
        leafs[88].argumentAddresses[0] = weETH_wETH_Curve_LP;
        leafs[89] = ManageLeaf(
            weETH_wETH_Curve_LP,
            false,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            "Swap using Curve weETH/wETH pool",
            rawDataDecoderAndSanitizer
        );
        leafs[90] = ManageLeaf(
            address(STETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve ETH/stETH pool to spend stETH",
            rawDataDecoderAndSanitizer
        );
        leafs[90].argumentAddresses[0] = EthStethPool;
        leafs[91] = ManageLeaf(
            EthStethPool,
            true,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            "Swap using Curve ETH/stETH pool",
            rawDataDecoderAndSanitizer
        );

        // swap with uniV3 -> move to other root
        leafs[92] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 router to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[92].argumentAddresses[0] = uniV3Router;
        leafs[93] = ManageLeaf(
            address(RETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 router to spend rETH",
            rawDataDecoderAndSanitizer
        );
        leafs[93].argumentAddresses[0] = uniV3Router;
        leafs[94] = ManageLeaf(
            address(WSTETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 router to spend wstETH",
            rawDataDecoderAndSanitizer
        );
        leafs[94].argumentAddresses[0] = uniV3Router;
        leafs[95] = ManageLeaf(
            address(WEETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 router to spend weETH",
            rawDataDecoderAndSanitizer
        );
        leafs[95].argumentAddresses[0] = uniV3Router;
        leafs[96] = ManageLeaf(
            address(RSWETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 router to spend rswETH",
            rawDataDecoderAndSanitizer
        );
        leafs[96].argumentAddresses[0] = uniV3Router;
        leafs[97] = ManageLeaf(
            address(EZETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 router to spend ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[97].argumentAddresses[0] = uniV3Router;
        leafs[98] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap wETH for wstETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[98].argumentAddresses[0] = address(WETH);
        leafs[98].argumentAddresses[1] = address(WSTETH);
        leafs[98].argumentAddresses[2] = address(boringVault);
        leafs[99] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap wETH for rETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[99].argumentAddresses[0] = address(WETH);
        leafs[99].argumentAddresses[1] = address(RETH);
        leafs[99].argumentAddresses[2] = address(boringVault);
        leafs[100] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap wETH for ezETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[100].argumentAddresses[0] = address(WETH);
        leafs[100].argumentAddresses[1] = address(EZETH);
        leafs[100].argumentAddresses[2] = address(boringVault);
        leafs[101] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap wETH for weETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[101].argumentAddresses[0] = address(WETH);
        leafs[101].argumentAddresses[1] = address(WEETH);
        leafs[101].argumentAddresses[2] = address(boringVault);
        leafs[102] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap wETH for rswETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[102].argumentAddresses[0] = address(WETH);
        leafs[102].argumentAddresses[1] = address(RSWETH);
        leafs[102].argumentAddresses[2] = address(boringVault);
        leafs[103] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap wstETH for wETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[103].argumentAddresses[0] = address(WSTETH);
        leafs[103].argumentAddresses[1] = address(WETH);
        leafs[103].argumentAddresses[2] = address(boringVault);
        leafs[104] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap rETH for wETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[104].argumentAddresses[0] = address(RETH);
        leafs[104].argumentAddresses[1] = address(WETH);
        leafs[104].argumentAddresses[2] = address(boringVault);
        leafs[105] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap ezETH for wETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[105].argumentAddresses[0] = address(EZETH);
        leafs[105].argumentAddresses[1] = address(WETH);
        leafs[105].argumentAddresses[2] = address(boringVault);
        leafs[106] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap weETH for wETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[106].argumentAddresses[0] = address(WEETH);
        leafs[106].argumentAddresses[1] = address(WETH);
        leafs[106].argumentAddresses[2] = address(boringVault);
        leafs[107] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap rswETH for wETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[107].argumentAddresses[0] = address(RSWETH);
        leafs[107].argumentAddresses[1] = address(WETH);
        leafs[107].argumentAddresses[2] = address(boringVault);

        // swap with 1inch -> move to other root
        leafs[108] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve 1inch router to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[108].argumentAddresses[0] = aggregationRouterV5;
        leafs[109] = ManageLeaf(
            address(RETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve 1inch router to spend rETH",
            rawDataDecoderAndSanitizer
        );
        leafs[109].argumentAddresses[0] = aggregationRouterV5;
        leafs[110] = ManageLeaf(
            address(WSTETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve 1inch router to spend wstETH",
            rawDataDecoderAndSanitizer
        );
        leafs[110].argumentAddresses[0] = aggregationRouterV5;
        leafs[111] = ManageLeaf(
            address(WEETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve 1inch router to spend weETH",
            rawDataDecoderAndSanitizer
        );
        leafs[111].argumentAddresses[0] = aggregationRouterV5;
        leafs[112] = ManageLeaf(
            address(RSWETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve 1inch router to spend rswETH",
            rawDataDecoderAndSanitizer
        );
        leafs[112].argumentAddresses[0] = aggregationRouterV5;
        leafs[113] = ManageLeaf(
            address(EZETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve 1inch router to spend ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[113].argumentAddresses[0] = aggregationRouterV5;
        leafs[114] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap wETH for ezETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[114].argumentAddresses[0] = oneInchExecutor;
        leafs[114].argumentAddresses[1] = address(WETH);
        leafs[114].argumentAddresses[2] = address(EZETH);
        leafs[114].argumentAddresses[3] = oneInchExecutor;
        leafs[114].argumentAddresses[4] = boringVault;
        leafs[115] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap wETH for weETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[115].argumentAddresses[0] = oneInchExecutor;
        leafs[115].argumentAddresses[1] = address(WETH);
        leafs[115].argumentAddresses[2] = address(WEETH);
        leafs[115].argumentAddresses[3] = oneInchExecutor;
        leafs[115].argumentAddresses[4] = boringVault;
        leafs[116] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap wETH for wstETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[116].argumentAddresses[0] = oneInchExecutor;
        leafs[116].argumentAddresses[1] = address(WETH);
        leafs[116].argumentAddresses[2] = address(WSTETH);
        leafs[116].argumentAddresses[3] = oneInchExecutor;
        leafs[116].argumentAddresses[4] = boringVault;
        leafs[117] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap wETH for rETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[117].argumentAddresses[0] = oneInchExecutor;
        leafs[117].argumentAddresses[1] = address(WETH);
        leafs[117].argumentAddresses[2] = address(RETH);
        leafs[117].argumentAddresses[3] = oneInchExecutor;
        leafs[117].argumentAddresses[4] = boringVault;
        leafs[118] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap wETH for rswETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[118].argumentAddresses[0] = oneInchExecutor;
        leafs[118].argumentAddresses[1] = address(WETH);
        leafs[118].argumentAddresses[2] = address(RSWETH);
        leafs[118].argumentAddresses[3] = oneInchExecutor;
        leafs[118].argumentAddresses[4] = boringVault;
        leafs[119] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap ezETH for wETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[119].argumentAddresses[0] = oneInchExecutor;
        leafs[119].argumentAddresses[1] = address(EZETH);
        leafs[119].argumentAddresses[2] = address(WETH);
        leafs[119].argumentAddresses[3] = oneInchExecutor;
        leafs[119].argumentAddresses[4] = boringVault;
        leafs[120] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap wstETH for wETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[120].argumentAddresses[0] = oneInchExecutor;
        leafs[120].argumentAddresses[1] = address(WSTETH);
        leafs[120].argumentAddresses[2] = address(WETH);
        leafs[120].argumentAddresses[3] = oneInchExecutor;
        leafs[120].argumentAddresses[4] = boringVault;
        leafs[121] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap rETH for wETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[121].argumentAddresses[0] = oneInchExecutor;
        leafs[121].argumentAddresses[1] = address(RETH);
        leafs[121].argumentAddresses[2] = address(WETH);
        leafs[121].argumentAddresses[3] = oneInchExecutor;
        leafs[121].argumentAddresses[4] = boringVault;
        leafs[122] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap weETH for wETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[122].argumentAddresses[0] = oneInchExecutor;
        leafs[122].argumentAddresses[1] = address(WEETH);
        leafs[122].argumentAddresses[2] = address(WETH);
        leafs[122].argumentAddresses[3] = oneInchExecutor;
        leafs[122].argumentAddresses[4] = boringVault;
        leafs[123] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap rswETH for wETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[123].argumentAddresses[0] = oneInchExecutor;
        leafs[123].argumentAddresses[1] = address(RSWETH);
        leafs[123].argumentAddresses[2] = address(WETH);
        leafs[123].argumentAddresses[3] = oneInchExecutor;
        leafs[123].argumentAddresses[4] = boringVault;

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/AdminStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function generateProductionRenzoStrategistMerkleRoot() public {
        ManageLeaf[] memory leafs = new ManageLeaf[](128);

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
            address(EZETH),
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
        leafs[31].argumentAddresses[1] = boringVault;
        leafs[31].argumentAddresses[2] = boringVault;
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
        leafs[36].argumentAddresses[1] = boringVault;
        leafs[36].argumentAddresses[2] = boringVault;
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
        leafs[37].argumentAddresses[1] = boringVault;
        leafs[37].argumentAddresses[2] = boringVault;
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
        leafs[42].argumentAddresses[1] = boringVault;
        leafs[42].argumentAddresses[2] = boringVault;
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
        leafs[56] = ManageLeaf(
            address(EZETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Pendle router to spend ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[56].argumentAddresses[0] = pendleRouter;
        leafs[57] = ManageLeaf(
            pendleEzEthSy,
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Pendle router to spend SY-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[57].argumentAddresses[0] = pendleRouter;
        leafs[58] = ManageLeaf(
            pendleEzEthPt,
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Pendle router to spend PT-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[58].argumentAddresses[0] = pendleRouter;
        leafs[59] = ManageLeaf(
            pendleEzEthYt,
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Pendle router to spend YT-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[59].argumentAddresses[0] = pendleRouter;
        leafs[60] = ManageLeaf(
            pendleEzEthMarket,
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Pendle router to spend LP-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[60].argumentAddresses[0] = pendleRouter;
        leafs[61] = ManageLeaf(
            pendleRouter,
            false,
            "mintSyFromToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            new address[](6),
            "Mint SY-ezETH using ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[61].argumentAddresses[0] = boringVault;
        leafs[61].argumentAddresses[1] = pendleEzEthSy;
        leafs[61].argumentAddresses[2] = address(EZETH);
        leafs[61].argumentAddresses[3] = address(EZETH);
        leafs[61].argumentAddresses[4] = address(0);
        leafs[61].argumentAddresses[5] = address(0);
        leafs[62] = ManageLeaf(
            pendleRouter,
            false,
            "mintPyFromSy(address,address,uint256,uint256)",
            new address[](2),
            "Mint PT-ezETH and YT-ezETH from SY-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[62].argumentAddresses[0] = boringVault;
        leafs[62].argumentAddresses[1] = pendleEzEthYt;
        leafs[63] = ManageLeaf(
            pendleRouter,
            false,
            "swapExactYtForPt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            new address[](2),
            "Swap YT-ezETH for PT-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[63].argumentAddresses[0] = boringVault;
        leafs[63].argumentAddresses[1] = pendleEzEthMarket;
        leafs[64] = ManageLeaf(
            pendleRouter,
            false,
            "swapExactPtForYt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            new address[](2),
            "Swap PT-ezETH for YT-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[64].argumentAddresses[0] = boringVault;
        leafs[64].argumentAddresses[1] = pendleEzEthMarket;
        leafs[65] = ManageLeaf(
            pendleRouter,
            false,
            "addLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
            new address[](2),
            "Mint LP-ezETH using SY-ezETH and PT-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[65].argumentAddresses[0] = boringVault;
        leafs[65].argumentAddresses[1] = pendleEzEthMarket;
        leafs[66] = ManageLeaf(
            pendleRouter,
            false,
            "removeLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
            new address[](2),
            "Burn LP-ezETH for SY-ezETH and PT-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[66].argumentAddresses[0] = boringVault;
        leafs[66].argumentAddresses[1] = pendleEzEthMarket;
        leafs[67] = ManageLeaf(
            pendleRouter,
            false,
            "redeemPyToSy(address,address,uint256,uint256)",
            new address[](2),
            "Burn PT-ezETH and YT-ezETH for SY-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[67].argumentAddresses[0] = boringVault;
        leafs[67].argumentAddresses[1] = pendleEzEthYt;
        leafs[68] = ManageLeaf(
            pendleRouter,
            false,
            "redeemSyToToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            new address[](6),
            "Burn SY-ezETH for ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[68].argumentAddresses[0] = address(boringVault);
        leafs[68].argumentAddresses[1] = pendleEzEthSy;
        leafs[68].argumentAddresses[2] = address(EZETH);
        leafs[68].argumentAddresses[3] = address(EZETH);
        leafs[68].argumentAddresses[4] = address(0);
        leafs[68].argumentAddresses[5] = address(0);

        // flashloans
        leafs[69] = ManageLeaf(
            managerAddress,
            false,
            "flashLoan(address,address[],uint256[],bytes)",
            new address[](2),
            "Flash loan wETH from Balancer",
            rawDataDecoderAndSanitizer
        );
        leafs[69].argumentAddresses[0] = managerAddress;
        leafs[69].argumentAddresses[1] = address(WETH);

        // swap with balancer
        leafs[70] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap ezETH for weETH using ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[70].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[70].argumentAddresses[1] = address(EZETH);
        leafs[70].argumentAddresses[2] = address(WEETH);
        leafs[70].argumentAddresses[3] = address(boringVault);
        leafs[70].argumentAddresses[4] = address(boringVault);
        leafs[71] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap ezETH for rswETH using ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[71].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[71].argumentAddresses[1] = address(EZETH);
        leafs[71].argumentAddresses[2] = address(RSWETH);
        leafs[71].argumentAddresses[3] = address(boringVault);
        leafs[71].argumentAddresses[4] = address(boringVault);
        leafs[72] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap weETH for ezETH using ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[72].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[72].argumentAddresses[1] = address(WEETH);
        leafs[72].argumentAddresses[2] = address(EZETH);
        leafs[72].argumentAddresses[3] = address(boringVault);
        leafs[72].argumentAddresses[4] = address(boringVault);
        leafs[73] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap rswETH for ezETH using ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[73].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[73].argumentAddresses[1] = address(RSWETH);
        leafs[73].argumentAddresses[2] = address(EZETH);
        leafs[73].argumentAddresses[3] = address(boringVault);
        leafs[73].argumentAddresses[4] = address(boringVault);
        leafs[74] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap weETH for rswETH using ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[74].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[74].argumentAddresses[1] = address(WEETH);
        leafs[74].argumentAddresses[2] = address(RSWETH);
        leafs[74].argumentAddresses[3] = address(boringVault);
        leafs[74].argumentAddresses[4] = address(boringVault);
        leafs[75] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap rswETH for weETH using ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[75].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[75].argumentAddresses[1] = address(RSWETH);
        leafs[75].argumentAddresses[2] = address(WEETH);
        leafs[75].argumentAddresses[3] = address(boringVault);
        leafs[75].argumentAddresses[4] = address(boringVault);
        leafs[76] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap ezETH for wETH using ezETH-wETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[76].argumentAddresses[0] = address(ezETH_wETH);
        leafs[76].argumentAddresses[1] = address(EZETH);
        leafs[76].argumentAddresses[2] = address(WETH);
        leafs[76].argumentAddresses[3] = address(boringVault);
        leafs[76].argumentAddresses[4] = address(boringVault);
        leafs[77] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap wETH for ezETH using ezETH-wETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[77].argumentAddresses[0] = address(ezETH_wETH);
        leafs[77].argumentAddresses[1] = address(WETH);
        leafs[77].argumentAddresses[2] = address(EZETH);
        leafs[77].argumentAddresses[3] = address(boringVault);
        leafs[77].argumentAddresses[4] = address(boringVault);

        // swap with curve
        leafs[78] = ManageLeaf(
            address(EZETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve ezETH/wETH pool to spend ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[78].argumentAddresses[0] = ezETH_wETH_Curve_Pool;
        leafs[79] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve ezETH/wETH pool to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[79].argumentAddresses[0] = ezETH_wETH_Curve_Pool;
        leafs[80] = ManageLeaf(
            ezETH_wETH_Curve_Pool,
            false,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            "Swap using Curve ezETH/wETH pool",
            rawDataDecoderAndSanitizer
        );
        leafs[81] = ManageLeaf(
            address(WEETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve weETH/rswETH pool to spend weETH",
            rawDataDecoderAndSanitizer
        );
        leafs[81].argumentAddresses[0] = weETH_rswETH_Curve_Pool;
        leafs[82] = ManageLeaf(
            address(RSWETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve weETH/rswETH pool to spend rswETH",
            rawDataDecoderAndSanitizer
        );
        leafs[82].argumentAddresses[0] = weETH_rswETH_Curve_Pool;
        leafs[83] = ManageLeaf(
            weETH_rswETH_Curve_Pool,
            false,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            "Swap using Curve weETH/rswETH pool",
            rawDataDecoderAndSanitizer
        );
        leafs[84] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve rswETH/wETH pool to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[84].argumentAddresses[0] = rswETH_wETH_Curve_Pool;
        leafs[85] = ManageLeaf(
            address(RSWETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve rswETH/wETH pool to spend rswETH",
            rawDataDecoderAndSanitizer
        );
        leafs[85].argumentAddresses[0] = rswETH_wETH_Curve_Pool;
        leafs[86] = ManageLeaf(
            rswETH_wETH_Curve_Pool,
            false,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            "Swap using Curve rswETH/wETH pool",
            rawDataDecoderAndSanitizer
        );
        leafs[87] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve weETH/wETH pool to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[87].argumentAddresses[0] = weETH_wETH_Curve_LP;
        leafs[88] = ManageLeaf(
            address(WEETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve weETH/wETH pool to spend weETH",
            rawDataDecoderAndSanitizer
        );
        leafs[88].argumentAddresses[0] = weETH_wETH_Curve_LP;
        leafs[89] = ManageLeaf(
            weETH_wETH_Curve_LP,
            false,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            "Swap using Curve weETH/wETH pool",
            rawDataDecoderAndSanitizer
        );
        leafs[90] = ManageLeaf(
            address(STETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve ETH/stETH pool to spend stETH",
            rawDataDecoderAndSanitizer
        );
        leafs[90].argumentAddresses[0] = EthStethPool;
        leafs[91] = ManageLeaf(
            EthStethPool,
            true,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            "Swap using Curve ETH/stETH pool",
            rawDataDecoderAndSanitizer
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/RenzoStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function generateProductionRenzoDexAggregatorMicroManager() public {
        ManageLeaf[] memory leafs = new ManageLeaf[](16);

        // swap with 1inch -> move to other root
        leafs[0] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve 1inch router to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[0].argumentAddresses[0] = aggregationRouterV5;
        leafs[1] = ManageLeaf(
            address(RETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve 1inch router to spend rETH",
            rawDataDecoderAndSanitizer
        );
        leafs[1].argumentAddresses[0] = aggregationRouterV5;
        leafs[2] = ManageLeaf(
            address(WSTETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve 1inch router to spend wstETH",
            rawDataDecoderAndSanitizer
        );
        leafs[2].argumentAddresses[0] = aggregationRouterV5;
        leafs[3] = ManageLeaf(
            address(WEETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve 1inch router to spend weETH",
            rawDataDecoderAndSanitizer
        );
        leafs[3].argumentAddresses[0] = aggregationRouterV5;
        leafs[4] = ManageLeaf(
            address(RSWETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve 1inch router to spend rswETH",
            rawDataDecoderAndSanitizer
        );
        leafs[4].argumentAddresses[0] = aggregationRouterV5;
        leafs[5] = ManageLeaf(
            address(EZETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve 1inch router to spend ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[5].argumentAddresses[0] = aggregationRouterV5;
        leafs[6] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap wETH for ezETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[6].argumentAddresses[0] = oneInchExecutor;
        leafs[6].argumentAddresses[1] = address(WETH);
        leafs[6].argumentAddresses[2] = address(EZETH);
        leafs[6].argumentAddresses[3] = oneInchExecutor;
        leafs[6].argumentAddresses[4] = boringVault;
        leafs[7] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap wETH for weETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[7].argumentAddresses[0] = oneInchExecutor;
        leafs[7].argumentAddresses[1] = address(WETH);
        leafs[7].argumentAddresses[2] = address(WEETH);
        leafs[7].argumentAddresses[3] = oneInchExecutor;
        leafs[7].argumentAddresses[4] = boringVault;
        leafs[8] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap wETH for wstETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[8].argumentAddresses[0] = oneInchExecutor;
        leafs[8].argumentAddresses[1] = address(WETH);
        leafs[8].argumentAddresses[2] = address(WSTETH);
        leafs[8].argumentAddresses[3] = oneInchExecutor;
        leafs[8].argumentAddresses[4] = boringVault;
        leafs[9] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap wETH for rETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[9].argumentAddresses[0] = oneInchExecutor;
        leafs[9].argumentAddresses[1] = address(WETH);
        leafs[9].argumentAddresses[2] = address(RETH);
        leafs[9].argumentAddresses[3] = oneInchExecutor;
        leafs[9].argumentAddresses[4] = boringVault;
        leafs[10] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap wETH for rswETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[10].argumentAddresses[0] = oneInchExecutor;
        leafs[10].argumentAddresses[1] = address(WETH);
        leafs[10].argumentAddresses[2] = address(RSWETH);
        leafs[10].argumentAddresses[3] = oneInchExecutor;
        leafs[10].argumentAddresses[4] = boringVault;
        leafs[11] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap ezETH for wETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[11].argumentAddresses[0] = oneInchExecutor;
        leafs[11].argumentAddresses[1] = address(EZETH);
        leafs[11].argumentAddresses[2] = address(WETH);
        leafs[11].argumentAddresses[3] = oneInchExecutor;
        leafs[11].argumentAddresses[4] = boringVault;
        leafs[12] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap wstETH for wETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[12].argumentAddresses[0] = oneInchExecutor;
        leafs[12].argumentAddresses[1] = address(WSTETH);
        leafs[12].argumentAddresses[2] = address(WETH);
        leafs[12].argumentAddresses[3] = oneInchExecutor;
        leafs[12].argumentAddresses[4] = boringVault;
        leafs[13] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap rETH for wETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[13].argumentAddresses[0] = oneInchExecutor;
        leafs[13].argumentAddresses[1] = address(RETH);
        leafs[13].argumentAddresses[2] = address(WETH);
        leafs[13].argumentAddresses[3] = oneInchExecutor;
        leafs[13].argumentAddresses[4] = boringVault;
        leafs[14] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap weETH for wETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[14].argumentAddresses[0] = oneInchExecutor;
        leafs[14].argumentAddresses[1] = address(WEETH);
        leafs[14].argumentAddresses[2] = address(WETH);
        leafs[14].argumentAddresses[3] = oneInchExecutor;
        leafs[14].argumentAddresses[4] = boringVault;
        leafs[15] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap rswETH for wETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[15].argumentAddresses[0] = oneInchExecutor;
        leafs[15].argumentAddresses[1] = address(RSWETH);
        leafs[15].argumentAddresses[2] = address(WETH);
        leafs[15].argumentAddresses[3] = oneInchExecutor;
        leafs[15].argumentAddresses[4] = boringVault;

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/RenzoDexAggregatorMicroManagerLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function generateProductionRenzoDexSwapperMicroManager() public {
        ManageLeaf[] memory leafs = new ManageLeaf[](16);

        // swap with uniV3 -> move to other root
        leafs[0] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 router to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[0].argumentAddresses[0] = uniV3Router;
        leafs[1] = ManageLeaf(
            address(RETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 router to spend rETH",
            rawDataDecoderAndSanitizer
        );
        leafs[1].argumentAddresses[0] = uniV3Router;
        leafs[2] = ManageLeaf(
            address(WSTETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 router to spend wstETH",
            rawDataDecoderAndSanitizer
        );
        leafs[2].argumentAddresses[0] = uniV3Router;
        leafs[3] = ManageLeaf(
            address(WEETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 router to spend weETH",
            rawDataDecoderAndSanitizer
        );
        leafs[3].argumentAddresses[0] = uniV3Router;
        leafs[4] = ManageLeaf(
            address(RSWETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 router to spend rswETH",
            rawDataDecoderAndSanitizer
        );
        leafs[4].argumentAddresses[0] = uniV3Router;
        leafs[5] = ManageLeaf(
            address(EZETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 router to spend ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[5].argumentAddresses[0] = uniV3Router;
        leafs[6] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap wETH for wstETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[6].argumentAddresses[0] = address(WETH);
        leafs[6].argumentAddresses[1] = address(WSTETH);
        leafs[6].argumentAddresses[2] = address(boringVault);
        leafs[7] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap wETH for rETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[7].argumentAddresses[0] = address(WETH);
        leafs[7].argumentAddresses[1] = address(RETH);
        leafs[7].argumentAddresses[2] = address(boringVault);
        leafs[8] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap wETH for ezETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[8].argumentAddresses[0] = address(WETH);
        leafs[8].argumentAddresses[1] = address(EZETH);
        leafs[8].argumentAddresses[2] = address(boringVault);
        leafs[9] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap wETH for weETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[9].argumentAddresses[0] = address(WETH);
        leafs[9].argumentAddresses[1] = address(WEETH);
        leafs[9].argumentAddresses[2] = address(boringVault);
        leafs[10] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap wETH for rswETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[10].argumentAddresses[0] = address(WETH);
        leafs[10].argumentAddresses[1] = address(RSWETH);
        leafs[10].argumentAddresses[2] = address(boringVault);
        leafs[11] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap wstETH for wETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[11].argumentAddresses[0] = address(WSTETH);
        leafs[11].argumentAddresses[1] = address(WETH);
        leafs[11].argumentAddresses[2] = address(boringVault);
        leafs[12] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap rETH for wETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[12].argumentAddresses[0] = address(RETH);
        leafs[12].argumentAddresses[1] = address(WETH);
        leafs[12].argumentAddresses[2] = address(boringVault);
        leafs[13] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap ezETH for wETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[13].argumentAddresses[0] = address(EZETH);
        leafs[13].argumentAddresses[1] = address(WETH);
        leafs[13].argumentAddresses[2] = address(boringVault);
        leafs[14] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap weETH for wETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[14].argumentAddresses[0] = address(WEETH);
        leafs[14].argumentAddresses[1] = address(WETH);
        leafs[14].argumentAddresses[2] = address(boringVault);
        leafs[15] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap rswETH for wETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[15].argumentAddresses[0] = address(RSWETH);
        leafs[15].argumentAddresses[1] = address(WETH);
        leafs[15].argumentAddresses[2] = address(boringVault);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/RenzoDexSwapperMicroManagerLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function _generateLeafs(
        string memory filePath,
        ManageLeaf[] memory leafs,
        bytes32 manageRoot,
        bytes32[][] memory manageTree
    ) internal {
        if (vm.exists(filePath)) {
            // Need to delete it
            vm.removeFile(filePath);
        }
        vm.writeLine(filePath, "{ \"metadata\": ");
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
        vm.writeLine(filePath, "\"leafs\": [");

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
            if (i != leafs.length - 1) {
                vm.writeLine(filePath, ",");
            }
        }
        vm.writeLine(filePath, "],");

        string memory merkleTreeName = "MerkleTree";
        string[][] memory merkleTree = new string[][](manageTree.length);
        for (uint256 k; k < manageTree.length; ++k) {
            merkleTree[k] = new string[](manageTree[k].length);
        }

        for (uint256 i; i < manageTree.length; ++i) {
            for (uint256 j; j < manageTree[i].length; ++j) {
                merkleTree[i][j] = vm.toString(manageTree[i][j]);
            }
        }

        string memory finalMerkleTree;
        for (uint256 i; i < merkleTree.length; ++i) {
            string memory layer = Strings.toString(merkleTree.length - (i + 1));
            finalMerkleTree = vm.serializeString(merkleTreeName, layer, merkleTree[i]);
        }
        vm.writeLine(filePath, "\"MerkleTree\": ");
        vm.writeLine(filePath, finalMerkleTree);
        vm.writeLine(filePath, "}");
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
}
