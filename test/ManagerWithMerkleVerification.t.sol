// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {AddressDecoder} from "src/base/AddressDecoder.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract ManagerWithMerkleVerificationTest is Test, MainnetAddresses {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    BoringVault public boring_vault;
    address public addressDecoder;

    bytes private swapCallData =
        hex"7a1eb1b9000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000e8d4a5100000000000000000000000000000000000000000000000001e28208ce24e074df00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000ae9f7bcc000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000002ba0b86991c6218b36c1d19d4a2e9eb0ce3606eb480001f4c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000003a3529440000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000042a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000064dac17f958d2ee523a2206206994597c13d831ec70001f4c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000000000000000000000869584cd00000000000000000000000010000000000000000000000000000000000000110000000000000000000000000000000000000000000000bd1225eed564187c41";

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 16571863;
        _startFork(rpcKey, blockNumber);

        boring_vault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(this), address(this), address(boring_vault), vault);

        addressDecoder = address(new AddressDecoder());

        boring_vault.grantRole(boring_vault.MANAGER_ROLE(), address(manager));

        manager.setAddressDecoder(address(addressDecoder));
    }

    function testManagerMerkleVerificationHappyPath() external {
        // Allow the manager to call the USDC approve function to a specific address,
        // and the USDT transfer function to a specific address.

        address[] memory allowed_address_arguments = new address[](2);
        allowed_address_arguments[0] = vm.addr(0xDEAD);
        allowed_address_arguments[1] = vm.addr(0xDEAD1);

        address[] memory allowed_targets = new address[](2);
        allowed_targets[0] = address(USDC);
        allowed_targets[1] = address(USDT);
        bytes4[] memory allowed_selectors = new bytes4[](2);
        allowed_selectors[0] = ERC20.approve.selector;
        allowed_selectors[1] = ERC20.transfer.selector;

        (bytes32[][] memory allowed_targets_and_selectors_tree, bytes32[][] memory allowed_address_argument_tree) =
            _generateMerkleTrees(allowed_targets, allowed_selectors, allowed_address_arguments);

        manager.setAllowedTargetSelectorRoot(allowed_targets_and_selectors_tree[1][0]);
        manager.setAllowedAddressArgumentRoot(allowed_address_argument_tree[1][0]);

        address[] memory targets = new address[](2);
        targets[0] = address(USDC);
        targets[1] = address(USDT);

        bytes[] memory target_data = new bytes[](2);
        target_data[0] = abi.encodeWithSelector(ERC20.approve.selector, allowed_address_arguments[0], 777);
        target_data[1] = abi.encodeWithSelector(ERC20.transfer.selector, allowed_address_arguments[1], 777);

        address[][] memory address_arguments = new address[][](2);
        address_arguments[0] = new address[](1);
        address_arguments[0][0] = allowed_address_arguments[0];
        address_arguments[1] = new address[](1);
        address_arguments[1][0] = allowed_address_arguments[1];

        (bytes32[][] memory target_proofs, bytes32[][][] memory arguments_proofs) = _getProofsUsingTrees(
            targets, target_data, address_arguments, allowed_targets_and_selectors_tree, allowed_address_argument_tree
        );

        string[] memory function_signatures = new string[](2);
        function_signatures[0] = "approve(address,uint256)";
        function_signatures[1] = "transfer(address,uint256)";

        uint256[] memory values = new uint256[](2);

        deal(address(USDT), address(boring_vault), 777);

        manager.manageVaultWithMerkleVerification(
            target_proofs, arguments_proofs, function_signatures, targets, target_data, values
        );

        assertEq(
            USDC.allowance(address(boring_vault), allowed_address_arguments[0]), 777, "USDC should have an allowance"
        );
        assertEq(USDT.balanceOf(allowed_address_arguments[1]), 777, "USDT should have been transfered");
    }

    function testFlashLoan() external {
        address[] memory allowed_address_arguments = new address[](4);
        allowed_address_arguments[0] = address(USDC);
        allowed_address_arguments[1] = address(this);
        allowed_address_arguments[2] = address(manager);
        allowed_address_arguments[3] = address(0);

        address[] memory allowed_targets = new address[](4);
        allowed_targets[0] = address(vault);
        allowed_targets[1] = address(this);
        allowed_targets[2] = address(USDC);
        allowed_targets[3] = address(0);
        bytes4[] memory allowed_selectors = new bytes4[](4);
        allowed_selectors[0] = BalancerVault.flashLoan.selector;
        allowed_selectors[1] = this.doSomethingWithFlashLoan.selector;
        allowed_selectors[2] = ERC20.approve.selector;
        allowed_selectors[3] = bytes4(0);

        (bytes32[][] memory allowed_targets_and_selectors_tree, bytes32[][] memory allowed_address_argument_tree) =
            _generateMerkleTrees(allowed_targets, allowed_selectors, allowed_address_arguments);

        manager.setAllowedTargetSelectorRoot(allowed_targets_and_selectors_tree[2][0]);
        manager.setAllowedAddressArgumentRoot(allowed_address_argument_tree[2][0]);

        bytes memory userData;
        {
            uint256 flash_loan_amount = 1_000_000e6;
            // Build flashLoan data.
            address[] memory targets = new address[](2);
            targets[0] = address(USDC);
            targets[1] = address(this);
            bytes[] memory target_data = new bytes[](2);
            target_data[0] = abi.encodeWithSelector(ERC20.approve.selector, address(this), flash_loan_amount);
            target_data[1] =
                abi.encodeWithSelector(this.doSomethingWithFlashLoan.selector, address(USDC), flash_loan_amount);
            address[][] memory address_arguments = new address[][](2);
            address_arguments[0] = new address[](1);
            address_arguments[0][0] = address(this);
            address_arguments[1] = new address[](1);
            address_arguments[1][0] = address(USDC);

            (bytes32[][] memory target_proofs, bytes32[][][] memory arguments_proofs) = _getProofsUsingTrees(
                targets,
                target_data,
                address_arguments,
                allowed_targets_and_selectors_tree,
                allowed_address_argument_tree
            );

            string[] memory function_signatures = new string[](2);
            function_signatures[0] = "approve(address,uint256)";
            function_signatures[1] = "doSomethingWithFlashLoan(address,uint256)";

            uint256[] memory values = new uint256[](2);

            userData = abi.encode(target_proofs, arguments_proofs, function_signatures, targets, target_data, values);
        }
        {
            address[] memory targets = new address[](1);
            targets[0] = address(vault);

            address[] memory tokens_to_borrow = new address[](1);
            tokens_to_borrow[0] = address(USDC);
            uint256[] memory amounts_to_borrow = new uint256[](1);
            amounts_to_borrow[0] = 1_000_000e6;
            bytes[] memory target_data = new bytes[](1);
            target_data[0] = abi.encodeWithSelector(
                BalancerVault.flashLoan.selector, address(manager), tokens_to_borrow, amounts_to_borrow, userData
            );

            address[][] memory address_arguments = new address[][](1);
            address_arguments[0] = new address[](2);
            address_arguments[0][0] = address(manager);
            address_arguments[0][1] = address(USDC);

            (bytes32[][] memory target_proofs, bytes32[][][] memory arguments_proofs) = _getProofsUsingTrees(
                targets,
                target_data,
                address_arguments,
                allowed_targets_and_selectors_tree,
                allowed_address_argument_tree
            );

            string[] memory function_signatures = new string[](1);
            function_signatures[0] = "flashLoan(address,address[],uint256[],bytes)";

            uint256[] memory values = new uint256[](1);

            manager.manageVaultWithMerkleVerification(
                target_proofs, arguments_proofs, function_signatures, targets, target_data, values
            );

            assertTrue(i_did_something == true, "Should have called doSomethingWithFlashLoan");
        }
    }

    function testReverts() external {
        bytes32[][] memory target_proofs;
        bytes32[][][] memory arguments_proofs;
        string[] memory function_signatures;
        address[] memory targets;
        targets = new address[](1);
        bytes[] memory target_data;
        uint256[] memory values;

        vm.expectRevert(bytes("Invalid target proof length"));
        manager.manageVaultWithMerkleVerification(
            target_proofs, arguments_proofs, function_signatures, targets, target_data, values
        );
        target_proofs = new bytes32[][](1);

        vm.expectRevert(bytes("Invalid argument proof length"));
        manager.manageVaultWithMerkleVerification(
            target_proofs, arguments_proofs, function_signatures, targets, target_data, values
        );
        arguments_proofs = new bytes32[][][](1);

        vm.expectRevert(bytes("Invalid function signatures length"));
        manager.manageVaultWithMerkleVerification(
            target_proofs, arguments_proofs, function_signatures, targets, target_data, values
        );
        function_signatures = new string[](1);

        vm.expectRevert(bytes("Invalid data length"));
        manager.manageVaultWithMerkleVerification(
            target_proofs, arguments_proofs, function_signatures, targets, target_data, values
        );
        target_data = new bytes[](1);

        vm.expectRevert(bytes("Invalid values length"));
        manager.manageVaultWithMerkleVerification(
            target_proofs, arguments_proofs, function_signatures, targets, target_data, values
        );
        values = new uint256[](1);

        targets[0] = address(USDC);
        target_data[0] = abi.encodeWithSelector(ERC20.approve.selector, address(this), 1_000);

        vm.expectRevert(bytes("Failed to verify target"));
        manager.manageVaultWithMerkleVerification(
            target_proofs, arguments_proofs, function_signatures, targets, target_data, values
        );

        // Set the target selector root to be the leaf of the USDC approve function
        bytes32 target_selector_root = keccak256(abi.encodePacked(targets[0], bytes4(target_data[0])));
        manager.setAllowedTargetSelectorRoot(target_selector_root);

        vm.expectRevert(bytes("Function Selector Mismatch"));
        manager.manageVaultWithMerkleVerification(
            target_proofs, arguments_proofs, function_signatures, targets, target_data, values
        );
        function_signatures[0] = "approve(address,uint256)";

        vm.expectRevert(bytes("Arguments proof length differs from found address length"));
        manager.manageVaultWithMerkleVerification(
            target_proofs, arguments_proofs, function_signatures, targets, target_data, values
        );

        arguments_proofs[0] = new bytes32[][](1);

        vm.expectRevert(bytes("Failed to verify address"));
        manager.manageVaultWithMerkleVerification(
            target_proofs, arguments_proofs, function_signatures, targets, target_data, values
        );

        bytes32 address_argument_root = keccak256(abi.encodePacked(address(this)));
        manager.setAllowedAddressArgumentRoot(address_argument_root);

        // Call now works.
        manager.manageVaultWithMerkleVerification(
            target_proofs, arguments_proofs, function_signatures, targets, target_data, values
        );

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
