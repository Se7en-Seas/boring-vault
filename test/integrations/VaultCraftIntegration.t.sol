// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {EtherFiLiquidEthDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidEthDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract VaultCraftIntegrationTest is Test, MerkleTreeHelper {
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
        setSourceChainName("arbitrum");
        // Setup forked environment.
        string memory rpcKey = "ARBITRUM_RPC_URL";
        uint256 blockNumber = 235623820;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(
            new EtherFiLiquidEthDecoderAndSanitizer(
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

    function testVaultCraftIntegration() external {
        // Give BoringVault some wETH.
        uint256 assets = 1_000e18;
        deal(getAddress(sourceChain, "WETH"), address(boringVault), assets);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addVaultCraftLeafs(
            leafs, ERC4626(getAddress(sourceChain, "compoundV3Weth")), getAddress(sourceChain, "compoundV3WethGauge")
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](4);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[3];
        manageLeafs[3] = leafs[4];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](4);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "compoundV3Weth");
        targets[2] = getAddress(sourceChain, "compoundV3Weth");
        targets[3] = getAddress(sourceChain, "compoundV3WethGauge");

        bytes[] memory targetData = new bytes[](4);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "compoundV3Weth"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature("deposit(uint256,address)", assets, address(boringVault));
        targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "compoundV3WethGauge"), type(uint256).max
        );
        uint256 expectedShares = 999945552337352695179;
        targetData[3] = abi.encodeWithSignature("deposit(uint256,address)", expectedShares, address(boringVault));

        address[] memory decodersAndSanitizers = new address[](4);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](4);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Let some ARB rewards accrue.
        skip(7 days);

        manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[6];
        manageLeafs[1] = leafs[5];
        manageLeafs[2] = leafs[2];

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](3);
        targets[0] = getAddress(sourceChain, "compoundV3WethGauge");
        targets[1] = getAddress(sourceChain, "compoundV3WethGauge");
        targets[2] = getAddress(sourceChain, "compoundV3Weth");

        targetData = new bytes[](3);
        targetData[0] = abi.encodeWithSignature("claim_rewards(address)", boringVault);
        targetData[1] = abi.encodeWithSignature("withdraw(uint256)", expectedShares);
        targetData[2] = abi.encodeWithSignature("withdraw(uint256,address,address)", assets, boringVault, boringVault);

        decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        values = new uint256[](3);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertGt(
            getERC20(sourceChain, "ARB").balanceOf(address(boringVault)), 0, "Boring Vault should have ARB rewards"
        );
        assertEq(
            getERC20(sourceChain, "WETH").balanceOf(address(boringVault)),
            assets,
            "Boring Vault should have gotten principal wETH out"
        );

        assertGt(
            getERC20(sourceChain, "compoundV3Weth").balanceOf(address(boringVault)),
            0,
            "Boring Vault should have earned yield"
        );
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
