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
    address public rawDataDecoderAndSanitizer;
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

        rawDataDecoderAndSanitizer = address(new StakingDecoderAndSanitizer(address(boringVault)));

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(1));

        owner = boringVault.owner();
    }

    function testProcessClaim() external {
        deal(getAddress(sourceChain, "EIGEN"), address(boringVault), 0);

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

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[6];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "eigenRewards");

        bytes[] memory targetData = new bytes[](1);
        targetData[0] =
            hex"3ccc861d0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000E77076518A813616315EaAba6cA8e595E845EeE9000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000c0a90000000000000000000000000000000000000000000000000000000000000100000000000000000000000000539ee70082ee32ce1cfc3cb69e004d8d06fca2b4dcd5db2d8cc0a4a192437a5292bfdf499ec20a5284074961436eb242370519ac000000000000000000000000000000000000000000000000000000000000036000000000000000000000000000000000000000000000000000000000000003c000000000000000000000000000000000000000000000000000000000000004a000000000000000000000000000000000000000000000000000000000000002409f3ae90c29ffb535b219c84fb7face5b4a1338fa68037a79f7a16a169ad62f790f08b8538861f4b4aa4662f2b6ae087e5935e3756cfd5a9b6aff73306410e593d1036c8496a5dc59361b8a9f1f02fade3698a5d896bc02e64c8b590f729a5492b54388bc0e9559bf3f336786e7337c45f55ce78b3584c2b4b5c16d6a05c588b87bb4ed43cd5a303cec4d97edbde2b4999b10497e5c5f61f12f1c10f7af4a60c684da7f164c2c780d257d316442501328963e30767f91b9960f75682100ee30a5784feb438dfffb07bb3a03ec7ae284c2d8fde1a9fea6e5fcc0d5c1d4e42b906f754413b392d31db248acf69ef4d7793eac403b7c0ea9898968c59972284074dbc073fd9c87d9acf4531a4e7eb78225a2464c728eaa1e331467a06d5409a017e6c8fa891839b43b7741dde8465b689090cbd13a96ec712a4801ffb8d592711bc2e77f41d9967f1c65f6c46243dbd5db891c52ee06b608b3cb49dc8e32f00559fbc60e7feb186c196e6d5cdf1de109f1dd72bf3e7e4a4f2427c1d91b218bc3aafb77264a8afe0a5bc37d3b4dd4d63d1968be9aeb0fe9e11fef2e0e5b949d519f0c46572889439e47402363cb73d7058dfa1e761ad382683229ca5599b5cc57b1c3cec1f5c20b5cb1386ecd2dca28c7c93851ba06463f9c708ce27fecc2dac4059f706a12ec33060f70e1fdf1ca7c5e23446cc1f20bd4cf8d8431617036d1ee63b6832db808f9963a620a1e76076df93a526d84a40f0ca076299f6f07ec33a3bd2d4034c7155e768f526f40fd4d75cf08d04d802873d4c0b181c35fbffa5477748e0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020767814e08bfe0a7a370944b34d200c7e66f5778e1fd776a3430dc272802a154e000000000000000000000000000000000000000000000000000000000000002025b4017da171d94818e4cfb02d337fb551b565fb5efe6de62682a43c688bb8790000000000000000000000000000000000000000000000000000000000000002000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000000361a50403e3000000000000000000000000ec53bf9167f50cdeb3ae105f56099aaab9061f83000000000000000000000000000000000000000000000000f246c134fb52b9fa";
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](1);

        // Before we can claim we need the user to call setClaimerFor(address boringVault)
        address user = 0x539Ee70082Ee32CE1cFc3cB69e004d8D06FCA2B4;
        vm.startPrank(user);
        EigenRewards(getAddress(sourceChain, "eigenRewards")).setClaimerFor(address(boringVault));
        vm.stopPrank();

        vm.prank(strategist);
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        uint256 expectedEigenBalance = 17.45785343884726937e18;
        assertEq(
            getERC20(sourceChain, "EIGEN").balanceOf(address(boringVault)),
            expectedEigenBalance,
            "Eigen process claim failed"
        );
    }

    function testSetClaimerFor() external {
        deal(getAddress(sourceChain, "EIGEN"), address(boringVault), 1_000e18);

        address claimer = getAddress(sourceChain, "dev0Address");
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

        vm.prank(owner);
        manager.setManageRoot(strategist, manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[6];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "eigenRewards");

        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature("setClaimerFor(address)", claimer);
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](1);

        vm.prank(strategist);
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        address claimerThatWasSet =
            EigenRewards(getAddress(sourceChain, "eigenRewards")).claimerFor(address(boringVault));

        assertTrue(claimerThatWasSet == claimer, "Claimer was not set correctly");
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

interface EigenRewards {
    function claimerFor(address) external view returns (address);
    function setClaimerFor(address) external;
}
