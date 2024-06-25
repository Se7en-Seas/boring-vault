// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {SymbioticUManager, DefaultCollateral} from "src/micro-managers/SymbioticUManager.sol";
import {BaseMerkleRootGenerator} from "resources/BaseMerkleRootGenerator.sol";

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract EthenaSymbioticUManagerTest is Test, MainnetAddresses, BaseMerkleRootGenerator {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    BoringVault public boringVault = BoringVault(payable(0x08c6F91e2B681FaF5e17227F2a44C307b3C1364C));
    ManagerWithMerkleVerification public manager =
        ManagerWithMerkleVerification(0xcFF411d5C54FE0583A984beE1eF43a4776854B9A);
    address public rawDataDecoderAndSanitizer = 0xdaEfE2146908BAd73A1C45f75eB2B8E46935c781;
    address public accountantAddress = 0xc315D6e14DDCDC7407784e2Caf815d131Bc1D3E7;
    uint8 public constant STRATEGIST_ROLE = 7;

    RolesAuthority public rolesAuthority = RolesAuthority(0xaBA6bA1E95E0926a6A6b917FE4E2f19ceaE4FF2e);
    SymbioticUManager public symbioticUManager = SymbioticUManager(0xC0Ef6577906665908FCe174a5D2D2CDFeDdEA46E);

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 20169656;

        _startFork(rpcKey, blockNumber);

        updateAddresses(address(boringVault), rawDataDecoderAndSanitizer, address(manager), accountantAddress);

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        leafIndex = type(uint256).max;
        _addSymbioticApproveAndDepositLeaf(leafs, sUSDeDefaultCollateral);

        bytes32[][] memory merkleTree = _generateMerkleTree(leafs);

        vm.startPrank(liquidMultisig);
        manager.setManageRoot(address(symbioticUManager), merkleTree[merkleTree.length - 1][0]);
        rolesAuthority.setUserRole(address(symbioticUManager), STRATEGIST_ROLE, true);
        vm.stopPrank();

        // symbioticUManager.updateMerkleTree(merkleTree, true);
    }

    function testHunch() public {
        DC dc = DC(sUSDeDefaultCollateral);

        address limitIncreaser = dc.limitIncreaser();

        vm.prank(limitIncreaser);
        dc.increaseLimit(1_000e18);

        vm.prank(dev1Address);
        uint256 assembled = symbioticUManager.fullAssemble(DefaultCollateral(sUSDeDefaultCollateral));
        assertEq(assembled, 1_000e18, "Assembled amount should be 1_000e18");

        assertEq(
            ERC20(sUSDeDefaultCollateral).balanceOf(address(boringVault)),
            1_000e18,
            "BoringVault balance should be 1_000e18"
        );
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

interface DC {
    function limitIncreaser() external view returns (address);
    function increaseLimit(uint256 amount) external;
}
