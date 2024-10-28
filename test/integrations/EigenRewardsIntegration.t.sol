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
    StakingDecoderAndSanitizer,
    EigenLayerLSTStakingDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/StakingDecoderAndSanitizer.sol";

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract EigenRewardsIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager =
        ManagerWithMerkleVerification(0x354ade0382EEC1BF0a444339ABc82931457C2c0e);
    BoringVault public boringVault = BoringVault(payable(0xE77076518A813616315EaAba6cA8e595E845EeE9));
    address public rawDataDecoderAndSanitizer = 0x0De55435028D904e1af8Ec58C2f86DF2c4d32f2a;
    RolesAuthority public rolesAuthority = RolesAuthority(0x1f5D0e8e7eb6390D2eb6024cdC8B38A7faab596E);

    address public owner;
    address public strategist = 0x41DFc53B13932a2690C9790527C1967d8579a6ae;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 21067456;

        _startFork(rpcKey, blockNumber);

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(1));

        owner = boringVault.owner();
    }

    function testSetClaimerFor() external {
        deal(getAddress(sourceChain, "EIGEN"), address(boringVault), 1_000e18);

        address claimer = vm.addr(4);
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addLeafsForEigenLayerLST(
            leafs,
            getAddress(sourceChain, "EIGEN"),
            getAddress(sourceChain, "eigenStrategy"),
            getAddress(sourceChain, "strategyManager"),
            getAddress(sourceChain, "delegationManager"),
            getAddress(sourceChain, "eEigenOperator"),
            getAddress(sourceChain, "eigenRewards"),
            claimer
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        vm.prank(owner);
        manager.setManageRoot(strategist, manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[4];
        manageLeafs[1] = leafs[5];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "delegationManager");
        targets[1] = getAddress(sourceChain, "delegationManager");

        bytes[] memory targetData = new bytes[](2);
        DecoderCustomTypes.SignatureWithExpiry memory signatureWithExpiry;
        targetData[0] = abi.encodeWithSignature(
            "delegateTo(address,(bytes,uint256),bytes32)",
            getAddress(sourceChain, "eEigenOperator"),
            signatureWithExpiry,
            bytes32(0)
        );
        targetData[1] = abi.encodeWithSignature("undelegate(address)", boringVault);
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        vm.prank(strategist);
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
