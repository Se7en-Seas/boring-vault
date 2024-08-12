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
    AerodromeDecoderAndSanitizer,
    VelodromeDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/AerodromeDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract AerodromeIntegrationTest is Test, MerkleTreeHelper {
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
        setSourceChainName("base");
        // Setup forked environment.
        string memory rpcKey = "BASE_RPC_URL";
        uint256 blockNumber = 17446047;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(
            new AerodromeDecoderAndSanitizer(
                address(boringVault), getAddress(sourceChain, "aerodromeNonFungiblePositionManager")
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

        // Allow the boring vault to receive ETH.
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);
    }

    function testAerodromeV2() external {
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "WSTETH"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "WETH");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "WSTETH");
        address[] memory gauges = new address[](1);
        gauges[0] = getAddress(sourceChain, "aerodrome_Weth_Wsteth_v2_30_gauge");
        _addVelodromeV2Leafs(leafs, token0, token1, getAddress(sourceChain, "aerodromeRouter"), gauges);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        address stakingToken = VelodromV2Gauge(gauges[0]).stakingToken();

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](5);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];
        manageLeafs[3] = leafs[4];
        manageLeafs[4] = leafs[6];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](5);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "WSTETH");
        targets[2] = getAddress(sourceChain, "aerodromeRouter");
        targets[3] = stakingToken;
        targets[4] = gauges[0];

        bytes[] memory targetData = new bytes[](5);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "aerodromeRouter"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "aerodromeRouter"), type(uint256).max
        );
        targetData[2] = abi.encodeWithSignature(
            "addLiquidity(address,address,bool,uint256,uint256,uint256,uint256,address,uint256)",
            getAddress(sourceChain, "WETH"),
            getAddress(sourceChain, "WSTETH"),
            false,
            1_000e18,
            1_000e18,
            0,
            0,
            address(boringVault),
            block.timestamp + 1
        );
        targetData[3] = abi.encodeWithSignature("approve(address,uint256)", gauges[0], type(uint256).max);
        uint256 lpTokens = 923627556299184964559;
        targetData[4] = abi.encodeWithSignature("deposit(uint256)", lpTokens);
        uint256[] memory values = new uint256[](5);
        address[] memory decodersAndSanitizers = new address[](5);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Allow rewards to accumulate.
        skip(7 days);

        manageLeafs = new ManageLeaf[](4);
        manageLeafs[0] = leafs[8];
        manageLeafs[1] = leafs[7];
        manageLeafs[2] = leafs[5];
        manageLeafs[3] = leafs[3];

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](4);
        targets[0] = gauges[0];
        targets[1] = gauges[0];
        targets[2] = stakingToken;
        targets[3] = getAddress(sourceChain, "aerodromeRouter");

        targetData = new bytes[](4);
        targetData[0] = abi.encodeWithSignature("getReward(address)", boringVault);
        targetData[1] = abi.encodeWithSignature("withdraw(uint256)", lpTokens);
        targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "aerodromeRouter"), type(uint256).max
        );
        targetData[3] = abi.encodeWithSignature(
            "removeLiquidity(address,address,bool,uint256,uint256,uint256,address,uint256)",
            getAddress(sourceChain, "WETH"),
            getAddress(sourceChain, "WSTETH"),
            false,
            lpTokens,
            0,
            0,
            address(boringVault),
            block.timestamp + 1
        );
        values = new uint256[](4);
        decodersAndSanitizers = new address[](4);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertGt(
            getERC20(sourceChain, "AERO").balanceOf(address(boringVault)), 0, "Boring Vault should have AERO tokens"
        );
    }

    function testAerodromeV3() external {
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "WSTETH"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "WETH");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "WSTETH");
        address[] memory gauges = new address[](1);
        gauges[0] = getAddress(sourceChain, "aerodrome_Weth_Wsteth_v3_1_gauge");
        _addVelodromeV3Leafs(
            leafs, token0, token1, getAddress(sourceChain, "aerodromeNonFungiblePositionManager"), gauges
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](6);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];
        manageLeafs[3] = leafs[3];
        manageLeafs[4] = leafs[4];
        manageLeafs[5] = leafs[8];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](6);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "WSTETH");
        targets[2] = getAddress(sourceChain, "aerodromeNonFungiblePositionManager");
        targets[3] = getAddress(sourceChain, "aerodromeNonFungiblePositionManager");
        targets[4] = getAddress(sourceChain, "aerodromeNonFungiblePositionManager");
        targets[5] = gauges[0];
        bytes[] memory targetData = new bytes[](6);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)",
            getAddress(sourceChain, "aerodromeNonFungiblePositionManager"),
            type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)",
            getAddress(sourceChain, "aerodromeNonFungiblePositionManager"),
            type(uint256).max
        );

        DecoderCustomTypes.VelodromeMintParams memory mintParams = DecoderCustomTypes.VelodromeMintParams(
            getAddress(sourceChain, "WETH"),
            getAddress(sourceChain, "WSTETH"),
            int24(1),
            int24(-1590), // lower tick
            int24(-1588), // upper tick
            500e18,
            500e18,
            0,
            0,
            address(boringVault),
            block.timestamp,
            0
        );
        targetData[2] = abi.encodeWithSignature(
            "mint((address,address,int24,int24,int24,uint256,uint256,uint256,uint256,address,uint256,uint160))",
            mintParams
        );
        uint256 expectedTokenId = 249881;
        DecoderCustomTypes.IncreaseLiquidityParams memory increaseLiquidityParams =
            DecoderCustomTypes.IncreaseLiquidityParams(expectedTokenId, 500e18, 500e18, 0, 0, block.timestamp);
        targetData[3] = abi.encodeWithSignature(
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))", increaseLiquidityParams
        );
        targetData[4] = abi.encodeWithSignature("approve(address,uint256)", gauges[0], expectedTokenId);
        targetData[5] = abi.encodeWithSignature("deposit(uint256)", expectedTokenId);

        address[] memory decodersAndSanitizers = new address[](6);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](6)
        );

        // Let rewards accrue.
        skip(7 days);

        manageLeafs = new ManageLeaf[](5);
        manageLeafs[0] = leafs[10];
        manageLeafs[1] = leafs[9];
        manageLeafs[2] = leafs[5];
        manageLeafs[3] = leafs[6];
        manageLeafs[4] = leafs[7];
        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](5);
        targets[0] = gauges[0];
        targets[1] = gauges[0];
        targets[2] = getAddress(sourceChain, "aerodromeNonFungiblePositionManager");
        targets[3] = getAddress(sourceChain, "aerodromeNonFungiblePositionManager");
        targets[4] = getAddress(sourceChain, "aerodromeNonFungiblePositionManager");

        targetData = new bytes[](5);
        targetData[0] = abi.encodeWithSignature("getReward(uint256)", expectedTokenId);
        targetData[1] = abi.encodeWithSignature("withdraw(uint256)", expectedTokenId);
        uint128 expectedLiquidity = 13997094079385443670261480;
        DecoderCustomTypes.DecreaseLiquidityParams memory decreaseLiquidityParams =
            DecoderCustomTypes.DecreaseLiquidityParams(expectedTokenId, expectedLiquidity, 0, 0, block.timestamp);
        targetData[2] = abi.encodeWithSignature(
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))", decreaseLiquidityParams
        );

        DecoderCustomTypes.CollectParams memory collectParams = DecoderCustomTypes.CollectParams(
            expectedTokenId, address(boringVault), type(uint128).max, type(uint128).max
        );
        targetData[3] = abi.encodeWithSignature("collect((uint256,address,uint128,uint128))", collectParams);
        targetData[4] = abi.encodeWithSignature("burn(uint256)", expectedTokenId);

        decodersAndSanitizers = new address[](5);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](5)
        );

        assertGt(
            getERC20(sourceChain, "AERO").balanceOf(address(boringVault)), 0, "Boring Vault should have AERO tokens"
        );
    }

    function testAerodromeV3Reverts() external {
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "WSTETH"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "WETH");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "WSTETH");
        address[] memory gauges = new address[](1);
        gauges[0] = getAddress(sourceChain, "aerodrome_Weth_Wsteth_v3_1_gauge");
        _addVelodromeV3Leafs(
            leafs, token0, token1, getAddress(sourceChain, "aerodromeNonFungiblePositionManager"), gauges
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](6);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];
        manageLeafs[3] = leafs[3];
        manageLeafs[4] = leafs[4];
        manageLeafs[5] = leafs[8];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](6);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "WSTETH");
        targets[2] = getAddress(sourceChain, "aerodromeNonFungiblePositionManager");
        targets[3] = getAddress(sourceChain, "aerodromeNonFungiblePositionManager");
        targets[4] = getAddress(sourceChain, "aerodromeNonFungiblePositionManager");
        targets[5] = gauges[0];
        bytes[] memory targetData = new bytes[](6);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)",
            getAddress(sourceChain, "aerodromeNonFungiblePositionManager"),
            type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)",
            getAddress(sourceChain, "aerodromeNonFungiblePositionManager"),
            type(uint256).max
        );

        DecoderCustomTypes.VelodromeMintParams memory mintParams = DecoderCustomTypes.VelodromeMintParams(
            getAddress(sourceChain, "WETH"),
            getAddress(sourceChain, "WSTETH"),
            int24(1),
            int24(-1590), // lower tick
            int24(-1588), // upper tick
            500e18,
            500e18,
            0,
            0,
            address(boringVault),
            block.timestamp,
            0
        );
        targetData[2] = abi.encodeWithSignature(
            "mint((address,address,int24,int24,int24,uint256,uint256,uint256,uint256,address,uint256,uint160))",
            mintParams
        );
        uint256 expectedTokenId = 249881;
        uint256 badTokenId = 249782;
        DecoderCustomTypes.IncreaseLiquidityParams memory increaseLiquidityParams =
            DecoderCustomTypes.IncreaseLiquidityParams(badTokenId, 500e18, 500e18, 0, 0, block.timestamp);
        targetData[3] = abi.encodeWithSignature(
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))", increaseLiquidityParams
        );
        targetData[4] = abi.encodeWithSignature("approve(address,uint256)", gauges[0], expectedTokenId);
        targetData[5] = abi.encodeWithSignature("deposit(uint256)", expectedTokenId);

        address[] memory decodersAndSanitizers = new address[](6);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(VelodromeDecoderAndSanitizer.VelodromeDecoderAndSanitizer__BadTokenId.selector)
            )
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](6)
        );

        increaseLiquidityParams.tokenId = expectedTokenId;
        targetData[3] = abi.encodeWithSignature(
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))", increaseLiquidityParams
        );
        mintParams = DecoderCustomTypes.VelodromeMintParams(
            getAddress(sourceChain, "WETH"),
            getAddress(sourceChain, "WSTETH"),
            int24(1),
            int24(-1590), // lower tick
            int24(-1588), // upper tick
            500e18,
            500e18,
            0,
            0,
            address(boringVault),
            block.timestamp,
            1
        );
        targetData[2] = abi.encodeWithSignature(
            "mint((address,address,int24,int24,int24,uint256,uint256,uint256,uint256,address,uint256,uint160))",
            mintParams
        );

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    VelodromeDecoderAndSanitizer.VelodromeDecoderAndSanitizer__PoolCreationNotAllowed.selector
                )
            )
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](6)
        );

        mintParams = DecoderCustomTypes.VelodromeMintParams(
            getAddress(sourceChain, "WETH"),
            getAddress(sourceChain, "WSTETH"),
            int24(1),
            int24(-1590), // lower tick
            int24(-1588), // upper tick
            500e18,
            500e18,
            0,
            0,
            address(boringVault),
            block.timestamp,
            0
        );
        targetData[2] = abi.encodeWithSignature(
            "mint((address,address,int24,int24,int24,uint256,uint256,uint256,uint256,address,uint256,uint160))",
            mintParams
        );

        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](6)
        );

        manageLeafs = new ManageLeaf[](5);
        manageLeafs[0] = leafs[10];
        manageLeafs[1] = leafs[9];
        manageLeafs[2] = leafs[5];
        manageLeafs[3] = leafs[6];
        manageLeafs[4] = leafs[7];
        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](5);
        targets[0] = gauges[0];
        targets[1] = gauges[0];
        targets[2] = getAddress(sourceChain, "aerodromeNonFungiblePositionManager");
        targets[3] = getAddress(sourceChain, "aerodromeNonFungiblePositionManager");
        targets[4] = getAddress(sourceChain, "aerodromeNonFungiblePositionManager");

        targetData = new bytes[](5);
        targetData[0] = abi.encodeWithSignature("getReward(uint256)", expectedTokenId);
        targetData[1] = abi.encodeWithSignature("withdraw(uint256)", expectedTokenId);
        uint128 expectedLiquidity = 13997094079385443670261480;
        DecoderCustomTypes.DecreaseLiquidityParams memory decreaseLiquidityParams =
            DecoderCustomTypes.DecreaseLiquidityParams(badTokenId, expectedLiquidity, 0, 0, block.timestamp);
        targetData[2] = abi.encodeWithSignature(
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))", decreaseLiquidityParams
        );

        DecoderCustomTypes.CollectParams memory collectParams = DecoderCustomTypes.CollectParams(
            expectedTokenId, address(boringVault), type(uint128).max, type(uint128).max
        );
        targetData[3] = abi.encodeWithSignature("collect((uint256,address,uint128,uint128))", collectParams);
        targetData[4] = abi.encodeWithSignature("burn(uint256)", expectedTokenId);

        decodersAndSanitizers = new address[](5);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(VelodromeDecoderAndSanitizer.VelodromeDecoderAndSanitizer__BadTokenId.selector)
            )
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](5)
        );

        decreaseLiquidityParams =
            DecoderCustomTypes.DecreaseLiquidityParams(expectedTokenId, expectedLiquidity, 0, 0, block.timestamp);
        targetData[2] = abi.encodeWithSignature(
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))", decreaseLiquidityParams
        );

        collectParams =
            DecoderCustomTypes.CollectParams(badTokenId, address(boringVault), type(uint128).max, type(uint128).max);
        targetData[3] = abi.encodeWithSignature("collect((uint256,address,uint128,uint128))", collectParams);

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(VelodromeDecoderAndSanitizer.VelodromeDecoderAndSanitizer__BadTokenId.selector)
            )
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](5)
        );

        collectParams = DecoderCustomTypes.CollectParams(
            expectedTokenId, address(boringVault), type(uint128).max, type(uint128).max
        );
        targetData[3] = abi.encodeWithSignature("collect((uint256,address,uint128,uint128))", collectParams);

        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](5)
        );
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

interface VelodromV2Gauge {
    function stakingToken() external view returns (address);
}
