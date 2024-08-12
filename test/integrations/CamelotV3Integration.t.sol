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
    CamelotFullDecoderAndSanitizer,
    CamelotDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/CamelotFullDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract CamelotV3IntegrationTest is Test, MerkleTreeHelper {
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
        setSourceChainName("arbitrum");
        // Setup forked environment.
        string memory rpcKey = "ARBITRUM_RPC_URL";
        uint256 blockNumber = 235601319;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(
            new CamelotFullDecoderAndSanitizer(
                address(boringVault), getAddress(sourceChain, "camelotNonFungiblePositionManager")
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

    function testCamelotV3Integration() external {
        deal(getAddress(sourceChain, "WSTETH"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "WEETH"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        address[] memory token0 = new address[](2);
        token0[0] = getAddress(sourceChain, "WETH");
        token0[1] = getAddress(sourceChain, "WETH");
        address[] memory token1 = new address[](2);
        token1[0] = getAddress(sourceChain, "WSTETH");
        token1[1] = getAddress(sourceChain, "WEETH");
        _addCamelotV3Leafs(leafs, token0, token1);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](9);
        manageLeafs[0] = leafs[2];
        manageLeafs[1] = leafs[6];
        manageLeafs[2] = leafs[1];
        manageLeafs[3] = leafs[8];
        manageLeafs[4] = leafs[10];
        manageLeafs[5] = leafs[11];
        manageLeafs[6] = leafs[14];
        manageLeafs[7] = leafs[15];
        manageLeafs[8] = leafs[16];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](9);
        targets[0] = getAddress(sourceChain, "WSTETH");
        targets[1] = getAddress(sourceChain, "camelotRouterV3");
        targets[2] = getAddress(sourceChain, "WETH");
        targets[3] = getAddress(sourceChain, "WEETH");
        targets[4] = getAddress(sourceChain, "camelotNonFungiblePositionManager");
        targets[5] = getAddress(sourceChain, "camelotNonFungiblePositionManager");
        targets[6] = getAddress(sourceChain, "camelotNonFungiblePositionManager");
        targets[7] = getAddress(sourceChain, "camelotNonFungiblePositionManager");
        targets[8] = getAddress(sourceChain, "camelotNonFungiblePositionManager");
        bytes[] memory targetData = new bytes[](9);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "camelotRouterV3"), type(uint256).max
        );
        DecoderCustomTypes.ExactInputParams memory exactInputParams = DecoderCustomTypes.ExactInputParams(
            abi.encodePacked(getAddress(sourceChain, "WSTETH"), getAddress(sourceChain, "WETH")),
            address(boringVault),
            block.timestamp,
            100e18,
            0
        );
        targetData[1] = abi.encodeWithSignature("exactInput((bytes,address,uint256,uint256,uint256))", exactInputParams);
        targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "camelotNonFungiblePositionManager"), type(uint256).max
        );
        targetData[3] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "camelotNonFungiblePositionManager"), type(uint256).max
        );

        DecoderCustomTypes.CamelotMintParams memory mintParams = DecoderCustomTypes.CamelotMintParams(
            getAddress(sourceChain, "WEETH"),
            getAddress(sourceChain, "WETH"),
            int24(400), // lower tick
            int24(450), // upper tick
            45e18,
            45e18,
            0,
            0,
            address(boringVault),
            block.timestamp
        );
        targetData[4] = abi.encodeWithSignature(
            "mint((address,address,int24,int24,uint256,uint256,uint256,uint256,address,uint256))", mintParams
        );
        uint256 expectedTokenId = 119901;
        DecoderCustomTypes.IncreaseLiquidityParams memory increaseLiquidityParams =
            DecoderCustomTypes.IncreaseLiquidityParams(expectedTokenId, 45e18, 45e18, 0, 0, block.timestamp);
        targetData[5] = abi.encodeWithSignature(
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))", increaseLiquidityParams
        );
        uint128 expectedLiquidity = 35024744166363799012869 + 35024744166363799012869;
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

    function testCamelotV3IntegrationReverts() external {
        deal(getAddress(sourceChain, "WSTETH"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "WEETH"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        address[] memory token0 = new address[](2);
        token0[0] = getAddress(sourceChain, "WETH");
        token0[1] = getAddress(sourceChain, "WETH");
        address[] memory token1 = new address[](2);
        token1[0] = getAddress(sourceChain, "WSTETH");
        token1[1] = getAddress(sourceChain, "WEETH");
        _addCamelotV3Leafs(leafs, token0, token1);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](9);
        manageLeafs[0] = leafs[2];
        manageLeafs[1] = leafs[6];
        manageLeafs[2] = leafs[1];
        manageLeafs[3] = leafs[8];
        manageLeafs[4] = leafs[10];
        manageLeafs[5] = leafs[11];
        manageLeafs[6] = leafs[14];
        manageLeafs[7] = leafs[15];
        manageLeafs[8] = leafs[16];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](9);
        targets[0] = getAddress(sourceChain, "WSTETH");
        targets[1] = getAddress(sourceChain, "camelotRouterV3");
        targets[2] = getAddress(sourceChain, "WETH");
        targets[3] = getAddress(sourceChain, "WEETH");
        targets[4] = getAddress(sourceChain, "camelotNonFungiblePositionManager");
        targets[5] = getAddress(sourceChain, "camelotNonFungiblePositionManager");
        targets[6] = getAddress(sourceChain, "camelotNonFungiblePositionManager");
        targets[7] = getAddress(sourceChain, "camelotNonFungiblePositionManager");
        targets[8] = getAddress(sourceChain, "camelotNonFungiblePositionManager");
        bytes[] memory targetData = new bytes[](9);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "camelotRouterV3"), type(uint256).max
        );
        DecoderCustomTypes.ExactInputParams memory exactInputParams = DecoderCustomTypes.ExactInputParams(
            abi.encodePacked(getAddress(sourceChain, "WSTETH"), getAddress(sourceChain, "WETH")),
            address(boringVault),
            block.timestamp,
            100e18,
            0
        );
        targetData[1] = abi.encodeWithSignature("exactInput((bytes,address,uint256,uint256,uint256))", exactInputParams);
        targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "camelotNonFungiblePositionManager"), type(uint256).max
        );
        targetData[3] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "camelotNonFungiblePositionManager"), type(uint256).max
        );

        DecoderCustomTypes.CamelotMintParams memory mintParams = DecoderCustomTypes.CamelotMintParams(
            getAddress(sourceChain, "WEETH"),
            getAddress(sourceChain, "WETH"),
            int24(400), // lower tick
            int24(450), // upper tick
            45e18,
            45e18,
            0,
            0,
            address(boringVault),
            block.timestamp
        );
        targetData[4] = abi.encodeWithSignature(
            "mint((address,address,int24,int24,uint256,uint256,uint256,uint256,address,uint256))", mintParams
        );
        uint256 expectedTokenId = 119901;
        DecoderCustomTypes.IncreaseLiquidityParams memory increaseLiquidityParams =
            DecoderCustomTypes.IncreaseLiquidityParams(expectedTokenId, 45e18, 45e18, 0, 0, block.timestamp);
        targetData[5] = abi.encodeWithSignature(
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))", increaseLiquidityParams
        );
        uint128 expectedLiquidity = 35024744166363799012869 + 35024744166363799012869;
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

        // Make swap path data malformed.
        exactInputParams = DecoderCustomTypes.ExactInputParams(
            abi.encodePacked(getAddress(sourceChain, "WSTETH"), uint24(100), getAddress(sourceChain, "WETH")),
            address(boringVault),
            block.timestamp,
            100e18,
            0
        );
        targetData[1] = abi.encodeWithSignature("exactInput((bytes,address,uint256,uint256,uint256))", exactInputParams);

        vm.expectRevert(
            abi.encodeWithSelector(CamelotDecoderAndSanitizer.CamelotDecoderAndSanitizer__BadPathFormat.selector)
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](9)
        );

        // Fix swap path data.
        exactInputParams = DecoderCustomTypes.ExactInputParams(
            abi.encodePacked(getAddress(sourceChain, "WSTETH"), getAddress(sourceChain, "WETH")),
            address(boringVault),
            block.timestamp,
            100e18,
            0
        );
        targetData[1] = abi.encodeWithSignature("exactInput((bytes,address,uint256,uint256,uint256))", exactInputParams);

        // Try adding liquidity to a token not owned by the boring vault.
        increaseLiquidityParams =
            DecoderCustomTypes.IncreaseLiquidityParams(expectedTokenId - 1, 45e18, 45e18, 0, 0, block.timestamp);
        targetData[5] = abi.encodeWithSignature(
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))", increaseLiquidityParams
        );

        vm.expectRevert(
            abi.encodeWithSelector(CamelotDecoderAndSanitizer.CamelotDecoderAndSanitizer__BadTokenId.selector)
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](9)
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
            abi.encodeWithSelector(CamelotDecoderAndSanitizer.CamelotDecoderAndSanitizer__BadTokenId.selector)
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](9)
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
            abi.encodeWithSelector(CamelotDecoderAndSanitizer.CamelotDecoderAndSanitizer__BadTokenId.selector)
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](9)
        );

        // Fix collect tokenId.
        collectParams = DecoderCustomTypes.CollectParams(
            expectedTokenId, address(boringVault), type(uint128).max, type(uint128).max
        );
        targetData[7] = abi.encodeWithSignature("collect((uint256,address,uint128,uint128))", collectParams);

        // Call now works.
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](9)
        );
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
