// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {WeETHFullDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/WeEthFullDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract WeETHIntegrationTest is Test, MerkleTreeHelper {
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
        setSourceChainName("base");
        // Setup forked environment.
        string memory rpcKey = "BASE_RPC_URL";
        uint256 blockNumber = 22276862;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new WeETHFullDecoderAndSanitizer(address(boringVault))); 

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

        // Allow the boring vault to receive ETH.
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);
    }


    function testWeETHIntegration() external {
        deal(address(boringVault), 100e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addWeETHLeafs(
            leafs,
            getAddress(sourceChain, "ETH"), //tokenIn
            getAddress(sourceChain, "boringVault") //referral
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "etherFiL2SyncPool"); 

        bytes[] memory targetData = new bytes[](1); 
        targetData[0] =
            abi.encodeWithSignature("deposit(address,uint256,uint256,address)", 
            getAddress(sourceChain, "ETH"), 
            198600000000000000, 
            178740000000000000, 
            getAddress(sourceChain, "boringVault")
        );
        uint256[] memory values = new uint256[](1);
        values[0] = 198600000000000000; 
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 

        //send the tx
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        
        //sanity check
        uint256 weETHBalance = getERC20(sourceChain, "WEETH").balanceOf(address(boringVault)); 
        assertGt(weETHBalance, 0); 
    }

    function testWeETHIntegration__Reverts() external {
        deal(address(boringVault), 1); 

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addWeETHLeafs(
            leafs,
            getAddress(sourceChain, "ETH"), //tokenIn
            getAddress(sourceChain, "boringVault") //referral
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "etherFiL2SyncPool"); 

        bytes[] memory targetData = new bytes[](1); 
        targetData[0] =
            abi.encodeWithSignature("deposit(address,uint256,uint256,address)", 
            getAddress(sourceChain, "ETH"), 
            198600000000000000, 
            178740000000000000, 
            getAddress(sourceChain, "boringVault")
        );
        uint256[] memory values = new uint256[](1);
        values[0] = 198600000000000000; 
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 

        //send the tx
        vm.expectRevert(); //not enough ETH
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        
        //sanity check
        uint256 weETHBalance = getERC20(sourceChain, "WEETH").balanceOf(address(boringVault)); 
        assertEq(weETHBalance, 0); 
    }


    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }

}
