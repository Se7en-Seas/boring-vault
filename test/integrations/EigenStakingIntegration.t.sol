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

contract EigenStakingIntegrationTest is Test, MerkleTreeHelper {
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
        uint256 blockNumber = 20965167;

        _startFork(rpcKey, blockNumber);

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(1));

        owner = boringVault.owner();
    }

    function testEigenStakingIntegration(uint256 amountToStake) external {
        amountToStake = bound(amountToStake, 1e18, 100_000e18);
        deal(getAddress(sourceChain, "EIGEN"), address(boringVault), amountToStake);

        // approve
        // Call deposit
        // withdraw
        // complete withdraw
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addLeafsForEigenLayerLST(
            leafs,
            getAddress(sourceChain, "EIGEN"),
            getAddress(sourceChain, "eigenStrategy"),
            getAddress(sourceChain, "strategyManager"),
            getAddress(sourceChain, "delegationManager"),
            getAddress(sourceChain, "eEigenOperator"),
            getAddress(sourceChain, "eigenRewards"),
            address(0)
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        vm.prank(owner);
        manager.setManageRoot(strategist, manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = getAddress(sourceChain, "EIGEN");
        targets[1] = getAddress(sourceChain, "strategyManager");
        targets[2] = getAddress(sourceChain, "delegationManager");

        bytes[] memory targetData = new bytes[](3);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "strategyManager"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "depositIntoStrategy(address,address,uint256)",
            getAddress(sourceChain, "eigenStrategy"),
            getAddress(sourceChain, "EIGEN"),
            amountToStake
        );
        DecoderCustomTypes.QueuedWithdrawalParams[] memory queuedParams =
            new DecoderCustomTypes.QueuedWithdrawalParams[](1);
        queuedParams[0].strategies = new address[](1);
        queuedParams[0].strategies[0] = getAddress(sourceChain, "eigenStrategy");
        queuedParams[0].shares = new uint256[](1);
        queuedParams[0].shares[0] = amountToStake;
        queuedParams[0].withdrawer = address(boringVault);
        targetData[2] = abi.encodeWithSignature("queueWithdrawals((address[],uint256[],address)[])", queuedParams);

        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](3);

        vm.prank(strategist);
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertEq(
            getERC20(sourceChain, "EIGEN").balanceOf(address(boringVault)), 0, "BoringVault should staked all EIGEN"
        );

        // Finalize withdraw requests.
        // Must wait atleast delegationManager.minWithdrawalDelayBlocks() blocks which is 50400.
        {
            uint32 withdrawRequestBlock = uint32(block.number);
            vm.roll(block.number + 50400);

            // Complete the withdrawal
            manageLeafs = new ManageLeaf[](1);
            manageLeafs[0] = leafs[3];

            manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

            targets = new address[](1);
            targets[0] = getAddress(sourceChain, "delegationManager");

            targetData = new bytes[](1);
            DecoderCustomTypes.Withdrawal[] memory withdrawParams = new DecoderCustomTypes.Withdrawal[](1);
            withdrawParams[0].staker = address(boringVault);
            withdrawParams[0].delegatedTo = address(0);
            withdrawParams[0].withdrawer = address(boringVault);
            withdrawParams[0].nonce = 0;
            withdrawParams[0].startBlock = withdrawRequestBlock;
            withdrawParams[0].strategies = new address[](1);
            withdrawParams[0].strategies[0] = getAddress(sourceChain, "eigenStrategy");
            withdrawParams[0].shares = new uint256[](1);
            withdrawParams[0].shares[0] = amountToStake;
            address[][] memory tokens = new address[][](1);
            tokens[0] = new address[](1);
            tokens[0][0] = getAddress(sourceChain, "EIGEN");
            uint256[] memory middlewareTimesIndexes = new uint256[](1);
            middlewareTimesIndexes[0] = 0;
            bool[] memory receiveAsTokens = new bool[](1);
            receiveAsTokens[0] = true;
            targetData[0] = abi.encodeWithSignature(
                "completeQueuedWithdrawals((address,address,address,uint256,uint32,address[],uint256[])[],address[][],uint256[],bool[])",
                withdrawParams,
                tokens,
                middlewareTimesIndexes,
                receiveAsTokens
            );

            decodersAndSanitizers = new address[](1);
            decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

            values = new uint256[](1);

            vm.prank(strategist);
            manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        }

        assertEq(
            getERC20(sourceChain, "EIGEN").balanceOf(address(boringVault)),
            amountToStake,
            "BoringVault should have amountToStake of EIGEN"
        );
    }

    function testDelegation() external {
        deal(getAddress(sourceChain, "EIGEN"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addLeafsForEigenLayerLST(
            leafs,
            getAddress(sourceChain, "EIGEN"),
            getAddress(sourceChain, "eigenStrategy"),
            getAddress(sourceChain, "strategyManager"),
            getAddress(sourceChain, "delegationManager"),
            getAddress(sourceChain, "eEigenOperator"),
            getAddress(sourceChain, "eigenRewards"),
            address(0)
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

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
