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
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract PancakeSwapV3IntegrationTest is Test, MerkleTreeHelper {
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
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 20213659;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(
            new PancakeSwapV3FullDecoderAndSanitizer(
                address(boringVault),
                getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager"),
                getAddress(sourceChain, "pancakeSwapV3MasterChefV3")
            )
        );

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
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

        // Allow the boring vault to receive ETH.
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);
    }

    function testPancakeSwapV3IntegrationNoStaking() external {
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 200e18);
        // Make sure the vault can
        // swap wETH -> rETH
        // create a new position rETH/wETH
        // add to an existing position rETH/wETH
        // pull from an existing position rETH/wETH
        // collect from a position rETH/wETH
        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        address[] memory tokens0 = new address[](1);
        tokens0[0] = getAddress(sourceChain, "WETH");
        address[] memory tokens1 = new address[](1);
        tokens1[0] = getAddress(sourceChain, "RETH");
        _addPancakeSwapV3Leafs(leafs, tokens0, tokens1);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](9);
        manageLeafs[0] = leafs[5];
        manageLeafs[1] = leafs[10];
        manageLeafs[2] = leafs[0];
        manageLeafs[3] = leafs[1];
        manageLeafs[4] = leafs[6];
        manageLeafs[5] = leafs[7];
        manageLeafs[6] = leafs[11];
        manageLeafs[7] = leafs[13];
        manageLeafs[8] = leafs[15];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](9);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "pancakeSwapV3Router");
        targets[2] = getAddress(sourceChain, "RETH");
        targets[3] = getAddress(sourceChain, "WETH");
        targets[4] = getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager");
        targets[5] = getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager");
        targets[6] = getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager");
        targets[7] = getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager");
        targets[8] = getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager");
        bytes[] memory targetData = new bytes[](9);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "pancakeSwapV3Router"), type(uint256).max
        );
        DecoderCustomTypes.PancakeSwapExactInputParams memory exactInputParams = DecoderCustomTypes
            .PancakeSwapExactInputParams(
            abi.encodePacked(getAddress(sourceChain, "WETH"), uint24(500), getAddress(sourceChain, "RETH")),
            address(boringVault),
            100e18,
            0
        );
        targetData[1] = abi.encodeWithSignature("exactInput((bytes,address,uint256,uint256))", exactInputParams);
        targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)",
            getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager"),
            type(uint256).max
        );
        targetData[3] = abi.encodeWithSignature(
            "approve(address,uint256)",
            getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager"),
            type(uint256).max
        );

        DecoderCustomTypes.MintParams memory mintParams = DecoderCustomTypes.MintParams(
            getAddress(sourceChain, "RETH"),
            getAddress(sourceChain, "WETH"),
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
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 200e18);

        // Make sure the vault can
        // swap wETH -> rETH
        // create a new position rETH/weETH
        // add to an existing position rETH/weETH
        // pull from an existing position rETH/weETH
        // collect from a position rETH/weETH
        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        address[] memory tokens0 = new address[](1);
        tokens0[0] = getAddress(sourceChain, "WETH");
        address[] memory tokens1 = new address[](1);
        tokens1[0] = getAddress(sourceChain, "RETH");
        _addPancakeSwapV3Leafs(leafs, tokens0, tokens1);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        // _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](14);
        manageLeafs[0] = leafs[5];
        manageLeafs[1] = leafs[10];
        manageLeafs[2] = leafs[0];
        manageLeafs[3] = leafs[1];
        manageLeafs[4] = leafs[2];
        manageLeafs[5] = leafs[3];
        manageLeafs[6] = leafs[6];
        manageLeafs[7] = leafs[16];
        manageLeafs[8] = leafs[8];
        manageLeafs[9] = leafs[17];
        manageLeafs[10] = leafs[12];
        manageLeafs[11] = leafs[14];
        manageLeafs[12] = leafs[18];
        manageLeafs[13] = leafs[15];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](14);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "pancakeSwapV3Router");
        targets[2] = getAddress(sourceChain, "RETH");
        targets[3] = getAddress(sourceChain, "WETH");
        targets[4] = getAddress(sourceChain, "RETH");
        targets[5] = getAddress(sourceChain, "WETH");
        targets[6] = getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager");
        targets[7] = getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager");
        targets[8] = getAddress(sourceChain, "pancakeSwapV3MasterChefV3");
        targets[9] = getAddress(sourceChain, "pancakeSwapV3MasterChefV3");
        targets[10] = getAddress(sourceChain, "pancakeSwapV3MasterChefV3");
        targets[11] = getAddress(sourceChain, "pancakeSwapV3MasterChefV3");
        targets[12] = getAddress(sourceChain, "pancakeSwapV3MasterChefV3");
        targets[13] = getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager");

        bytes[] memory targetData = new bytes[](14);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "pancakeSwapV3Router"), type(uint256).max
        );
        DecoderCustomTypes.PancakeSwapExactInputParams memory exactInputParams = DecoderCustomTypes
            .PancakeSwapExactInputParams(
            abi.encodePacked(getAddress(sourceChain, "WETH"), uint24(500), getAddress(sourceChain, "RETH")),
            address(boringVault),
            100e18,
            0
        );
        targetData[1] = abi.encodeWithSignature("exactInput((bytes,address,uint256,uint256))", exactInputParams);
        targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)",
            getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager"),
            type(uint256).max
        );
        targetData[3] = abi.encodeWithSignature(
            "approve(address,uint256)",
            getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager"),
            type(uint256).max
        );
        targetData[4] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "pancakeSwapV3MasterChefV3"), type(uint256).max
        );
        targetData[5] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "pancakeSwapV3MasterChefV3"), type(uint256).max
        );

        DecoderCustomTypes.MintParams memory mintParams = DecoderCustomTypes.MintParams(
            getAddress(sourceChain, "RETH"),
            getAddress(sourceChain, "WETH"),
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
            getAddress(sourceChain, "pancakeSwapV3MasterChefV3"),
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

    function testPancakeSwapV3IntegrationReverts() external {
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 200e18);
        // Make sure the vault can
        // swap wETH -> rETH
        // create a new position rETH/weETH
        // add to an existing position rETH/weETH
        // pull from an existing position rETH/weETH
        // collect from a position rETH/weETH
        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        address[] memory tokens0 = new address[](1);
        tokens0[0] = getAddress(sourceChain, "WETH");
        address[] memory tokens1 = new address[](1);
        tokens1[0] = getAddress(sourceChain, "RETH");
        _addPancakeSwapV3Leafs(leafs, tokens0, tokens1);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](8);
        manageLeafs[0] = leafs[5];
        manageLeafs[1] = leafs[10];
        manageLeafs[2] = leafs[0];
        manageLeafs[3] = leafs[1];
        manageLeafs[4] = leafs[6];
        manageLeafs[5] = leafs[7];
        manageLeafs[6] = leafs[11];
        manageLeafs[7] = leafs[13];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](8);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "pancakeSwapV3Router");
        targets[2] = getAddress(sourceChain, "RETH");
        targets[3] = getAddress(sourceChain, "WETH");
        targets[4] = getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager");
        targets[5] = getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager");
        targets[6] = getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager");
        targets[7] = getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager");
        bytes[] memory targetData = new bytes[](8);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "pancakeSwapV3Router"), type(uint256).max
        );
        DecoderCustomTypes.PancakeSwapExactInputParams memory exactInputParams = DecoderCustomTypes
            .PancakeSwapExactInputParams(
            abi.encodePacked(getAddress(sourceChain, "WETH"), uint24(500), getAddress(sourceChain, "RETH")),
            address(boringVault),
            100e18,
            0
        );
        targetData[1] = abi.encodeWithSignature("exactInput((bytes,address,uint256,uint256))", exactInputParams);
        targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)",
            getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager"),
            type(uint256).max
        );
        targetData[3] = abi.encodeWithSignature(
            "approve(address,uint256)",
            getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager"),
            type(uint256).max
        );

        DecoderCustomTypes.MintParams memory mintParams = DecoderCustomTypes.MintParams(
            getAddress(sourceChain, "RETH"),
            getAddress(sourceChain, "WETH"),
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
            abi.encodePacked(getAddress(sourceChain, "WETH"), uint32(500), getAddress(sourceChain, "RETH")),
            address(boringVault),
            100e18,
            0
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
            abi.encodePacked(getAddress(sourceChain, "WETH"), uint24(500), getAddress(sourceChain, "RETH")),
            address(boringVault),
            100e18,
            0
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

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }

    function withdraw(uint256 amount) external {
        boringVault.enter(address(0), ERC20(address(0)), 0, address(this), amount);
    }
}
