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
    EtherFiLiquidDecoderAndSanitizer,
    MorphoBlueDecoderAndSanitizer,
    UniswapV3DecoderAndSanitizer,
    BalancerV2DecoderAndSanitizer,
    PendleRouterDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/EtherFiLiquidDecoderAndSanitizer.sol";
import {EtherFiLiquidUsdDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidUsdDecoderAndSanitizer.sol";
import {LidoLiquidDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LidoLiquidDecoderAndSanitizer.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {IUniswapV3Router} from "src/interfaces/IUniswapV3Router.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {
    PointFarmingDecoderAndSanitizer,
    EigenLayerLSTStakingDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/PointFarmingDecoderAndSanitizer.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract ManagerWithMerkleVerificationTest is Test, MainnetAddresses {
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
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        // uint256 blockNumber = 19369928;
        uint256 blockNumber = 19826676;
        // uint256 blockNumber = 20036275;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager = new ManagerWithMerkleVerification(address(this), address(boringVault), vault);

        rawDataDecoderAndSanitizer =
            address(new EtherFiLiquidDecoderAndSanitizer(address(boringVault), uniswapV3NonFungiblePositionManager));

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
        rolesAuthority.setUserRole(vault, BALANCER_VAULT_ROLE, true);

        // Allow the boring vault to receive ETH.
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);
    }

    function testManagerMerkleVerificationHappyPath() external {
        // Allow the manager to call the USDC approve function to a specific address,
        // and the USDT transfer function to a specific address.
        address usdcSpender = vm.addr(0xDEAD);
        address usdtTo = vm.addr(0xDEAD1);
        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        leafs[0] = ManageLeaf(address(USDC), false, "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = usdcSpender;
        leafs[1] = ManageLeaf(address(USDT), false, "approve(address,uint256)", new address[](1));
        leafs[1].argumentAddresses[0] = usdtTo;

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[1][0]);

        address[] memory targets = new address[](2);
        targets[0] = address(USDC);
        targets[1] = address(USDT);

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, usdcSpender, 777);
        targetData[1] = abi.encodeWithSelector(ERC20.approve.selector, usdtTo, 777);

        (bytes32[][] memory manageProofs) = _getProofsUsingTree(leafs, manageTree);

        uint256[] memory values = new uint256[](2);

        deal(address(USDT), address(boringVault), 777);

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256 gas = gasleft();
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        console.log("Gas used", gas - gasleft());

        assertEq(USDC.allowance(address(boringVault), usdcSpender), 777, "USDC should have an allowance");
        assertEq(USDT.allowance(address(boringVault), usdtTo), 777, "USDT should have have an allowance");
    }

    function testSwellSimpleStakingIntegration() external {
        deal(address(WETH), address(boringVault), 1_000e18);

        // update DecoderAndSanitizer
        rawDataDecoderAndSanitizer = address(new PointFarmingDecoderAndSanitizer(address(boringVault)));

        // approve
        // Call deposit
        // withdraw
        // complete withdraw
        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        leafs[0] = ManageLeaf(address(WETH), false, "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = swellSimpleStaking;
        leafs[1] = ManageLeaf(swellSimpleStaking, false, "deposit(address,uint256,address)", new address[](2));
        leafs[1].argumentAddresses[0] = address(WETH);
        leafs[1].argumentAddresses[1] = address(boringVault);
        leafs[2] = ManageLeaf(swellSimpleStaking, false, "withdraw(address,uint256,address)", new address[](2));
        leafs[2].argumentAddresses[0] = address(WETH);
        leafs[2].argumentAddresses[1] = address(boringVault);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = address(WETH);
        targets[1] = swellSimpleStaking;
        targets[2] = swellSimpleStaking;

        bytes[] memory targetData = new bytes[](3);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", swellSimpleStaking, type(uint256).max);
        targetData[1] =
            abi.encodeWithSignature("deposit(address,uint256,address)", WETH, 1_000e18, address(boringVault));
        targetData[2] =
            abi.encodeWithSignature("withdraw(address,uint256,address)", WETH, 1_000e18, address(boringVault));

        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](3);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertEq(WETH.balanceOf(address(boringVault)), 1_000e18, "BoringVault should have received 1,000 WETH");
    }

    function testZircuitSimpleStakingIntegration() external {
        deal(address(WETH), address(boringVault), 1_000e18);

        // update DecoderAndSanitizer
        rawDataDecoderAndSanitizer = address(new PointFarmingDecoderAndSanitizer(address(boringVault)));

        // approve
        // Call deposit
        // withdraw
        // complete withdraw
        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        leafs[0] = ManageLeaf(address(WETH), false, "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = zircuitSimpleStaking;
        leafs[1] = ManageLeaf(zircuitSimpleStaking, false, "depositFor(address,address,uint256)", new address[](2));
        leafs[1].argumentAddresses[0] = address(WETH);
        leafs[1].argumentAddresses[1] = address(boringVault);
        leafs[2] = ManageLeaf(zircuitSimpleStaking, false, "withdraw(address,uint256)", new address[](1));
        leafs[2].argumentAddresses[0] = address(WETH);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = address(WETH);
        targets[1] = zircuitSimpleStaking;
        targets[2] = zircuitSimpleStaking;

        bytes[] memory targetData = new bytes[](3);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", zircuitSimpleStaking, type(uint256).max);
        targetData[1] =
            abi.encodeWithSignature("depositFor(address,address,uint256)", WETH, address(boringVault), 1_000e18);
        targetData[2] = abi.encodeWithSignature("withdraw(address,uint256)", WETH, 1_000e18);

        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](3);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertEq(WETH.balanceOf(address(boringVault)), 1_000e18, "BoringVault should have received 1,000 WETH");
    }

    function testEthenaWithdrawIntegration() external {
        // Give BoringVault some sUSDE.
        uint256 assets = 100_000e18;
        deal(address(SUSDE), address(boringVault), assets);

        // update DecoderAndSanitizer
        rawDataDecoderAndSanitizer =
            address(new EtherFiLiquidUsdDecoderAndSanitizer(address(boringVault), uniswapV3NonFungiblePositionManager));

        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        leafs[0] = ManageLeaf(address(SUSDE), false, "cooldownAssets(uint256)", new address[](0));
        leafs[1] = ManageLeaf(address(SUSDE), false, "cooldownShares(uint256)", new address[](0));
        leafs[2] = ManageLeaf(address(SUSDE), false, "unstake(address)", new address[](1));
        leafs[2].argumentAddresses[0] = address(boringVault);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = address(SUSDE);
        targets[1] = address(SUSDE);

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("cooldownAssets(uint256)", assets / 2);
        uint256 shares = ERC4626(address(SUSDE)).previewWithdraw(assets / 2);
        targetData[1] = abi.encodeWithSignature("cooldownShares(uint256)", shares);

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        EthenaSusde susde = EthenaSusde(address(SUSDE));
        (uint104 end, uint152 amount) = susde.cooldowns(address(boringVault));
        assertGt(end, block.timestamp, "Cooldown end should have been set.");
        assertEq(amount, assets, "Cooldown amount should equal assets.");

        // Wait the cooldown duration.
        skip(susde.cooldownDuration());

        manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[2];

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](1);
        targets[0] = address(SUSDE);

        targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature("unstake(address)", address(boringVault));

        decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        values = new uint256[](1);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertEq(USDE.balanceOf(address(boringVault)), amount, "BoringVault should have received unstaked USDe.");
    }

    function testFluidFTokenIntegration() external {
        // Give BoringVault some USDC.
        uint256 assets = 100_000e6;
        deal(address(USDT), address(boringVault), assets);

        // update DecoderAndSanitizer
        rawDataDecoderAndSanitizer =
            address(new EtherFiLiquidUsdDecoderAndSanitizer(address(boringVault), uniswapV3NonFungiblePositionManager));

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        leafs[0] = ManageLeaf(address(USDT), false, "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = fUSDT;
        leafs[1] = ManageLeaf(fUSDT, false, "deposit(uint256,address,uint256)", new address[](1));
        leafs[1].argumentAddresses[0] = address(boringVault);
        leafs[2] = ManageLeaf(fUSDT, false, "mint(uint256,address,uint256)", new address[](1));
        leafs[2].argumentAddresses[0] = address(boringVault);
        leafs[3] = ManageLeaf(fUSDT, false, "withdraw(uint256,address,address,uint256)", new address[](2));
        leafs[3].argumentAddresses[0] = address(boringVault);
        leafs[3].argumentAddresses[1] = address(boringVault);
        leafs[4] = ManageLeaf(fUSDT, false, "redeem(uint256,address,address,uint256)", new address[](2));
        leafs[4].argumentAddresses[0] = address(boringVault);
        leafs[4].argumentAddresses[1] = address(boringVault);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](5);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];
        manageLeafs[3] = leafs[3];
        manageLeafs[4] = leafs[4];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](5);
        targets[0] = address(USDT);
        targets[1] = fUSDT;
        targets[2] = fUSDT;
        targets[3] = fUSDT;
        targets[4] = fUSDT;

        bytes[] memory targetData = new bytes[](5);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", fUSDT, type(uint256).max);
        targetData[1] = abi.encodeWithSignature("deposit(uint256,address,uint256)", assets / 2, address(boringVault), 0);
        targetData[2] = abi.encodeWithSignature(
            "mint(uint256,address,uint256)", type(uint256).max, address(boringVault), type(uint256).max
        ); // Use first type uint256 max to specify to use full USDT balanace.
        targetData[3] = abi.encodeWithSignature(
            "withdraw(uint256,address,address,uint256)",
            assets / 2,
            address(boringVault),
            address(boringVault),
            type(uint256).max
        );
        targetData[4] = abi.encodeWithSignature(
            "redeem(uint256,address,address,uint256)", type(uint256).max, address(boringVault), address(boringVault), 0
        );

        address[] memory decodersAndSanitizers = new address[](5);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](5);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertApproxEqAbs(
            USDT.balanceOf(address(boringVault)), assets, 2, "BoringVault should have received all USDT back."
        );
        assertEq(ERC20(fUSDT).balanceOf(address(boringVault)), 0, "BoringVault should have withdrawn all fUSDT.");
    }

    function testReverts() external {
        bytes32[][] memory manageProofs;
        address[] memory targets;
        targets = new address[](1);
        bytes[] memory targetData;
        uint256[] memory values;
        address[] memory decodersAndSanitizers;

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__InvalidManageProofLength.selector
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        manageProofs = new bytes32[][](1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__InvalidTargetDataLength.selector
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        targetData = new bytes[](1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__InvalidValuesLength.selector
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        values = new uint256[](1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__InvalidDecodersAndSanitizersLength.selector
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        decodersAndSanitizers = new address[](1);

        targets[0] = address(USDC);
        targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(this), 1_000);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector,
                targets[0],
                targetData[0],
                values[0]
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Set the manage root to be the leaf of the USDC approve function
        bytes32 manageRoot = keccak256(
            abi.encodePacked(rawDataDecoderAndSanitizer, targets[0], false, bytes4(targetData[0]), address(this))
        );
        manager.setManageRoot(address(this), manageRoot);

        // Call now works.
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Check `flashLoan`
        address[] memory tokens;
        uint256[] memory amounts;

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__OnlyCallableByBoringVault.selector
            )
        );
        manager.flashLoan(address(this), tokens, amounts, abi.encode(0));

        // Check `receiveFlashLoan`
        uint256[] memory feeAmounts;

        address attacker = vm.addr(1);
        vm.startPrank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__OnlyCallableByBalancerVault.selector
            )
        );
        manager.receiveFlashLoan(tokens, amounts, feeAmounts, abi.encode(0));
        vm.stopPrank();

        // Someone else initiated a flash loan
        vm.startPrank(vault);
        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FlashLoanNotInProgress.selector
            )
        );
        manager.receiveFlashLoan(tokens, amounts, feeAmounts, abi.encode(0));
        vm.stopPrank();
    }

    function testManagementMintingSharesRevert() external {
        deal(address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        leafs[0] = ManageLeaf(address(this), false, "withdraw(uint256)", new address[](0));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = address(this);

        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature("withdraw(uint256)", 1);

        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification
                    .ManagerWithMerkleVerification__TotalSupplyMustRemainConstantDuringManagement
                    .selector
            )
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](1)
        );
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _generateProof(bytes32 leaf, bytes32[][] memory tree) internal pure returns (bytes32[] memory proof) {
        // The length of each proof is the height of the tree - 1.
        uint256 tree_length = tree.length;
        proof = new bytes32[](tree_length - 1);

        // Build the proof
        for (uint256 i; i < tree_length - 1; ++i) {
            // For each layer we need to find the leaf.
            for (uint256 j; j < tree[i].length; ++j) {
                if (leaf == tree[i][j]) {
                    // We have found the leaf, so now figure out if the proof needs the next leaf or the previous one.
                    proof[i] = j % 2 == 0 ? tree[i][j + 1] : tree[i][j - 1];
                    leaf = _hashPair(leaf, proof[i]);
                    break;
                }
            }
        }
    }

    function _getProofsUsingTree(ManageLeaf[] memory manageLeafs, bytes32[][] memory tree)
        internal
        view
        returns (bytes32[][] memory proofs)
    {
        proofs = new bytes32[][](manageLeafs.length);
        for (uint256 i; i < manageLeafs.length; ++i) {
            // Generate manage proof.
            bytes4 selector = bytes4(keccak256(abi.encodePacked(manageLeafs[i].signature)));
            bytes memory rawDigest = abi.encodePacked(
                rawDataDecoderAndSanitizer, manageLeafs[i].target, manageLeafs[i].canSendValue, selector
            );
            uint256 argumentAddressesLength = manageLeafs[i].argumentAddresses.length;
            for (uint256 j; j < argumentAddressesLength; ++j) {
                rawDigest = abi.encodePacked(rawDigest, manageLeafs[i].argumentAddresses[j]);
            }
            bytes32 leaf = keccak256(rawDigest);
            proofs[i] = _generateProof(leaf, tree);
        }
    }

    function _buildTrees(bytes32[][] memory merkleTreeIn) internal pure returns (bytes32[][] memory merkleTreeOut) {
        // We are adding another row to the merkle tree, so make merkleTreeOut be 1 longer.
        uint256 merkleTreeIn_length = merkleTreeIn.length;
        merkleTreeOut = new bytes32[][](merkleTreeIn_length + 1);
        uint256 layer_length;
        // Iterate through merkleTreeIn to copy over data.
        for (uint256 i; i < merkleTreeIn_length; ++i) {
            layer_length = merkleTreeIn[i].length;
            merkleTreeOut[i] = new bytes32[](layer_length);
            for (uint256 j; j < layer_length; ++j) {
                merkleTreeOut[i][j] = merkleTreeIn[i][j];
            }
        }

        uint256 next_layer_length;
        if (layer_length % 2 != 0) {
            next_layer_length = (layer_length + 1) / 2;
        } else {
            next_layer_length = layer_length / 2;
        }
        merkleTreeOut[merkleTreeIn_length] = new bytes32[](next_layer_length);
        uint256 count;
        for (uint256 i; i < layer_length; i += 2) {
            merkleTreeOut[merkleTreeIn_length][count] =
                _hashPair(merkleTreeIn[merkleTreeIn_length - 1][i], merkleTreeIn[merkleTreeIn_length - 1][i + 1]);
            count++;
        }

        if (next_layer_length > 1) {
            // We need to process the next layer of leaves.
            merkleTreeOut = _buildTrees(merkleTreeOut);
        }
    }

    struct ManageLeaf {
        address target;
        bool canSendValue;
        string signature;
        address[] argumentAddresses;
    }

    function _generateMerkleTree(ManageLeaf[] memory manageLeafs) internal view returns (bytes32[][] memory tree) {
        uint256 leafsLength = manageLeafs.length;
        bytes32[][] memory leafs = new bytes32[][](1);
        leafs[0] = new bytes32[](leafsLength);
        for (uint256 i; i < leafsLength; ++i) {
            bytes4 selector = bytes4(keccak256(abi.encodePacked(manageLeafs[i].signature)));
            bytes memory rawDigest = abi.encodePacked(
                rawDataDecoderAndSanitizer, manageLeafs[i].target, manageLeafs[i].canSendValue, selector
            );
            uint256 argumentAddressesLength = manageLeafs[i].argumentAddresses.length;
            for (uint256 j; j < argumentAddressesLength; ++j) {
                rawDigest = abi.encodePacked(rawDigest, manageLeafs[i].argumentAddresses[j]);
            }
            leafs[0][i] = keccak256(rawDigest);
        }
        tree = _buildTrees(leafs);
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }

    function _finalizeRequest(uint256 requestId, uint256 amount) internal {
        // Spoof unstEth contract into finalizing our request.
        IWithdrawRequestNft w = IWithdrawRequestNft(withdrawalRequestNft);
        address owner = w.owner();
        vm.startPrank(owner);
        w.updateAdmin(address(this), true);
        vm.stopPrank();

        ILiquidityPool lp = ILiquidityPool(EETH_LIQUIDITY_POOL);

        deal(address(this), amount);
        lp.deposit{value: amount}();
        address admin = lp.etherFiAdminContract();

        vm.startPrank(admin);
        lp.addEthAmountLockedForWithdrawal(uint128(amount));
        vm.stopPrank();

        w.finalizeRequests(requestId);
    }

    function withdraw(uint256 amount) external {
        boringVault.enter(address(0), ERC20(address(0)), 0, address(this), amount);
    }
}

interface IWithdrawRequestNft {
    struct WithdrawRequest {
        uint96 amountOfEEth;
        uint96 shareOfEEth;
        bool isValid;
        uint32 feeGwei;
    }

    function claimWithdraw(uint256 tokenId) external;

    function getRequest(uint256 requestId) external view returns (WithdrawRequest memory);

    function finalizeRequests(uint256 requestId) external;

    function owner() external view returns (address);

    function updateAdmin(address admin, bool isAdmin) external;
}

interface ILiquidityPool {
    function deposit() external payable returns (uint256);

    function requestWithdraw(address recipient, uint256 amount) external returns (uint256);

    function amountForShare(uint256 shares) external view returns (uint256);

    function etherFiAdminContract() external view returns (address);

    function addEthAmountLockedForWithdrawal(uint128 _amount) external;
}

interface IUNSTETH {
    function finalize(uint256 _lastRequestIdToBeFinalized, uint256 _maxShareRate) external payable;

    function getRoleMember(bytes32 role, uint256 index) external view returns (address);

    function FINALIZE_ROLE() external view returns (bytes32);

    function findCheckpointHints(uint256[] memory requestIds, uint256 firstIndex, uint256 lastIndex)
        external
        view
        returns (uint256[] memory);

    function getLastCheckpointIndex() external view returns (uint256);
}

interface EthenaSusde {
    function cooldownDuration() external view returns (uint24);
    function cooldowns(address) external view returns (uint104 cooldownEnd, uint152 underlyingAmount);
}
