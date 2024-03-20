// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {
    EtherFiLiquidDecoderAndSanitizer,
    BalancerV2DecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/EtherFiLiquidDecoderAndSanitizer.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {IUniswapV3Router} from "src/interfaces/IUniswapV3Router.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract ManagerWithMerkleVerificationTest is Test, MainnetAddresses {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;

    address public weEthOracle = 0x3fa58b74e9a8eA8768eb33c8453e9C2Ed089A40a;
    address public weEthIrm = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19369928;
        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(this), address(this), address(boringVault), vault);

        rawDataDecoderAndSanitizer =
            address(new EtherFiLiquidDecoderAndSanitizer(address(boringVault), uniswapV3NonFungiblePositionManager));

        boringVault.grantRole(boringVault.MANAGER_ROLE(), address(manager));

        manager.setRawDataDecoderAndSanitizer(address(rawDataDecoderAndSanitizer));
    }

    function testManagerMerkleVerificationHappyPath() external {
        // Allow the manager to call the USDC approve function to a specific address,
        // and the USDT transfer function to a specific address.
        address usdcSpender = vm.addr(0xDEAD);
        address usdtTo = vm.addr(0xDEAD1);
        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        leafs[0] = ManageLeaf(address(USDC), "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = usdcSpender;
        leafs[1] = ManageLeaf(address(USDT), "approve(address,uint256)", new address[](1));
        leafs[1].argumentAddresses[0] = usdtTo;

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(manageTree[1][0]);

        address[] memory targets = new address[](2);
        targets[0] = address(USDC);
        targets[1] = address(USDT);

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, usdcSpender, 777);
        targetData[1] = abi.encodeWithSelector(ERC20.approve.selector, usdtTo, 777);

        (bytes32[][] memory manageProofs) = _getProofsUsingTree(leafs, manageTree);

        uint256[] memory values = new uint256[](2);

        deal(address(USDT), address(boringVault), 777);

        uint256 gas = gasleft();
        manager.manageVaultWithMerkleVerification(manageProofs, targets, targetData, values);
        console.log("Gas used", gas - gasleft());

        assertEq(USDC.allowance(address(boringVault), usdcSpender), 777, "USDC should have an allowance");
        assertEq(USDT.allowance(address(boringVault), usdtTo), 777, "USDT should have have an allowance");
    }

    function testFlashLoan() external {
        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        leafs[0] = ManageLeaf(address(manager), "flashLoan(address,address[],uint256[],bytes)", new address[](2));
        leafs[0].argumentAddresses[0] = address(manager);
        leafs[0].argumentAddresses[1] = address(USDC);
        leafs[1] = ManageLeaf(address(this), "approve(address,uint256)", new address[](1));
        leafs[1].argumentAddresses[0] = address(USDC);
        leafs[2] = ManageLeaf(address(USDC), "approve(address,uint256)", new address[](1));
        leafs[2].argumentAddresses[0] = address(this);
        // leaf[3] empty

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(manageTree[2][0]);

        bytes memory userData;
        {
            uint256 flashLoanAmount = 1_000_000e6;
            // Build flashLoan data.
            address[] memory targets = new address[](2);
            targets[0] = address(USDC);
            targets[1] = address(this);
            bytes[] memory targetData = new bytes[](2);
            targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(this), flashLoanAmount);
            targetData[1] = abi.encodeWithSelector(ERC20.approve.selector, address(USDC), flashLoanAmount);

            ManageLeaf[] memory flashLoanLeafs = new ManageLeaf[](2);
            flashLoanLeafs[0] = leafs[2];
            flashLoanLeafs[1] = leafs[1];

            bytes32[][] memory flashLoanManageProofs = _getProofsUsingTree(flashLoanLeafs, manageTree);

            uint256[] memory values = new uint256[](2);

            userData = abi.encode(flashLoanManageProofs, targets, targetData, values);
        }
        {
            address[] memory targets = new address[](1);
            targets[0] = address(manager);

            address[] memory tokensToBorrow = new address[](1);
            tokensToBorrow[0] = address(USDC);
            uint256[] memory amountsToBorrow = new uint256[](1);
            amountsToBorrow[0] = 1_000_000e6;
            bytes[] memory targetData = new bytes[](1);
            targetData[0] = abi.encodeWithSelector(
                BalancerVault.flashLoan.selector, address(manager), tokensToBorrow, amountsToBorrow, userData
            );

            ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
            manageLeafs[0] = leafs[0];

            bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

            uint256[] memory values = new uint256[](1);

            manager.manageVaultWithMerkleVerification(manageProofs, targets, targetData, values);

            assertTrue(iDidSomething == true, "Should have called doSomethingWithFlashLoan");
        }
    }

    // TODO add balancer revert test checks
    function testBalancerV2AndAuraIntegration() external {
        deal(address(WETH), address(boringVault), 1_000e18);
        bytes32 poolId = 0x1e19cf2d73a72ef1332c882f20534b6519be0276000200000000000000000112;
        // Make sure the vault can
        // swap wETH -> rETH
        // add liquidity rETH/wETH
        // add to an existing position rETH/wETH
        // stake in balancer
        // unstake from balancer
        // stake in aura
        // unstake from aura
        // remove liquidity from rETH/wETH
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        leafs[0] = ManageLeaf(address(WETH), "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = vault;
        leafs[1] = ManageLeaf(
            vault,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5)
        );
        leafs[1].argumentAddresses[0] = address(rETH_wETH);
        leafs[1].argumentAddresses[1] = address(WETH);
        leafs[1].argumentAddresses[2] = address(RETH);
        leafs[1].argumentAddresses[3] = address(boringVault);
        leafs[1].argumentAddresses[4] = address(boringVault);
        leafs[2] = ManageLeaf(address(RETH), "approve(address,uint256)", new address[](1));
        leafs[2].argumentAddresses[0] = vault;
        leafs[3] =
            ManageLeaf(vault, "joinPool(bytes32,address,address,(address[],uint256[],bytes,bool))", new address[](5));
        leafs[3].argumentAddresses[0] = address(rETH_wETH);
        leafs[3].argumentAddresses[1] = address(boringVault);
        leafs[3].argumentAddresses[2] = address(boringVault);
        leafs[3].argumentAddresses[3] = address(RETH);
        leafs[3].argumentAddresses[4] = address(WETH);
        leafs[4] = ManageLeaf(address(rETH_wETH), "approve(address,uint256)", new address[](1));
        leafs[4].argumentAddresses[0] = rETH_wETH_gauge;
        leafs[5] = ManageLeaf(rETH_wETH_gauge, "deposit(uint256,address)", new address[](1));
        leafs[5].argumentAddresses[0] = address(boringVault);
        leafs[6] = ManageLeaf(rETH_wETH_gauge, "withdraw(uint256)", new address[](0));
        leafs[7] = ManageLeaf(address(rETH_wETH), "approve(address,uint256)", new address[](1));
        leafs[7].argumentAddresses[0] = aura_reth_weth;
        leafs[8] = ManageLeaf(aura_reth_weth, "deposit(uint256,address)", new address[](1));
        leafs[8].argumentAddresses[0] = address(boringVault);
        leafs[9] = ManageLeaf(aura_reth_weth, "withdraw(uint256,address,address)", new address[](2));
        leafs[9].argumentAddresses[0] = address(boringVault);
        leafs[9].argumentAddresses[1] = address(boringVault);
        leafs[10] =
            ManageLeaf(vault, "exitPool(bytes32,address,address,(address[],uint256[],bytes,bool))", new address[](5));
        leafs[10].argumentAddresses[0] = address(rETH_wETH);
        leafs[10].argumentAddresses[1] = address(boringVault);
        leafs[10].argumentAddresses[2] = address(boringVault);
        leafs[10].argumentAddresses[3] = address(RETH);
        leafs[10].argumentAddresses[4] = address(WETH);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](11);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];
        manageLeafs[3] = leafs[3];
        manageLeafs[4] = leafs[4];
        manageLeafs[5] = leafs[5];
        manageLeafs[6] = leafs[6];
        manageLeafs[7] = leafs[7];
        manageLeafs[8] = leafs[8];
        manageLeafs[9] = leafs[9];
        manageLeafs[10] = leafs[10];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](11);
        targets[0] = address(WETH);
        targets[1] = vault;
        targets[2] = address(RETH);
        targets[3] = vault;
        targets[4] = address(rETH_wETH);
        targets[5] = rETH_wETH_gauge;
        targets[6] = rETH_wETH_gauge;
        targets[7] = address(rETH_wETH);
        targets[8] = aura_reth_weth;
        targets[9] = aura_reth_weth;
        targets[10] = vault;
        // targets[7] = uniswapV3NonFungiblePositionManager;
        bytes[] memory targetData = new bytes[](11);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", vault, type(uint256).max);
        DecoderCustomTypes.SingleSwap memory singleSwap = DecoderCustomTypes.SingleSwap({
            poolId: poolId,
            kind: DecoderCustomTypes.SwapKind.GIVEN_IN,
            assetIn: address(WETH),
            assetOut: address(RETH),
            amount: 500e18,
            userData: hex""
        });
        DecoderCustomTypes.FundManagement memory funds = DecoderCustomTypes.FundManagement({
            sender: address(boringVault),
            fromInternalBalance: false,
            recipient: address(boringVault),
            toInternalBalance: false
        });
        targetData[1] = abi.encodeWithSelector(BalancerV2DecoderAndSanitizer.swap.selector, singleSwap, funds, 0);
        targetData[2] = abi.encodeWithSignature("approve(address,uint256)", vault, type(uint256).max);
        DecoderCustomTypes.JoinPoolRequest memory joinRequest = DecoderCustomTypes.JoinPoolRequest({
            assets: new address[](2),
            maxAmountsIn: new uint256[](2),
            userData: hex"",
            fromInternalBalance: false
        });
        joinRequest.assets[0] = address(RETH);
        joinRequest.assets[1] = address(WETH);
        joinRequest.maxAmountsIn[0] = 100e18;
        joinRequest.maxAmountsIn[1] = 100e18;
        joinRequest.userData = abi.encode(1, joinRequest.maxAmountsIn, 0); // EXACT_TOKENS_IN_FOR_BPT_OUT, [100e18,100e18], 0
        targetData[3] = abi.encodeWithSelector(
            BalancerV2DecoderAndSanitizer.joinPool.selector,
            poolId,
            address(boringVault),
            address(boringVault),
            joinRequest
        );
        targetData[4] = abi.encodeWithSignature("approve(address,uint256)", rETH_wETH_gauge, type(uint256).max);
        targetData[5] = abi.encodeWithSignature("deposit(uint256,address)", 203690537881715311640, address(boringVault));
        targetData[6] = abi.encodeWithSignature("withdraw(uint256)", 203690537881715311640, address(boringVault));
        targetData[7] = abi.encodeWithSignature("approve(address,uint256)", aura_reth_weth, type(uint256).max);
        targetData[8] = abi.encodeWithSignature("deposit(uint256,address)", 203690537881715311640, address(boringVault));
        targetData[9] = abi.encodeWithSignature(
            "withdraw(uint256,address,address)", 203690537881715311640, address(boringVault), address(boringVault)
        );
        DecoderCustomTypes.ExitPoolRequest memory exitRequest = DecoderCustomTypes.ExitPoolRequest({
            assets: new address[](2),
            minAmountsOut: new uint256[](2),
            userData: hex"",
            toInternalBalance: false
        });
        exitRequest.assets[0] = address(RETH);
        exitRequest.assets[1] = address(WETH);
        exitRequest.userData = abi.encode(1, 203690537881715311640); // EXACT_BPT_IN_FOR_TOKENS_OUT, 203690537881715311640
        targetData[10] = abi.encodeWithSelector(
            BalancerV2DecoderAndSanitizer.exitPool.selector,
            poolId,
            address(boringVault),
            address(boringVault),
            exitRequest
        );

        manager.manageVaultWithMerkleVerification(manageProofs, targets, targetData, new uint256[](11));

        // Make sure we can call Balancer mint and Aura getReward
        leafs = new ManageLeaf[](2);
        leafs[0] = ManageLeaf(minter, "mint(address)", new address[](1));
        leafs[0].argumentAddresses[0] = rETH_wETH_gauge;
        leafs[1] = ManageLeaf(aura_reth_weth, "getReward(address,bool)", new address[](1));
        leafs[1].argumentAddresses[0] = address(boringVault);

        manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(manageTree[manageTree.length - 1][0]);

        manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](2);
        targets[0] = minter;
        targets[1] = aura_reth_weth;
        targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("mint(address)", rETH_wETH_gauge);
        targetData[1] = abi.encodeWithSignature("getReward(address,bool)", address(boringVault), true);

        manager.manageVaultWithMerkleVerification(manageProofs, targets, targetData, new uint256[](2));
    }

    // TODO add uniswap revert test checks
    function testUniswapV3Integration() external {
        deal(address(WETH), address(boringVault), 100e18);
        deal(address(WEETH), address(boringVault), 100e18);
        // Make sure the vault can
        // swap wETH -> rETH
        // create a new position rETH/weETH
        // add to an existing position rETH/weETH
        // pull from an existing position rETH/weETH
        // collect from a position rETH/weETH
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        leafs[0] = ManageLeaf(address(WETH), "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = uniV3Router;
        leafs[1] = ManageLeaf(uniV3Router, "exactInput((bytes,address,uint256,uint256,uint256))", new address[](3));
        leafs[1].argumentAddresses[0] = address(WETH);
        leafs[1].argumentAddresses[1] = address(RETH);
        leafs[1].argumentAddresses[2] = address(boringVault);
        leafs[2] = ManageLeaf(address(RETH), "approve(address,uint256)", new address[](1));
        leafs[2].argumentAddresses[0] = uniswapV3NonFungiblePositionManager;
        leafs[3] = ManageLeaf(address(WEETH), "approve(address,uint256)", new address[](1));
        leafs[3].argumentAddresses[0] = uniswapV3NonFungiblePositionManager;
        leafs[4] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
            new address[](3)
        );
        leafs[4].argumentAddresses[0] = address(RETH);
        leafs[4].argumentAddresses[1] = address(WEETH);
        leafs[4].argumentAddresses[2] = address(boringVault);
        leafs[5] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
            new address[](0)
        );
        leafs[6] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            new address[](0)
        );
        leafs[7] = ManageLeaf(
            uniswapV3NonFungiblePositionManager, "collect((uint256,address,uint128,uint128))", new address[](1)
        );
        leafs[7].argumentAddresses[0] = address(boringVault);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](8);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];
        manageLeafs[3] = leafs[3];
        manageLeafs[4] = leafs[4];
        manageLeafs[5] = leafs[5];
        manageLeafs[6] = leafs[6];
        manageLeafs[7] = leafs[7];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](8);
        targets[0] = address(WETH);
        targets[1] = uniV3Router;
        targets[2] = address(RETH);
        targets[3] = address(WEETH);
        targets[4] = uniswapV3NonFungiblePositionManager;
        targets[5] = uniswapV3NonFungiblePositionManager;
        targets[6] = uniswapV3NonFungiblePositionManager;
        targets[7] = uniswapV3NonFungiblePositionManager;
        bytes[] memory targetData = new bytes[](8);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", uniV3Router, type(uint256).max);
        DecoderCustomTypes.ExactInputParams memory exactInputParams = DecoderCustomTypes.ExactInputParams(
            abi.encodePacked(WETH, uint24(100), RETH), address(boringVault), block.timestamp, 100e18, 0
        );
        targetData[1] = abi.encodeWithSignature("exactInput((bytes,address,uint256,uint256,uint256))", exactInputParams);
        targetData[2] =
            abi.encodeWithSignature("approve(address,uint256)", uniswapV3NonFungiblePositionManager, type(uint256).max);
        targetData[3] =
            abi.encodeWithSignature("approve(address,uint256)", uniswapV3NonFungiblePositionManager, type(uint256).max);

        DecoderCustomTypes.MintParams memory mintParams = DecoderCustomTypes.MintParams(
            address(RETH),
            address(WEETH),
            uint24(100),
            int24(600), // lower tick
            int24(700), // upper tick
            45e18,
            45e18,
            0,
            0,
            address(boringVault),
            block.timestamp
        );
        targetData[4] = abi.encodeWithSignature(
            "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))", mintParams
        );
        uint256 expectedTokenId = 688183;
        DecoderCustomTypes.IncreaseLiquidityParams memory increaseLiquidityParams =
            DecoderCustomTypes.IncreaseLiquidityParams(expectedTokenId, 45e18, 45e18, 0, 0, block.timestamp);
        targetData[5] = abi.encodeWithSignature(
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))", increaseLiquidityParams
        );
        uint128 expectedLiquidity = 17435811346020121907400;
        DecoderCustomTypes.DecreaseLiquidityParams memory decreaseLiquidityParams =
            DecoderCustomTypes.DecreaseLiquidityParams(expectedTokenId, expectedLiquidity, 0, 0, block.timestamp);
        targetData[6] = abi.encodeWithSignature(
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))", decreaseLiquidityParams
        );

        DecoderCustomTypes.CollectParams memory collectParams = DecoderCustomTypes.CollectParams(
            expectedTokenId, address(boringVault), type(uint128).max, type(uint128).max
        );
        targetData[7] = abi.encodeWithSignature("collect((uint256,address,uint128,uint128))", collectParams);

        // uint256 memSize = 0;
        // assembly {
        //     memSize := msize()
        // }
        uint256 gas = gasleft();
        manager.manageVaultWithMerkleVerification(manageProofs, targets, targetData, new uint256[](8));
        console.log("Gas used", gas - gasleft());
    }

    function testCurveAndConvexIntegration() external {
        deal(address(WETH), address(boringVault), 100e18);

        // weETH_wETH_Curve_LP
        // weETH_wETH_Curve_Gauge

        // Make sure the vault can
        // swap wETH -> weETH
        // add liquidity weETH/wETH
        // deposit to gauge
        // withdraw from gauge
        // claim gauge rewards
        // deposit into convex pId 275
        // withdraw from convex pId 275
        // claim rewards from convex
        // redeem LP for underlying
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        leafs[0] = ManageLeaf(address(WETH), "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = weETH_wETH_Curve_LP;
        leafs[1] = ManageLeaf(weETH_wETH_Curve_LP, "exchange(int128,int128,uint256,uint256)", new address[](0));
        leafs[2] = ManageLeaf(address(WETH), "approve(address,uint256)", new address[](1));
        leafs[2].argumentAddresses[0] = weETH_wETH_Curve_LP;
        leafs[3] = ManageLeaf(address(WEETH), "approve(address,uint256)", new address[](1));
        leafs[3].argumentAddresses[0] = weETH_wETH_Curve_LP;
        leafs[4] = ManageLeaf(weETH_wETH_Curve_LP, "add_liquidity(uint256[],uint256)", new address[](0));
        leafs[5] = ManageLeaf(weETH_wETH_Curve_LP, "approve(address,uint256)", new address[](1));
        leafs[5].argumentAddresses[0] = weETH_wETH_Curve_Gauge;
        leafs[6] = ManageLeaf(weETH_wETH_Curve_Gauge, "deposit(uint256,address)", new address[](1));
        leafs[6].argumentAddresses[0] = address(boringVault);
        leafs[7] = ManageLeaf(weETH_wETH_Curve_Gauge, "withdraw(uint256)", new address[](0));
        leafs[8] = ManageLeaf(weETH_wETH_Curve_Gauge, "claim_rewards(address)", new address[](1));
        leafs[8].argumentAddresses[0] = address(boringVault);
        leafs[9] = ManageLeaf(weETH_wETH_Curve_LP, "approve(address,uint256)", new address[](1));
        leafs[9].argumentAddresses[0] = convexCurveMainnetBooster;
        leafs[10] = ManageLeaf(convexCurveMainnetBooster, "deposit(uint256,uint256,bool)", new address[](0));
        leafs[11] = ManageLeaf(weETH_wETH_Convex_Reward, "withdrawAndUnwrap(uint256,bool)", new address[](0));
        leafs[12] = ManageLeaf(weETH_wETH_Convex_Reward, "getReward(address,bool)", new address[](1));
        leafs[12].argumentAddresses[0] = weETH_wETH_Convex_Reward;
        leafs[13] = ManageLeaf(weETH_wETH_Curve_LP, "remove_liquidity(uint256,uint256[])", new address[](0));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](14);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];
        manageLeafs[3] = leafs[3];
        manageLeafs[4] = leafs[4];
        manageLeafs[5] = leafs[5];
        manageLeafs[6] = leafs[6];
        manageLeafs[7] = leafs[7];
        manageLeafs[8] = leafs[8];
        manageLeafs[9] = leafs[9];
        manageLeafs[10] = leafs[10];
        manageLeafs[11] = leafs[11];
        manageLeafs[12] = leafs[12];
        manageLeafs[13] = leafs[13];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](14);
        targets[0] = address(WETH);
        targets[1] = weETH_wETH_Curve_LP;
        targets[2] = address(WETH);
        targets[3] = address(WEETH);
        targets[4] = weETH_wETH_Curve_LP;
        targets[5] = weETH_wETH_Curve_LP;
        targets[6] = weETH_wETH_Curve_Gauge;
        targets[7] = weETH_wETH_Curve_Gauge;
        targets[8] = weETH_wETH_Curve_Gauge;
        targets[9] = weETH_wETH_Curve_LP;
        targets[10] = convexCurveMainnetBooster;
        targets[11] = weETH_wETH_Convex_Reward;
        targets[12] = weETH_wETH_Convex_Reward;
        targets[13] = weETH_wETH_Curve_LP;

        bytes[] memory targetData = new bytes[](14);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", weETH_wETH_Curve_LP, type(uint256).max);
        targetData[1] =
            abi.encodeWithSignature("exchange(int128,int128,uint256,uint256)", int128(1), int128(0), 50e18, 0);
        targetData[2] = abi.encodeWithSignature("approve(address,uint256)", weETH_wETH_Curve_LP, type(uint256).max);
        targetData[3] = abi.encodeWithSignature("approve(address,uint256)", weETH_wETH_Curve_LP, type(uint256).max);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 48473470070721278615;
        amounts[1] = 50e18;
        targetData[4] = abi.encodeWithSignature("add_liquidity(uint256[],uint256)", amounts, 0);
        uint256 lpTokens = 99561344877023277620;
        targetData[5] = abi.encodeWithSignature("approve(address,uint256)", weETH_wETH_Curve_Gauge, type(uint256).max);
        targetData[6] = abi.encodeWithSignature("deposit(uint256,address)", lpTokens, address(boringVault));
        targetData[7] = abi.encodeWithSignature("withdraw(uint256)", lpTokens);
        targetData[8] = abi.encodeWithSignature("claim_rewards(address)", address(boringVault));
        targetData[9] =
            abi.encodeWithSignature("approve(address,uint256)", convexCurveMainnetBooster, type(uint256).max);
        targetData[10] = abi.encodeWithSignature("deposit(uint256,uint256,bool)", 275, lpTokens, true);
        targetData[11] = abi.encodeWithSignature("withdrawAndUnwrap(uint256,bool)", lpTokens, true);
        targetData[12] = abi.encodeWithSignature("getReward(address,bool)", weETH_wETH_Convex_Reward, true);
        amounts[0] = 0;
        amounts[1] = 0;
        targetData[13] = abi.encodeWithSignature("remove_liquidity(uint256,uint256[])", lpTokens, amounts);

        manager.manageVaultWithMerkleVerification(manageProofs, targets, targetData, new uint256[](14));
    }

    // TODO native wrapper integration test
    // TODO integration test for etherfi
    // TODO integration test for morpho blue
    function testMorphoBlueIntegration() external {
        deal(address(WETH), address(boringVault), 100e18);
        deal(address(WEETH), address(boringVault), 100e18);

        // supply weth
        // withdraw weth
        // supply weeth
        // borrow weth
        // repay weth
        // withdraw weeth.
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        leafs[0] = ManageLeaf(address(WETH), "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = morphoBlue;
        leafs[1] = ManageLeaf(
            morphoBlue,
            "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            new address[](5)
        );
        leafs[1].argumentAddresses[0] = address(WETH);
        leafs[1].argumentAddresses[1] = address(WEETH);
        leafs[1].argumentAddresses[2] = weEthOracle;
        leafs[1].argumentAddresses[3] = weEthIrm;
        leafs[1].argumentAddresses[4] = address(boringVault);
        leafs[2] = ManageLeaf(
            morphoBlue,
            "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
            new address[](6)
        );
        leafs[2].argumentAddresses[0] = address(WETH);
        leafs[2].argumentAddresses[1] = address(WEETH);
        leafs[2].argumentAddresses[2] = weEthOracle;
        leafs[2].argumentAddresses[3] = weEthIrm;
        leafs[2].argumentAddresses[4] = address(boringVault);
        leafs[2].argumentAddresses[5] = address(boringVault);
        leafs[3] = ManageLeaf(address(WEETH), "approve(address,uint256)", new address[](1));
        leafs[3].argumentAddresses[0] = morphoBlue;
        leafs[4] = ManageLeaf(
            morphoBlue,
            "supplyCollateral((address,address,address,address,uint256),uint256,address,bytes)",
            new address[](5)
        );
        leafs[4].argumentAddresses[0] = address(WETH);
        leafs[4].argumentAddresses[1] = address(WEETH);
        leafs[4].argumentAddresses[2] = weEthOracle;
        leafs[4].argumentAddresses[3] = weEthIrm;
        leafs[4].argumentAddresses[4] = address(boringVault);
        leafs[5] = ManageLeaf(
            morphoBlue,
            "borrow((address,address,address,address,uint256),uint256,uint256,address,address)",
            new address[](6)
        );
        leafs[5].argumentAddresses[0] = address(WETH);
        leafs[5].argumentAddresses[1] = address(WEETH);
        leafs[5].argumentAddresses[2] = weEthOracle;
        leafs[5].argumentAddresses[3] = weEthIrm;
        leafs[5].argumentAddresses[4] = address(boringVault);
        leafs[5].argumentAddresses[5] = address(boringVault);
        leafs[6] = ManageLeaf(
            morphoBlue,
            "repay((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            new address[](5)
        );
        leafs[6].argumentAddresses[0] = address(WETH);
        leafs[6].argumentAddresses[1] = address(WEETH);
        leafs[6].argumentAddresses[2] = weEthOracle;
        leafs[6].argumentAddresses[3] = weEthIrm;
        leafs[6].argumentAddresses[4] = address(boringVault);
        leafs[7] = ManageLeaf(
            morphoBlue,
            "withdrawCollateral((address,address,address,address,uint256),uint256,address,address)",
            new address[](6)
        );
        leafs[7].argumentAddresses[0] = address(WETH);
        leafs[7].argumentAddresses[1] = address(WEETH);
        leafs[7].argumentAddresses[2] = weEthOracle;
        leafs[7].argumentAddresses[3] = weEthIrm;
        leafs[7].argumentAddresses[4] = address(boringVault);
        leafs[7].argumentAddresses[5] = address(boringVault);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](8);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];
        manageLeafs[3] = leafs[3];
        manageLeafs[4] = leafs[4];
        manageLeafs[5] = leafs[5];
        manageLeafs[6] = leafs[6];
        manageLeafs[7] = leafs[7];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](8);
        targets[0] = address(WETH);
        targets[1] = morphoBlue;
        targets[2] = morphoBlue;
        targets[3] = address(WEETH);
        targets[4] = morphoBlue;
        targets[5] = morphoBlue;
        targets[6] = morphoBlue;
        targets[7] = morphoBlue;

        bytes[] memory targetData = new bytes[](8);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", morphoBlue, type(uint256).max);
        DecoderCustomTypes.MarketParams memory params =
            DecoderCustomTypes.MarketParams(address(WETH), address(WEETH), weEthOracle, weEthIrm, 0.86e18);
        targetData[1] = abi.encodeWithSignature(
            "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            params,
            100e18,
            0,
            address(boringVault),
            hex""
        );
        targetData[2] = abi.encodeWithSignature(
            "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
            params,
            100e18 - 1,
            0,
            address(boringVault),
            address(boringVault)
        );
        targetData[3] = abi.encodeWithSignature("approve(address,uint256)", morphoBlue, type(uint256).max);
        targetData[4] = abi.encodeWithSignature(
            "supplyCollateral((address,address,address,address,uint256),uint256,address,bytes)",
            params,
            100e18,
            address(boringVault),
            hex""
        );
        targetData[5] = abi.encodeWithSignature(
            "borrow((address,address,address,address,uint256),uint256,uint256,address,address)",
            params,
            10e18,
            0,
            address(boringVault),
            address(boringVault)
        );
        targetData[6] = abi.encodeWithSignature(
            "repay((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            params,
            10e18,
            0,
            address(boringVault),
            hex""
        );
        targetData[7] = abi.encodeWithSignature(
            "withdrawCollateral((address,address,address,address,uint256),uint256,address,address)",
            params,
            90e18,
            address(boringVault),
            address(boringVault)
        );

        manager.manageVaultWithMerkleVerification(manageProofs, targets, targetData, new uint256[](8));
    }

    function testReverts() external {
        bytes32[][] memory manageProofs;
        address[] memory targets;
        targets = new address[](1);
        bytes[] memory targetData;
        uint256[] memory values;

        vm.expectRevert(bytes("Invalid target proof length"));
        manager.manageVaultWithMerkleVerification(manageProofs, targets, targetData, values);
        manageProofs = new bytes32[][](1);

        vm.expectRevert(bytes("Invalid data length"));
        manager.manageVaultWithMerkleVerification(manageProofs, targets, targetData, values);
        targetData = new bytes[](1);

        vm.expectRevert(bytes("Invalid values length"));
        manager.manageVaultWithMerkleVerification(manageProofs, targets, targetData, values);
        values = new uint256[](1);

        targets[0] = address(USDC);
        targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(this), 1_000);

        vm.expectRevert(bytes("Failed to verify manage call"));
        manager.manageVaultWithMerkleVerification(manageProofs, targets, targetData, values);

        // Set the manage root to be the leaf of the USDC approve function
        bytes32 manageRoot = keccak256(abi.encodePacked(targets[0], bytes4(targetData[0]), address(this)));
        manager.setManageRoot(manageRoot);

        // Call now works.
        manager.manageVaultWithMerkleVerification(manageProofs, targets, targetData, values);

        // Check `receiveFlashLoan`
        address[] memory tokens;
        uint256[] memory amounts;
        uint256[] memory feeAmounts;

        vm.expectRevert(bytes("wrong caller"));
        manager.receiveFlashLoan(tokens, amounts, feeAmounts, abi.encode(0));

        // Someone else initiated a flash loan
        vm.startPrank(vault);
        vm.expectRevert(bytes("no flash loan"));
        manager.receiveFlashLoan(tokens, amounts, feeAmounts, abi.encode(0));
        vm.stopPrank();
    }

    // ========================================= HELPER FUNCTIONS =========================================
    bool iDidSomething = false;

    // Call this function approve, so that we can use the standard decoder.
    function approve(ERC20 token, uint256 amount) external {
        token.safeTransferFrom(msg.sender, address(this), amount);
        token.safeTransfer(msg.sender, amount);
        iDidSomething = true;
    }

    function _generateProof(bytes32 leaf, bytes32[][] memory tree) internal pure returns (bytes32[] memory proof) {
        // The length of each proof is the height of the tree - 1.
        uint256 tree_length = tree.length;
        proof = new bytes32[](tree_length - 1);

        // Build the proof
        for (uint256 i; i < tree_length - 1; ++i) {
            // For each layer we need to find the leaf.
            for (uint256 j; j < tree[i].length; ++j) {
                if (leaf == tree[i][j]) {
                    // We have found the leaf, so now figure out if the proof needs the next leaf or the previous one.
                    proof[i] = j % 2 == 0 ? tree[i][j + 1] : tree[i][j - 1];
                    leaf = _hashPair(leaf, proof[i]);
                    break;
                }
            }
        }
    }

    function _getProofsUsingTree(ManageLeaf[] memory manageLeafs, bytes32[][] memory tree)
        internal
        pure
        returns (bytes32[][] memory proofs)
    {
        proofs = new bytes32[][](manageLeafs.length);
        for (uint256 i; i < manageLeafs.length; ++i) {
            // Generate manage proof.
            bytes4 selector = bytes4(keccak256(abi.encodePacked(manageLeafs[i].signature)));
            bytes memory rawDigest = abi.encodePacked(manageLeafs[i].target, selector);
            uint256 argumentAddressesLength = manageLeafs[i].argumentAddresses.length;
            for (uint256 j; j < argumentAddressesLength; ++j) {
                rawDigest = abi.encodePacked(rawDigest, manageLeafs[i].argumentAddresses[j]);
            }
            bytes32 leaf = keccak256(rawDigest);
            proofs[i] = _generateProof(leaf, tree);
        }
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

    struct ManageLeaf {
        address target;
        string signature;
        address[] argumentAddresses;
    }

    function _generateMerkleTree(ManageLeaf[] memory manageLeafs) internal pure returns (bytes32[][] memory tree) {
        uint256 leafsLength = manageLeafs.length;
        bytes32[][] memory leafs = new bytes32[][](1);
        leafs[0] = new bytes32[](leafsLength);
        for (uint256 i; i < leafsLength; ++i) {
            bytes4 selector = bytes4(keccak256(abi.encodePacked(manageLeafs[i].signature)));
            bytes memory rawDigest = abi.encodePacked(manageLeafs[i].target, selector);
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
}
