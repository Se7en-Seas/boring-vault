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
import {CellarMigrationAdaptor2} from "src/migration/CellarMigrationAdaptor2.sol";
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
    CellarMigrationAdaptor2 public migrationAdaptor2;
    EtherFiLiquid1 public etherFiLiquid1;
    RolesAuthority public rolesAuthority;
    GenericRateProvider public ptRateProvider;
    GenericRateProvider public ytRateProvider;
    GenericRateProvider public zircuitPtRateProvider;
    GenericRateProvider public zircuitYtRateProvider;
    MigrationSharePriceOracle public migrationSharePriceOracle;
    CompleteMigration public migrator;

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
    address public fakeStrategist = vm.addr(987654321);
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
        uint256 blockNumber = 19870746;
        _startFork(rpcKey, blockNumber);

        etherFiLiquid1 = EtherFiLiquid1(0xeA1A6307D9b18F8d1cbf1c3Dd6aad8416C06a221);

        boringVault = new BoringVault(multisig, "Boring Vault", "BV", 18);

        manager = new ManagerWithMerkleVerification(multisig, address(boringVault), vault);

        accountant = new AccountantWithRateProviders(
            multisig, address(boringVault), payout_address, 1e18, address(WETH), 1.1e4, 0.9e4, 1, 0.01e4
        );

        teller = new TellerWithMultiAssetSupport(multisig, address(boringVault), address(accountant), address(WETH));

        migrationAdaptor = new CellarMigrationAdaptor(address(boringVault), address(accountant), address(teller));
        migrationAdaptor2 = new CellarMigrationAdaptor2(address(boringVault), address(accountant), address(teller));

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

        pt = 0x0000000000000000000000004AE5411F3863CdB640309e84CEDf4B08B8b33FfF;
        zircuitPtRateProvider =
            new GenericRateProvider(liquidV1PriceRouter, selector, pt, bytes32(amount), quote, 0, 0, 0, 0, 0);

        yt = 0x0000000000000000000000007C2D26182adeEf96976035986cF56474feC03bDa;
        zircuitYtRateProvider =
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
        rolesAuthority.setUserRole(fakeStrategist, STRATEGIST_ROLE, true);
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
        accountant.setRateProviderData(ERC20(pendleZircuitEethPt), false, address(zircuitPtRateProvider));
        accountant.setRateProviderData(ERC20(pendleZircuitEethYt), false, address(zircuitYtRateProvider));
        teller.addAsset(WETH);
        teller.addAsset(NATIVE_ERC20);
        teller.addAsset(EETH);
        teller.addAsset(WEETH);
        teller.addAsset(ERC20(pendleEethPt));
        teller.addAsset(ERC20(pendleEethYt));
        teller.addAsset(ERC20(pendleZircuitEethPt));
        teller.addAsset(ERC20(pendleZircuitEethYt));
        vm.stopPrank();
    }

    function testMigration(uint256 seed) external {
        address jointMultisig = etherFiLiquid1.owner();
        rolesAuthority.transferOwnership(jointMultisig);
        Registry registry = Registry(etherFiLiquid1.registry());
        address registryMultisig = registry.owner();
        address strategist = registryMultisig;
        address user = vm.addr(3);

        // Give fake user some shares.
        deal(address(etherFiLiquid1), user, 10e18);

        // Deploy migrator.
        migrator = new CompleteMigration(boringVault, ERC4626(address(etherFiLiquid1)), accountant, jointMultisig);

        // Simulate rebalancing the Cellar into simpler positions that can be deposited into the BoringVault.
        _simulateRebalance(seed);

        // Add both migration adaptors and positions to the registry.
        // Also setAddress 1 to be the migration share price oracle.
        uint32 migrationPosition = 77777777;
        uint32 migrationPosition2 = 77777778;
        vm.startPrank(registryMultisig);
        registry.trustAdaptor(address(migrationAdaptor));
        registry.trustPosition(migrationPosition, address(migrationAdaptor), hex"");
        registry.trustAdaptor(address(migrationAdaptor2));
        registry.trustPosition(migrationPosition2, address(migrationAdaptor2), hex"");
        registry.setAddress(1, address(migrationSharePriceOracle));
        vm.stopPrank();

        // Joint multisig only adds the first migration position/adaptor to the catalogue,
        // then adds the position ot the cellar, specifying it to be illiquid.
        // Next it gives etherfi liquid the solver role so it can rebalance.
        vm.startPrank(jointMultisig);
        etherFiLiquid1.addAdaptorToCatalogue(address(migrationAdaptor));
        etherFiLiquid1.addPositionToCatalogue(migrationPosition);
        etherFiLiquid1.addPosition(0, migrationPosition, abi.encode(false), false);
        rolesAuthority.setUserRole(address(etherFiLiquid1), SOLVER_ROLE, true);
        vm.stopPrank();

        uint256 totalAssetsBefore = etherFiLiquid1.totalAssets();

        // Strategist rebalances all liquid assets into BoringVault.
        EtherFiLiquid1.AdaptorCall[] memory data = new EtherFiLiquid1.AdaptorCall[](1);
        bytes[] memory adaptorCalls = new bytes[](7);
        adaptorCalls[0] = abi.encodeWithSignature("deposit(address,uint256,uint256)", WETH, type(uint256).max, 0);
        adaptorCalls[1] = abi.encodeWithSignature("deposit(address,uint256,uint256)", EETH, type(uint256).max, 0);
        adaptorCalls[2] = abi.encodeWithSignature("deposit(address,uint256,uint256)", WEETH, type(uint256).max, 0);
        adaptorCalls[3] =
            abi.encodeWithSignature("deposit(address,uint256,uint256)", ERC20(pendleEethPt), type(uint256).max, 0);
        adaptorCalls[4] =
            abi.encodeWithSignature("deposit(address,uint256,uint256)", ERC20(pendleEethYt), type(uint256).max, 0);
        adaptorCalls[5] = abi.encodeWithSignature(
            "deposit(address,uint256,uint256)", ERC20(pendleZircuitEethPt), type(uint256).max, 0
        );
        adaptorCalls[6] = abi.encodeWithSignature(
            "deposit(address,uint256,uint256)", ERC20(pendleZircuitEethYt), type(uint256).max, 0
        );
        data[0] = EtherFiLiquid1.AdaptorCall({adaptor: address(migrationAdaptor), callData: adaptorCalls});
        vm.startPrank(strategist);
        etherFiLiquid1.callOnAdaptor(data);
        vm.stopPrank();

        uint256 totalAssetsAfter = etherFiLiquid1.totalAssets();

        // There is a small change in total assets because the BoringVault prices weETH using the rate, but,
        // when the cellar prices weETH, there is some small rounding errors when getValue logic is used.
        assertApproxEqRel(
            totalAssetsAfter, totalAssetsBefore, 0.00000001e18, "Total assets should not change after migration."
        );

        /// NOTE the above migration can happen over the course of multiple weeks, since all the assets are in the illiquid
        /// BoringVault position withdraws fail.

        /// NOTE if we want to the UI could be updated to state that a migration is underway, and maybe prompt users to use the atomic queue for new deposits or withdraws?

        // Wait long enough so that we can update the exchnage rate.
        vm.warp(block.timestamp + 2);

        uint256 withdrawable = etherFiLiquid1.maxWithdraw(user);
        assertEq(withdrawable, 0, "User should not be able to withdraw any assets.");

        // Strategist sets the holding position to the migration position to stop further deposits.
        vm.startPrank(strategist);
        etherFiLiquid1.setHoldingPosition(migrationPosition); // This also doubley checks that deposits fail, as users can not deposit into this position.
        vm.stopPrank();

        // Deposits now revert.
        deal(address(WETH), address(this), 1e18);
        WETH.safeApprove(address(etherFiLiquid1), 1e18);
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(CellarMigrationAdaptor.CellarMigrationAdaptor__UserDepositsNotAllowed.selector)
            )
        );
        etherFiLiquid1.deposit(1e18, address(this));

        // If need be the strategist would rebalance 1 more time to move all assets into the boring vault.

        // At this point the entire vault is migrated. Strategist can iniaite shutdown to prevent further deposits.
        vm.prank(strategist);
        etherFiLiquid1.initiateShutdown();
        // Deposits still revert.
        vm.expectRevert(bytes(abi.encodeWithSelector(EtherFiLiquid1.Cellar__ContractShutdown.selector)));
        etherFiLiquid1.deposit(1e18, address(this));

        // Registry distrusts eETH position, and migration position so they can be forced out.
        vm.startPrank(registryMultisig);
        registry.distrustPosition(2);
        registry.distrustPosition(migrationPosition);
        vm.stopPrank();

        assertEq(
            etherFiLiquid1.totalAssets(),
            totalAssetsAfter,
            "Total assets should not change after distrusting positions."
        );

        // registry pauses cellar before final migration.
        vm.startPrank(registryMultisig);
        address[] memory _add = new address[](1);
        _add[0] = address(etherFiLiquid1);
        registry.batchPause(_add);
        vm.stopPrank();

        vm.startPrank(jointMultisig);
        etherFiLiquid1.toggleIgnorePause();
        // Force out eETH position as it always keeps 1 wei in balance so can not be removed normally.
        etherFiLiquid1.forcePositionOut(3, 2, false);
        // Remove all positions from cellar, except for migration position.
        etherFiLiquid1.removePosition(1, false);
        etherFiLiquid1.removePosition(1, false);
        etherFiLiquid1.removePosition(1, false);
        etherFiLiquid1.removePosition(1, false);
        etherFiLiquid1.removePosition(1, false);
        etherFiLiquid1.removePosition(1, false);
        // Remove all positions from catalogue so they can not be added back.
        etherFiLiquid1.removePositionFromCatalogue(3);
        etherFiLiquid1.removePositionFromCatalogue(1);
        etherFiLiquid1.removePositionFromCatalogue(2);
        etherFiLiquid1.removePositionFromCatalogue(17);
        etherFiLiquid1.removePositionFromCatalogue(18);
        etherFiLiquid1.removePositionFromCatalogue(31);
        etherFiLiquid1.removePositionFromCatalogue(30);
        // Revoke solver role from Cellar so that strategist can not deposit or withdraw from BoringVault.
        rolesAuthority.setUserRole(address(etherFiLiquid1), SOLVER_ROLE, false);
        // Give the migrator contract the appropriate roles to complete the migration.
        rolesAuthority.setUserRole(address(migrator), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(migrator), BURNER_ROLE, true);
        rolesAuthority.setUserRole(address(migrator), UPDATE_EXCHANGE_RATE_ROLE, true);
        // Complete the migration.
        migrator.completeMigration(true, 0.0001e4);
        // Update Share price oracle to use the migration share price oracle.
        etherFiLiquid1.setSharePriceOracle(1, address(migrationSharePriceOracle));
        // Revoke roles from migrator.
        rolesAuthority.setUserRole(address(migrator), MINTER_ROLE, false);
        rolesAuthority.setUserRole(address(migrator), BURNER_ROLE, false);
        rolesAuthority.setUserRole(address(migrator), UPDATE_EXCHANGE_RATE_ROLE, false);
        // Lift the shutdown.
        etherFiLiquid1.liftShutdown();
        // Add the second migration position, add it as a liquid position, make it the holding position, then force out the first one.
        etherFiLiquid1.addAdaptorToCatalogue(address(migrationAdaptor2));
        etherFiLiquid1.addPositionToCatalogue(migrationPosition2);
        etherFiLiquid1.addPosition(0, migrationPosition2, abi.encode(true), false);
        etherFiLiquid1.setHoldingPosition(migrationPosition2);
        etherFiLiquid1.forcePositionOut(1, migrationPosition, false);
        // Shutdown cellar again.
        etherFiLiquid1.initiateShutdown();
        etherFiLiquid1.toggleIgnorePause();
        vm.stopPrank();

        // If everything looks good registry can unpause the cellar.
        vm.startPrank(registryMultisig);
        registry.batchUnpause(_add);
        vm.stopPrank();

        assertApproxEqRel(
            etherFiLiquid1.totalAssets(),
            totalAssetsBefore,
            0.00000001e18,
            "Total assets should not change after completing migration."
        );

        // Check share prices match.
        {
            uint256 realSharePrice = etherFiLiquid1.totalAssets().mulDivDown(1e18, etherFiLiquid1.totalSupply());
            uint256 approxSharePrice = etherFiLiquid1.previewRedeem(1e18);

            assertApproxEqAbs(realSharePrice, approxSharePrice, 1, "Real share price should be the same as approx.");
        }

        assertEq(
            etherFiLiquid1.totalSupply(),
            boringVault.balanceOf(address(etherFiLiquid1)),
            "BV share balance should match V1 total supply."
        );

        /// NOTE at this point the BoringVault Teller should have any unwanted deposit assets removed, then public deposits can be turned on.

        // When users withdraw, they receive BoringVault shares.
        vm.startPrank(user);
        uint256 boringVaultShareDelta = boringVault.balanceOf(user);
        uint256 cellarSharesRedeemed = 1e18;
        etherFiLiquid1.redeem(1e18, user, user);
        boringVaultShareDelta = boringVault.balanceOf(user) - boringVaultShareDelta;
        vm.stopPrank();
        assertApproxEqAbs(
            boringVaultShareDelta, cellarSharesRedeemed, 2, "User should have received BoringVault shares."
        );

        // Even as the rate changes, users still receieve BoringVault shares at a 1:1 ratio.
        // Rate goes down.
        // Wait long enough so that we can update the exchnage rate.
        vm.warp(block.timestamp + 2);
        uint256 newRate = accountant.getRate().mulDivDown(0.95e4, 1e4);
        accountant.updateExchangeRate(uint96(newRate));

        vm.startPrank(user);
        boringVaultShareDelta = boringVault.balanceOf(user);
        cellarSharesRedeemed = 1e18;
        etherFiLiquid1.redeem(1e18, user, user);
        boringVaultShareDelta = boringVault.balanceOf(user) - boringVaultShareDelta;
        vm.stopPrank();
        assertApproxEqAbs(
            boringVaultShareDelta, cellarSharesRedeemed, 2, "User should have received BoringVault shares."
        );

        // Rate goes up.
        // Wait long enough so that we can update the exchnage rate.
        vm.warp(block.timestamp + 2);
        newRate = accountant.getRate().mulDivDown(1.05e4, 1e4);
        accountant.updateExchangeRate(uint96(newRate));

        vm.startPrank(user);
        boringVaultShareDelta = boringVault.balanceOf(user);
        cellarSharesRedeemed = 1e18;
        etherFiLiquid1.redeem(1e18, user, user);
        boringVaultShareDelta = boringVault.balanceOf(user) - boringVaultShareDelta;
        vm.stopPrank();
        assertApproxEqAbs(
            boringVaultShareDelta, cellarSharesRedeemed, 2, "User should have received BoringVault shares."
        );

        // If exchangeRate is updated to some extreme value, pause it triggered which causes all Cellar withdraws to revert.
        // Wait long enough so that we can update the exchnage rate.
        vm.warp(block.timestamp + 2);
        newRate = accountant.getRate().mulDivDown(0.01e4, 1e4);
        accountant.updateExchangeRate(uint96(newRate));

        vm.expectRevert(bytes(abi.encodeWithSelector(EtherFiLiquid1.Cellar__OracleFailure.selector)));
        etherFiLiquid1.redeem(1e18, user, user);

        accountant.unpause();

        vm.startPrank(user);
        boringVaultShareDelta = boringVault.balanceOf(user);
        cellarSharesRedeemed = 1e18;
        etherFiLiquid1.redeem(1e18, user, user);
        boringVaultShareDelta = boringVault.balanceOf(user) - boringVaultShareDelta;
        vm.stopPrank();
        /// NOTE in this example the extreme rate was made very small which does introduce more rounding errors, so the abs tolerance
        /// for the assert is increased.
        assertApproxEqAbs(
            boringVaultShareDelta, cellarSharesRedeemed, 100, "User should have received BoringVault shares."
        );
    }

    function _simulateRebalance(uint256 seed) internal {
        uint256[7] memory makeup = [
            uint256(keccak256(abi.encode(seed, 0))) % type(uint16).max + 1e6,
            uint256(keccak256(abi.encode(seed, 1))) % type(uint16).max + 1e6,
            uint256(keccak256(abi.encode(seed, 2))) % type(uint16).max + 1e6,
            uint256(keccak256(abi.encode(seed, 3))) % type(uint16).max + 1e6,
            uint256(keccak256(abi.encode(seed, 4))) % type(uint16).max + 1e6,
            uint256(keccak256(abi.encode(seed, 5))) % type(uint16).max + 1e6,
            uint256(keccak256(abi.encode(seed, 6))) % type(uint16).max + 1e6
        ];
        uint256 makeupTotal;
        for (uint256 i; i < makeup.length; i++) {
            makeupTotal += makeup[i];
        }

        address cellarOwner = etherFiLiquid1.owner();
        Registry registry = Registry(etherFiLiquid1.registry());
        address registryOwner = registry.owner();

        // Rebalance the Cellar so that it only has assets in PT weETH, YT weETH, PT Zircuit weETH, YT Zircuit weETH, eETH, weETH, and wETH.
        uint32[7] memory positionsToKeep = [
            uint32(3), // weETH
            uint32(1), // wETH
            uint32(2), // eETH
            uint32(17), // PT weETH
            uint32(18), // YT weETH
            uint32(31), // YT Zircuit weETH
            uint32(30) // PT Zircuit weETH
        ];

        uint256 startingTotalAssets = etherFiLiquid1.totalAssets();

        // Force out all positions except wETH, eETH, weETH, PT weETH, YT weETH, PT Zircuit weETH, YT Zircuit weETH.
        uint32 targetIndex = 0;
        uint32[] memory creditPositions = etherFiLiquid1.getCreditPositions();

        for (uint256 i; i < creditPositions.length; i++) {
            bool con = false;
            for (uint256 j; j < positionsToKeep.length; j++) {
                if (creditPositions[i] == positionsToKeep[j]) {
                    targetIndex++;
                    con = true;
                    break;
                }
            }
            if (con) {
                continue;
            }

            vm.prank(registryOwner);
            registry.distrustPosition(creditPositions[i]);

            vm.prank(cellarOwner);
            etherFiLiquid1.forcePositionOut(targetIndex, creditPositions[i], false);
        }

        // Remove all debt positions.
        targetIndex = 0;
        uint32[] memory debtPositions = etherFiLiquid1.getDebtPositions();
        for (uint256 i; i < debtPositions.length; i++) {
            vm.prank(registryOwner);
            registry.distrustPosition(debtPositions[i]);

            vm.prank(cellarOwner);
            etherFiLiquid1.forcePositionOut(targetIndex, debtPositions[i], true);
        }

        debtPositions = etherFiLiquid1.getDebtPositions();
        assertEq(debtPositions.length, 0, "All debt positions should be removed.");

        // Use deal to deal out appropriate balances to match makeup.
        PriceRouter priceRouter = PriceRouter(etherFiLiquid1.priceRouter());
        address[7] memory assets = [
            address(WEETH),
            address(WETH),
            address(EETH),
            pendleEethPt,
            pendleEethYt,
            pendleZircuitEethYt,
            pendleZircuitEethPt
        ];
        for (uint256 i; i < makeup.length; i++) {
            uint256 amount = startingTotalAssets.mulDivDown(makeup[i], makeupTotal);

            uint256 amountInAsset = priceRouter.getValue(address(WETH), amount, assets[i]);

            if (assets[i] == address(EETH)) {
                // We need to get rid of any eETH we alreay have.
                vm.startPrank(address(etherFiLiquid1));
                EETH.transfer(address(1), EETH.balanceOf(address(etherFiLiquid1)));
                vm.stopPrank();
                // Deal ETH to Cellar.
                deal(address(etherFiLiquid1), amountInAsset);
                // Deposit ETH into EETH liquidity pool.
                vm.prank(address(etherFiLiquid1));
                ILiquidityPool(EETH_LIQUIDITY_POOL).deposit{value: amountInAsset}();
            } else {
                deal(assets[i], address(etherFiLiquid1), amountInAsset);
            }
        }

        assertApproxEqAbs(
            etherFiLiquid1.totalAssets(),
            startingTotalAssets,
            100,
            "Total assets should be the same after simulated rebalance."
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
    function batchPause(address[] memory _add) external;
    function batchUnpause(address[] memory _add) external;
}

interface PriceRouter {
    function getValue(address base, uint256 amount, address quote) external view returns (uint256);
}
