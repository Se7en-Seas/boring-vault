// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract ManagerWithMerkleVerificationTest is Test, MainnetAddresses {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    BoringVault public boring_vault;

    bytes private swapCallData =
        hex"7a1eb1b9000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000e8d4a5100000000000000000000000000000000000000000000000001e28208ce24e074df00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000ae9f7bcc000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000002ba0b86991c6218b36c1d19d4a2e9eb0ce3606eb480001f4c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000003a3529440000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000042a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000064dac17f958d2ee523a2206206994597c13d831ec70001f4c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000000000000000000000869584cd00000000000000000000000010000000000000000000000000000000000000110000000000000000000000000000000000000000000000bd1225eed564187c41";

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 16571863;
        _startFork(rpcKey, blockNumber);

        boring_vault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager = new ManagerWithMerkleVerification(address(this), address(this), address(this), address(boring_vault));

        boring_vault.grantRole(boring_vault.MANAGER_ROLE(), address(manager));
    }

    function testManagerMerkleVerificationHappyPath() external {
        // Allow the manager to call the USDC approve function to a specific address,
        // and the USDT transfer function to a specific address.
        bytes32 leaf_a = keccak256(abi.encodePacked(USDC, ERC20.approve.selector));
        bytes32 leaf_b = keccak256(abi.encodePacked(USDT, ERC20.transfer.selector));
        bytes32 allowed_targets_and_selectors_root = _hashPair(leaf_a, leaf_b);

        address allowed_address_0 = vm.addr(0xDEAD);
        address allowed_address_1 = vm.addr(0xDEAD1);

        manager.setAllowedTargetsRoot(allowed_targets_and_selectors_root);

        bytes32[][] memory target_proofs = new bytes32[][](2);
        target_proofs[0] = new bytes32[](1);
        target_proofs[0][0] = leaf_b;
        target_proofs[1] = new bytes32[](1);
        target_proofs[1][0] = leaf_a;

        address[] memory targets = new address[](2);
        targets[0] = address(USDC);
        targets[1] = address(USDT);
        bytes[] memory target_data = new bytes[](2);
        target_data[0] = abi.encodeWithSelector(ERC20.approve.selector, allowed_address_0, 777);
        target_data[1] = abi.encodeWithSelector(ERC20.transfer.selector, allowed_address_1, 777);

        uint256[] memory values = new uint256[](2);

        deal(address(USDT), address(boring_vault), 777);

        manager.manageVaultWithMerkleVerification(target_proofs, targets, target_data, values);

        assertEq(USDT.balanceOf(allowed_address_1), 777, "USDT should have been transfered");
    }

    // ========================================= HELPER FUNCTIONS =========================================
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
