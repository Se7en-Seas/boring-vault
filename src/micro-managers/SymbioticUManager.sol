// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {SSTORE2} from "lib/solmate/src/utils/SSTORE2.sol";
import {SymbioticDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SymbioticDecoderAndSanitizer.sol";

contract SymbioticUManager is Auth {
    using FixedPointMathLib for uint256;

    // ========================================= STRUCTS =========================================

    struct Configuration {
        uint96 minimumDeposit;
        address decoderAndSanitizer;
    }
    // ========================================= CONSTANTS =========================================

    bytes4 internal constant APPROVE_SELECTOR = ERC20.approve.selector;
    bytes4 internal constant DEPOSIT_SELECTOR = SymbioticDecoderAndSanitizer.deposit.selector;

    // ========================================= STATE =========================================

    mapping(address => Configuration) public configurations; // Map symbiotic default collateral to configuration.

    address internal pointer;

    //============================== ERRORS ===============================

    error SymbioticUManager__LeafNotFound(bytes32 leaf);
    error SymbioticUManager__BadHash(bytes32 leafA, bytes32 leafB, bytes32 expectedLeafAB, bytes32 actualLeafAB);
    error SymbioticUManager__InvalidMerkleTree();

    //============================== EVENTS ===============================

    event MerkleLeafsUpdated(address pointer);

    //============================== IMMUTABLES ===============================

    /**
     * @notice The ManagerWithMerkleVerification this uManager works with.
     */
    ManagerWithMerkleVerification internal immutable manager;

    /**
     * @notice The BoringVault this uManager works with.
     */
    address internal immutable boringVault;

    constructor(address _owner, Authority _authoirty, address _manager, address _boringVault)
        Auth(_owner, Authority(_authoirty))
    {
        manager = ManagerWithMerkleVerification(_manager);
        boringVault = _boringVault;
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    function updateMerkleTree(bytes32[][] calldata _merkleTree, bool validateMerkleTree) external requiresAuth {
        if (validateMerkleTree) {
            // Check that the tree is valid.
            for (uint256 i; i < _merkleTree.length - 1; ++i) {
                uint256 levelLength = _merkleTree[i].length;
                if (levelLength % 2 != 0) revert SymbioticUManager__InvalidMerkleTree();
                uint256 nextLevelLength = _merkleTree[i + 1].length;
                if (levelLength / 2 != nextLevelLength) revert SymbioticUManager__InvalidMerkleTree();

                for (uint256 j; j < _merkleTree[i].length; j += 2) {
                    bytes32 leafA = _merkleTree[i][j];
                    bytes32 leafB = _merkleTree[i][j + 1];
                    bytes32 expectedLeafAB = _merkleTree[i + 1][j / 2];

                    bytes32 actualLeafAB = _hashPair(leafA, leafB);

                    if (actualLeafAB != expectedLeafAB) {
                        revert SymbioticUManager__BadHash(leafA, leafB, expectedLeafAB, actualLeafAB);
                    }
                }
            }
        }

        bytes memory data = abi.encode(_merkleTree);
        address _pointer = SSTORE2.write(data);
        pointer = _pointer;

        emit MerkleLeafsUpdated(_pointer);
    }

    // ========================================= SNIPER FUNCTIONS =========================================

    function assemble(address defaultCollateral, uint256 amount) external {
        // We need an aprpoval leaf, and a deposit leaf in order to assemble.
        // This should handle approvals, including zero it is the approval is not enough, granting it, then revoking it
        // Logic if approval is granted, then it revokes unused approval afterwords.
        // If approval is not granted, then it does not revoke the approval afterwards
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    function _generateProof(bytes32 leaf, bytes32[][] memory tree) internal pure returns (bytes32[] memory proof) {
        // The length of each proof is the height of the tree - 1.
        uint256 treeLength = tree.length;
        proof = new bytes32[](treeLength - 1);

        // Build the proof
        for (uint256 i; i < treeLength - 1; ++i) {
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

    function buildLeaf(address decoderAndSanitizer, address target, bytes4 selector, address addressArgument)
        internal
        pure
        returns (bytes32 leaf)
    {
        leaf = keccak256(abi.encodePacked(decoderAndSanitizer, target, false, selector, addressArgument));
    }

    function viewMerkleTree() public view returns (bytes32[][] memory merkleTree) {
        bytes memory data = SSTORE2.read(pointer);

        merkleTree = abi.decode(data, (bytes32[][]));
    }
}
