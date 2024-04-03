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
    MorphoBlueDecoderAndSanitizer,
    UniswapV3DecoderAndSanitizer,
    BalancerV2DecoderAndSanitizer,
    PendleRouterDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/EtherFiLiquidDecoderAndSanitizer.sol";
import {RenzoLiquidDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/RenzoLiquidDecoderAndSanitizer.sol";
import {LidoLiquidDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LidoLiquidDecoderAndSanitizer.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {IUniswapV3Router} from "src/interfaces/IUniswapV3Router.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract ManagerWithMerkleVerificationTest is Test, MainnetAddresses {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;

    address public weEthOracle = 0x3fa58b74e9a8eA8768eb33c8453e9C2Ed089A40a;
    address public weEthIrm = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19369928;
        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager = new ManagerWithMerkleVerification(address(this), address(boringVault), vault);

        rawDataDecoderAndSanitizer =
            address(new EtherFiLiquidDecoderAndSanitizer(address(boringVault), uniswapV3NonFungiblePositionManager));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);

        // Setup roles authority.
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)"))),
            true
        );
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])"))),
            true
        );

        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            MANGER_INTERNAL_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector, true
        );
        rolesAuthority.setRoleCapability(
            BORING_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.flashLoan.selector, true
        );
        rolesAuthority.setRoleCapability(
            BALANCER_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.receiveFlashLoan.selector, true
        );

        // Grant roles
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        rolesAuthority.setUserRole(vault, BALANCER_VAULT_ROLE, true);

        // Allow the boring vault to receive ETH.
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);
    }

    function testManagerMerkleVerificationHappyPath() external {
        // Allow the manager to call the USDC approve function to a specific address,
        // and the USDT transfer function to a specific address.
        address usdcSpender = vm.addr(0xDEAD);
        address usdtTo = vm.addr(0xDEAD1);
        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        leafs[0] = ManageLeaf(address(USDC), false, "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = usdcSpender;
        leafs[1] = ManageLeaf(address(USDT), false, "approve(address,uint256)", new address[](1));
        leafs[1].argumentAddresses[0] = usdtTo;

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[1][0]);

        address[] memory targets = new address[](2);
        targets[0] = address(USDC);
        targets[1] = address(USDT);

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, usdcSpender, 777);
        targetData[1] = abi.encodeWithSelector(ERC20.approve.selector, usdtTo, 777);

        (bytes32[][] memory manageProofs) = _getProofsUsingTree(leafs, manageTree);

        uint256[] memory values = new uint256[](2);

        deal(address(USDT), address(boringVault), 777);

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256 gas = gasleft();
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        console.log("Gas used", gas - gasleft());

        assertEq(USDC.allowance(address(boringVault), usdcSpender), 777, "USDC should have an allowance");
        assertEq(USDT.allowance(address(boringVault), usdtTo), 777, "USDT should have have an allowance");
    }

    function testFlashLoan() external {
        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        leafs[0] = ManageLeaf(address(manager), false, "flashLoan(address,address[],uint256[],bytes)", new address[](2));
        leafs[0].argumentAddresses[0] = address(manager);
        leafs[0].argumentAddresses[1] = address(USDC);
        leafs[1] = ManageLeaf(address(this), false, "approve(address,uint256)", new address[](1));
        leafs[1].argumentAddresses[0] = address(USDC);
        leafs[2] = ManageLeaf(address(USDC), false, "approve(address,uint256)", new address[](1));
        leafs[2].argumentAddresses[0] = address(this);
        // leaf[3] empty

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[2][0]);
        // Since the manager calls to itself to fulfill the flashloan, we need to set its root.
        manager.setManageRoot(address(manager), manageTree[2][0]);

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
            address[] memory dAs = new address[](2);
            dAs[0] = rawDataDecoderAndSanitizer;
            dAs[1] = rawDataDecoderAndSanitizer;
            userData = abi.encode(flashLoanManageProofs, dAs, targets, targetData, values);
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
            address[] memory decodersAndSanitizers = new address[](1);
            decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
            manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

            assertTrue(iDidSomething == true, "Should have called doSomethingWithFlashLoan");
        }
    }

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
        leafs[0] = ManageLeaf(address(WETH), false, "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = vault;
        leafs[1] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5)
        );
        leafs[1].argumentAddresses[0] = address(rETH_wETH);
        leafs[1].argumentAddresses[1] = address(WETH);
        leafs[1].argumentAddresses[2] = address(RETH);
        leafs[1].argumentAddresses[3] = address(boringVault);
        leafs[1].argumentAddresses[4] = address(boringVault);
        leafs[2] = ManageLeaf(address(RETH), false, "approve(address,uint256)", new address[](1));
        leafs[2].argumentAddresses[0] = vault;
        leafs[3] = ManageLeaf(
            vault, false, "joinPool(bytes32,address,address,(address[],uint256[],bytes,bool))", new address[](5)
        );
        leafs[3].argumentAddresses[0] = address(rETH_wETH);
        leafs[3].argumentAddresses[1] = address(boringVault);
        leafs[3].argumentAddresses[2] = address(boringVault);
        leafs[3].argumentAddresses[3] = address(RETH);
        leafs[3].argumentAddresses[4] = address(WETH);
        leafs[4] = ManageLeaf(address(rETH_wETH), false, "approve(address,uint256)", new address[](1));
        leafs[4].argumentAddresses[0] = rETH_wETH_gauge;
        leafs[5] = ManageLeaf(rETH_wETH_gauge, false, "deposit(uint256,address)", new address[](1));
        leafs[5].argumentAddresses[0] = address(boringVault);
        leafs[6] = ManageLeaf(rETH_wETH_gauge, false, "withdraw(uint256)", new address[](0));
        leafs[7] = ManageLeaf(address(rETH_wETH), false, "approve(address,uint256)", new address[](1));
        leafs[7].argumentAddresses[0] = aura_reth_weth;
        leafs[8] = ManageLeaf(aura_reth_weth, false, "deposit(uint256,address)", new address[](1));
        leafs[8].argumentAddresses[0] = address(boringVault);
        leafs[9] = ManageLeaf(aura_reth_weth, false, "withdraw(uint256,address,address)", new address[](2));
        leafs[9].argumentAddresses[0] = address(boringVault);
        leafs[9].argumentAddresses[1] = address(boringVault);
        leafs[10] = ManageLeaf(
            vault, false, "exitPool(bytes32,address,address,(address[],uint256[],bytes,bool))", new address[](5)
        );
        leafs[10].argumentAddresses[0] = address(rETH_wETH);
        leafs[10].argumentAddresses[1] = address(boringVault);
        leafs[10].argumentAddresses[2] = address(boringVault);
        leafs[10].argumentAddresses[3] = address(RETH);
        leafs[10].argumentAddresses[4] = address(WETH);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

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
        address[] memory decodersAndSanitizers = new address[](11);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[8] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[9] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[10] = rawDataDecoderAndSanitizer;
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](11)
        );

        // Make sure we can call Balancer mint and Aura getReward
        leafs = new ManageLeaf[](2);
        leafs[0] = ManageLeaf(minter, false, "mint(address)", new address[](1));
        leafs[0].argumentAddresses[0] = rETH_wETH_gauge;
        leafs[1] = ManageLeaf(aura_reth_weth, false, "getReward(address,bool)", new address[](1));
        leafs[1].argumentAddresses[0] = address(boringVault);

        manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

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
        decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](2)
        );
    }

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
        leafs[0] = ManageLeaf(address(WETH), false, "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = uniV3Router;
        leafs[1] =
            ManageLeaf(uniV3Router, false, "exactInput((bytes,address,uint256,uint256,uint256))", new address[](3));
        leafs[1].argumentAddresses[0] = address(WETH);
        leafs[1].argumentAddresses[1] = address(RETH);
        leafs[1].argumentAddresses[2] = address(boringVault);
        leafs[2] = ManageLeaf(address(RETH), false, "approve(address,uint256)", new address[](1));
        leafs[2].argumentAddresses[0] = uniswapV3NonFungiblePositionManager;
        leafs[3] = ManageLeaf(address(WEETH), false, "approve(address,uint256)", new address[](1));
        leafs[3].argumentAddresses[0] = uniswapV3NonFungiblePositionManager;
        leafs[4] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
            new address[](3)
        );
        leafs[4].argumentAddresses[0] = address(RETH);
        leafs[4].argumentAddresses[1] = address(WEETH);
        leafs[4].argumentAddresses[2] = address(boringVault);
        leafs[5] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
            new address[](3)
        );
        leafs[5].argumentAddresses[0] = address(0);
        leafs[5].argumentAddresses[1] = address(RETH);
        leafs[5].argumentAddresses[2] = address(WEETH);
        leafs[6] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            new address[](0)
        );
        leafs[7] = ManageLeaf(
            uniswapV3NonFungiblePositionManager, false, "collect((uint256,address,uint128,uint128))", new address[](1)
        );
        leafs[7].argumentAddresses[0] = address(boringVault);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

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
        address[] memory decodersAndSanitizers = new address[](8);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        uint256 gas = gasleft();
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](8)
        );
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
        leafs[0] = ManageLeaf(address(WETH), false, "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = weETH_wETH_Curve_LP;
        leafs[1] = ManageLeaf(weETH_wETH_Curve_LP, false, "exchange(int128,int128,uint256,uint256)", new address[](0));
        leafs[2] = ManageLeaf(address(WETH), false, "approve(address,uint256)", new address[](1));
        leafs[2].argumentAddresses[0] = weETH_wETH_Curve_LP;
        leafs[3] = ManageLeaf(address(WEETH), false, "approve(address,uint256)", new address[](1));
        leafs[3].argumentAddresses[0] = weETH_wETH_Curve_LP;
        leafs[4] = ManageLeaf(weETH_wETH_Curve_LP, false, "add_liquidity(uint256[],uint256)", new address[](0));
        leafs[5] = ManageLeaf(weETH_wETH_Curve_LP, false, "approve(address,uint256)", new address[](1));
        leafs[5].argumentAddresses[0] = weETH_wETH_Curve_Gauge;
        leafs[6] = ManageLeaf(weETH_wETH_Curve_Gauge, false, "deposit(uint256,address)", new address[](1));
        leafs[6].argumentAddresses[0] = address(boringVault);
        leafs[7] = ManageLeaf(weETH_wETH_Curve_Gauge, false, "withdraw(uint256)", new address[](0));
        leafs[8] = ManageLeaf(weETH_wETH_Curve_Gauge, false, "claim_rewards(address)", new address[](1));
        leafs[8].argumentAddresses[0] = address(boringVault);
        leafs[9] = ManageLeaf(weETH_wETH_Curve_LP, false, "approve(address,uint256)", new address[](1));
        leafs[9].argumentAddresses[0] = convexCurveMainnetBooster;
        leafs[10] = ManageLeaf(convexCurveMainnetBooster, false, "deposit(uint256,uint256,bool)", new address[](0));
        leafs[11] = ManageLeaf(weETH_wETH_Convex_Reward, false, "withdrawAndUnwrap(uint256,bool)", new address[](0));
        leafs[12] = ManageLeaf(weETH_wETH_Convex_Reward, false, "getReward(address,bool)", new address[](1));
        leafs[12].argumentAddresses[0] = weETH_wETH_Convex_Reward;
        leafs[13] = ManageLeaf(weETH_wETH_Curve_LP, false, "remove_liquidity(uint256,uint256[])", new address[](0));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

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
        address[] memory decodersAndSanitizers = new address[](14);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[8] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[9] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[10] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[11] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[12] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[13] = rawDataDecoderAndSanitizer;
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](14)
        );
    }

    function testNativeWrapperIntegration() external {
        deal(address(WETH), address(boringVault), 100e18);

        // Unwrap all WETH
        // mint WETH via deposit
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        leafs[0] = ManageLeaf(address(WETH), false, "withdraw(uint256)", new address[](0));
        leafs[1] = ManageLeaf(address(WETH), true, "deposit()", new address[](0));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = address(WETH);
        targets[1] = address(WETH);

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("withdraw(uint256)", 100e18);
        targetData[1] = abi.encodeWithSignature("deposit()");
        uint256[] memory values = new uint256[](2);
        values[1] = 100e18;
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testEtherFiIntegration() external {
        deal(address(WETH), address(boringVault), 100e18);

        // unwrap weth
        // mint eETH
        // wrap eETH
        // unwrap weETH
        // unstaking eETH
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        leafs[0] = ManageLeaf(address(WETH), false, "withdraw(uint256)", new address[](0));
        leafs[1] = ManageLeaf(EETH_LIQUIDITY_POOL, true, "deposit()", new address[](0));
        leafs[2] = ManageLeaf(address(EETH), false, "approve(address,uint256)", new address[](1));
        leafs[2].argumentAddresses[0] = address(WEETH);
        leafs[3] = ManageLeaf(address(WEETH), false, "wrap(uint256)", new address[](0));
        leafs[4] = ManageLeaf(address(WEETH), false, "unwrap(uint256)", new address[](0));
        leafs[5] = ManageLeaf(address(EETH), false, "approve(address,uint256)", new address[](1));
        leafs[5].argumentAddresses[0] = EETH_LIQUIDITY_POOL;
        leafs[6] = ManageLeaf(EETH_LIQUIDITY_POOL, false, "requestWithdraw(address,uint256)", new address[](1));
        leafs[6].argumentAddresses[0] = address(boringVault);
        leafs[7] = ManageLeaf(withdrawalRequestNft, false, "claimWithdraw(uint256)", new address[](0));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](7);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];
        manageLeafs[3] = leafs[3];
        manageLeafs[4] = leafs[4];
        manageLeafs[5] = leafs[5];
        manageLeafs[6] = leafs[6];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](7);
        targets[0] = address(WETH);
        targets[1] = EETH_LIQUIDITY_POOL;
        targets[2] = address(EETH);
        targets[3] = address(WEETH);
        targets[4] = address(WEETH);
        targets[5] = address(EETH);
        targets[6] = EETH_LIQUIDITY_POOL;

        bytes[] memory targetData = new bytes[](7);
        targetData[0] = abi.encodeWithSignature("withdraw(uint256)", 100e18);
        targetData[1] = abi.encodeWithSignature("deposit()");
        targetData[2] = abi.encodeWithSignature("approve(address,uint256)", address(WEETH), type(uint256).max);
        targetData[3] = abi.encodeWithSignature("wrap(uint256)", 100e18 - 1);
        uint256 weETHAmount = 96806692052320886040;
        targetData[4] = abi.encodeWithSignature("unwrap(uint256)", weETHAmount);
        targetData[5] = abi.encodeWithSignature("approve(address,uint256)", EETH_LIQUIDITY_POOL, type(uint256).max);
        targetData[6] = abi.encodeWithSignature("requestWithdraw(address,uint256)", address(boringVault), 100e18 - 2);
        uint256[] memory values = new uint256[](7);
        values[1] = 100e18;
        address[] memory decodersAndSanitizers = new address[](7);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        uint256 withdrawRequestId = 4840;

        _finalizeRequest(withdrawRequestId, 100e18 - 2);

        manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[7];
        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](1);
        targets[0] = withdrawalRequestNft;

        targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature("claimWithdraw(uint256)", withdrawRequestId);
        values = new uint256[](1);

        decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

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
        leafs[0] = ManageLeaf(address(WETH), false, "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = morphoBlue;
        leafs[1] = ManageLeaf(
            morphoBlue,
            false,
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
            false,
            "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
            new address[](6)
        );
        leafs[2].argumentAddresses[0] = address(WETH);
        leafs[2].argumentAddresses[1] = address(WEETH);
        leafs[2].argumentAddresses[2] = weEthOracle;
        leafs[2].argumentAddresses[3] = weEthIrm;
        leafs[2].argumentAddresses[4] = address(boringVault);
        leafs[2].argumentAddresses[5] = address(boringVault);
        leafs[3] = ManageLeaf(address(WEETH), false, "approve(address,uint256)", new address[](1));
        leafs[3].argumentAddresses[0] = morphoBlue;
        leafs[4] = ManageLeaf(
            morphoBlue,
            false,
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
            false,
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
            false,
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
            false,
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

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

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

        address[] memory decodersAndSanitizers = new address[](8);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](8)
        );
    }

    function testGearboxIntegration() external {
        deal(address(WETH), address(boringVault), 1_000e18);

        // get dWETHV3
        // get sdWETHV3
        // claim rewards
        // sell sdWETHV3
        // sell dWETHV3
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        leafs[0] = ManageLeaf(address(WETH), false, "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = dWETHV3;
        leafs[1] = ManageLeaf(dWETHV3, false, "deposit(uint256,address)", new address[](1));
        leafs[1].argumentAddresses[0] = address(boringVault);
        leafs[2] = ManageLeaf(dWETHV3, false, "approve(address,uint256)", new address[](1));
        leafs[2].argumentAddresses[0] = sdWETHV3;
        leafs[3] = ManageLeaf(sdWETHV3, false, "deposit(uint256)", new address[](0));
        leafs[4] = ManageLeaf(sdWETHV3, false, "claim()", new address[](0));
        leafs[5] = ManageLeaf(sdWETHV3, false, "withdraw(uint256)", new address[](0));
        leafs[6] = ManageLeaf(dWETHV3, false, "withdraw(uint256,address,address)", new address[](2));
        leafs[6].argumentAddresses[0] = address(boringVault);
        leafs[6].argumentAddresses[1] = address(boringVault);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](7);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];
        manageLeafs[3] = leafs[3];
        manageLeafs[4] = leafs[4];
        manageLeafs[5] = leafs[5];
        manageLeafs[6] = leafs[6];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](7);
        targets[0] = address(WETH);
        targets[1] = dWETHV3;
        targets[2] = dWETHV3;
        targets[3] = sdWETHV3;
        targets[4] = sdWETHV3;
        targets[5] = sdWETHV3;
        targets[6] = dWETHV3;

        bytes[] memory targetData = new bytes[](7);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", dWETHV3, type(uint256).max);
        targetData[1] = abi.encodeWithSignature("deposit(uint256,address)", 1_000e18, address(boringVault));
        targetData[2] = abi.encodeWithSignature("approve(address,uint256)", sdWETHV3, type(uint256).max);
        targetData[3] = abi.encodeWithSignature("deposit(uint256)", 100e18);
        targetData[4] = abi.encodeWithSignature("claim()");
        targetData[5] = abi.encodeWithSignature("withdraw(uint256)", 100e18);
        targetData[6] = abi.encodeWithSignature(
            "withdraw(uint256,address,address)", 1_000e18 - 1, address(boringVault), address(boringVault)
        );

        address[] memory decodersAndSanitizers = new address[](7);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](7)
        );
    }

    function testPendleRouterIntegration() external {
        deal(address(WEETH), address(boringVault), 1_000e18);

        // Need 4 approvals all for router, WEETH, SY, PT, YT
        // WEETH -> SY
        // SY/2 -> PY
        // swap YT for PT
        // swap PT for YT
        // add liquidity
        // remove liquidity
        // PY -> SY
        // SY -> WEETH
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        leafs[0] = ManageLeaf(address(WEETH), false, "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = pendleRouter;
        leafs[1] = ManageLeaf(pendleWeethSy, false, "approve(address,uint256)", new address[](1));
        leafs[1].argumentAddresses[0] = pendleRouter;
        leafs[2] = ManageLeaf(pendleEethPt, false, "approve(address,uint256)", new address[](1));
        leafs[2].argumentAddresses[0] = pendleRouter;
        leafs[3] = ManageLeaf(pendleEethYt, false, "approve(address,uint256)", new address[](1));
        leafs[3].argumentAddresses[0] = pendleRouter;
        leafs[4] = ManageLeaf(pendleWeETHMarket, false, "approve(address,uint256)", new address[](1));
        leafs[4].argumentAddresses[0] = pendleRouter;
        leafs[5] = ManageLeaf(
            pendleRouter,
            false,
            "mintSyFromToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            new address[](6)
        );
        leafs[5].argumentAddresses[0] = address(boringVault);
        leafs[5].argumentAddresses[1] = pendleWeethSy;
        leafs[5].argumentAddresses[2] = address(WEETH);
        leafs[5].argumentAddresses[3] = address(WEETH);
        leafs[5].argumentAddresses[4] = address(0);
        leafs[5].argumentAddresses[5] = address(0);
        leafs[6] = ManageLeaf(pendleRouter, false, "mintPyFromSy(address,address,uint256,uint256)", new address[](2));
        leafs[6].argumentAddresses[0] = address(boringVault);
        leafs[6].argumentAddresses[1] = pendleEethYt;
        leafs[7] = ManageLeaf(
            pendleRouter,
            false,
            "swapExactYtForPt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            new address[](2)
        );
        leafs[7].argumentAddresses[0] = address(boringVault);
        leafs[7].argumentAddresses[1] = pendleWeETHMarket;
        leafs[8] = ManageLeaf(
            pendleRouter,
            false,
            "swapExactPtForYt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            new address[](2)
        );
        leafs[8].argumentAddresses[0] = address(boringVault);
        leafs[8].argumentAddresses[1] = pendleWeETHMarket;
        leafs[9] = ManageLeaf(
            pendleRouter, false, "addLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)", new address[](2)
        );
        leafs[9].argumentAddresses[0] = address(boringVault);
        leafs[9].argumentAddresses[1] = pendleWeETHMarket;
        leafs[10] = ManageLeaf(
            pendleRouter, false, "removeLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)", new address[](2)
        );
        leafs[10].argumentAddresses[0] = address(boringVault);
        leafs[10].argumentAddresses[1] = pendleWeETHMarket;
        leafs[11] = ManageLeaf(pendleRouter, false, "redeemPyToSy(address,address,uint256,uint256)", new address[](2));
        leafs[11].argumentAddresses[0] = address(boringVault);
        leafs[11].argumentAddresses[1] = pendleEethYt;
        leafs[12] = ManageLeaf(
            pendleRouter,
            false,
            "redeemSyToToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            new address[](6)
        );
        leafs[12].argumentAddresses[0] = address(boringVault);
        leafs[12].argumentAddresses[1] = pendleWeethSy;
        leafs[12].argumentAddresses[2] = address(WEETH);
        leafs[12].argumentAddresses[3] = address(WEETH);
        leafs[12].argumentAddresses[4] = address(0);
        leafs[12].argumentAddresses[5] = address(0);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](13);
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
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](13);
        targets[0] = address(WEETH);
        targets[1] = pendleWeethSy;
        targets[2] = pendleEethPt;
        targets[3] = pendleEethYt;
        targets[4] = pendleWeETHMarket;
        targets[5] = pendleRouter;
        targets[6] = pendleRouter;
        targets[7] = pendleRouter;
        targets[8] = pendleRouter;
        targets[9] = pendleRouter;
        targets[10] = pendleRouter;
        targets[11] = pendleRouter;
        targets[12] = pendleRouter;

        bytes[] memory targetData = new bytes[](13);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", pendleRouter, type(uint256).max);
        targetData[1] = abi.encodeWithSignature("approve(address,uint256)", pendleRouter, type(uint256).max);
        targetData[2] = abi.encodeWithSignature("approve(address,uint256)", pendleRouter, type(uint256).max);
        targetData[3] = abi.encodeWithSignature("approve(address,uint256)", pendleRouter, type(uint256).max);
        targetData[4] = abi.encodeWithSignature("approve(address,uint256)", pendleRouter, type(uint256).max);
        DecoderCustomTypes.SwapData memory swapData =
            DecoderCustomTypes.SwapData(DecoderCustomTypes.SwapType.NONE, address(0), hex"", false);
        DecoderCustomTypes.TokenInput memory tokenInput =
            DecoderCustomTypes.TokenInput(address(WEETH), 1_000e18, address(WEETH), address(0), swapData);
        targetData[5] = abi.encodeWithSignature(
            "mintSyFromToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            address(boringVault),
            pendleWeethSy,
            0,
            tokenInput
        );
        targetData[6] = abi.encodeWithSignature(
            "mintPyFromSy(address,address,uint256,uint256)", address(boringVault), pendleEethYt, 100e18, 0
        );
        DecoderCustomTypes.ApproxParams memory approxParams =
            DecoderCustomTypes.ApproxParams(0, type(uint256).max, 0, 2566, 1e14);
        targetData[7] = abi.encodeWithSignature(
            "swapExactYtForPt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            address(boringVault),
            pendleWeETHMarket,
            10e18,
            0,
            approxParams
        );
        targetData[8] = abi.encodeWithSignature(
            "swapExactPtForYt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            address(boringVault),
            pendleWeETHMarket,
            1e18,
            0,
            approxParams
        );
        targetData[9] = abi.encodeWithSignature(
            "addLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
            address(boringVault),
            pendleWeETHMarket,
            1e18,
            1e18,
            0
        );
        targetData[10] = abi.encodeWithSignature(
            "removeLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
            address(boringVault),
            pendleWeETHMarket,
            0.1e18,
            0,
            0
        );
        targetData[11] = abi.encodeWithSignature(
            "redeemPyToSy(address,address,uint256,uint256)", address(boringVault), pendleEethYt, 0.1e18, 0
        );
        DecoderCustomTypes.TokenOutput memory tokenOutput =
            DecoderCustomTypes.TokenOutput(address(WEETH), 0, address(WEETH), address(0), swapData);
        targetData[12] = abi.encodeWithSignature(
            "redeemSyToToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            address(boringVault),
            pendleWeethSy,
            1e18,
            tokenOutput
        );

        address[] memory decodersAndSanitizers = new address[](13);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[8] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[9] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[10] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[11] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[12] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](13);
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testAaveV3Integration() external {
        deal(address(WSTETH), address(boringVault), 1_000e18);
        deal(address(WETH), address(boringVault), 1_000e18);

        // Approve WSTETH
        // Approve WETH
        // Supply WSTETH
        // Borrow WETH
        // Repay WETH
        // Withdraw WSTETH
        // Call setUserUseReserveAsCollateral
        // Call setUserEMode
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        leafs[0] = ManageLeaf(address(WSTETH), false, "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = v3Pool;
        leafs[1] = ManageLeaf(address(WETH), false, "approve(address,uint256)", new address[](1));
        leafs[1].argumentAddresses[0] = v3Pool;
        leafs[2] = ManageLeaf(v3Pool, false, "supply(address,uint256,address,uint16)", new address[](2));
        leafs[2].argumentAddresses[0] = address(WSTETH);
        leafs[2].argumentAddresses[1] = address(boringVault);
        leafs[3] = ManageLeaf(v3Pool, false, "borrow(address,uint256,uint256,uint16,address)", new address[](2));
        leafs[3].argumentAddresses[0] = address(WETH);
        leafs[3].argumentAddresses[1] = address(boringVault);
        leafs[4] = ManageLeaf(v3Pool, false, "repay(address,uint256,uint256,address)", new address[](2));
        leafs[4].argumentAddresses[0] = address(WETH);
        leafs[4].argumentAddresses[1] = address(boringVault);
        leafs[5] = ManageLeaf(v3Pool, false, "withdraw(address,uint256,address)", new address[](2));
        leafs[5].argumentAddresses[0] = address(WSTETH);
        leafs[5].argumentAddresses[1] = address(boringVault);
        leafs[6] = ManageLeaf(v3Pool, false, "setUserUseReserveAsCollateral(address,bool)", new address[](1));
        leafs[6].argumentAddresses[0] = address(WSTETH);
        leafs[7] = ManageLeaf(v3Pool, false, "setUserEMode(uint8)", new address[](0));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

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
        targets[0] = address(WSTETH);
        targets[1] = address(WETH);
        targets[2] = v3Pool;
        targets[3] = v3Pool;
        targets[4] = v3Pool;
        targets[5] = v3Pool;
        targets[6] = v3Pool;
        targets[7] = v3Pool;

        bytes[] memory targetData = new bytes[](8);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", v3Pool, type(uint256).max);
        targetData[1] = abi.encodeWithSignature("approve(address,uint256)", v3Pool, type(uint256).max);
        targetData[2] = abi.encodeWithSignature(
            "supply(address,uint256,address,uint16)", address(WSTETH), 1_000e18, address(boringVault), 0
        );
        targetData[3] = abi.encodeWithSignature(
            "borrow(address,uint256,uint256,uint16,address)", address(WETH), 100e18, 2, 0, address(boringVault)
        );
        targetData[4] = abi.encodeWithSignature(
            "repay(address,uint256,uint256,address)", address(WETH), type(uint256).max, 2, address(boringVault)
        );
        targetData[5] = abi.encodeWithSignature(
            "withdraw(address,uint256,address)", address(WSTETH), 1_000e18 - 1, address(boringVault)
        );
        targetData[6] = abi.encodeWithSignature("setUserUseReserveAsCollateral(address,bool)", address(WSTETH), true);
        targetData[7] = abi.encodeWithSignature("setUserEMode(uint8)", 0);

        address[] memory decodersAndSanitizers = new address[](8);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](8);
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testRenzoIntegration() external {
        deal(address(boringVault), 1_000e18);

        // update DecoderAndSanitizer
        rawDataDecoderAndSanitizer =
            address(new RenzoLiquidDecoderAndSanitizer(address(boringVault), uniswapV3NonFungiblePositionManager));

        // Call depositETH to renzo
        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        leafs[0] = ManageLeaf(restakeManager, true, "depositETH()", new address[](0));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = restakeManager;

        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature("depositETH()");

        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](1);
        values[0] = 1_000e18;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertGt(EZETH.balanceOf(address(boringVault)), 0, "BoringVault should have ezETH.");
    }

    function testLidoIntegration() external {
        deal(address(boringVault), 1_000e18);

        // update DecoderAndSanitizer
        rawDataDecoderAndSanitizer =
            address(new LidoLiquidDecoderAndSanitizer(address(boringVault), uniswapV3NonFungiblePositionManager));

        // Call submit
        // call approve
        // wrap it
        // unwrap it
        // Request a withdrawal
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        leafs[0] = ManageLeaf(address(STETH), true, "submit(address)", new address[](1));
        leafs[0].argumentAddresses[0] = address(0);
        leafs[1] = ManageLeaf(address(STETH), false, "approve(address,uint256)", new address[](1));
        leafs[1].argumentAddresses[0] = address(WSTETH);
        leafs[2] = ManageLeaf(address(WSTETH), false, "wrap(uint256)", new address[](0));
        leafs[3] = ManageLeaf(address(WSTETH), false, "unwrap(uint256)", new address[](0));
        leafs[4] = ManageLeaf(address(STETH), false, "approve(address,uint256)", new address[](1));
        leafs[4].argumentAddresses[0] = unstETH;
        leafs[5] = ManageLeaf(unstETH, false, "requestWithdrawals(uint256[],address)", new address[](1));
        leafs[5].argumentAddresses[0] = address(boringVault);
        leafs[6] = ManageLeaf(unstETH, false, "claimWithdrawal(uint256)", new address[](0));
        leafs[7] = ManageLeaf(unstETH, false, "claimWithdrawals(uint256[],uint256[])", new address[](0));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](6);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];
        manageLeafs[3] = leafs[3];
        manageLeafs[4] = leafs[4];
        manageLeafs[5] = leafs[5];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](6);
        targets[0] = address(STETH);
        targets[1] = address(STETH);
        targets[2] = address(WSTETH);
        targets[3] = address(WSTETH);
        targets[4] = address(STETH);
        targets[5] = unstETH;

        bytes[] memory targetData = new bytes[](6);
        targetData[0] = abi.encodeWithSignature("submit(address)", address(0));
        targetData[1] = abi.encodeWithSignature("approve(address,uint256)", address(WSTETH), type(uint256).max);
        targetData[2] = abi.encodeWithSignature("wrap(uint256)", 100e18);
        targetData[3] = abi.encodeWithSignature("unwrap(uint256)", 10e18);
        targetData[4] = abi.encodeWithSignature("approve(address,uint256)", unstETH, type(uint256).max);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100e18;
        amounts[1] = 100e18;
        amounts[2] = 100e18;
        targetData[5] = abi.encodeWithSignature("requestWithdrawals(uint256[],address)", amounts, address(boringVault));

        address[] memory decodersAndSanitizers = new address[](6);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](6);
        values[0] = 1_000e18;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Finalize withdraw requests.
        address admin = IUNSTETH(unstETH).getRoleMember(IUNSTETH(unstETH).FINALIZE_ROLE(), 0);
        deal(admin, 300e18);
        vm.startPrank(admin);
        IUNSTETH(unstETH).finalize{value: 100e18}(28_791, type(uint256).max);
        IUNSTETH(unstETH).finalize{value: 100e18}(28_792, type(uint256).max);
        IUNSTETH(unstETH).finalize{value: 100e18}(28_793, type(uint256).max);
        vm.stopPrank();

        manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[6];
        manageLeafs[1] = leafs[7];

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](2);
        targets[0] = unstETH;
        targets[1] = unstETH;

        targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("claimWithdrawal(uint256)", 28_791);
        uint256[] memory ids = new uint256[](2);
        ids[0] = 28_792;
        ids[1] = 28_793;
        uint256[] memory hints =
            IUNSTETH(unstETH).findCheckpointHints(ids, 100, IUNSTETH(unstETH).getLastCheckpointIndex());
        targetData[1] = abi.encodeWithSignature("claimWithdrawals(uint256[],uint256[])", ids, hints);

        decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        values = new uint256[](2);

        uint256 boringVaultETHBalance = address(boringVault).balance;
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertEq(
            address(boringVault).balance - boringVaultETHBalance,
            300e18,
            "BoringVault should have received 300 ETH from withdrawals"
        );
    }

    function testReverts() external {
        bytes32[][] memory manageProofs;
        address[] memory targets;
        targets = new address[](1);
        bytes[] memory targetData;
        uint256[] memory values;
        address[] memory decodersAndSanitizers;

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__InvalidManageProofLength.selector
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        manageProofs = new bytes32[][](1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__InvalidTargetDataLength.selector
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        targetData = new bytes[](1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__InvalidValuesLength.selector
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        values = new uint256[](1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__InvalidDecodersAndSanitizersLength.selector
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        decodersAndSanitizers = new address[](1);

        targets[0] = address(USDC);
        targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(this), 1_000);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Set the manage root to be the leaf of the USDC approve function
        bytes32 manageRoot = keccak256(
            abi.encodePacked(rawDataDecoderAndSanitizer, targets[0], false, bytes4(targetData[0]), address(this))
        );
        manager.setManageRoot(address(this), manageRoot);

        // Call now works.
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Check `receiveFlashLoan`
        address[] memory tokens;
        uint256[] memory amounts;
        uint256[] memory feeAmounts;

        address attacker = vm.addr(1);
        vm.startPrank(attacker);
        vm.expectRevert(bytes("UNAUTHORIZED"));
        manager.receiveFlashLoan(tokens, amounts, feeAmounts, abi.encode(0));
        vm.stopPrank();

        // Someone else initiated a flash loan
        vm.startPrank(vault);
        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FlashLoanNotInProgress.selector
            )
        );
        manager.receiveFlashLoan(tokens, amounts, feeAmounts, abi.encode(0));
        vm.stopPrank();
    }

    function testFlashLoanReverts() external {
        // Deploy a new manager, setting the Balancer Vault as address(this)
        manager = new ManagerWithMerkleVerification(address(this), address(boringVault), address(this));
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            MANGER_INTERNAL_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            BORING_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.flashLoan.selector, true
        );
        rolesAuthority.setRoleCapability(
            BALANCER_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.receiveFlashLoan.selector, true
        );
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        rolesAuthority.setUserRole(address(this), BALANCER_VAULT_ROLE, true);
        manager.setAuthority(rolesAuthority);

        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        leafs[0] = ManageLeaf(address(manager), false, "flashLoan(address,address[],uint256[],bytes)", new address[](2));
        leafs[0].argumentAddresses[0] = address(manager);
        leafs[0].argumentAddresses[1] = address(USDC);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[2][0]);
        // Since the manager calls to itself to fulfill the flashloan, we need to set its root.
        manager.setManageRoot(address(manager), manageTree[2][0]);

        bytes memory userData = hex"DEAD";
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
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        // Try performing a flash loan where receiveFlashLoan is not called.
        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FlashLoanNotExecuted.selector
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        doNothing = false;

        // Try performing a flash loan but with userData editted.
        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__BadFlashLoanIntentHash.selector
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testBalancerV2IntegrationReverts() external {
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
        leafs[0] = ManageLeaf(address(WETH), false, "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = vault;
        leafs[1] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5)
        );
        leafs[1].argumentAddresses[0] = address(rETH_wETH);
        leafs[1].argumentAddresses[1] = address(WETH);
        leafs[1].argumentAddresses[2] = address(RETH);
        leafs[1].argumentAddresses[3] = address(boringVault);
        leafs[1].argumentAddresses[4] = address(boringVault);
        leafs[2] = ManageLeaf(address(RETH), false, "approve(address,uint256)", new address[](1));
        leafs[2].argumentAddresses[0] = vault;
        leafs[3] = ManageLeaf(
            vault, false, "joinPool(bytes32,address,address,(address[],uint256[],bytes,bool))", new address[](5)
        );
        leafs[3].argumentAddresses[0] = address(rETH_wETH);
        leafs[3].argumentAddresses[1] = address(boringVault);
        leafs[3].argumentAddresses[2] = address(boringVault);
        leafs[3].argumentAddresses[3] = address(RETH);
        leafs[3].argumentAddresses[4] = address(WETH);
        leafs[4] = ManageLeaf(address(rETH_wETH), false, "approve(address,uint256)", new address[](1));
        leafs[4].argumentAddresses[0] = rETH_wETH_gauge;
        leafs[5] = ManageLeaf(rETH_wETH_gauge, false, "deposit(uint256,address)", new address[](1));
        leafs[5].argumentAddresses[0] = address(boringVault);
        leafs[6] = ManageLeaf(rETH_wETH_gauge, false, "withdraw(uint256)", new address[](0));
        leafs[7] = ManageLeaf(address(rETH_wETH), false, "approve(address,uint256)", new address[](1));
        leafs[7].argumentAddresses[0] = aura_reth_weth;
        leafs[8] = ManageLeaf(aura_reth_weth, false, "deposit(uint256,address)", new address[](1));
        leafs[8].argumentAddresses[0] = address(boringVault);
        leafs[9] = ManageLeaf(aura_reth_weth, false, "withdraw(uint256,address,address)", new address[](2));
        leafs[9].argumentAddresses[0] = address(boringVault);
        leafs[9].argumentAddresses[1] = address(boringVault);
        leafs[10] = ManageLeaf(
            vault, false, "exitPool(bytes32,address,address,(address[],uint256[],bytes,bool))", new address[](5)
        );
        leafs[10].argumentAddresses[0] = address(rETH_wETH);
        leafs[10].argumentAddresses[1] = address(boringVault);
        leafs[10].argumentAddresses[2] = address(boringVault);
        leafs[10].argumentAddresses[3] = address(RETH);
        leafs[10].argumentAddresses[4] = address(WETH);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

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

        // Build targetData but add data to userData.
        bytes[] memory targetData = new bytes[](11);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", vault, type(uint256).max);
        DecoderCustomTypes.SingleSwap memory singleSwap = DecoderCustomTypes.SingleSwap({
            poolId: poolId,
            kind: DecoderCustomTypes.SwapKind.GIVEN_IN,
            assetIn: address(WETH),
            assetOut: address(RETH),
            amount: 500e18,
            userData: hex"DEAD"
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
        address[] memory decodersAndSanitizers = new address[](11);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[8] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[9] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[10] = rawDataDecoderAndSanitizer;

        vm.expectRevert(
            abi.encodeWithSelector(
                BalancerV2DecoderAndSanitizer.BalancerV2DecoderAndSanitizer__SingleSwapUserDataLengthNonZero.selector
            )
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](11)
        );

        // Fix swap userData, but set fromInternalBalance to true.
        singleSwap = DecoderCustomTypes.SingleSwap({
            poolId: poolId,
            kind: DecoderCustomTypes.SwapKind.GIVEN_IN,
            assetIn: address(WETH),
            assetOut: address(RETH),
            amount: 500e18,
            userData: hex""
        });
        funds = DecoderCustomTypes.FundManagement({
            sender: address(boringVault),
            fromInternalBalance: true,
            recipient: address(boringVault),
            toInternalBalance: false
        });
        targetData[1] = abi.encodeWithSelector(BalancerV2DecoderAndSanitizer.swap.selector, singleSwap, funds, 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                BalancerV2DecoderAndSanitizer.BalancerV2DecoderAndSanitizer__InternalBalancesNotSupported.selector
            )
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](11)
        );

        // Fix swap fromInternalBalance, but set toInternalBalance to true.
        singleSwap = DecoderCustomTypes.SingleSwap({
            poolId: poolId,
            kind: DecoderCustomTypes.SwapKind.GIVEN_IN,
            assetIn: address(WETH),
            assetOut: address(RETH),
            amount: 500e18,
            userData: hex""
        });
        funds = DecoderCustomTypes.FundManagement({
            sender: address(boringVault),
            fromInternalBalance: false,
            recipient: address(boringVault),
            toInternalBalance: true
        });
        targetData[1] = abi.encodeWithSelector(BalancerV2DecoderAndSanitizer.swap.selector, singleSwap, funds, 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                BalancerV2DecoderAndSanitizer.BalancerV2DecoderAndSanitizer__InternalBalancesNotSupported.selector
            )
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](11)
        );

        // Fix swap data.
        singleSwap = DecoderCustomTypes.SingleSwap({
            poolId: poolId,
            kind: DecoderCustomTypes.SwapKind.GIVEN_IN,
            assetIn: address(WETH),
            assetOut: address(RETH),
            amount: 500e18,
            userData: hex""
        });
        funds = DecoderCustomTypes.FundManagement({
            sender: address(boringVault),
            fromInternalBalance: false,
            recipient: address(boringVault),
            toInternalBalance: false
        });
        targetData[1] = abi.encodeWithSelector(BalancerV2DecoderAndSanitizer.swap.selector, singleSwap, funds, 0);

        // Set joinPool fromInternalBalance to true.
        joinRequest = DecoderCustomTypes.JoinPoolRequest({
            assets: new address[](2),
            maxAmountsIn: new uint256[](2),
            userData: hex"",
            fromInternalBalance: true
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

        vm.expectRevert(
            abi.encodeWithSelector(
                BalancerV2DecoderAndSanitizer.BalancerV2DecoderAndSanitizer__InternalBalancesNotSupported.selector
            )
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](11)
        );

        // Fix joinPool.
        joinRequest = DecoderCustomTypes.JoinPoolRequest({
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

        // Set exitPool toInternalBalance to true.
        exitRequest = DecoderCustomTypes.ExitPoolRequest({
            assets: new address[](2),
            minAmountsOut: new uint256[](2),
            userData: hex"",
            toInternalBalance: true
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

        vm.expectRevert(
            abi.encodeWithSelector(
                BalancerV2DecoderAndSanitizer.BalancerV2DecoderAndSanitizer__InternalBalancesNotSupported.selector
            )
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](11)
        );

        // Fix exitPool
        exitRequest = DecoderCustomTypes.ExitPoolRequest({
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

        // Call no works.
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](11)
        );
    }

    function testMorphoBlueIntegrationReverts() external {
        deal(address(WETH), address(boringVault), 100e18);
        deal(address(WEETH), address(boringVault), 100e18);

        // supply weth
        // withdraw weth
        // supply weeth
        // borrow weth
        // repay weth
        // withdraw weeth.
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        leafs[0] = ManageLeaf(address(WETH), false, "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = morphoBlue;
        leafs[1] = ManageLeaf(
            morphoBlue,
            false,
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
            false,
            "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
            new address[](6)
        );
        leafs[2].argumentAddresses[0] = address(WETH);
        leafs[2].argumentAddresses[1] = address(WEETH);
        leafs[2].argumentAddresses[2] = weEthOracle;
        leafs[2].argumentAddresses[3] = weEthIrm;
        leafs[2].argumentAddresses[4] = address(boringVault);
        leafs[2].argumentAddresses[5] = address(boringVault);
        leafs[3] = ManageLeaf(address(WEETH), false, "approve(address,uint256)", new address[](1));
        leafs[3].argumentAddresses[0] = morphoBlue;
        leafs[4] = ManageLeaf(
            morphoBlue,
            false,
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
            false,
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
            false,
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
            false,
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

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

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

        address[] memory decodersAndSanitizers = new address[](8);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;

        // Pass in callback data to supply.
        targetData[1] = abi.encodeWithSignature(
            "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            params,
            100e18,
            0,
            address(boringVault),
            hex"DEAD"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                MorphoBlueDecoderAndSanitizer.MorphoBlueDecoderAndSanitizer__CallbackNotSupported.selector
            )
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](8)
        );

        // Fix supply call.
        targetData[1] = abi.encodeWithSignature(
            "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            params,
            100e18,
            0,
            address(boringVault),
            hex""
        );

        // Pass in callback data to supply collateral
        targetData[4] = abi.encodeWithSignature(
            "supplyCollateral((address,address,address,address,uint256),uint256,address,bytes)",
            params,
            100e18,
            address(boringVault),
            hex"DEAD"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                MorphoBlueDecoderAndSanitizer.MorphoBlueDecoderAndSanitizer__CallbackNotSupported.selector
            )
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](8)
        );

        // Fix supply collateral call
        targetData[4] = abi.encodeWithSignature(
            "supplyCollateral((address,address,address,address,uint256),uint256,address,bytes)",
            params,
            100e18,
            address(boringVault),
            hex""
        );

        // Pass in callback data to repay
        targetData[6] = abi.encodeWithSignature(
            "repay((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            params,
            10e18,
            0,
            address(boringVault),
            hex"DEAD"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                MorphoBlueDecoderAndSanitizer.MorphoBlueDecoderAndSanitizer__CallbackNotSupported.selector
            )
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](8)
        );

        // Fix repay call
        targetData[6] = abi.encodeWithSignature(
            "repay((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            params,
            10e18,
            0,
            address(boringVault),
            hex""
        );

        // Call now works.
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](8)
        );
    }

    function testUniswapV3IntegrationReverts() external {
        deal(address(WETH), address(boringVault), 100e18);
        deal(address(WEETH), address(boringVault), 100e18);
        // Make sure the vault can
        // swap wETH -> rETH
        // create a new position rETH/weETH
        // add to an existing position rETH/weETH
        // pull from an existing position rETH/weETH
        // collect from a position rETH/weETH
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        leafs[0] = ManageLeaf(address(WETH), false, "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = uniV3Router;
        leafs[1] =
            ManageLeaf(uniV3Router, false, "exactInput((bytes,address,uint256,uint256,uint256))", new address[](3));
        leafs[1].argumentAddresses[0] = address(WETH);
        leafs[1].argumentAddresses[1] = address(RETH);
        leafs[1].argumentAddresses[2] = address(boringVault);
        leafs[2] = ManageLeaf(address(RETH), false, "approve(address,uint256)", new address[](1));
        leafs[2].argumentAddresses[0] = uniswapV3NonFungiblePositionManager;
        leafs[3] = ManageLeaf(address(WEETH), false, "approve(address,uint256)", new address[](1));
        leafs[3].argumentAddresses[0] = uniswapV3NonFungiblePositionManager;
        leafs[4] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
            new address[](3)
        );
        leafs[4].argumentAddresses[0] = address(RETH);
        leafs[4].argumentAddresses[1] = address(WEETH);
        leafs[4].argumentAddresses[2] = address(boringVault);
        leafs[5] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
            new address[](3)
        );
        leafs[5].argumentAddresses[0] = address(0);
        leafs[5].argumentAddresses[1] = address(RETH);
        leafs[5].argumentAddresses[2] = address(WEETH);
        leafs[6] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            new address[](0)
        );
        leafs[7] = ManageLeaf(
            uniswapV3NonFungiblePositionManager, false, "collect((uint256,address,uint128,uint128))", new address[](1)
        );
        leafs[7].argumentAddresses[0] = address(boringVault);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

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

        address[] memory decodersAndSanitizers = new address[](8);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;

        // Make swap path data malformed.
        exactInputParams = DecoderCustomTypes.ExactInputParams(
            abi.encodePacked(WETH, uint32(100), RETH), address(boringVault), block.timestamp, 100e18, 0
        );
        targetData[1] = abi.encodeWithSignature("exactInput((bytes,address,uint256,uint256,uint256))", exactInputParams);

        vm.expectRevert(
            abi.encodeWithSelector(UniswapV3DecoderAndSanitizer.UniswapV3DecoderAndSanitizer__BadPathFormat.selector)
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](8)
        );

        // Fix swap path data.
        exactInputParams = DecoderCustomTypes.ExactInputParams(
            abi.encodePacked(WETH, uint24(100), RETH), address(boringVault), block.timestamp, 100e18, 0
        );
        targetData[1] = abi.encodeWithSignature("exactInput((bytes,address,uint256,uint256,uint256))", exactInputParams);

        // Try adding liquidity to a token not owned by the boring vault.
        increaseLiquidityParams =
            DecoderCustomTypes.IncreaseLiquidityParams(expectedTokenId - 1, 45e18, 45e18, 0, 0, block.timestamp);
        targetData[5] = abi.encodeWithSignature(
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))", increaseLiquidityParams
        );

        vm.expectRevert(
            abi.encodeWithSelector(UniswapV3DecoderAndSanitizer.UniswapV3DecoderAndSanitizer__BadTokenId.selector)
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](8)
        );

        // Fix increase liquidity, but change decreaseLiquidity tokenId.
        increaseLiquidityParams =
            DecoderCustomTypes.IncreaseLiquidityParams(expectedTokenId, 45e18, 45e18, 0, 0, block.timestamp);
        targetData[5] = abi.encodeWithSignature(
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))", increaseLiquidityParams
        );

        decreaseLiquidityParams =
            DecoderCustomTypes.DecreaseLiquidityParams(expectedTokenId - 1, expectedLiquidity, 0, 0, block.timestamp);
        targetData[6] = abi.encodeWithSignature(
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))", decreaseLiquidityParams
        );

        vm.expectRevert(
            abi.encodeWithSelector(UniswapV3DecoderAndSanitizer.UniswapV3DecoderAndSanitizer__BadTokenId.selector)
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](8)
        );

        // Fix decrease liquidity but change collect tokenId.
        decreaseLiquidityParams =
            DecoderCustomTypes.DecreaseLiquidityParams(expectedTokenId, expectedLiquidity, 0, 0, block.timestamp);
        targetData[6] = abi.encodeWithSignature(
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))", decreaseLiquidityParams
        );

        collectParams = DecoderCustomTypes.CollectParams(
            expectedTokenId - 1, address(boringVault), type(uint128).max, type(uint128).max
        );
        targetData[7] = abi.encodeWithSignature("collect((uint256,address,uint128,uint128))", collectParams);

        vm.expectRevert(
            abi.encodeWithSelector(UniswapV3DecoderAndSanitizer.UniswapV3DecoderAndSanitizer__BadTokenId.selector)
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](8)
        );

        // Fix collect tokenId.
        collectParams = DecoderCustomTypes.CollectParams(
            expectedTokenId, address(boringVault), type(uint128).max, type(uint128).max
        );
        targetData[7] = abi.encodeWithSignature("collect((uint256,address,uint128,uint128))", collectParams);

        // Call now works.
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](8)
        );
    }

    function testPendleRouterReverts() external {
        deal(address(WEETH), address(boringVault), 1_000e18);

        // Need 4 approvals all for router, WEETH, SY, PT, YT
        // WEETH -> SY
        // SY/2 -> PY
        // swap YT for PT
        // swap PT for YT
        // add liquidity
        // remove liquidity
        // PY -> SY
        // SY -> WEETH
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        leafs[0] = ManageLeaf(address(WEETH), false, "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = pendleRouter;
        leafs[1] = ManageLeaf(pendleWeethSy, false, "approve(address,uint256)", new address[](1));
        leafs[1].argumentAddresses[0] = pendleRouter;
        leafs[2] = ManageLeaf(pendleEethPt, false, "approve(address,uint256)", new address[](1));
        leafs[2].argumentAddresses[0] = pendleRouter;
        leafs[3] = ManageLeaf(pendleEethYt, false, "approve(address,uint256)", new address[](1));
        leafs[3].argumentAddresses[0] = pendleRouter;
        leafs[4] = ManageLeaf(pendleWeETHMarket, false, "approve(address,uint256)", new address[](1));
        leafs[4].argumentAddresses[0] = pendleRouter;
        leafs[5] = ManageLeaf(
            pendleRouter,
            false,
            "mintSyFromToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            new address[](6)
        );
        leafs[5].argumentAddresses[0] = address(boringVault);
        leafs[5].argumentAddresses[1] = pendleWeethSy;
        leafs[5].argumentAddresses[2] = address(WEETH);
        leafs[5].argumentAddresses[3] = address(WEETH);
        leafs[5].argumentAddresses[4] = address(0);
        leafs[5].argumentAddresses[5] = address(0);
        leafs[6] = ManageLeaf(pendleRouter, false, "mintPyFromSy(address,address,uint256,uint256)", new address[](2));
        leafs[6].argumentAddresses[0] = address(boringVault);
        leafs[6].argumentAddresses[1] = pendleEethYt;
        leafs[7] = ManageLeaf(
            pendleRouter,
            false,
            "swapExactYtForPt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            new address[](2)
        );
        leafs[7].argumentAddresses[0] = address(boringVault);
        leafs[7].argumentAddresses[1] = pendleWeETHMarket;
        leafs[8] = ManageLeaf(
            pendleRouter,
            false,
            "swapExactPtForYt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            new address[](2)
        );
        leafs[8].argumentAddresses[0] = address(boringVault);
        leafs[8].argumentAddresses[1] = pendleWeETHMarket;
        leafs[9] = ManageLeaf(
            pendleRouter, false, "addLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)", new address[](2)
        );
        leafs[9].argumentAddresses[0] = address(boringVault);
        leafs[9].argumentAddresses[1] = pendleWeETHMarket;
        leafs[10] = ManageLeaf(
            pendleRouter, false, "removeLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)", new address[](2)
        );
        leafs[10].argumentAddresses[0] = address(boringVault);
        leafs[10].argumentAddresses[1] = pendleWeETHMarket;
        leafs[11] = ManageLeaf(pendleRouter, false, "redeemPyToSy(address,address,uint256,uint256)", new address[](2));
        leafs[11].argumentAddresses[0] = address(boringVault);
        leafs[11].argumentAddresses[1] = pendleEethYt;
        leafs[12] = ManageLeaf(
            pendleRouter,
            false,
            "redeemSyToToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            new address[](6)
        );
        leafs[12].argumentAddresses[0] = address(boringVault);
        leafs[12].argumentAddresses[1] = pendleWeethSy;
        leafs[12].argumentAddresses[2] = address(WEETH);
        leafs[12].argumentAddresses[3] = address(WEETH);
        leafs[12].argumentAddresses[4] = address(0);
        leafs[12].argumentAddresses[5] = address(0);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](13);
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
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](13);
        targets[0] = address(WEETH);
        targets[1] = pendleWeethSy;
        targets[2] = pendleEethPt;
        targets[3] = pendleEethYt;
        targets[4] = pendleWeETHMarket;
        targets[5] = pendleRouter;
        targets[6] = pendleRouter;
        targets[7] = pendleRouter;
        targets[8] = pendleRouter;
        targets[9] = pendleRouter;
        targets[10] = pendleRouter;
        targets[11] = pendleRouter;
        targets[12] = pendleRouter;

        bytes[] memory targetData = new bytes[](13);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", pendleRouter, type(uint256).max);
        targetData[1] = abi.encodeWithSignature("approve(address,uint256)", pendleRouter, type(uint256).max);
        targetData[2] = abi.encodeWithSignature("approve(address,uint256)", pendleRouter, type(uint256).max);
        targetData[3] = abi.encodeWithSignature("approve(address,uint256)", pendleRouter, type(uint256).max);
        targetData[4] = abi.encodeWithSignature("approve(address,uint256)", pendleRouter, type(uint256).max);
        DecoderCustomTypes.SwapData memory swapData =
            DecoderCustomTypes.SwapData(DecoderCustomTypes.SwapType.NONE, address(0), hex"", false);
        DecoderCustomTypes.TokenInput memory tokenInput =
            DecoderCustomTypes.TokenInput(address(WEETH), 1_000e18, address(WEETH), address(0), swapData);
        targetData[5] = abi.encodeWithSignature(
            "mintSyFromToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            address(boringVault),
            pendleWeethSy,
            0,
            tokenInput
        );
        targetData[6] = abi.encodeWithSignature(
            "mintPyFromSy(address,address,uint256,uint256)", address(boringVault), pendleEethYt, 100e18, 0
        );
        DecoderCustomTypes.ApproxParams memory approxParams =
            DecoderCustomTypes.ApproxParams(0, type(uint256).max, 0, 2566, 1e14);
        targetData[7] = abi.encodeWithSignature(
            "swapExactYtForPt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            address(boringVault),
            pendleWeETHMarket,
            10e18,
            0,
            approxParams
        );
        targetData[8] = abi.encodeWithSignature(
            "swapExactPtForYt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            address(boringVault),
            pendleWeETHMarket,
            1e18,
            0,
            approxParams
        );
        targetData[9] = abi.encodeWithSignature(
            "addLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
            address(boringVault),
            pendleWeETHMarket,
            1e18,
            1e18,
            0
        );
        targetData[10] = abi.encodeWithSignature(
            "removeLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
            address(boringVault),
            pendleWeETHMarket,
            0.1e18,
            0,
            0
        );
        targetData[11] = abi.encodeWithSignature(
            "redeemPyToSy(address,address,uint256,uint256)", address(boringVault), pendleEethYt, 0.1e18, 0
        );
        DecoderCustomTypes.TokenOutput memory tokenOutput =
            DecoderCustomTypes.TokenOutput(address(WEETH), 0, address(WEETH), address(0), swapData);
        targetData[12] = abi.encodeWithSignature(
            "redeemSyToToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            address(boringVault),
            pendleWeethSy,
            1e18,
            tokenOutput
        );

        address[] memory decodersAndSanitizers = new address[](13);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[8] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[9] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[10] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[11] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[12] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](13);

        // Change token input to try and swap.
        tokenInput = DecoderCustomTypes.TokenInput(address(EETH), 1_000e18, address(WEETH), address(0), swapData);
        targetData[5] = abi.encodeWithSignature(
            "mintSyFromToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            address(boringVault),
            pendleWeethSy,
            0,
            tokenInput
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                PendleRouterDecoderAndSanitizer.PendleRouterDecoderAndSanitizer__AggregatorSwapsNotPermitted.selector
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Fix tokenInput
        tokenInput = DecoderCustomTypes.TokenInput(address(WEETH), 1_000e18, address(WEETH), address(0), swapData);
        targetData[5] = abi.encodeWithSignature(
            "mintSyFromToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            address(boringVault),
            pendleWeethSy,
            0,
            tokenInput
        );

        // Try to make a swap when exiting
        tokenOutput = DecoderCustomTypes.TokenOutput(address(EETH), 0, address(WEETH), address(0), swapData);
        targetData[12] = abi.encodeWithSignature(
            "redeemSyToToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            address(boringVault),
            pendleWeethSy,
            1e18,
            tokenOutput
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                PendleRouterDecoderAndSanitizer.PendleRouterDecoderAndSanitizer__AggregatorSwapsNotPermitted.selector
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Fix tokenOutput
        tokenOutput = DecoderCustomTypes.TokenOutput(address(WEETH), 0, address(WEETH), address(0), swapData);
        targetData[12] = abi.encodeWithSignature(
            "redeemSyToToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            address(boringVault),
            pendleWeethSy,
            1e18,
            tokenOutput
        );

        // Call now works.
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // ========================================= HELPER FUNCTIONS =========================================
    bool doNothing = true;

    function flashLoan(address, address[] calldata tokens, uint256[] calldata amounts, bytes memory userData)
        external
    {
        if (doNothing) {
            return;
        } else {
            // Edit userData.
            userData = hex"DEAD01";
            manager.receiveFlashLoan(tokens, amounts, amounts, userData);
        }
    }

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
        view
        returns (bytes32[][] memory proofs)
    {
        proofs = new bytes32[][](manageLeafs.length);
        for (uint256 i; i < manageLeafs.length; ++i) {
            // Generate manage proof.
            bytes4 selector = bytes4(keccak256(abi.encodePacked(manageLeafs[i].signature)));
            bytes memory rawDigest = abi.encodePacked(
                rawDataDecoderAndSanitizer, manageLeafs[i].target, manageLeafs[i].canSendValue, selector
            );
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
        bool canSendValue;
        string signature;
        address[] argumentAddresses;
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

interface IUNSTETH {
    function finalize(uint256 _lastRequestIdToBeFinalized, uint256 _maxShareRate) external payable;

    function getRoleMember(bytes32 role, uint256 index) external view returns (address);

    function FINALIZE_ROLE() external view returns (bytes32);

    function findCheckpointHints(uint256[] memory requestIds, uint256 firstIndex, uint256 lastIndex)
        external
        view
        returns (uint256[] memory);

    function getLastCheckpointIndex() external view returns (uint256);
}
