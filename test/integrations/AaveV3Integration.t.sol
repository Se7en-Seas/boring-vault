// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {EtherFiLiquidDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/EtherFiLiquidDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract AaveV3IntegrationTest is Test, MerkleTreeHelper {
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
        uint256 blockNumber = 20227663;

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

        // Allow the boring vault to receive ETH.
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);
    }

    function testAaveV3Integration() external {
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "WSTETH"), address(boringVault), 1_000e18);

        // Approve WSTETH
        // Approve WETH
        // Supply WSTETH
        // Borrow WETH
        // Repay WETH
        // Withdraw WSTETH
        // Call setUserUseReserveAsCollateral
        // Call setUserEMode
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        ERC20[] memory supplyAssets = new ERC20[](1);
        supplyAssets[0] = getERC20(sourceChain, "WSTETH");
        ERC20[] memory borrowAssets = new ERC20[](1);
        borrowAssets[0] = getERC20(sourceChain, "WETH");
        ERC20[] memory claimAssets = new ERC20[](1); 
        claimAssets[0] = getERC20(sourceChain, "WSTETH");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets, claimAssets);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](9);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];
        manageLeafs[3] = leafs[4];
        manageLeafs[4] = leafs[5];
        manageLeafs[5] = leafs[3];
        manageLeafs[6] = leafs[6];
        manageLeafs[7] = leafs[7];
        manageLeafs[8] = leafs[8];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](9);
        targets[0] = getAddress(sourceChain, "WSTETH");
        targets[1] = getAddress(sourceChain, "WETH");
        targets[2] = getAddress(sourceChain, "v3Pool");
        targets[3] = getAddress(sourceChain, "v3Pool");
        targets[4] = getAddress(sourceChain, "v3Pool");
        targets[5] = getAddress(sourceChain, "v3Pool");
        targets[6] = getAddress(sourceChain, "v3Pool");
        targets[7] = getAddress(sourceChain, "v3Pool");
        targets[8] = getAddress(sourceChain, "v3RewardsController");

        address[] memory claimAssetsData = new address[](1); 
        claimAssetsData[0] = getAddress(sourceChain, "WSTETH"); 

        bytes[] memory targetData = new bytes[](9);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "v3Pool"), type(uint256).max);
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "v3Pool"), type(uint256).max);
        targetData[2] = abi.encodeWithSignature(
            "supply(address,uint256,address,uint16)",
            getAddress(sourceChain, "WSTETH"),
            1_000e18,
            address(boringVault),
            0
        );
        targetData[3] = abi.encodeWithSignature(
            "borrow(address,uint256,uint256,uint16,address)",
            getAddress(sourceChain, "WETH"),
            100e18,
            2,
            0,
            address(boringVault)
        );
        targetData[4] = abi.encodeWithSignature(
            "repay(address,uint256,uint256,address)",
            getAddress(sourceChain, "WETH"),
            type(uint256).max,
            2,
            address(boringVault)
        );
        targetData[5] = abi.encodeWithSignature(
            "withdraw(address,uint256,address)", getAddress(sourceChain, "WSTETH"), 1_000e18 - 1, address(boringVault)
        );
        targetData[6] = abi.encodeWithSignature(
            "setUserUseReserveAsCollateral(address,bool)", getAddress(sourceChain, "WSTETH"), true
        );
        targetData[7] = abi.encodeWithSignature("setUserEMode(uint8)", 0);
        targetData[8] = abi.encodeWithSignature("claimRewards(address[],uint256,address,address)", claimAssetsData, 0, getAddress(sourceChain, "boringVault"), 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0); 

        address[] memory decodersAndSanitizers = new address[](9);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[8] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](9);
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
