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

        boring_vault =
            new BoringVault(address(this), "Boring Vault", "BV", 18, address(0), address(this), address(this));

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
        bytes32 leaf_c = keccak256(abi.encodePacked(allowed_address_0));
        bytes32 leaf_d = keccak256(abi.encodePacked(allowed_address_1));
        bytes32 allowed_address_arguments_root = _hashPair(leaf_c, leaf_d);

        manager.setAllowedTargetsRoot(allowed_targets_and_selectors_root);
        manager.setAllowedAddressArgumentsRoot(allowed_address_arguments_root);

        bytes32[][] memory target_proofs = new bytes32[][](2);
        target_proofs[0] = new bytes32[](1);
        target_proofs[0][0] = leaf_b;
        target_proofs[1] = new bytes32[](1);
        target_proofs[1][0] = leaf_a;
        bytes32[][][] memory address_arguments_proofs = new bytes32[][][](2);
        address_arguments_proofs[0] = new bytes32[][](1);
        address_arguments_proofs[0][0] = new bytes32[](1);
        address_arguments_proofs[0][0][0] = leaf_d;
        address_arguments_proofs[1] = new bytes32[][](1);
        address_arguments_proofs[1][0] = new bytes32[](1);
        address_arguments_proofs[1][0][0] = leaf_c;
        string[][] memory function_strings = new string[][](2);
        function_strings[0] = new string[](6);
        function_strings[0][0] = "approve";
        function_strings[0][1] = "(";
        function_strings[0][2] = "address";
        function_strings[0][3] = ",";
        function_strings[0][4] = "uint256";
        function_strings[0][5] = ")";

        function_strings[1] = new string[](6);
        function_strings[1][0] = "transfer";
        function_strings[1][1] = "(";
        function_strings[1][2] = "address";
        function_strings[1][3] = ",";
        function_strings[1][4] = "uint256";
        function_strings[1][5] = ")";

        address[] memory targets = new address[](2);
        targets[0] = address(USDC);
        targets[1] = address(USDT);
        bytes[] memory target_data = new bytes[](2);
        target_data[0] = abi.encodeWithSelector(ERC20.approve.selector, allowed_address_0, 777);
        target_data[1] = abi.encodeWithSelector(ERC20.transfer.selector, allowed_address_1, 777);

        uint256[] memory values = new uint256[](2);

        deal(address(USDT), address(boring_vault), 777);

        manager.manageVaultWithMerkleVerification(
            target_proofs, address_arguments_proofs, function_strings, targets, target_data, values
        );

        assertEq(USDT.balanceOf(allowed_address_1), 777, "USDT should have been transfered");
    }

    struct ComplexStruct {
        address a;
        bytes b;
        bool c;
        address d;
    }

    function doComplexThing(address a, bytes calldata b, bool c, address d) external pure returns (bool) {
        return c;
    }

    function testComplexStructAddressParsing() external {
        bytes32 allowed_targets_and_selectors_root =
            keccak256(abi.encodePacked(address(this), ManagerWithMerkleVerificationTest.doComplexThing.selector));

        address allowed_address_0 = vm.addr(0xDEAD);
        address allowed_address_1 = vm.addr(0xDEAD1);
        bytes32 leaf_c = keccak256(abi.encodePacked(allowed_address_0));
        bytes32 leaf_d = keccak256(abi.encodePacked(allowed_address_1));
        bytes32 allowed_address_arguments_root = _hashPair(leaf_c, leaf_d);

        manager.setAllowedTargetsRoot(allowed_targets_and_selectors_root);
        manager.setAllowedAddressArgumentsRoot(allowed_address_arguments_root);

        bytes32[][] memory target_proofs = new bytes32[][](1);
        bytes32[][][] memory address_arguments_proofs = new bytes32[][][](1);
        address_arguments_proofs[0] = new bytes32[][](2);
        address_arguments_proofs[0][0] = new bytes32[](1);
        address_arguments_proofs[0][0][0] = leaf_d;
        address_arguments_proofs[0][1] = new bytes32[](1);
        address_arguments_proofs[0][1][0] = leaf_c;
        string[][] memory function_strings = new string[][](1);
        function_strings[0] = new string[](10);
        function_strings[0][0] = "doComplexThing";
        function_strings[0][1] = "(";
        function_strings[0][2] = "address";
        function_strings[0][3] = ",";
        function_strings[0][4] = "bytes";
        function_strings[0][5] = ",";
        function_strings[0][6] = "bool";
        function_strings[0][7] = ",";
        function_strings[0][8] = "address";
        function_strings[0][9] = ")";

        address[] memory targets = new address[](1);
        targets[0] = address(this);
        bytes[] memory target_data = new bytes[](1);
        ComplexStruct memory s = ComplexStruct({
            a: allowed_address_0,
            b: hex"DEADDEADDEADDEADDEADDEADDEADDEADDEAD",
            c: true,
            d: allowed_address_1
        });
        target_data[0] = abi.encodeWithSelector(
            ManagerWithMerkleVerificationTest.doComplexThing.selector,
            allowed_address_0,
            hex"DEADDEADDEADDEADDEADDEADDEADDEADDEAD",
            true,
            allowed_address_1
        );

        uint256[] memory values = new uint256[](1);

        manager.manageVaultWithMerkleVerification(
            target_proofs, address_arguments_proofs, function_strings, targets, target_data, values
        );

        // This is how complex data breaks down.
        // 0000000000000000000000000000000000000000000000000000000000000020 // I think this is an indicator that there is some complex data in this argument
        // 0000000000000000000000007b1afe2745533d852d6fd5a677f14c074210d896
        // 0000000000000000000000000000000000000000000000000000000000000080
        // 0000000000000000000000000000000000000000000000000000000000000001
        // 0000000000000000000000007b1afe2745533d852d6fd5a677f14c074210d896
        // 0000000000000000000000000000000000000000000000000000000000000012 // The number of bytes in b
        // deaddeaddeaddeaddeaddeaddeaddeaddead0000000000000000000000000000
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
