// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RawDataDecoderAndSanitizer} from "src/base/RawDataDecoderAndSanitizer.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract ArbitrumMerkleMakerTest is Test, MainnetAddresses {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    BoringVault public boring_vault;
    address public addressDecoder;

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "ARBITRUM_RPC_URL";
        uint256 blockNumber = 187539749;
        _startFork(rpcKey, blockNumber);
    }

    function testHunch() external view {
        address[] memory allowed_address_arguments = new address[](2);
        allowed_address_arguments[0] = 0x552acA1343A6383aF32ce1B7c7B1b47959F7ad90;
        allowed_address_arguments[1] = 0xeeF7b7205CAF2Bcd71437D9acDE3874C3388c138;

        address[] memory allowed_targets = new address[](2);
        allowed_targets[0] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; //USDC
        allowed_targets[1] = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9; // USDT
        bytes4[] memory allowed_selectors = new bytes4[](2);
        allowed_selectors[0] = ERC20.approve.selector;
        allowed_selectors[1] = ERC20.approve.selector;

        (bytes32[][] memory allowed_targets_and_selectors_tree, bytes32[][] memory allowed_address_argument_tree) =
            _generateMerkleTrees(allowed_targets, allowed_selectors, allowed_address_arguments);

        console.logBytes32(allowed_targets_and_selectors_tree[1][0]);
        console.logBytes32(allowed_address_argument_tree[1][0]);
    }

    // ========================================= HELPER FUNCTIONS =========================================
    bool i_did_something = false;

    function doSomethingWithFlashLoan(ERC20 token, uint256 amount) external {
        token.safeTransferFrom(msg.sender, address(this), amount);
        token.safeTransfer(msg.sender, amount);
        i_did_something = true;
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

    function _getProofsUsingTrees(
        address[] memory targets,
        bytes[] memory target_data,
        address[][] memory address_arguments,
        bytes32[][] memory target_tree,
        bytes32[][] memory argument_tree
    ) internal pure returns (bytes32[][] memory target_proofs, bytes32[][][] memory argument_proofs) {
        target_proofs = new bytes32[][](targets.length);
        argument_proofs = new bytes32[][][](targets.length);
        for (uint256 i; i < targets.length; ++i) {
            // First generate target proof.
            bytes32 target_leaf = keccak256(abi.encodePacked(targets[i], bytes4(target_data[i])));
            target_proofs[i] = _generateProof(target_leaf, target_tree);
            // Iterate through address arguments for target and generate argument proofs.
            argument_proofs[i] = new bytes32[][](address_arguments[i].length);
            for (uint256 j; j < address_arguments[i].length; ++j) {
                bytes32 argument_leaf = keccak256(abi.encodePacked(address_arguments[i][j]));
                argument_proofs[i][j] = _generateProof(argument_leaf, argument_tree);
            }
        }
    }

    function _buildTrees(bytes32[][] memory merkle_tree_in)
        internal
        pure
        returns (bytes32[][] memory merkle_tree_out)
    {
        // We are adding another row to the merkle tree, so make merkle_tree_out be 1 longer.
        uint256 merkle_tree_in_length = merkle_tree_in.length;
        merkle_tree_out = new bytes32[][](merkle_tree_in_length + 1);
        uint256 layer_length;
        // Iterate through merkle_tree_in to copy over data.
        for (uint256 i; i < merkle_tree_in_length; ++i) {
            layer_length = merkle_tree_in[i].length;
            merkle_tree_out[i] = new bytes32[](layer_length);
            for (uint256 j; j < layer_length; ++j) {
                merkle_tree_out[i][j] = merkle_tree_in[i][j];
            }
        }

        uint256 next_layer_length;
        if (layer_length % 2 != 0) {
            next_layer_length = (layer_length + 1) / 2;
        } else {
            next_layer_length = layer_length / 2;
        }
        merkle_tree_out[merkle_tree_in_length] = new bytes32[](next_layer_length);
        uint256 count;
        for (uint256 i; i < layer_length; i += 2) {
            merkle_tree_out[merkle_tree_in_length][count] = _hashPair(
                merkle_tree_in[merkle_tree_in_length - 1][i], merkle_tree_in[merkle_tree_in_length - 1][i + 1]
            );
            count++;
        }

        if (next_layer_length > 1) {
            // We need to process the next layer of leaves.
            merkle_tree_out = _buildTrees(merkle_tree_out);
        }
    }

    function _generateMerkleTrees(
        address[] memory targets,
        bytes4[] memory selectors,
        address[] memory address_arguments
    ) internal pure returns (bytes32[][] memory target_selector_tree, bytes32[][] memory address_arguments_tree) {
        // Handle target selector first
        {
            uint256 targets_length = targets.length;
            bytes32[][] memory leafs = new bytes32[][](1);
            leafs[0] = new bytes32[](targets_length);
            for (uint256 i; i < targets_length; ++i) {
                leafs[0][i] = keccak256(abi.encodePacked(targets[i], selectors[i]));
            }
            target_selector_tree = _buildTrees(leafs);
        }

        // Handle address arguments
        {
            uint256 arguments_length = address_arguments.length;
            bytes32[][] memory leafs = new bytes32[][](1);
            leafs[0] = new bytes32[](arguments_length);
            for (uint256 i; i < arguments_length; ++i) {
                leafs[0][i] = keccak256(abi.encodePacked(address_arguments[i]));
            }
            address_arguments_tree = _buildTrees(leafs);
        }
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
