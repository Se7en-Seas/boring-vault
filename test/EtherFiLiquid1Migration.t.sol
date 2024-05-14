// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {AtomicQueue} from "src/atomic-queue/AtomicQueue.sol";
import {AtomicSolver} from "src/atomic-queue/AtomicSolver.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {IWEETH} from "src/interfaces/IStaking.sol";
import {ILiquidityPool} from "src/interfaces/IStaking.sol";
import {WETH} from "@solmate/tokens/WETH.sol";
import {EtherFiLiquidDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/EtherFiLiquidDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {EtherFiLiquid1} from "src/interfaces/EtherFiLiquid1.sol";
import {CellarMigrationAdaptor} from "src/migration/CellarMigrationAdaptor.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {GenericRateProvider} from "src/helper/GenericRateProvider.sol";
import {MigrationSharePriceOracle} from "src/migration/MigrationSharePriceOracle.sol";
import {CompleteMigration, ERC4626} from "src/migration/CompleteMigration.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract EtherFiLiquid1MigrationTest is Test, MainnetAddresses {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    BoringVault public boringVault;
    ManagerWithMerkleVerification public manager;
    TellerWithMultiAssetSupport public teller;
    AccountantWithRateProviders public accountant;
    AtomicQueue public atomic_queue;
    AtomicSolver public atomic_solver;
    address public rawDataDecoderAndSanitizer;
    CellarMigrationAdaptor public migrationAdaptor;
    EtherFiLiquid1 public etherFiLiquid1;
    RolesAuthority public rolesAuthority;
    GenericRateProvider public ptRateProvider;
    GenericRateProvider public ytRateProvider;
    MigrationSharePriceOracle public migrationSharePriceOracle;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;
    uint8 public constant MINTER_ROLE = 7;
    uint8 public constant BURNER_ROLE = 8;
    uint8 public constant UPDATE_EXCHANGE_RATE_ROLE = 9;
    uint8 public constant SOLVER_ROLE = 10;

    address public multisig = vm.addr(123456789);
    address public strategist = vm.addr(987654321);
    address public payout_address = vm.addr(777);
    address public weth_user = vm.addr(11);
    address public eeth_user = vm.addr(111);
    address public weeth_user = vm.addr(1111);
    ERC20 internal constant NATIVE_ERC20 = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    address public balancer_vault = vault;
    address public weEthOracle = 0x3fa58b74e9a8eA8768eb33c8453e9C2Ed089A40a;
    address public weEthIrm = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        // uint256 blockNumber = 19466630; // from before first rebalance
        uint256 blockNumber = 19862477;
        _startFork(rpcKey, blockNumber);

        etherFiLiquid1 = EtherFiLiquid1(0xeA1A6307D9b18F8d1cbf1c3Dd6aad8416C06a221);

        boringVault = new BoringVault(multisig, "Boring Vault", "BV", 18);

        manager = new ManagerWithMerkleVerification(multisig, address(boringVault), vault);

        accountant = new AccountantWithRateProviders(
            multisig, address(boringVault), payout_address, 1e18, address(WETH), 1.1e4, 0.9e4, 1, 0.01e4
        );

        teller = new TellerWithMultiAssetSupport(multisig, address(boringVault), address(accountant), address(WETH));

        migrationAdaptor = new CellarMigrationAdaptor(address(boringVault), address(accountant), address(teller));

        migrationSharePriceOracle = new MigrationSharePriceOracle(address(etherFiLiquid1), address(accountant));

        rawDataDecoderAndSanitizer =
            address(new EtherFiLiquidDecoderAndSanitizer(address(boringVault), uniswapV3NonFungiblePositionManager));

        bytes4 selector = bytes4(keccak256(abi.encodePacked("getValue(address,uint256,address)")));
        uint256 amount = 1e18;
        bytes32 pt = 0x000000000000000000000000c69Ad9baB1dEE23F4605a82b3354F8E40d1E5966; // pendleEethPt
        bytes32 quote = 0x000000000000000000000000C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // wETH

        ptRateProvider =
            new GenericRateProvider(liquidV1PriceRouter, selector, pt, bytes32(amount), quote, 0, 0, 0, 0, 0);

        bytes32 yt = 0x000000000000000000000000fb35Fd0095dD1096b1Ca49AD44d8C5812A201677; // pendleEethYt

        ytRateProvider =
            new GenericRateProvider(liquidV1PriceRouter, selector, yt, bytes32(amount), quote, 0, 0, 0, 0, 0);

        // Deploy queue.
        atomic_queue = new AtomicQueue();
        atomic_solver = new AtomicSolver(address(this), vault);

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        vm.startPrank(multisig);
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);
        vm.stopPrank();

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
        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);

        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);
        rolesAuthority.setPublicCapability(
            address(teller), TellerWithMultiAssetSupport.depositWithPermit.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.addAsset.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.removeAsset.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant), AccountantWithRateProviders.pause.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant), AccountantWithRateProviders.unpause.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant), AccountantWithRateProviders.updateDelay.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant), AccountantWithRateProviders.updateUpper.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant), AccountantWithRateProviders.updateLower.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant), AccountantWithRateProviders.updateManagementFee.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant), AccountantWithRateProviders.updatePayoutAddress.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant), AccountantWithRateProviders.setRateProviderData.selector, true
        );
        rolesAuthority.setRoleCapability(
            UPDATE_EXCHANGE_RATE_ROLE,
            address(accountant),
            AccountantWithRateProviders.updateExchangeRate.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            BORING_VAULT_ROLE, address(accountant), AccountantWithRateProviders.claimFees.selector, true
        );
        rolesAuthority.setRoleCapability(
            SOLVER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkDeposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            SOLVER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
        );

        // Grant roles
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(strategist, STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(multisig, ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        rolesAuthority.setUserRole(vault, BALANCER_VAULT_ROLE, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);
        rolesAuthority.setUserRole(address(this), UPDATE_EXCHANGE_RATE_ROLE, true);
        rolesAuthority.setUserRole(address(atomic_solver), SOLVER_ROLE, true);
        rolesAuthority.setUserRole(address(atomic_solver), SOLVER_ROLE, true);

        vm.startPrank(multisig);
        accountant.setRateProviderData(EETH, true, address(0));
        accountant.setRateProviderData(WEETH, false, address(WEETH_RATE_PROVIDER));
        accountant.setRateProviderData(ERC20(pendleEethPt), false, address(ptRateProvider));
        accountant.setRateProviderData(ERC20(pendleEethYt), false, address(ytRateProvider));
        teller.addAsset(WETH);
        teller.addAsset(NATIVE_ERC20);
        teller.addAsset(EETH);
        teller.addAsset(WEETH);
        teller.addAsset(ERC20(pendleEethPt));
        teller.addAsset(ERC20(pendleEethYt));
        vm.stopPrank();

        uint256 wETH_amount = 1_500e18;
        deal(address(WETH), weth_user, wETH_amount);
        uint256 eETH_amount = 500e18;
        deal(eeth_user, eETH_amount + 1);
        vm.prank(eeth_user);
        ILiquidityPool(EETH_LIQUIDITY_POOL).deposit{value: eETH_amount + 1}();
        uint256 weETH_amount = uint256(1_000e18).mulDivDown(1e18, IRateProvider(WEETH_RATE_PROVIDER).getRate());
        deal(address(WEETH), weeth_user, weETH_amount);

        // vm.startPrank(weth_user);
        // WETH.safeApprove(address(boringVault), wETH_amount);
        // teller.deposit(WETH, wETH_amount, 0);
        // vm.stopPrank();

        // vm.startPrank(eeth_user);
        // EETH.safeApprove(address(boringVault), eETH_amount);
        // teller.deposit(EETH, eETH_amount, 0);
        // vm.stopPrank();

        // vm.startPrank(weeth_user);
        // WEETH.safeApprove(address(boringVault), weETH_amount);
        // teller.deposit(WEETH, weETH_amount, 0);
        // vm.stopPrank();
    }

    function testMigration() external {
        // Setup Cellar to use migration adaptor.
        uint32 migrationPosition = 77777777;
        address cellarOwner = etherFiLiquid1.owner();
        Registry registry = Registry(etherFiLiquid1.registry());
        address registryOwner = registry.owner();
        vm.startPrank(registryOwner);
        registry.trustAdaptor(address(migrationAdaptor));
        registry.trustPosition(migrationPosition, address(migrationAdaptor), hex"");
        vm.stopPrank();
        vm.startPrank(cellarOwner);
        etherFiLiquid1.addAdaptorToCatalogue(address(migrationAdaptor));
        etherFiLiquid1.addPositionToCatalogue(migrationPosition);
        etherFiLiquid1.addPosition(0, migrationPosition, abi.encode(true), false);
        vm.stopPrank();
        // Give EtherFiLiquid1 the appropriate roles so it can rebalance.
        rolesAuthority.setUserRole(address(etherFiLiquid1), SOLVER_ROLE, true);

        uint256 totalAssetsBefore = etherFiLiquid1.totalAssets();

        // Strategist rebalances all liquid assets into BoringVault.
        EtherFiLiquid1.AdaptorCall[] memory data = new EtherFiLiquid1.AdaptorCall[](1);
        bytes[] memory adaptorCalls = new bytes[](5);
        adaptorCalls[0] = abi.encodeWithSignature("deposit(address,uint256,uint256)", WETH, type(uint256).max, 0);
        adaptorCalls[1] = abi.encodeWithSignature("deposit(address,uint256,uint256)", EETH, type(uint256).max, 0);
        adaptorCalls[2] = abi.encodeWithSignature("deposit(address,uint256,uint256)", WEETH, type(uint256).max, 0);
        adaptorCalls[3] =
            abi.encodeWithSignature("deposit(address,uint256,uint256)", ERC20(pendleEethPt), type(uint256).max, 0);
        adaptorCalls[4] =
            abi.encodeWithSignature("deposit(address,uint256,uint256)", ERC20(pendleEethYt), type(uint256).max, 0);
        data[0] = EtherFiLiquid1.AdaptorCall({adaptor: address(migrationAdaptor), callData: adaptorCalls});
        vm.startPrank(cellarOwner);
        etherFiLiquid1.callOnAdaptor(data);
        vm.stopPrank();

        uint256 totalAssetsAfter = etherFiLiquid1.totalAssets();

        // There is a small change in total assets because the BoringVault prices weETH usinf the rate, but,
        // when the cellar prices weETH, there is some small rounding errors when getValue logic is used.
        assertApproxEqRel(
            totalAssetsAfter, totalAssetsBefore, 0.00000001e18, "Total assets should not change after migration."
        );

        // When users withdraw, they receive BoringVault shares.
        address user = 0x12e8987C762701d60f0FcfeE687Bb8E4c07555aa;
        uint256 assets = etherFiLiquid1.maxWithdraw(user);
        vm.startPrank(user);
        etherFiLiquid1.withdraw(assets, user, user);
        vm.stopPrank();

        assertGt(boringVault.balanceOf(user), 0, "User should have received BoringVault shares.");
    }

    function testMigrationWithSharePriceOracle() external {
        vm.warp(block.timestamp + 2);
        // Liquid V1 should be rebalanced into non yield bearing positions if possible.
        // This will keep the share price as stable as possible.
        // We will simulate this by forcing all positions out except wETH, then dealing the exact amount of wETH needed
        // such that total assets are the same as before.
        uint256 startingTotalAssets = etherFiLiquid1.totalAssets();
        uint256 boringVaultStartingSupply = boringVault.totalSupply();
        uint32 wETH_ERC20_Position = 1;
        uint32 migrationPosition = 77777777;
        address cellarOwner = etherFiLiquid1.owner();
        Registry registry = Registry(etherFiLiquid1.registry());
        address registryOwner = registry.owner();
        vm.startPrank(registryOwner);
        registry.distrustPosition(3);
        registry.distrustPosition(12);
        registry.distrustPosition(25);
        registry.distrustPosition(27);
        registry.distrustPosition(2);
        registry.distrustPosition(22);
        registry.distrustPosition(20);
        registry.distrustPosition(32);
        registry.distrustPosition(15);
        registry.distrustPosition(17);
        registry.distrustPosition(11);
        registry.distrustPosition(9);
        registry.distrustPosition(18);
        registry.distrustPosition(31);
        registry.distrustPosition(30);
        registry.distrustPosition(29);
        registry.distrustPosition(28);
        registry.distrustPosition(23);
        registry.distrustPosition(16);
        registry.distrustPosition(10);
        registry.distrustPosition(4);
        registry.distrustPosition(21);
        registry.trustAdaptor(address(migrationAdaptor));
        registry.trustPosition(migrationPosition, address(migrationAdaptor), hex"");
        registry.setAddress(1, address(migrationSharePriceOracle));
        vm.stopPrank();
        vm.startPrank(cellarOwner);
        etherFiLiquid1.setHoldingPosition(wETH_ERC20_Position);
        etherFiLiquid1.forcePositionOut(0, 3, false);
        etherFiLiquid1.forcePositionOut(0, 12, false);
        etherFiLiquid1.forcePositionOut(1, 25, false);
        etherFiLiquid1.forcePositionOut(1, 27, false);
        etherFiLiquid1.forcePositionOut(1, 2, false);
        etherFiLiquid1.forcePositionOut(1, 22, false);
        etherFiLiquid1.forcePositionOut(1, 20, false);
        etherFiLiquid1.forcePositionOut(1, 32, false);
        etherFiLiquid1.forcePositionOut(1, 15, false);
        etherFiLiquid1.forcePositionOut(1, 17, false);
        etherFiLiquid1.forcePositionOut(1, 11, false);
        etherFiLiquid1.forcePositionOut(1, 9, false);
        etherFiLiquid1.forcePositionOut(1, 18, false);
        etherFiLiquid1.forcePositionOut(1, 31, false);
        etherFiLiquid1.forcePositionOut(1, 30, false);
        etherFiLiquid1.forcePositionOut(1, 29, false);
        etherFiLiquid1.forcePositionOut(1, 28, false);
        etherFiLiquid1.forcePositionOut(1, 23, false);
        etherFiLiquid1.forcePositionOut(1, 16, false);
        etherFiLiquid1.forcePositionOut(1, 10, false);
        etherFiLiquid1.forcePositionOut(1, 4, false);
        etherFiLiquid1.forcePositionOut(0, 21, true);
        etherFiLiquid1.addAdaptorToCatalogue(address(migrationAdaptor));
        etherFiLiquid1.addPositionToCatalogue(migrationPosition);
        etherFiLiquid1.addPosition(0, migrationPosition, abi.encode(true), false);
        vm.stopPrank();

        // Give V1 wETH to cover value lost in forced out positions.
        deal(address(WETH), address(etherFiLiquid1), startingTotalAssets);

        assertEq(etherFiLiquid1.totalAssets(), startingTotalAssets, "Total assets should be the same after rebalance.");

        // Give EtherFiLiquid1 the appropriate roles so it can rebalance.
        rolesAuthority.setUserRole(address(etherFiLiquid1), SOLVER_ROLE, true);

        // Strategist rebalances all liquid assets into BoringVault.
        EtherFiLiquid1.AdaptorCall[] memory data = new EtherFiLiquid1.AdaptorCall[](1);
        bytes[] memory adaptorCalls = new bytes[](1);
        adaptorCalls[0] = abi.encodeWithSignature("deposit(address,uint256,uint256)", WETH, type(uint256).max, 0);
        data[0] = EtherFiLiquid1.AdaptorCall({adaptor: address(migrationAdaptor), callData: adaptorCalls});
        vm.startPrank(cellarOwner);
        etherFiLiquid1.callOnAdaptor(data);
        vm.stopPrank();

        assertApproxEqAbs(
            etherFiLiquid1.totalAssets(), startingTotalAssets, 1, "Total assets should be the same after migration."
        );

        // At this point we could continue migrating little by litle, but once all assets have been migrated, we can fix the share price.

        // Once all assets are migrated, match the share prices of the 2 vaults.
        rolesAuthority.setUserRole(0x2a07706473244BC757E10F2a9E86fB532828afe3, MINTER_ROLE, true);
        rolesAuthority.setUserRole(0x2a07706473244BC757E10F2a9E86fB532828afe3, BURNER_ROLE, true);
        rolesAuthority.setUserRole(0x2a07706473244BC757E10F2a9E86fB532828afe3, UPDATE_EXCHANGE_RATE_ROLE, true);
        new CompleteMigration(boringVault, ERC4626(address(etherFiLiquid1)), accountant);

        // Setup Cellar to use migration share price oracle.
        vm.startPrank(cellarOwner);
        etherFiLiquid1.setSharePriceOracle(1, address(migrationSharePriceOracle));
        vm.stopPrank();

        // We shut down v1 cellar for deposits.
        // At this point we make the V1 cellar liquid for user withdraws

        assertEq(
            etherFiLiquid1.totalSupply(),
            boringVault.balanceOf(address(etherFiLiquid1)),
            "BV share balance should match V1 total supply."
        );

        // TODO I belive there is a rounding error that makes this be slightly off.
        assertApproxEqRel(
            etherFiLiquid1.totalAssets(),
            startingTotalAssets,
            0.0001e12,
            "Total assets should be the same after everything."
        );

        // When users withdraw, they receive BoringVault shares.
        address user = 0x12e8987C762701d60f0FcfeE687Bb8E4c07555aa;
        uint256 assets = etherFiLiquid1.maxWithdraw(user);
        vm.startPrank(user);
        uint256 expectedBoringVaultShares = etherFiLiquid1.withdraw(assets, user, user);
        vm.stopPrank();

        assertApproxEqAbs(
            boringVault.balanceOf(user),
            expectedBoringVaultShares,
            1,
            "User should have received expected BoringVault shares."
        );

        // Check share prices match.
        uint256 realSharePrice = etherFiLiquid1.totalAssets().mulDivDown(1e18, etherFiLiquid1.totalSupply());
        uint256 approxSharePrice = etherFiLiquid1.previewRedeem(1e18);

        assertApproxEqAbs(realSharePrice, approxSharePrice, 1, "Real share price should be the same as approx.");
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
        pure
        returns (bytes32[][] memory proofs)
    {
        proofs = new bytes32[][](manageLeafs.length);
        for (uint256 i; i < manageLeafs.length; ++i) {
            // Generate manage proof.
            bytes4 selector = bytes4(keccak256(abi.encodePacked(manageLeafs[i].signature)));
            bytes memory rawDigest = abi.encodePacked(manageLeafs[i].target, manageLeafs[i].canSendValue, selector);
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

    function _generateMerkleTree(ManageLeaf[] memory manageLeafs) internal pure returns (bytes32[][] memory tree) {
        uint256 leafsLength = manageLeafs.length;
        bytes32[][] memory leafs = new bytes32[][](1);
        leafs[0] = new bytes32[](leafsLength);
        for (uint256 i; i < leafsLength; ++i) {
            bytes4 selector = bytes4(keccak256(abi.encodePacked(manageLeafs[i].signature)));
            bytes memory rawDigest = abi.encodePacked(manageLeafs[i].target, manageLeafs[i].canSendValue, selector);
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
}

interface Registry {
    function owner() external view returns (address);
    function trustAdaptor(address adaptor) external;
    function trustPosition(uint32 id, address adaptor, bytes calldata adaptorData) external;
    function distrustPosition(uint32 id) external;
    function setAddress(uint256 id, address _add) external;
}
