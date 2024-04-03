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
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {DexSwapperUManager} from "src/micro-managers/DexSwapperUManager.sol";
import {PriceRouter} from "src/interfaces/PriceRouter.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract DexSwapperUManagerTest is Test, MainnetAddresses {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;
    PriceRouter public priceRouter = PriceRouter(0xAB2d48358D41980eee1cb93764f45148F6818964);
    DexSwapperUManager public dexSwapperUManager;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19512443;
        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager = new ManagerWithMerkleVerification(address(this), address(boringVault), vault);

        rawDataDecoderAndSanitizer =
            address(new EtherFiLiquidDecoderAndSanitizer(address(boringVault), uniswapV3NonFungiblePositionManager));

        dexSwapperUManager = new DexSwapperUManager(
            address(this), address(manager), address(boringVault), uniV3Router, vault, address(priceRouter)
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
        rolesAuthority.setUserRole(address(dexSwapperUManager), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        rolesAuthority.setUserRole(vault, BALANCER_VAULT_ROLE, true);

        dexSwapperUManager.setSwapPeriod(300);
        dexSwapperUManager.setAllowedSwapsPerPeriod(10);
    }

    function testSwapWithUniswapV3() external {
        deal(address(WEETH), address(boringVault), 10_000e18);
        // Make sure the vault can
        // swap weETH -> wETH
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        leafs[0] = ManageLeaf(address(WEETH), false, "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = uniV3Router;
        leafs[1] =
            ManageLeaf(uniV3Router, false, "exactInput((bytes,address,uint256,uint256,uint256))", new address[](3));
        leafs[1].argumentAddresses[0] = address(WEETH);
        leafs[1].argumentAddresses[1] = address(WETH);
        leafs[1].argumentAddresses[2] = address(boringVault);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(dexSwapperUManager), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        ERC20[] memory path = new ERC20[](2);
        path[0] = WEETH;
        path[1] = WETH;
        uint24[] memory fees = new uint24[](1);
        fees[0] = 500;

        // This swap is acceptable.
        dexSwapperUManager.swapWithUniswapV3(manageProofs, decodersAndSanitizers, path, fees, 10e18, 0, block.timestamp);

        uint256 swapCount = dexSwapperUManager.swapCountPerPeriod(block.timestamp % 300);
        assertEq(swapCount, 1, "Swap count should have been incremented.");

        // But if strategist tries to perform a high slippage swap it reverts.
        vm.expectRevert(abi.encodeWithSelector(DexSwapperUManager.DexSwapperUManager__Slippage.selector));
        dexSwapperUManager.swapWithUniswapV3(
            manageProofs, decodersAndSanitizers, path, fees, 9_990e18, 0, block.timestamp
        );

        // uManager should also be able to revoke approvals to router.
        manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];
        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        path = new ERC20[](1);
        path[0] = WEETH;
        address[] memory spenders = new address[](1);
        spenders[0] = uniV3Router;

        dexSwapperUManager.revokeTokenApproval(manageProofs, decodersAndSanitizers, path, spenders);
    }

    function testSwapWithBalancerV2() external {
        dexSwapperUManager.setAllowedSlippage(0.01e4);

        deal(address(WETH), address(boringVault), 100_000e18);
        bytes32 poolId = 0x1e19cf2d73a72ef1332c882f20534b6519be0276000200000000000000000112;

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
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

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(dexSwapperUManager), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        DecoderCustomTypes.SingleSwap memory singleSwap = DecoderCustomTypes.SingleSwap({
            poolId: poolId,
            kind: DecoderCustomTypes.SwapKind.GIVEN_IN,
            assetIn: address(WETH),
            assetOut: address(RETH),
            amount: 1e18,
            userData: hex""
        });
        DecoderCustomTypes.FundManagement memory funds = DecoderCustomTypes.FundManagement({
            sender: address(boringVault),
            fromInternalBalance: false,
            recipient: address(boringVault),
            toInternalBalance: false
        });

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        dexSwapperUManager.swapWithBalancerV2(
            manageProofs, decodersAndSanitizers, singleSwap, funds, 0, block.timestamp
        );

        singleSwap.amount = 99_000e18;
        // But if strategist tries to perform a high slippage swap it reverts.
        vm.expectRevert(abi.encodeWithSelector(DexSwapperUManager.DexSwapperUManager__Slippage.selector));
        dexSwapperUManager.swapWithBalancerV2(
            manageProofs, decodersAndSanitizers, singleSwap, funds, 0, block.timestamp
        );
    }

    function testSwapWithCurve() external {
        dexSwapperUManager.setAllowedSlippage(0.01e4);
        deal(address(WETH), address(boringVault), 100_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        leafs[0] = ManageLeaf(address(WETH), false, "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = weETH_wETH_Curve_LP;
        leafs[1] = ManageLeaf(weETH_wETH_Curve_LP, false, "exchange(int128,int128,uint256,uint256)", new address[](0));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(dexSwapperUManager), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        DexSwapperUManager.CurveInfo memory info = DexSwapperUManager.CurveInfo(
            weETH_wETH_Curve_LP, WETH, WEETH, bytes4(abi.encodeWithSignature("exchange(int128,int128,uint256,uint256)"))
        );
        dexSwapperUManager.swapWithCurve(manageProofs, decodersAndSanitizers, info, 1, 0, 50e18, 0);

        // But if strategist tries to perform a high slippage swap it reverts.
        vm.expectRevert(abi.encodeWithSelector(DexSwapperUManager.DexSwapperUManager__Slippage.selector));
        dexSwapperUManager.swapWithCurve(manageProofs, decodersAndSanitizers, info, 1, 0, 99_000e18, 0);
    }

    function testSetAllowedSlippage() external {
        // Call should work.
        dexSwapperUManager.setAllowedSlippage(0.05e4);

        // Call should revert.
        vm.expectRevert(abi.encodeWithSelector(DexSwapperUManager.DexSwapperUManager__NewSlippageTooLarge.selector));
        dexSwapperUManager.setAllowedSlippage(0.1001e4);
    }

    function testSetSwapPeriod() external {
        dexSwapperUManager.setSwapPeriod(900);

        assertEq(dexSwapperUManager.swapPeriod(), 900, "Swap period should have been updated.");
    }

    function testSetAllowedSwapsPerPeriod() external {
        dexSwapperUManager.setAllowedSwapsPerPeriod(20);

        assertEq(dexSwapperUManager.allowedSwapsPerPeriod(), 20, "Allowed swaps per period should have been updated.");
    }

    function testRateLimitRevert() external {
        // Set allowed swaps per period to zero.
        dexSwapperUManager.setAllowedSwapsPerPeriod(0);

        deal(address(WEETH), address(boringVault), 10_000e18);
        // Make sure the vault can
        // swap weETH -> wETH
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        leafs[0] = ManageLeaf(address(WEETH), false, "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = uniV3Router;
        leafs[1] =
            ManageLeaf(uniV3Router, false, "exactInput((bytes,address,uint256,uint256,uint256))", new address[](3));
        leafs[1].argumentAddresses[0] = address(WEETH);
        leafs[1].argumentAddresses[1] = address(WETH);
        leafs[1].argumentAddresses[2] = address(boringVault);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(dexSwapperUManager), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        ERC20[] memory path = new ERC20[](2);
        path[0] = WEETH;
        path[1] = WETH;
        uint24[] memory fees = new uint24[](1);
        fees[0] = 500;

        // Rate limit set to zero, so call reverts.
        vm.expectRevert(abi.encodeWithSelector(DexSwapperUManager.DexSwapperUManager__SwapCountExceeded.selector));
        dexSwapperUManager.swapWithUniswapV3(manageProofs, decodersAndSanitizers, path, fees, 10e18, 0, block.timestamp);
    }

    // ========================================= HELPER FUNCTIONS =========================================

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
}
