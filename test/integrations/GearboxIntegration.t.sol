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
    EtherFiLiquidDecoderAndSanitizer,
    GearboxDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/EtherFiLiquidDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract GearboxIntegrationTest is Test, MerkleTreeHelper {
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

    address public weEthOracle = 0x3fa58b74e9a8eA8768eb33c8453e9C2Ed089A40a;
    address public weEthIrm = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19826676;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(
            new EtherFiLiquidDecoderAndSanitizer(
                address(boringVault), getAddress(sourceChain, "uniswapV3NonFungiblePositionManager")
            )
        );

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

    function testGearboxIntegration() external {
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);

        // get dWETHV3
        // get sdWETHV3
        // claim rewards
        // sell sdWETHV3
        // sell dWETHV3
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addGearboxLeafs(leafs, ERC4626(getAddress(sourceChain, "dWETHV3")), getAddress(sourceChain, "sdWETHV3"));
        // leafs[2] = ManageLeaf(dWETHV3, false, "approve(address,uint256)", new address[](1));
        // leafs[2].argumentAddresses[0] = sdWETHV3;
        // leafs[3] = ManageLeaf(sdWETHV3, false, "deposit(uint256)", new address[](0));
        // leafs[4] = ManageLeaf(sdWETHV3, false, "claim()", new address[](0));
        // leafs[5] = ManageLeaf(sdWETHV3, false, "withdraw(uint256)", new address[](0));
        // leafs[6] = ManageLeaf(dWETHV3, false, "withdraw(uint256,address,address)", new address[](2));
        // leafs[6].argumentAddresses[0] = address(boringVault);
        // leafs[6].argumentAddresses[1] = address(boringVault);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](7);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[3];
        manageLeafs[3] = leafs[4];
        manageLeafs[4] = leafs[6];
        manageLeafs[5] = leafs[5];
        manageLeafs[6] = leafs[2];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](7);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "dWETHV3");
        targets[2] = getAddress(sourceChain, "dWETHV3");
        targets[3] = getAddress(sourceChain, "sdWETHV3");
        targets[4] = getAddress(sourceChain, "sdWETHV3");
        targets[5] = getAddress(sourceChain, "sdWETHV3");
        targets[6] = getAddress(sourceChain, "dWETHV3");

        bytes[] memory targetData = new bytes[](7);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "dWETHV3"), type(uint256).max);
        targetData[1] = abi.encodeWithSignature("deposit(uint256,address)", 1_000e18, address(boringVault));
        targetData[2] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "sdWETHV3"), type(uint256).max);
        targetData[3] = abi.encodeWithSignature("deposit(uint256)", 100e18);
        targetData[4] = abi.encodeWithSignature("claim()");
        targetData[5] = abi.encodeWithSignature("withdraw(uint256)", 100e18);
        targetData[6] = abi.encodeWithSignature(
            "withdraw(uint256,address,address)", 1_000e18 - 1, address(boringVault), address(boringVault)
        );

        address[] memory decodersAndSanitizers = new address[](7);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](7)
        );
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
