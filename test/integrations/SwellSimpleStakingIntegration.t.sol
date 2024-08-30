// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {
    PointFarmingDecoderAndSanitizer,
    SwellSimpleStakingDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/PointFarmingDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {DroneLib} from "src/base/Drones/DroneLib.sol";
import {BoringDrone} from "src/base/Drones/BoringDrone.sol";

import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract SwellSimpleStakingIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;
    BoringDrone public boringDrone;

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
        uint256 blockNumber = 19826676;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        boringDrone = new BoringDrone(address(boringVault), 0);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new PointFarmingDecoderAndSanitizer(address(boringVault)));

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(1));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);

        // Setup roles authority.
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)"))),
            true
        );
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])"))),
            true
        );

        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            MANGER_INTERNAL_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector, true
        );
        rolesAuthority.setRoleCapability(
            BORING_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.flashLoan.selector, true
        );
        rolesAuthority.setRoleCapability(
            BALANCER_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.receiveFlashLoan.selector, true
        );

        // Grant roles
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        rolesAuthority.setUserRole(getAddress(sourceChain, "vault"), BALANCER_VAULT_ROLE, true);
    }

    function testSwellSimpleStakingIntegration() external {
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);

        // approve
        // Call deposit
        // withdraw
        // complete withdraw
        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        _addSwellSimpleStakingLeafs(
            leafs, getAddress(sourceChain, "WETH"), getAddress(sourceChain, "swellSimpleStaking")
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "swellSimpleStaking");
        targets[2] = getAddress(sourceChain, "swellSimpleStaking");

        bytes[] memory targetData = new bytes[](3);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "swellSimpleStaking"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "deposit(address,uint256,address)", getAddress(sourceChain, "WETH"), 1_000e18, address(boringVault)
        );
        targetData[2] = abi.encodeWithSignature(
            "withdraw(address,uint256,address)", getAddress(sourceChain, "WETH"), 1_000e18, address(boringVault)
        );

        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](3);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertEq(
            getERC20(sourceChain, "WETH").balanceOf(address(boringVault)),
            1_000e18,
            "BoringVault should have received 1,000 WETH"
        );
    }

    function testSwellSimpleStakingIntegrationViaDrone() external {
        deal(getAddress(sourceChain, "WETH"), address(boringDrone), 1_000e18);

        // Before creating merkle leafs, set the boringVault address to be the puppet.
        setAddress(true, sourceChain, "boringVault", address(boringDrone));
        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        _addSwellSimpleStakingLeafs(
            leafs, getAddress(sourceChain, "WETH"), getAddress(sourceChain, "swellSimpleStaking")
        );

        // Convert the leafs into puppet leafs.
        ManageLeaf[] memory puppetLeafs = _createPuppetLeafs(leafs, address(boringDrone));

        bytes32[][] memory manageTree = _generateMerkleTree(puppetLeafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = puppetLeafs[0];
        manageLeafs[1] = puppetLeafs[1];
        manageLeafs[2] = puppetLeafs[2];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = address(boringDrone);
        targets[1] = address(boringDrone);
        targets[2] = address(boringDrone);

        bytes[] memory targetData = new bytes[](3);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "swellSimpleStaking"), type(uint256).max
        );
        // Note this logic even works with encode packing the data to reduce calldata size.
        targetData[0] = abi.encodePacked(targetData[0], getAddress(sourceChain, "WETH"), DroneLib.TARGET_FLAG);
        targetData[1] = abi.encodeWithSignature(
            "deposit(address,uint256,address)",
            getAddress(sourceChain, "WETH"),
            1_000e18,
            address(boringDrone),
            getAddress(sourceChain, "swellSimpleStaking"),
            DroneLib.TARGET_FLAG
        );
        targetData[2] = abi.encodeWithSignature(
            "withdraw(address,uint256,address)",
            getAddress(sourceChain, "WETH"),
            1_000e18,
            address(boringDrone),
            getAddress(sourceChain, "swellSimpleStaking"),
            DroneLib.TARGET_FLAG
        );

        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](3);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertEq(
            getERC20(sourceChain, "WETH").balanceOf(address(boringDrone)),
            1_000e18,
            "BoringVault should have received 1,000 WETH"
        );
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
