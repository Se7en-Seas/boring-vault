// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {
    EtherFiLiquidDecoderAndSanitizer,
    BalancerV2DecoderAndSanitizer,
    AuraDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/EtherFiLiquidDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract BalancerAndAuraIntegrationTest is Test, MerkleTreeHelper {
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

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19826676;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(
            new EtherFiLiquidDecoderAndSanitizer(
                address(boringVault), getAddress(sourceChain, "uniswapV3NonFungiblePositionManager")
            )
        );

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(1));

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
        rolesAuthority.setUserRole(getAddress(sourceChain, "vault"), BALANCER_VAULT_ROLE, true);
    }

    function testBalancerV2AndAuraIntegration() external {
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
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
        _addBalancerLeafs(leafs, poolId, getAddress(sourceChain, "rETH_wETH_gauge"));
        leafs[8] = ManageLeaf(
            getAddress(sourceChain, "vault"),
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap wETH for rETH using Balancer",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafIndex++;
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "rETH_wETH");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "WETH");
        leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "RETH");
        leafs[leafIndex].argumentAddresses[3] = address(boringVault);
        leafs[leafIndex].argumentAddresses[4] = address(boringVault);
        _addAuraLeafs(leafs, getAddress(sourceChain, "aura_reth_weth"));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](11);
        manageLeafs[0] = leafs[1];
        manageLeafs[1] = leafs[8];
        manageLeafs[2] = leafs[0];
        manageLeafs[3] = leafs[3];
        manageLeafs[4] = leafs[2];
        manageLeafs[5] = leafs[5];
        manageLeafs[6] = leafs[6];
        manageLeafs[7] = leafs[9];
        manageLeafs[8] = leafs[10];
        manageLeafs[9] = leafs[11];
        manageLeafs[10] = leafs[4];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](11);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "vault");
        targets[2] = getAddress(sourceChain, "RETH");
        targets[3] = getAddress(sourceChain, "vault");
        targets[4] = getAddress(sourceChain, "rETH_wETH");
        targets[5] = getAddress(sourceChain, "rETH_wETH_gauge");
        targets[6] = getAddress(sourceChain, "rETH_wETH_gauge");
        targets[7] = getAddress(sourceChain, "rETH_wETH");
        targets[8] = getAddress(sourceChain, "aura_reth_weth");
        targets[9] = getAddress(sourceChain, "aura_reth_weth");
        targets[10] = getAddress(sourceChain, "vault");
        // targets[7] = uniswapV3NonFungiblePositionManager;
        bytes[] memory targetData = new bytes[](11);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "vault"), type(uint256).max);
        DecoderCustomTypes.SingleSwap memory singleSwap = DecoderCustomTypes.SingleSwap({
            poolId: poolId,
            kind: DecoderCustomTypes.SwapKind.GIVEN_IN,
            assetIn: getAddress(sourceChain, "WETH"),
            assetOut: getAddress(sourceChain, "RETH"),
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
        targetData[2] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "vault"), type(uint256).max);
        DecoderCustomTypes.JoinPoolRequest memory joinRequest = DecoderCustomTypes.JoinPoolRequest({
            assets: new address[](2),
            maxAmountsIn: new uint256[](2),
            userData: hex"",
            fromInternalBalance: false
        });
        joinRequest.assets[0] = getAddress(sourceChain, "RETH");
        joinRequest.assets[1] = getAddress(sourceChain, "WETH");
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
        targetData[4] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "rETH_wETH_gauge"), type(uint256).max
        );
        targetData[5] = abi.encodeWithSignature("deposit(uint256,address)", 203690537881715311640, address(boringVault));
        targetData[6] = abi.encodeWithSignature("withdraw(uint256)", 203690537881715311640, address(boringVault));
        targetData[7] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "aura_reth_weth"), type(uint256).max
        );
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
        exitRequest.assets[0] = getAddress(sourceChain, "RETH");
        exitRequest.assets[1] = getAddress(sourceChain, "WETH");
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
        manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[7];
        manageLeafs[1] = leafs[12];
        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](2);
        targets[0] = getAddress(sourceChain, "minter");
        targets[1] = getAddress(sourceChain, "aura_reth_weth");
        targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("mint(address)", getAddress(sourceChain, "rETH_wETH_gauge"));
        targetData[1] = abi.encodeWithSignature("getReward(address,bool)", address(boringVault), true);
        decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](2)
        );
    }

    function testBalancerV2IntegrationReverts() external {
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
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
        _addBalancerLeafs(leafs, poolId, getAddress(sourceChain, "rETH_wETH_gauge"));
        leafs[8] = ManageLeaf(
            getAddress(sourceChain, "vault"),
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap wETH for rETH using Balancer",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafIndex++;
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "rETH_wETH");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "WETH");
        leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "RETH");
        leafs[leafIndex].argumentAddresses[3] = address(boringVault);
        leafs[leafIndex].argumentAddresses[4] = address(boringVault);
        _addAuraLeafs(leafs, getAddress(sourceChain, "aura_reth_weth"));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](11);
        manageLeafs[0] = leafs[1];
        manageLeafs[1] = leafs[8];
        manageLeafs[2] = leafs[0];
        manageLeafs[3] = leafs[3];
        manageLeafs[4] = leafs[2];
        manageLeafs[5] = leafs[5];
        manageLeafs[6] = leafs[6];
        manageLeafs[7] = leafs[9];
        manageLeafs[8] = leafs[10];
        manageLeafs[9] = leafs[11];
        manageLeafs[10] = leafs[4];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](11);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "vault");
        targets[2] = getAddress(sourceChain, "RETH");
        targets[3] = getAddress(sourceChain, "vault");
        targets[4] = getAddress(sourceChain, "rETH_wETH");
        targets[5] = getAddress(sourceChain, "rETH_wETH_gauge");
        targets[6] = getAddress(sourceChain, "rETH_wETH_gauge");
        targets[7] = getAddress(sourceChain, "rETH_wETH");
        targets[8] = getAddress(sourceChain, "aura_reth_weth");
        targets[9] = getAddress(sourceChain, "aura_reth_weth");
        targets[10] = getAddress(sourceChain, "vault");

        // Build targetData but add data to userData.
        bytes[] memory targetData = new bytes[](11);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "vault"), type(uint256).max);
        DecoderCustomTypes.SingleSwap memory singleSwap = DecoderCustomTypes.SingleSwap({
            poolId: poolId,
            kind: DecoderCustomTypes.SwapKind.GIVEN_IN,
            assetIn: getAddress(sourceChain, "WETH"),
            assetOut: getAddress(sourceChain, "RETH"),
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
        targetData[2] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "vault"), type(uint256).max);
        DecoderCustomTypes.JoinPoolRequest memory joinRequest = DecoderCustomTypes.JoinPoolRequest({
            assets: new address[](2),
            maxAmountsIn: new uint256[](2),
            userData: hex"",
            fromInternalBalance: false
        });
        joinRequest.assets[0] = getAddress(sourceChain, "RETH");
        joinRequest.assets[1] = getAddress(sourceChain, "WETH");
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
        targetData[4] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "rETH_wETH_gauge"), type(uint256).max
        );
        targetData[5] = abi.encodeWithSignature("deposit(uint256,address)", 203690537881715311640, address(boringVault));
        targetData[6] = abi.encodeWithSignature("withdraw(uint256)", 203690537881715311640, address(boringVault));
        targetData[7] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "aura_reth_weth"), type(uint256).max
        );
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
        exitRequest.assets[0] = getAddress(sourceChain, "RETH");
        exitRequest.assets[1] = getAddress(sourceChain, "WETH");
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
            assetIn: getAddress(sourceChain, "WETH"),
            assetOut: getAddress(sourceChain, "RETH"),
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
            assetIn: getAddress(sourceChain, "WETH"),
            assetOut: getAddress(sourceChain, "RETH"),
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
            assetIn: getAddress(sourceChain, "WETH"),
            assetOut: getAddress(sourceChain, "RETH"),
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
        joinRequest.assets[0] = getAddress(sourceChain, "RETH");
        joinRequest.assets[1] = getAddress(sourceChain, "WETH");
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
        joinRequest.assets[0] = getAddress(sourceChain, "RETH");
        joinRequest.assets[1] = getAddress(sourceChain, "WETH");
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
        exitRequest.assets[0] = getAddress(sourceChain, "RETH");
        exitRequest.assets[1] = getAddress(sourceChain, "WETH");
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
        exitRequest.assets[0] = getAddress(sourceChain, "RETH");
        exitRequest.assets[1] = getAddress(sourceChain, "WETH");
        exitRequest.userData = abi.encode(1, 203690537881715311640); // EXACT_BPT_IN_FOR_TOKENS_OUT, 203690537881715311640
        targetData[10] = abi.encodeWithSelector(
            BalancerV2DecoderAndSanitizer.exitPool.selector,
            poolId,
            address(boringVault),
            address(boringVault),
            exitRequest
        );

        // Call now works.
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](11)
        );
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
