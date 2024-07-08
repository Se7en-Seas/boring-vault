// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {PancakeSwapV3FullDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/PancakeSwapV3FullDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {UniswapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3DecoderAndSanitizer.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract PancakeSwapV3IntegrationTest is Test, MainnetAddresses {
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
        uint256 blockNumber = 20213659;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager = new ManagerWithMerkleVerification(address(this), address(boringVault), vault);

        rawDataDecoderAndSanitizer = address(
            new PancakeSwapV3FullDecoderAndSanitizer(
                address(boringVault), pancakeSwapV3NonFungiblePositionManager, pancakeSwapV3MasterChefV3
            )
        );

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

    function testPancakeSwapV3IntegrationNoStaking() external {
        deal(address(WETH), address(boringVault), 200e18);
        // Make sure the vault can
        // swap wETH -> rETH
        // create a new position rETH/weETH
        // add to an existing position rETH/weETH
        // pull from an existing position rETH/weETH
        // collect from a position rETH/weETH
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        leafs[0] = ManageLeaf(address(WETH), false, "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = pancakeSwapV3Router;
        leafs[1] =
            ManageLeaf(pancakeSwapV3Router, false, "exactInput((bytes,address,uint256,uint256))", new address[](3));
        leafs[1].argumentAddresses[0] = address(WETH);
        leafs[1].argumentAddresses[1] = address(RETH);
        leafs[1].argumentAddresses[2] = address(boringVault);
        leafs[2] = ManageLeaf(address(RETH), false, "approve(address,uint256)", new address[](1));
        leafs[2].argumentAddresses[0] = pancakeSwapV3NonFungiblePositionManager;
        leafs[3] = ManageLeaf(address(WETH), false, "approve(address,uint256)", new address[](1));
        leafs[3].argumentAddresses[0] = pancakeSwapV3NonFungiblePositionManager;
        leafs[4] = ManageLeaf(
            pancakeSwapV3NonFungiblePositionManager,
            false,
            "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
            new address[](3)
        );
        leafs[4].argumentAddresses[0] = address(RETH);
        leafs[4].argumentAddresses[1] = address(WETH);
        leafs[4].argumentAddresses[2] = address(boringVault);
        leafs[5] = ManageLeaf(
            pancakeSwapV3NonFungiblePositionManager,
            false,
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
            new address[](3)
        );
        leafs[5].argumentAddresses[0] = address(0);
        leafs[5].argumentAddresses[1] = address(RETH);
        leafs[5].argumentAddresses[2] = address(WETH);
        leafs[6] = ManageLeaf(
            pancakeSwapV3NonFungiblePositionManager,
            false,
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            new address[](0)
        );
        leafs[7] = ManageLeaf(
            pancakeSwapV3NonFungiblePositionManager,
            false,
            "collect((uint256,address,uint128,uint128))",
            new address[](1)
        );
        leafs[7].argumentAddresses[0] = address(boringVault);
        leafs[8] = ManageLeaf(pancakeSwapV3NonFungiblePositionManager, false, "burn(uint256)", new address[](0));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](9);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];
        manageLeafs[3] = leafs[3];
        manageLeafs[4] = leafs[4];
        manageLeafs[5] = leafs[5];
        manageLeafs[6] = leafs[6];
        manageLeafs[7] = leafs[7];
        manageLeafs[8] = leafs[8];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](9);
        targets[0] = address(WETH);
        targets[1] = pancakeSwapV3Router;
        targets[2] = address(RETH);
        targets[3] = address(WETH);
        targets[4] = pancakeSwapV3NonFungiblePositionManager;
        targets[5] = pancakeSwapV3NonFungiblePositionManager;
        targets[6] = pancakeSwapV3NonFungiblePositionManager;
        targets[7] = pancakeSwapV3NonFungiblePositionManager;
        targets[8] = pancakeSwapV3NonFungiblePositionManager;
        bytes[] memory targetData = new bytes[](9);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", pancakeSwapV3Router, type(uint256).max);
        DecoderCustomTypes.PancakeSwapExactInputParams memory exactInputParams = DecoderCustomTypes
            .PancakeSwapExactInputParams(abi.encodePacked(WETH, uint24(500), RETH), address(boringVault), 100e18, 0);
        targetData[1] = abi.encodeWithSignature("exactInput((bytes,address,uint256,uint256))", exactInputParams);
        targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", pancakeSwapV3NonFungiblePositionManager, type(uint256).max
        );
        targetData[3] = abi.encodeWithSignature(
            "approve(address,uint256)", pancakeSwapV3NonFungiblePositionManager, type(uint256).max
        );

        DecoderCustomTypes.MintParams memory mintParams = DecoderCustomTypes.MintParams(
            address(RETH),
            address(WETH),
            uint24(500),
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
        uint256 expectedTokenId = 11099;
        DecoderCustomTypes.IncreaseLiquidityParams memory increaseLiquidityParams =
            DecoderCustomTypes.IncreaseLiquidityParams(expectedTokenId, 45e18, 45e18, 0, 0, block.timestamp);
        targetData[5] = abi.encodeWithSignature(
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))", increaseLiquidityParams
        );
        uint128 expectedLiquidity = 8712642733663394060416 + 8712642733663394060416;
        DecoderCustomTypes.DecreaseLiquidityParams memory decreaseLiquidityParams =
            DecoderCustomTypes.DecreaseLiquidityParams(expectedTokenId, expectedLiquidity, 0, 0, block.timestamp);
        targetData[6] = abi.encodeWithSignature(
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))", decreaseLiquidityParams
        );

        DecoderCustomTypes.CollectParams memory collectParams = DecoderCustomTypes.CollectParams(
            expectedTokenId, address(boringVault), type(uint128).max, type(uint128).max
        );
        targetData[7] = abi.encodeWithSignature("collect((uint256,address,uint128,uint128))", collectParams);
        targetData[8] = abi.encodeWithSignature("burn(uint256)", expectedTokenId);

        address[] memory decodersAndSanitizers = new address[](9);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[8] = rawDataDecoderAndSanitizer;
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](9)
        );
    }

    function testPancakeSwapV3IntegrationWithStaking() external {
        deal(address(WETH), address(boringVault), 200e18);
        // Make sure the vault can
        // swap wETH -> rETH
        // create a new position rETH/weETH
        // add to an existing position rETH/weETH
        // pull from an existing position rETH/weETH
        // collect from a position rETH/weETH
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        leafs[0] = ManageLeaf(address(WETH), false, "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = pancakeSwapV3Router;
        leafs[1] =
            ManageLeaf(pancakeSwapV3Router, false, "exactInput((bytes,address,uint256,uint256))", new address[](3));
        leafs[1].argumentAddresses[0] = address(WETH);
        leafs[1].argumentAddresses[1] = address(RETH);
        leafs[1].argumentAddresses[2] = address(boringVault);
        leafs[2] = ManageLeaf(address(RETH), false, "approve(address,uint256)", new address[](1));
        leafs[2].argumentAddresses[0] = pancakeSwapV3NonFungiblePositionManager;
        leafs[3] = ManageLeaf(address(WETH), false, "approve(address,uint256)", new address[](1));
        leafs[3].argumentAddresses[0] = pancakeSwapV3NonFungiblePositionManager;
        leafs[4] = ManageLeaf(address(RETH), false, "approve(address,uint256)", new address[](1));
        leafs[4].argumentAddresses[0] = pancakeSwapV3MasterChefV3;
        leafs[5] = ManageLeaf(address(WETH), false, "approve(address,uint256)", new address[](1));
        leafs[5].argumentAddresses[0] = pancakeSwapV3MasterChefV3;
        leafs[6] = ManageLeaf(
            pancakeSwapV3NonFungiblePositionManager,
            false,
            "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
            new address[](3)
        );
        leafs[6].argumentAddresses[0] = address(RETH);
        leafs[6].argumentAddresses[1] = address(WETH);
        leafs[6].argumentAddresses[2] = address(boringVault);
        leafs[7] = ManageLeaf(
            pancakeSwapV3NonFungiblePositionManager,
            false,
            "safeTransferFrom(address,address,uint256)",
            new address[](2)
        );
        leafs[7].argumentAddresses[0] = address(boringVault);
        leafs[7].argumentAddresses[1] = pancakeSwapV3MasterChefV3;
        leafs[8] = ManageLeaf(
            pancakeSwapV3MasterChefV3,
            false,
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
            new address[](3)
        );
        leafs[8].argumentAddresses[0] = address(0);
        leafs[8].argumentAddresses[1] = address(RETH);
        leafs[8].argumentAddresses[2] = address(WETH);
        leafs[9] = ManageLeaf(pancakeSwapV3MasterChefV3, false, "harvest(uint256,address)", new address[](1));
        leafs[9].argumentAddresses[0] = address(boringVault);
        leafs[10] = ManageLeaf(
            pancakeSwapV3MasterChefV3,
            false,
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            new address[](0)
        );
        leafs[11] =
            ManageLeaf(pancakeSwapV3MasterChefV3, false, "collect((uint256,address,uint128,uint128))", new address[](1));
        leafs[11].argumentAddresses[0] = address(boringVault);
        leafs[12] = ManageLeaf(pancakeSwapV3MasterChefV3, false, "withdraw(uint256,address)", new address[](1));
        leafs[12].argumentAddresses[0] = address(boringVault);
        leafs[13] = ManageLeaf(pancakeSwapV3NonFungiblePositionManager, false, "burn(uint256)", new address[](0));

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
        targets[1] = pancakeSwapV3Router;
        targets[2] = address(RETH);
        targets[3] = address(WETH);
        targets[4] = address(RETH);
        targets[5] = address(WETH);
        targets[6] = pancakeSwapV3NonFungiblePositionManager;
        targets[7] = pancakeSwapV3NonFungiblePositionManager;
        targets[8] = pancakeSwapV3MasterChefV3;
        targets[9] = pancakeSwapV3MasterChefV3;
        targets[10] = pancakeSwapV3MasterChefV3;
        targets[11] = pancakeSwapV3MasterChefV3;
        targets[12] = pancakeSwapV3MasterChefV3;
        targets[13] = pancakeSwapV3NonFungiblePositionManager;

        bytes[] memory targetData = new bytes[](14);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", pancakeSwapV3Router, type(uint256).max);
        DecoderCustomTypes.PancakeSwapExactInputParams memory exactInputParams = DecoderCustomTypes
            .PancakeSwapExactInputParams(abi.encodePacked(WETH, uint24(500), RETH), address(boringVault), 100e18, 0);
        targetData[1] = abi.encodeWithSignature("exactInput((bytes,address,uint256,uint256))", exactInputParams);
        targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", pancakeSwapV3NonFungiblePositionManager, type(uint256).max
        );
        targetData[3] = abi.encodeWithSignature(
            "approve(address,uint256)", pancakeSwapV3NonFungiblePositionManager, type(uint256).max
        );
        targetData[4] =
            abi.encodeWithSignature("approve(address,uint256)", pancakeSwapV3MasterChefV3, type(uint256).max);
        targetData[5] =
            abi.encodeWithSignature("approve(address,uint256)", pancakeSwapV3MasterChefV3, type(uint256).max);

        DecoderCustomTypes.MintParams memory mintParams = DecoderCustomTypes.MintParams(
            address(RETH),
            address(WETH),
            uint24(500),
            int24(600), // lower tick
            int24(700), // upper tick
            45e18,
            45e18,
            0,
            0,
            address(boringVault),
            block.timestamp
        );
        targetData[6] = abi.encodeWithSignature(
            "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))", mintParams
        );
        uint256 expectedTokenId = 11099;
        targetData[7] = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256)",
            address(boringVault),
            pancakeSwapV3MasterChefV3,
            expectedTokenId
        );
        DecoderCustomTypes.IncreaseLiquidityParams memory increaseLiquidityParams =
            DecoderCustomTypes.IncreaseLiquidityParams(expectedTokenId, 45e18, 45e18, 0, 0, block.timestamp);
        targetData[8] = abi.encodeWithSignature(
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))", increaseLiquidityParams
        );
        targetData[9] = abi.encodeWithSignature("harvest(uint256,address)", expectedTokenId, address(boringVault));
        uint128 expectedLiquidity = 8712642733663394060416 + 8712642733663394060416;
        DecoderCustomTypes.DecreaseLiquidityParams memory decreaseLiquidityParams =
            DecoderCustomTypes.DecreaseLiquidityParams(expectedTokenId, expectedLiquidity, 0, 0, block.timestamp);
        targetData[10] = abi.encodeWithSignature(
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))", decreaseLiquidityParams
        );

        DecoderCustomTypes.CollectParams memory collectParams = DecoderCustomTypes.CollectParams(
            expectedTokenId, address(boringVault), type(uint128).max, type(uint128).max
        );
        targetData[11] = abi.encodeWithSignature("collect((uint256,address,uint128,uint128))", collectParams);
        targetData[12] = abi.encodeWithSignature("withdraw(uint256,address)", expectedTokenId, address(boringVault));
        targetData[13] = abi.encodeWithSignature("burn(uint256)", expectedTokenId);

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

    function testUniswapV3IntegrationReverts() external {
        deal(address(WETH), address(boringVault), 200e18);
        // Make sure the vault can
        // swap wETH -> rETH
        // create a new position rETH/weETH
        // add to an existing position rETH/weETH
        // pull from an existing position rETH/weETH
        // collect from a position rETH/weETH
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        leafs[0] = ManageLeaf(address(WETH), false, "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = pancakeSwapV3Router;
        leafs[1] =
            ManageLeaf(pancakeSwapV3Router, false, "exactInput((bytes,address,uint256,uint256))", new address[](3));
        leafs[1].argumentAddresses[0] = address(WETH);
        leafs[1].argumentAddresses[1] = address(RETH);
        leafs[1].argumentAddresses[2] = address(boringVault);
        leafs[2] = ManageLeaf(address(RETH), false, "approve(address,uint256)", new address[](1));
        leafs[2].argumentAddresses[0] = pancakeSwapV3NonFungiblePositionManager;
        leafs[3] = ManageLeaf(address(WETH), false, "approve(address,uint256)", new address[](1));
        leafs[3].argumentAddresses[0] = pancakeSwapV3NonFungiblePositionManager;
        leafs[4] = ManageLeaf(
            pancakeSwapV3NonFungiblePositionManager,
            false,
            "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
            new address[](3)
        );
        leafs[4].argumentAddresses[0] = address(RETH);
        leafs[4].argumentAddresses[1] = address(WETH);
        leafs[4].argumentAddresses[2] = address(boringVault);
        leafs[5] = ManageLeaf(
            pancakeSwapV3NonFungiblePositionManager,
            false,
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
            new address[](3)
        );
        leafs[5].argumentAddresses[0] = address(0);
        leafs[5].argumentAddresses[1] = address(RETH);
        leafs[5].argumentAddresses[2] = address(WETH);
        leafs[6] = ManageLeaf(
            pancakeSwapV3NonFungiblePositionManager,
            false,
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            new address[](0)
        );
        leafs[7] = ManageLeaf(
            pancakeSwapV3NonFungiblePositionManager,
            false,
            "collect((uint256,address,uint128,uint128))",
            new address[](1)
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
        targets[1] = pancakeSwapV3Router;
        targets[2] = address(RETH);
        targets[3] = address(WETH);
        targets[4] = pancakeSwapV3NonFungiblePositionManager;
        targets[5] = pancakeSwapV3NonFungiblePositionManager;
        targets[6] = pancakeSwapV3NonFungiblePositionManager;
        targets[7] = pancakeSwapV3NonFungiblePositionManager;
        bytes[] memory targetData = new bytes[](8);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", pancakeSwapV3Router, type(uint256).max);
        DecoderCustomTypes.PancakeSwapExactInputParams memory exactInputParams = DecoderCustomTypes
            .PancakeSwapExactInputParams(abi.encodePacked(WETH, uint24(500), RETH), address(boringVault), 100e18, 0);
        targetData[1] = abi.encodeWithSignature("exactInput((bytes,address,uint256,uint256))", exactInputParams);
        targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", pancakeSwapV3NonFungiblePositionManager, type(uint256).max
        );
        targetData[3] = abi.encodeWithSignature(
            "approve(address,uint256)", pancakeSwapV3NonFungiblePositionManager, type(uint256).max
        );

        DecoderCustomTypes.MintParams memory mintParams = DecoderCustomTypes.MintParams(
            address(RETH),
            address(WETH),
            uint24(500),
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
        uint256 expectedTokenId = 11099;
        DecoderCustomTypes.IncreaseLiquidityParams memory increaseLiquidityParams =
            DecoderCustomTypes.IncreaseLiquidityParams(expectedTokenId, 45e18, 45e18, 0, 0, block.timestamp);
        targetData[5] = abi.encodeWithSignature(
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))", increaseLiquidityParams
        );
        uint128 expectedLiquidity = 8712642733663394060416 + 8712642733663394060416;
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
        exactInputParams = DecoderCustomTypes.PancakeSwapExactInputParams(
            abi.encodePacked(WETH, uint32(500), RETH), address(boringVault), 100e18, 0
        );
        targetData[1] = abi.encodeWithSignature("exactInput((bytes,address,uint256,uint256))", exactInputParams);

        vm.expectRevert(
            abi.encodeWithSelector(UniswapV3DecoderAndSanitizer.UniswapV3DecoderAndSanitizer__BadPathFormat.selector)
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](8)
        );

        // Fix swap path data.
        exactInputParams = DecoderCustomTypes.PancakeSwapExactInputParams(
            abi.encodePacked(WETH, uint24(500), RETH), address(boringVault), 100e18, 0
        );
        targetData[1] = abi.encodeWithSignature("exactInput((bytes,address,uint256,uint256))", exactInputParams);

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

    function withdraw(uint256 amount) external {
        boringVault.enter(address(0), ERC20(address(0)), 0, address(this), amount);
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

interface EthenaSusde {
    function cooldownDuration() external view returns (uint24);
    function cooldowns(address) external view returns (uint104 cooldownEnd, uint152 underlyingAmount);
}
