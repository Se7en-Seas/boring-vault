// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RawDataDecoderAndSanitizer, DecoderCustomTypes} from "src/base/RawDataDecoderAndSanitizer.sol";
import {EtherFiLiquidDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/EtherFiLiquidDecoderAndSanitizer.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {IUniswapV3Router} from "src/interfaces/IUniswapV3Router.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract ManagerWithMerkleVerificationTest is Test, MainnetAddresses {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19369928;
        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(this), address(this), address(boringVault), vault);

        rawDataDecoderAndSanitizer = address(new RawDataDecoderAndSanitizer(uniswapV3NonFungiblePositionManager));
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
        leafs[1] = ManageLeaf(address(USDT), "transfer(address,uint256)", new address[](1));
        leafs[1].argumentAddresses[0] = usdtTo;

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(manageTree[1][0]);

        address[] memory targets = new address[](2);
        targets[0] = address(USDC);
        targets[1] = address(USDT);

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, usdcSpender, 777);
        targetData[1] = abi.encodeWithSelector(ERC20.transfer.selector, usdtTo, 777);

        (bytes32[][] memory manageProofs) = _getProofsUsingTree(leafs, manageTree);

        string[] memory functionSignatures = new string[](2);
        functionSignatures[0] = "approve(address,uint256)";
        functionSignatures[1] = "transfer(address,uint256)";

        uint256[] memory values = new uint256[](2);

        deal(address(USDT), address(boringVault), 777);

        uint256 gas = gasleft();
        manager.manageVaultWithMerkleVerification(manageProofs, functionSignatures, targets, targetData, values);
        console.log("Gas used", gas - gasleft());

        assertEq(USDC.allowance(address(boringVault), usdcSpender), 777, "USDC should have an allowance");
        assertEq(USDT.balanceOf(usdtTo), 777, "USDT should have been transfered");
    }

    function testFlashLoan() external {
        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        leafs[0] = ManageLeaf(vault, "flashLoan(address,address[],uint256[],bytes)", new address[](2));
        leafs[0].argumentAddresses[0] = address(manager);
        leafs[0].argumentAddresses[1] = address(USDC);
        leafs[1] = ManageLeaf(address(this), "doSomethingWithFlashLoan(address,uint256)", new address[](1));
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
            targetData[1] =
                abi.encodeWithSelector(this.doSomethingWithFlashLoan.selector, address(USDC), flashLoanAmount);

            ManageLeaf[] memory flashLoanLeafs = new ManageLeaf[](2);
            flashLoanLeafs[0] = leafs[2];
            flashLoanLeafs[1] = leafs[1];

            bytes32[][] memory flashLoanManageProofs = _getProofsUsingTree(flashLoanLeafs, manageTree);

            string[] memory functionSignatures = new string[](2);
            functionSignatures[0] = "approve(address,uint256)";
            functionSignatures[1] = "doSomethingWithFlashLoan(address,uint256)";

            uint256[] memory values = new uint256[](2);

            userData = abi.encode(flashLoanManageProofs, functionSignatures, targets, targetData, values);
        }
        {
            address[] memory targets = new address[](1);
            targets[0] = address(vault);

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

            string[] memory functionSignatures = new string[](1);
            functionSignatures[0] = "flashLoan(address,address[],uint256[],bytes)";

            uint256[] memory values = new uint256[](1);

            manager.manageVaultWithMerkleVerification(manageProofs, functionSignatures, targets, targetData, values);

            assertTrue(iDidSomething == true, "Should have called doSomethingWithFlashLoan");
        }
    }

    function testBalancerV2Integration() external {
        deal(address(WETH), address(boringVault), 100e18);
        deal(address(WEETH), address(boringVault), 100e18);
        // Make sure the vault can
        // swap wETH -> rETH
        // create a new position rETH/weETH
        // add to an existing position rETH/weETH
        // pull from an existing position rETH/weETH
        // collect from a position rETH/weETH
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

        string[] memory functionSignatures = new string[](8);
        functionSignatures[0] = "approve(address,uint256)";
        functionSignatures[1] = "exactInput((bytes,address,uint256,uint256,uint256))";
        functionSignatures[2] = "approve(address,uint256)";
        functionSignatures[3] = "approve(address,uint256)";
        functionSignatures[4] =
            "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))";
        functionSignatures[5] = "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))";
        functionSignatures[6] = "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))";
        functionSignatures[7] = "collect((uint256,address,uint128,uint128))";

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
        manager.manageVaultWithMerkleVerification(
            manageProofs, functionSignatures, targets, targetData, new uint256[](8)
        );
        console.log("Gas used", gas - gasleft());
    }

    function testReverts() external {
        bytes32[][] memory manageProofs;
        string[] memory functionSignatures;
        address[] memory targets;
        targets = new address[](1);
        bytes[] memory targetData;
        uint256[] memory values;

        vm.expectRevert(bytes("Invalid target proof length"));
        manager.manageVaultWithMerkleVerification(manageProofs, functionSignatures, targets, targetData, values);
        manageProofs = new bytes32[][](1);

        vm.expectRevert(bytes("Invalid function signatures length"));
        manager.manageVaultWithMerkleVerification(manageProofs, functionSignatures, targets, targetData, values);
        functionSignatures = new string[](1);

        vm.expectRevert(bytes("Invalid data length"));
        manager.manageVaultWithMerkleVerification(manageProofs, functionSignatures, targets, targetData, values);
        targetData = new bytes[](1);

        vm.expectRevert(bytes("Invalid values length"));
        manager.manageVaultWithMerkleVerification(manageProofs, functionSignatures, targets, targetData, values);
        values = new uint256[](1);

        vm.expectRevert(bytes("Function Selector Mismatch"));
        manager.manageVaultWithMerkleVerification(manageProofs, functionSignatures, targets, targetData, values);
        functionSignatures[0] = "approve(address,uint256)";

        targets[0] = address(USDC);
        targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(this), 1_000);

        vm.expectRevert(bytes("Failed to verify manage call"));
        manager.manageVaultWithMerkleVerification(manageProofs, functionSignatures, targets, targetData, values);

        // Set the manage root to be the leaf of the USDC approve function
        bytes32 manageRoot = keccak256(abi.encodePacked(targets[0], bytes4(targetData[0]), address(this)));
        manager.setManageRoot(manageRoot);

        // Call now works.
        manager.manageVaultWithMerkleVerification(manageProofs, functionSignatures, targets, targetData, values);

        // Check `receiveFlashLoan`
        address[] memory tokens;
        uint256[] memory amounts;
        uint256[] memory feeAmounts;

        vm.expectRevert(bytes("wrong caller"));
        manager.receiveFlashLoan(tokens, amounts, feeAmounts, abi.encode(0));

        // Someone else initiated a flash loan
        vm.startPrank(vault);
        vm.expectRevert(bytes("not being managed"));
        manager.receiveFlashLoan(tokens, amounts, feeAmounts, abi.encode(0));
        vm.stopPrank();
    }

    // ========================================= HELPER FUNCTIONS =========================================
    bool iDidSomething = false;

    function doSomethingWithFlashLoan(ERC20 token, uint256 amount) external {
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
