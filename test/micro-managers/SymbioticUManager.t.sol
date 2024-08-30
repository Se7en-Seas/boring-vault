// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {SymbioticUManager, DefaultCollateral} from "src/micro-managers/SymbioticUManager.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract SymbioticUManagerTest is Test, MainnetAddresses, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    BoringVault public boringVault = BoringVault(payable(0x917ceE801a67f933F2e6b33fC0cD1ED2d5909D88));
    ManagerWithMerkleVerification public manager =
        ManagerWithMerkleVerification(0xA24dD7B978Fbe36125cC4817192f7b8AA18d213c);
    address public managerAddress = 0xA24dD7B978Fbe36125cC4817192f7b8AA18d213c;
    address public rawDataDecoderAndSanitizer = 0xdaEfE2146908BAd73A1C45f75eB2B8E46935c781;
    address public accountantAddress = 0xbe16605B22a7faCEf247363312121670DFe5afBE;
    uint8 public constant STRATEGIST_ROLE = 7;

    RolesAuthority public rolesAuthority = RolesAuthority(0x402DFF43b4f24b006BBD6520a11C169f81085039);
    SymbioticUManager public symbioticUManager;

    address public wstETHSymbioticWhale = 0x7a4EffD87C2f3C55CA251080b1343b605f327E3a;

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 20083900;

        _startFork(rpcKey, blockNumber);

        symbioticUManager = new SymbioticUManager(address(this), rolesAuthority, address(manager), address(boringVault));

        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", address(boringVault));
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        leafIndex = type(uint256).max;
        _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "wstETHDefaultCollateral"));
        _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "cbETHDefaultCollateral"));
        _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "wBETHDefaultCollateral"));
        _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "rETHDefaultCollateral"));
        _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "mETHDefaultCollateral"));
        _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "swETHDefaultCollateral"));
        _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "sfrxETHDefaultCollateral"));
        _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "ETHxDefaultCollateral"));

        bytes32[][] memory merkleTree = _generateMerkleTree(leafs);

        vm.startPrank(dev1Address);
        manager.setManageRoot(address(symbioticUManager), merkleTree[merkleTree.length - 1][0]);
        rolesAuthority.setUserRole(address(symbioticUManager), STRATEGIST_ROLE, true);
        vm.stopPrank();
        symbioticUManager.updateMerkleTree(merkleTree, true);

        // Force Whale to remove 10,000 collateral.
        vm.prank(wstETHSymbioticWhale);
        DefaultCollateral(wstETHDefaultCollateral).withdraw(address(boringVault), 10_000e18);

        symbioticUManager.setConfiguration(DefaultCollateral(wstETHDefaultCollateral), 1, rawDataDecoderAndSanitizer);
    }

    function testSniperBotSpecifiedAmountNoApproval(uint256 amount) external {
        amount = bound(amount, 2, 10_000e18);
        // In a previous transaction, strategist has approved default collateral to spend wstETH.
        vm.prank(address(boringVault));
        WSTETH.approve(wstETHDefaultCollateral, type(uint256).max);
        DefaultCollateral defaultCollateral = DefaultCollateral(wstETHDefaultCollateral);

        // Sniper bot deposits 10,000 wstETH.
        symbioticUManager.assemble(defaultCollateral, amount);

        assertEq(defaultCollateral.balanceOf(address(boringVault)), amount, "BoringVault should have deposited amount");
    }

    function testSniperBotSpecifiedAmountWithApproval(uint256 amount) external {
        amount = bound(amount, 2, 10_000e18);
        DefaultCollateral defaultCollateral = DefaultCollateral(wstETHDefaultCollateral);

        // Sniper bot deposits approves, then 10,000 wstETH.
        symbioticUManager.assemble(defaultCollateral, amount);

        assertEq(defaultCollateral.balanceOf(address(boringVault)), amount, "BoringVault should have deposited amount");
        assertEq(
            WSTETH.allowance(address(boringVault), wstETHDefaultCollateral),
            0,
            "Default Collateral should have no allowance"
        );
    }

    function testSniperBotApeAmountNoApprovalLimitVaultBalance(uint256 amount) external {
        amount = bound(amount, 2, 10_000e18);
        uint256 wstETHBalance = amount / 2;

        // Make BoringVaults wstETH balance equal wstETHBalance.
        deal(address(WSTETH), address(boringVault), wstETHBalance);

        // In a previous transaction, strategist has approved default collateral to spend wstETH.
        vm.prank(address(boringVault));
        WSTETH.approve(wstETHDefaultCollateral, type(uint256).max);
        DefaultCollateral defaultCollateral = DefaultCollateral(wstETHDefaultCollateral);

        // Sniper bot deposits as much wstETH as possible.
        symbioticUManager.fullAssemble(defaultCollateral);

        assertEq(
            defaultCollateral.balanceOf(address(boringVault)),
            wstETHBalance,
            "BoringVault should have deposited wstETHBalance"
        );
    }

    function testSniperBotApeAmountWithApprovalLimitVaultBalance(uint256 amount) external {
        amount = bound(amount, 2, 10_000e18);
        uint256 wstETHBalance = amount / 2;

        // Make BoringVaults wstETH balance equal wstETHBalance.
        deal(address(WSTETH), address(boringVault), wstETHBalance);

        DefaultCollateral defaultCollateral = DefaultCollateral(wstETHDefaultCollateral);

        // Sniper bot deposits as much wstETH as possible.
        symbioticUManager.fullAssemble(defaultCollateral);

        assertEq(
            defaultCollateral.balanceOf(address(boringVault)),
            wstETHBalance,
            "BoringVault should have deposited wstETHBalance"
        );
        assertEq(
            WSTETH.allowance(address(boringVault), wstETHDefaultCollateral),
            0,
            "Default Collateral should have no allowance"
        );
    }

    function testSniperBotApeAmountNoApprovalLimitCollateralLimit(uint256 wstETHBalance) external {
        wstETHBalance = bound(wstETHBalance, 10_000e18, 100_000e18);
        uint256 collateralLimit = 10_000e18;

        // Make BoringVaults wstETH balance equal wstETHBalance.
        deal(address(WSTETH), address(boringVault), wstETHBalance);

        // In a previous transaction, strategist has approved default collateral to spend wstETH.
        vm.prank(address(boringVault));
        WSTETH.approve(wstETHDefaultCollateral, type(uint256).max);
        DefaultCollateral defaultCollateral = DefaultCollateral(wstETHDefaultCollateral);

        // Sniper bot deposits as much wstETH as possible.
        symbioticUManager.fullAssemble(defaultCollateral);

        assertEq(
            defaultCollateral.balanceOf(address(boringVault)),
            collateralLimit,
            "BoringVault should have deposited collateralLimit"
        );
    }

    function testSniperBotApeAmountWithApprovalLimitCollateralLimit(uint256 wstETHBalance) external {
        wstETHBalance = bound(wstETHBalance, 10_000e18, 100_000e18);
        uint256 collateralLimit = 10_000e18;

        // Make BoringVaults wstETH balance equal wstETHBalance.
        deal(address(WSTETH), address(boringVault), wstETHBalance);

        DefaultCollateral defaultCollateral = DefaultCollateral(wstETHDefaultCollateral);

        // Sniper bot deposits as much wstETH as possible.
        symbioticUManager.fullAssemble(defaultCollateral);

        assertEq(
            defaultCollateral.balanceOf(address(boringVault)),
            collateralLimit,
            "BoringVault should have deposited collateralLimit"
        );
        assertEq(
            WSTETH.allowance(address(boringVault), wstETHDefaultCollateral),
            0,
            "Default Collateral should have no allowance"
        );
    }

    function testSettingMerkleTree() external {
        bytes32[][] memory merkleTree = symbioticUManager.viewMerkleTree();
        bytes32 realHash = merkleTree[1][0];
        bytes32 badHash = keccak256(abi.encode("badHash"));
        merkleTree[1][0] = badHash;

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    SymbioticUManager.SymbioticUManager__BadHash.selector,
                    merkleTree[0][0],
                    merkleTree[0][1],
                    badHash,
                    realHash
                )
            )
        );
        symbioticUManager.updateMerkleTree(merkleTree, true);

        // Correct the hash.
        merkleTree[1][0] = realHash;

        // Change the root hash.
        vm.prank(dev1Address);
        manager.setManageRoot(address(symbioticUManager), badHash);

        vm.expectRevert(bytes(abi.encodeWithSelector(SymbioticUManager.SymbioticUManager__InvalidMerkleTree.selector)));
        symbioticUManager.updateMerkleTree(merkleTree, true);

        // Make the tree malformed.
        merkleTree[1] = new bytes32[](1);

        vm.expectRevert(bytes(abi.encodeWithSelector(SymbioticUManager.SymbioticUManager__InvalidMerkleTree.selector)));
        symbioticUManager.updateMerkleTree(merkleTree, true);

        merkleTree[0] = new bytes32[](4);

        vm.expectRevert(bytes(abi.encodeWithSelector(SymbioticUManager.SymbioticUManager__InvalidMerkleTree.selector)));
        symbioticUManager.updateMerkleTree(merkleTree, true);

        // However, all checks can be bypassed, and an invalid merkle tree can be set.
        symbioticUManager.updateMerkleTree(merkleTree, false);
    }

    function testReverts() external {
        DefaultCollateral defaultCollateral = DefaultCollateral(mETHDefaultCollateral);

        // Sniper bot calls assemble for unknown collateral.
        vm.expectRevert(
            bytes(abi.encodeWithSelector(SymbioticUManager.SymbioticUManager__DecoderAndSanitizerNotSet.selector))
        );
        symbioticUManager.assemble(defaultCollateral, 0);

        // Admin messes up configuration.
        vm.expectRevert(
            bytes(abi.encodeWithSelector(SymbioticUManager.SymbioticUManager__DecoderAndSanitizerNotSet.selector))
        );
        symbioticUManager.setConfiguration(defaultCollateral, 0, address(0));

        vm.expectRevert(
            bytes(abi.encodeWithSelector(SymbioticUManager.SymbioticUManager__MinimumDepositNotSet.selector))
        );
        symbioticUManager.setConfiguration(defaultCollateral, 0, rawDataDecoderAndSanitizer);

        symbioticUManager.setConfiguration(defaultCollateral, 1_000e18, rawDataDecoderAndSanitizer);

        // Sniper bot tries assembling with a specified amount that is too large.
        uint256 limitDelta = defaultCollateral.limit() - defaultCollateral.totalSupply();
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    SymbioticUManager.SymbioticUManager__DepositAmountExceedsLimit.selector, 1_000e18, limitDelta
                )
            )
        );
        symbioticUManager.assemble(defaultCollateral, 1_000e18);

        // Sniper bot tries assembling with a specified amount that is below the limit but larger than the mETH balance.
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    SymbioticUManager.SymbioticUManager__DepositAmountExceedsBalance.selector, limitDelta, 0
                )
            )
        );
        symbioticUManager.assemble(defaultCollateral, limitDelta);

        // Give BoringVault some mETH.
        deal(address(METH), address(boringVault), 10_000e18);

        // Sniper bot tries full assembling, but limit delta is less than minimum deposit.
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    SymbioticUManager.SymbioticUManager__DepositAmountTooSmall.selector, limitDelta, 1_000e18
                )
            )
        );
        symbioticUManager.fullAssemble(defaultCollateral);

        // Only way sniper bot can deposit is if minimumDeposit is lowered and it is assembles using limitDelta.
        symbioticUManager.setConfiguration(defaultCollateral, 1, rawDataDecoderAndSanitizer);
        symbioticUManager.assemble(defaultCollateral, limitDelta);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
