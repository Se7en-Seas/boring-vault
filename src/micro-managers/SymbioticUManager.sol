// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {SSTORE2} from "lib/solmate/src/utils/SSTORE2.sol";
import {SymbioticDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SymbioticDecoderAndSanitizer.sol";
import {DefaultCollateral} from "src/interfaces/DefaultCollateral.sol";

contract SymbioticUManager is Auth {
    using FixedPointMathLib for uint256;

    // ========================================= STRUCTS =========================================

    /**
     * @notice Configuration for a symbiotic default collateral.
     * @param minimumDeposit The minimum amount of the DefaultCollateral.asset() that can be deposited.
     * @param decoderAndSanitizer The decoder and sanitizer to use to sanitize the call.
     */
    struct Configuration {
        uint96 minimumDeposit;
        address decoderAndSanitizer;
    }
    // ========================================= CONSTANTS =========================================

    /**
     * @notice The selector for the ERC20.approve function.
     */
    bytes4 internal constant APPROVE_SELECTOR = ERC20.approve.selector;

    /**
     * @notice The selector for the DefaultCollateral.deposit function.
     */
    bytes4 internal constant DEPOSIT_SELECTOR = DefaultCollateral.deposit.selector;

    // ========================================= STATE =========================================

    /**
     * @notice The configuration for each symbiotic default collateral.
     */
    mapping(address => Configuration) public configurations;

    /**
     * @notice The pointer to the merkle tree.
     */
    address internal pointer;

    //============================== ERRORS ===============================

    error SymbioticUManager__BadHash(bytes32 leafA, bytes32 leafB, bytes32 expectedLeafAB, bytes32 actualLeafAB);
    error SymbioticUManager__InvalidMerkleTree();
    error SymbioticUManager__DepositAmountExceedsLimit(uint256 amount, uint256 limitDelta);
    error SymbioticUManager__DepositAmountExceedsBalance(uint256 amount, uint256 balance);
    error SymbioticUManager__DepositAmountTooSmall(uint256 amount, uint256 minimumDeposit);
    error SymbioticUManager__DecoderAndSanitizerNotSet();
    error SymbioticUManager__MinimumDepositNotSet();

    //============================== EVENTS ===============================

    event MerkleLeafsUpdated(address pointer);
    event ConfigurationSet(address indexed defaultCollateral, uint96 minimumDeposit, address decoderAndSanitizer);
    event Assembled(address indexed defaultCollateral, uint256 amount);

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

    /**
     * @notice Update the merkle tree.
     * @param _merkleTree The new merkle tree.
     * @param validateMerkleTree If true, the merkle tree will be validated.
     * @dev Callable by STRATEGIST_MULTISIG_ROLE
     */
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

            // Check that the root of this tree matches the root in the manager contract.
            bytes32 proposedRoot = _merkleTree[_merkleTree.length - 1][0];
            bytes32 managerRoot = manager.manageRoot(address(this));
            if (proposedRoot != managerRoot) {
                revert SymbioticUManager__InvalidMerkleTree();
            }
        }

        bytes memory data = abi.encode(_merkleTree);
        address _pointer = SSTORE2.write(data);
        pointer = _pointer;

        emit MerkleLeafsUpdated(_pointer);
    }

    /**
     * @notice Set the configuration for a symbiotic default collateral.
     * @param defaultCollateral The default collateral to set the configuration for.
     * @param minimumDeposit The minimum amount of the DefaultCollateral.asset() that can be deposited.
     * @param decoderAndSanitizer The decoder and sanitizer to use to sanitize the call.
     * @dev Callable by STRATEGIST_MULTISIG_ROLE
     */
    function setConfiguration(DefaultCollateral defaultCollateral, uint96 minimumDeposit, address decoderAndSanitizer)
        external
        requiresAuth
    {
        if (decoderAndSanitizer == address(0)) {
            revert SymbioticUManager__DecoderAndSanitizerNotSet();
        }
        if (minimumDeposit == 0) {
            revert SymbioticUManager__MinimumDepositNotSet();
        }
        configurations[address(defaultCollateral)] = Configuration(minimumDeposit, decoderAndSanitizer);

        emit ConfigurationSet(address(defaultCollateral), minimumDeposit, decoderAndSanitizer);
    }

    // ========================================= SNIPER FUNCTIONS =========================================

    /**
     * @notice Assemble a specific amount of a default collateral.
     * @param defaultCollateral The default collateral to assemble.
     * @param amount The amount to assemble.
     * @dev Callable by SNIPER_ROLE
     * @dev Use type(uint256).max to deposit as much as possible.
     */
    function assemble(DefaultCollateral defaultCollateral, uint256 amount)
        external
        requiresAuth
        returns (uint256 assembled)
    {
        assembled = _assemble(defaultCollateral, amount);
    }

    /**
     * @notice Assemble as much as possible of a default collateral.
     * @param defaultCollateral The default collateral to assemble.
     * @dev Callable by SNIPER_ROLE
     */
    function fullAssemble(DefaultCollateral defaultCollateral) external requiresAuth returns (uint256 assembled) {
        assembled = _assemble(defaultCollateral, type(uint256).max);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    /**
     * @notice Helper function to handle approving and depositing into a default collateral.
     * @return the amount assembled.
     */
    function _assemble(DefaultCollateral defaultCollateral, uint256 amount) internal returns (uint256) {
        ERC20 asset = defaultCollateral.asset();
        uint256 allowance = asset.allowance(boringVault, address(defaultCollateral));

        address[] memory unoDecoderAndSanitizer = new address[](1);
        {
            Configuration memory configuration = configurations[address(defaultCollateral)];
            amount = _maxDeposit(defaultCollateral, asset, amount, configuration.minimumDeposit);
            unoDecoderAndSanitizer[0] = configuration.decoderAndSanitizer;
        }

        bytes32 leaf;
        bytes32[][] memory merkleTree = viewMerkleTree();
        bytes32[][] memory unoProof = new bytes32[][](1);
        if (unoDecoderAndSanitizer[0] == address(0)) {
            revert SymbioticUManager__DecoderAndSanitizerNotSet();
        }
        address[] memory unoTarget = new address[](1);
        bytes[] memory unoTargetData = new bytes[](1);
        uint256[] memory unoZero = new uint256[](1);

        if (allowance < amount) {
            unoTarget[0] = address(asset);
            leaf = _buildLeaf(unoDecoderAndSanitizer[0], unoTarget[0], APPROVE_SELECTOR, address(defaultCollateral));
            unoProof[0] = _generateProof(leaf, merkleTree);
            if (allowance > 0) {
                // Set approval to zero.
                unoTargetData[0] = abi.encodeWithSelector(APPROVE_SELECTOR, address(defaultCollateral), 0);
                manager.manageVaultWithMerkleVerification(
                    unoProof, unoDecoderAndSanitizer, unoTarget, unoTargetData, unoZero
                );
            }
            // Set approval to amount.
            unoTargetData[0] = abi.encodeWithSelector(APPROVE_SELECTOR, address(defaultCollateral), amount);
            manager.manageVaultWithMerkleVerification(
                unoProof, unoDecoderAndSanitizer, unoTarget, unoTargetData, unoZero
            );

            // We set the allowance to zero, to indicate that we should revokeApproval if non zero after deposit.
            allowance = 0;
        }

        // Deposit the amount.
        unoTarget[0] = address(defaultCollateral);
        leaf = _buildLeaf(unoDecoderAndSanitizer[0], unoTarget[0], DEPOSIT_SELECTOR, boringVault);
        unoProof[0] = _generateProof(leaf, merkleTree);
        unoTargetData[0] = abi.encodeWithSelector(DEPOSIT_SELECTOR, boringVault, amount);
        manager.manageVaultWithMerkleVerification(unoProof, unoDecoderAndSanitizer, unoTarget, unoTargetData, unoZero);

        if (allowance == 0 && asset.allowance(boringVault, address(defaultCollateral)) > 0) {
            // Zero out approval.
            unoTarget[0] = address(asset);
            leaf = _buildLeaf(unoDecoderAndSanitizer[0], unoTarget[0], APPROVE_SELECTOR, address(defaultCollateral));
            unoProof[0] = _generateProof(leaf, merkleTree);
            unoTargetData[0] = abi.encodeWithSelector(APPROVE_SELECTOR, address(defaultCollateral), 0);
            manager.manageVaultWithMerkleVerification(
                unoProof, unoDecoderAndSanitizer, unoTarget, unoTargetData, unoZero
            );
        }

        emit Assembled(address(defaultCollateral), amount);

        return amount;
    }

    /**
     * @notice Calculate the maximum amount that can be deposited into a default collateral.
     * @param defaultCollateral The default collateral to deposit into.
     * @param asset The asset to deposit.
     * @param amount The amount to deposit.
     * @param minimumDeposit The minimum amount that can be deposited.
     * @return max The maximum amount that can be deposited.
     */
    function _maxDeposit(DefaultCollateral defaultCollateral, ERC20 asset, uint256 amount, uint256 minimumDeposit)
        internal
        view
        returns (uint256 max)
    {
        uint256 limitDelta = defaultCollateral.limit() - defaultCollateral.totalSupply();
        uint256 assetBalance = asset.balanceOf(boringVault);

        if (amount != type(uint256).max) {
            // Bot wants to deposit a specific amount.
            // Revert early if the amount is too high.
            if (amount > limitDelta) {
                revert SymbioticUManager__DepositAmountExceedsLimit(amount, limitDelta);
            }
            if (amount > assetBalance) {
                revert SymbioticUManager__DepositAmountExceedsBalance(amount, assetBalance);
            }
            max = amount;
        } else {
            // Bot wants to deposit as much as possible.

            max = limitDelta < assetBalance ? limitDelta : assetBalance;
        }

        // Make sure we meet the minimum deposit requirement.
        if (max < minimumDeposit) {
            revert SymbioticUManager__DepositAmountTooSmall(max, minimumDeposit);
        }
    }

    /**
     * @notice Efficiently hash two bytes32 values.
     */
    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }

    /**
     * @notice Efficiently hash a pair of bytes32 values in numerical order.
     */
    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    /**
     * @notice Generate a proof for a leaf in a merkle tree.
     * @param leaf The leaf to generate a proof for.
     * @param tree The merkle tree to generate the proof from.
     * @return proof The proof for the leaf.
     */
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

    /**
     * @notice Build a leaf for the merkle tree.
     * @param decoderAndSanitizer The decoder and sanitizer to use to sanitize the call.
     * @param target The target to call.
     * @param selector The selector to call.
     * @param addressArgument The address argument of the call.
     * @return leaf The leaf for the merkle tree.
     */
    function _buildLeaf(address decoderAndSanitizer, address target, bytes4 selector, address addressArgument)
        internal
        pure
        returns (bytes32 leaf)
    {
        leaf = keccak256(abi.encodePacked(decoderAndSanitizer, target, false, selector, addressArgument));
    }

    /**
     * @notice View the merkle tree.
     * @return merkleTree The merkle tree.
     */
    function viewMerkleTree() public view returns (bytes32[][] memory merkleTree) {
        bytes memory data = SSTORE2.read(pointer);

        merkleTree = abi.decode(data, (bytes32[][]));
    }
}
