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
    PumpBtcDecoderAndSanitizer,
    PumpStakingDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/PumpBtcDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract PumpStakingIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;

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
        uint256 blockNumber = 20543218;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new PumpBtcDecoderAndSanitizer(address(boringVault), address(0)));

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

    function testPumpStakingIntegrationStake() external {
        deal(getAddress(sourceChain, "WBTC"), address(boringVault), 10e8);

        // approve
        // Call deposit
        // withdraw
        // complete withdraw
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addLeafsForPumpStaking(leafs, getAddress(sourceChain, "pumpStaking"), getERC20(sourceChain, "WBTC"));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "WBTC");
        targets[1] = getAddress(sourceChain, "pumpStaking");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "pumpStaking"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature("stake(uint256)", 10e8);

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertEq(
            getERC20(sourceChain, "pumpBTC").balanceOf(address(boringVault)),
            10e8,
            "BoringVault should have received 10 pumpBTC"
        );
    }

    function testPumpStakingIntegrationUnstake() external {
        // Spoof PumpStaking owner to allow for usntaking.
        PumpStaking ps = PumpStaking(getAddress(sourceChain, "pumpStaking"));
        address owner = ps.owner();
        vm.startPrank(owner);
        ps.setOnlyAllowStake(false);
        ps.setOperator(address(this));
        vm.stopPrank();

        deal(getAddress(sourceChain, "pumpBTC"), address(boringVault), 10e8);
        deal(getAddress(sourceChain, "WBTC"), address(this), 10e8);

        // approve
        // Call deposit
        // withdraw
        // complete withdraw
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addLeafsForPumpStaking(leafs, getAddress(sourceChain, "pumpStaking"), getERC20(sourceChain, "WBTC"));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[2];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "pumpStaking");

        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature("unstakeRequest(uint256)", 10e8);

        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](1);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertEq(
            getERC20(sourceChain, "pumpBTC").balanceOf(address(boringVault)), 0, "BoringVault should have zero pumpBTC"
        );

        skip(10 days);

        // Operator deposits claimable WBTC into PumpStaking.
        getERC20(sourceChain, "WBTC").approve(getAddress(sourceChain, "pumpStaking"), 10e8);
        ps.deposit(10e8);

        uint256 beforeClaim = vm.snapshot();

        // Finish claim using claimSlot(uint8)
        manageLeafs[0] = leafs[3];
        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);
        targets[0] = getAddress(sourceChain, "pumpStaking");
        targetData[0] = abi.encodeWithSignature("claimSlot(uint8)", 2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        values[0] = 0;
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertEq(
            getERC20(sourceChain, "WBTC").balanceOf(address(boringVault)), 10e8, "BoringVault should have 10e8 wBTC"
        );

        vm.revertTo(beforeClaim);

        // Finish claim using claimAll()
        manageLeafs[0] = leafs[4];
        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);
        targets[0] = getAddress(sourceChain, "pumpStaking");
        targetData[0] = abi.encodeWithSignature("claimAll()");
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        values[0] = 0;
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertEq(
            getERC20(sourceChain, "WBTC").balanceOf(address(boringVault)), 10e8, "BoringVault should have 10e8 wBTC"
        );
    }

    function testPumpStakingIntegrationUnstakeInstant() external {
        // Spoof PumpStaking owner to allow for usntaking.
        PumpStaking ps = PumpStaking(getAddress(sourceChain, "pumpStaking"));
        address owner = ps.owner();
        vm.prank(owner);
        ps.setOnlyAllowStake(false);

        deal(getAddress(sourceChain, "WBTC"), getAddress(sourceChain, "boringVault"), 10e8);

        // approve
        // Call deposit
        // withdraw
        // complete withdraw
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addLeafsForPumpStaking(leafs, getAddress(sourceChain, "pumpStaking"), getERC20(sourceChain, "WBTC"));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[5];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = getAddress(sourceChain, "WBTC");
        targets[1] = getAddress(sourceChain, "pumpStaking");
        targets[2] = getAddress(sourceChain, "pumpStaking");

        bytes[] memory targetData = new bytes[](3);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "pumpStaking"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature("stake(uint256)", 10e8);
        targetData[2] = abi.encodeWithSignature("unstakeInstant(uint256)", 10e8);

        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](3);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertEq(
            getERC20(sourceChain, "pumpBTC").balanceOf(address(boringVault)), 0, "BoringVault should have zero pumpBTC"
        );

        assertEq(
            getERC20(sourceChain, "WBTC").balanceOf(address(boringVault)), 9.7e8, "BoringVault should have 10e8 wBTC"
        );
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

interface PumpStaking {
    function owner() external view returns (address);
    function setOnlyAllowStake(bool _onlyAllowStake) external;
    function deposit(uint256 amount) external;
    function setOperator(address newOperator) external;
}
