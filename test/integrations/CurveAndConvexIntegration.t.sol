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
    CurveDecoderAndSanitizer,
    ConvexDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/EtherFiLiquidDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract CurveAndConvexIntegrationTest is Test, MerkleTreeHelper {
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

    // TODO Curve and Convex leafs still need to be added to MerkleTreeHelper.
    function testCurveAndConvexIntegration() external {
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 100e18);

        // getAddress(sourceChain, "weETH_wETH_Curve_LP")
        // getAddress(sourceChain, "weETH_wETH_Curve_Gauge")

        // Make sure the vault can
        // swap wETH -> weETH
        // add liquidity weETH/wETH
        // deposit to gauge
        // withdraw from gauge
        // claim gauge rewards
        // deposit into convex pId 275
        // withdraw from convex pId 275
        // claim rewards from convex
        // redeem LP for underlying
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        leafs[0] = ManageLeaf(
            getAddress(sourceChain, "WETH"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[0].argumentAddresses[0] = getAddress(sourceChain, "weETH_wETH_Curve_LP");
        leafs[1] = ManageLeaf(
            getAddress(sourceChain, "weETH_wETH_Curve_LP"),
            false,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[2] = ManageLeaf(
            getAddress(sourceChain, "WETH"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[2].argumentAddresses[0] = getAddress(sourceChain, "weETH_wETH_Curve_LP");
        leafs[3] = ManageLeaf(
            getAddress(sourceChain, "WEETH"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[3].argumentAddresses[0] = getAddress(sourceChain, "weETH_wETH_Curve_LP");
        leafs[4] = ManageLeaf(
            getAddress(sourceChain, "weETH_wETH_Curve_LP"),
            false,
            "add_liquidity(uint256[],uint256)",
            new address[](0),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[5] = ManageLeaf(
            getAddress(sourceChain, "weETH_wETH_Curve_LP"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[5].argumentAddresses[0] = getAddress(sourceChain, "weETH_wETH_Curve_Gauge");
        leafs[6] = ManageLeaf(
            getAddress(sourceChain, "weETH_wETH_Curve_Gauge"),
            false,
            "deposit(uint256,address)",
            new address[](1),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[6].argumentAddresses[0] = address(boringVault);
        leafs[7] = ManageLeaf(
            getAddress(sourceChain, "weETH_wETH_Curve_Gauge"),
            false,
            "withdraw(uint256)",
            new address[](0),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[8] = ManageLeaf(
            getAddress(sourceChain, "weETH_wETH_Curve_Gauge"),
            false,
            "claim_rewards(address)",
            new address[](1),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[8].argumentAddresses[0] = address(boringVault);
        leafs[9] = ManageLeaf(
            getAddress(sourceChain, "weETH_wETH_Curve_LP"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[9].argumentAddresses[0] = getAddress(sourceChain, "convexCurveMainnetBooster");
        leafs[10] = ManageLeaf(
            getAddress(sourceChain, "convexCurveMainnetBooster"),
            false,
            "deposit(uint256,uint256,bool)",
            new address[](0),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[11] = ManageLeaf(
            getAddress(sourceChain, "weETH_wETH_Convex_Reward"),
            false,
            "withdrawAndUnwrap(uint256,bool)",
            new address[](0),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[12] = ManageLeaf(
            getAddress(sourceChain, "weETH_wETH_Convex_Reward"),
            false,
            "getReward(address,bool)",
            new address[](1),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[12].argumentAddresses[0] = getAddress(sourceChain, "weETH_wETH_Convex_Reward");
        leafs[13] = ManageLeaf(
            getAddress(sourceChain, "weETH_wETH_Curve_LP"),
            false,
            "remove_liquidity(uint256,uint256[])",
            new address[](0),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](14);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];
        manageLeafs[3] = leafs[3];
        manageLeafs[4] = leafs[4];
        manageLeafs[5] = leafs[5];
        manageLeafs[6] = leafs[6];
        manageLeafs[7] = leafs[7];
        manageLeafs[8] = leafs[8];
        manageLeafs[9] = leafs[9];
        manageLeafs[10] = leafs[10];
        manageLeafs[11] = leafs[11];
        manageLeafs[12] = leafs[12];
        manageLeafs[13] = leafs[13];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](14);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "weETH_wETH_Curve_LP");
        targets[2] = getAddress(sourceChain, "WETH");
        targets[3] = getAddress(sourceChain, "WEETH");
        targets[4] = getAddress(sourceChain, "weETH_wETH_Curve_LP");
        targets[5] = getAddress(sourceChain, "weETH_wETH_Curve_LP");
        targets[6] = getAddress(sourceChain, "weETH_wETH_Curve_Gauge");
        targets[7] = getAddress(sourceChain, "weETH_wETH_Curve_Gauge");
        targets[8] = getAddress(sourceChain, "weETH_wETH_Curve_Gauge");
        targets[9] = getAddress(sourceChain, "weETH_wETH_Curve_LP");
        targets[10] = getAddress(sourceChain, "convexCurveMainnetBooster");
        targets[11] = getAddress(sourceChain, "weETH_wETH_Convex_Reward");
        targets[12] = getAddress(sourceChain, "weETH_wETH_Convex_Reward");
        targets[13] = getAddress(sourceChain, "weETH_wETH_Curve_LP");

        bytes[] memory targetData = new bytes[](14);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "weETH_wETH_Curve_LP"), type(uint256).max
        );
        targetData[1] =
            abi.encodeWithSignature("exchange(int128,int128,uint256,uint256)", int128(1), int128(0), 50e18, 0);
        targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "weETH_wETH_Curve_LP"), type(uint256).max
        );
        targetData[3] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "weETH_wETH_Curve_LP"), type(uint256).max
        );
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 48082277094560238132;
        amounts[1] = 50e18;
        targetData[4] = abi.encodeWithSignature("add_liquidity(uint256[],uint256)", amounts, 0);
        uint256 lpTokens = 98371392079353838711;
        targetData[5] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "weETH_wETH_Curve_Gauge"), type(uint256).max
        );
        targetData[6] = abi.encodeWithSignature("deposit(uint256,address)", lpTokens, address(boringVault));
        targetData[7] = abi.encodeWithSignature("withdraw(uint256)", lpTokens);
        targetData[8] = abi.encodeWithSignature("claim_rewards(address)", address(boringVault));
        targetData[9] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "convexCurveMainnetBooster"), type(uint256).max
        );
        targetData[10] = abi.encodeWithSignature("deposit(uint256,uint256,bool)", 275, lpTokens, true);
        targetData[11] = abi.encodeWithSignature("withdrawAndUnwrap(uint256,bool)", lpTokens, true);
        targetData[12] = abi.encodeWithSignature(
            "getReward(address,bool)", getAddress(sourceChain, "weETH_wETH_Convex_Reward"), true
        );
        amounts[0] = 0;
        amounts[1] = 0;
        targetData[13] = abi.encodeWithSignature("remove_liquidity(uint256,uint256[])", lpTokens, amounts);
        address[] memory decodersAndSanitizers = new address[](14);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[8] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[9] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[10] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[11] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[12] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[13] = rawDataDecoderAndSanitizer;
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](14)
        );
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
