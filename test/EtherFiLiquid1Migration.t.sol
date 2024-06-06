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
import {ParitySharePriceOracle} from "src/migration/ParitySharePriceOracle.sol";
import {CellarMigratorWithSharePriceParity, ERC4626} from "src/migration/CellarMigratorWithSharePriceParity.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Deployer} from "src/helper/Deployer.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract EtherFiLiquid1MigrationTest is Test, MainnetAddresses {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;
    using AddressToBytes32Lib for address;
    using Address for address;

    // Mainnet Contracts.
    Deployer public deployer = Deployer(deployerAddress);
    BoringVault public boringVault = BoringVault(payable(0xf0bb20865277aBd641a307eCe5Ee04E79073416C));
    ManagerWithMerkleVerification public manager =
        ManagerWithMerkleVerification(0x227975088C28DBBb4b421c6d96781a53578f19a8);
    TellerWithMultiAssetSupport public teller = TellerWithMultiAssetSupport(0x5c135e8eC99557b412b9B4492510dCfBD36066F5);
    AccountantWithRateProviders public accountant =
        AccountantWithRateProviders(0x0d05D94a5F1E76C18fbeB7A13d17C8a314088198);
    RolesAuthority public rolesAuthority = RolesAuthority(0x485Bde66Bb668a51f2372E34e45B1c6226798122);
    EtherFiLiquid1 public etherFiLiquid1 = EtherFiLiquid1(0xeA1A6307D9b18F8d1cbf1c3Dd6aad8416C06a221);
    address public auraERC4626Adaptor = 0x0F3f8cab8D3888281033faf7A6C0b74dE62bb162;
    address public uniswapV3Adaptor = 0xBC912F54ddeb7221A21F7d41B0a8A08336A55056;
    address public erc4626Adaptor = 0xb1761a7C7799Cb429eB5bf2db16d88534DA681e2;
    address public morphoBlueSupplyAdaptor = 0x11747E893eFE2AB739A3f52C090b2e39130b18F4;
    address public aaveV3ATokenAdaptor = 0x7613b7f78A1672FBC478bfecf4598EeDE10a2Fa7;
    address public aaveV3DebtTokenAdaptor = 0x79677329a4B2d4576e820f69b5e260F77d93FcCE;
    CellarMigrationAdaptor public migrationAdaptor = CellarMigrationAdaptor(0x3D77e32F07f4B54C590eA9102A4cF55299DCCb71);
    CellarMigrationAdaptor2 public migrationAdaptor2 =
        CellarMigrationAdaptor2(0x37Bf4f94D045e5Fcda3ed4A223F7Ecdedbf73303);
    ParitySharePriceOracle public paritySharePriceOracle =
        ParitySharePriceOracle(0xdE6a8E421300fB785622A7AC0d487274333BC15d);
    CellarMigratorWithSharePriceParity public migrator =
        CellarMigratorWithSharePriceParity(0x16Ec46B07Ab9cDa589f57025d794B50c2ADBbECF);

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant MINTER_ROLE = 2;
    uint8 public constant BURNER_ROLE = 3;
    uint8 public constant MANAGER_INTERNAL_ROLE = 4;
    uint8 public constant SOLVER_ROLE = 12;
    uint8 public constant OWNER_ROLE = 8;
    uint8 public constant MULTISIG_ROLE = 9;
    uint8 public constant STRATEGIST_MULTISIG_ROLE = 10;
    uint8 public constant STRATEGIST_ROLE = 7;
    uint8 public constant UPDATE_EXCHANGE_RATE_ROLE = 11;

    // Position IDs.
    uint32 public EETH_POSITION = 2;
    uint32 public ILLIQUID_MIGRATION_POSITION = 77777777;
    uint32 public LIQUID_MIGRATION_POSITION = 77777778;

    // Registry getAddress ID.
    uint256 ETHER_FI_LIQUID_SHARE_PRICE_ORACLE_ID = 3;

    address public registryMultisig;
    address public strategist;
    Registry public registry;

    // Test user that will withdraw after migration.
    address user = vm.addr(3);

    // This is used for the `testParitySharePriceOracle` test.
    ERC20 public asset = USDC;

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 20019360;
        _startFork(rpcKey, blockNumber);

        registry = Registry(etherFiLiquid1.registry());
        registryMultisig = registry.owner();
        strategist = registryMultisig;

        vm.prank(dev1Address);
        rolesAuthority.transferOwnership(liquidMultisig);

        vm.startPrank(liquidMultisig);
        rolesAuthority.setUserRole(strategist, STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(liquidMultisig, OWNER_ROLE, true);
        rolesAuthority.setUserRole(liquidMultisig, MULTISIG_ROLE, true);
        rolesAuthority.setUserRole(address(this), UPDATE_EXCHANGE_RATE_ROLE, true);
        vm.stopPrank();

        // Give fake user some shares.
        deal(address(etherFiLiquid1), user, 10e18);
    }

    function testMigration() external {
        // Setup the BoringVault position.
        // Add both migration adaptors and positions to the registry.
        // Also setAddress 1 to be the migration share price oracle.
        vm.startPrank(registryMultisig);
        registry.trustAdaptor(address(migrationAdaptor));
        registry.trustPosition(ILLIQUID_MIGRATION_POSITION, address(migrationAdaptor), hex"");
        vm.stopPrank();

        // Joint multisig only adds the first migration position/adaptor to the catalogue,
        // then adds the position ot the cellar, specifying it to be illiquid.
        // Next it gives etherfi liquid the solver role so it can rebalance.
        vm.startPrank(liquidMultisig);
        etherFiLiquid1.addAdaptorToCatalogue(address(migrationAdaptor));
        etherFiLiquid1.addPositionToCatalogue(ILLIQUID_MIGRATION_POSITION);
        etherFiLiquid1.addPosition(0, ILLIQUID_MIGRATION_POSITION, abi.encode(false), false);
        rolesAuthority.setUserRole(address(etherFiLiquid1), SOLVER_ROLE, true);
        vm.stopPrank();

        // Strategist begins rebalancing positions.
        uint256 startingTotalAssets = etherFiLiquid1.totalAssets();
        _migratePendleAssets();
        assertApproxEqRel(
            etherFiLiquid1.totalAssets(),
            startingTotalAssets,
            0.0001e18,
            "Total assets should not change after migrating pendle assets."
        );

        _migrateAuraAssets();
        assertApproxEqRel(
            etherFiLiquid1.totalAssets(),
            startingTotalAssets,
            0.0001e18,
            "Total assets should not change after migrating aura assets."
        );

        _closeUniswapV3Positions();

        assertApproxEqRel(
            etherFiLiquid1.totalAssets(),
            startingTotalAssets,
            0.0001e18,
            "Total assets should not change after migrating uniV3 assets."
        );
        _closeGearBoxPosition();
        assertApproxEqRel(
            etherFiLiquid1.totalAssets(),
            startingTotalAssets,
            0.0001e18,
            "Total assets should not change after migrating aura assets."
        );

        _closeMorphoBluePosition();

        _migrateAavePosition();
        assertApproxEqRel(
            etherFiLiquid1.totalAssets(),
            startingTotalAssets,
            0.0001e18,
            "Total assets should not change after migrating aave assets."
        );

        ERC20[] memory tokensToMigrate = new ERC20[](4);
        tokensToMigrate[0] = WETH;
        tokensToMigrate[1] = WEETH;
        tokensToMigrate[2] = WSTETH;
        tokensToMigrate[3] = EETH;
        _migrateERC20Positions(tokensToMigrate);

        // Strategist sets the holding position to the migration position to stop further deposits.
        // Also allows us to remove current holding position.
        vm.startPrank(strategist);
        etherFiLiquid1.setHoldingPosition(ILLIQUID_MIGRATION_POSITION);
        vm.stopPrank();

        // Remove remaning positions, except the migration position and the eETH position(since it cant be removed due to 1 wei balance).
        _removeAnyPositionThatIsNotTheBoringVaultPosition(ILLIQUID_MIGRATION_POSITION, 2);

        assertApproxEqRel(
            etherFiLiquid1.totalAssets(),
            startingTotalAssets,
            0.0001e18,
            "Total assets should not change after removing positions."
        );

        /// NOTE the above migration can happen over the course of multiple weeks, since all the assets are in the illiquid
        /// BoringVault position withdraws fail.

        /// NOTE if we want to the UI could be updated to state that a migration is underway, and maybe prompt users to use the atomic queue for new deposits or withdraws?

        uint256 withdrawable = etherFiLiquid1.maxWithdraw(user);
        assertEq(withdrawable, 0, "User should not be able to withdraw any assets.");

        // Deposits now revert.
        deal(address(WETH), address(this), 1e18);
        WETH.safeApprove(address(etherFiLiquid1), 1e18);
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(CellarMigrationAdaptor.CellarMigrationAdaptor__UserDepositsNotAllowed.selector)
            )
        );
        etherFiLiquid1.deposit(1e18, address(this));

        // At this point the entire vault is migrated. Strategist can iniaite shutdown to prevent further deposits.
        vm.prank(strategist);
        etherFiLiquid1.initiateShutdown();
        // Deposits still revert.
        vm.expectRevert(bytes(abi.encodeWithSelector(EtherFiLiquid1.Cellar__ContractShutdown.selector)));
        etherFiLiquid1.deposit(1e18, address(this));

        // Withdraws should also revert, sicne all assets are illiquid.
        vm.startPrank(user);
        vm.expectRevert(bytes(abi.encodeWithSelector(EtherFiLiquid1.Cellar__IncompleteWithdraw.selector, 1)));
        etherFiLiquid1.withdraw(1, user, user);
        vm.stopPrank();

        // Also check that BoringVault deposits fail.
        vm.expectRevert(bytes("UNAUTHORIZED"));
        teller.deposit(WETH, 1, 0);

        // Registry multisig
        // - Trusts the liquid migration adaptor and position
        // - Sets the migration share price oracle to be the parity share price oracle
        // - Distrusts the eETH position, and the illiquid migration position
        // - Pauses the cellar
        vm.startPrank(registryMultisig);
        address[] memory _add = new address[](1);
        _add[0] = address(etherFiLiquid1);
        registry.trustAdaptor(address(migrationAdaptor2));
        registry.trustPosition(LIQUID_MIGRATION_POSITION, address(migrationAdaptor2), hex"");
        registry.setAddress(ETHER_FI_LIQUID_SHARE_PRICE_ORACLE_ID, address(paritySharePriceOracle));
        registry.distrustPosition(EETH_POSITION);
        registry.distrustPosition(ILLIQUID_MIGRATION_POSITION);
        registry.batchPause(_add);
        vm.stopPrank();

        vm.startPrank(liquidMultisig);
        etherFiLiquid1.toggleIgnorePause();
        // Force out eETH position as it always keeps 1 wei in balance so can not be removed normally.
        // 1 is the index in etherFiLiquid1.getCreditPositions();
        etherFiLiquid1.forcePositionOut(1, EETH_POSITION, false);
        // Revoke solver role from Cellar so that strategist can not deposit or withdraw from BoringVault.
        rolesAuthority.setUserRole(address(etherFiLiquid1), SOLVER_ROLE, false);
        // Give the migrator contract the appropriate roles to complete the migration.
        rolesAuthority.setUserRole(address(migrator), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(migrator), BURNER_ROLE, true);
        rolesAuthority.setUserRole(address(migrator), UPDATE_EXCHANGE_RATE_ROLE, true);
        // Complete the migration.
        migrator.completeMigration(true, 0.0001e4);
        // Update Share price oracle to use the migration share price oracle.
        etherFiLiquid1.setSharePriceOracle(ETHER_FI_LIQUID_SHARE_PRICE_ORACLE_ID, address(paritySharePriceOracle));
        // Revoke roles from migrator.
        rolesAuthority.setUserRole(address(migrator), MINTER_ROLE, false);
        rolesAuthority.setUserRole(address(migrator), BURNER_ROLE, false);
        rolesAuthority.setUserRole(address(migrator), UPDATE_EXCHANGE_RATE_ROLE, false);
        // Lift the shutdown.
        etherFiLiquid1.liftShutdown();
        // Add the second migration position, add it as a liquid position, make it the holding position, then force out the first one.
        etherFiLiquid1.addAdaptorToCatalogue(address(migrationAdaptor2));
        etherFiLiquid1.addPositionToCatalogue(LIQUID_MIGRATION_POSITION);
        etherFiLiquid1.addPosition(0, LIQUID_MIGRATION_POSITION, abi.encode(true), false);
        etherFiLiquid1.setHoldingPosition(LIQUID_MIGRATION_POSITION);
        etherFiLiquid1.forcePositionOut(1, ILLIQUID_MIGRATION_POSITION, false);
        etherFiLiquid1.removeAdaptorFromCatalogue(address(migrationAdaptor));
        etherFiLiquid1.removeAdaptorFromCatalogue(address(migrationAdaptor2));
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
            startingTotalAssets,
            0.0001e18,
            "Total assets should not change after completing migration."
        );

        vm.startPrank(liquidMultisig);
        teller.removeAsset(rETH_weETH);
        teller.removeAsset(WSTETH);
        teller.removeAsset(aV3WeETH);
        teller.removeAsset(ERC20(pendleWeETHMarket));
        teller.removeAsset(ERC20(pendleZircuitWeETHMarket));
        teller.removeAsset(ERC20(pendleEethPt));
        teller.removeAsset(ERC20(pendleEethYt));
        teller.removeAsset(ERC20(pendleZircuitEethPt));
        teller.removeAsset(ERC20(pendleZircuitEethYt));
        teller.removeAsset(ERC20(pendleWeETHMarketSeptember));
        teller.removeAsset(ERC20(pendleEethPtSeptember));
        teller.removeAsset(ERC20(pendleEethYtSeptember));
        teller.removeAsset(ERC20(pendleWeETHMarketDecember));
        teller.removeAsset(ERC20(pendleEethPtDecember));
        teller.removeAsset(ERC20(pendleEethYtDecember));

        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);
        rolesAuthority.setPublicCapability(
            address(teller), TellerWithMultiAssetSupport.depositWithPermit.selector, true
        );
        vm.stopPrank();

        // Users can now deposit into the BoringVault.
        deal(address(WETH), user, 1e18);
        WETH.safeApprove(address(boringVault), 1e18);
        uint256 sharesOut = teller.deposit(WETH, 1e18, 0);

        assertApproxEqRel(
            sharesOut, etherFiLiquid1.previewDeposit(1e18), 0.0001e18, "Shares minted should match preview mint."
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
        uint256 newRate = accountant.getRate().mulDivDown(0.95e4, 1e4);
        accountant.updateExchangeRate(uint96(newRate));

        vm.startPrank(liquidMultisig);
        accountant.unpause();

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
        newRate = accountant.getRate().mulDivDown(1.05e4, 1e4);
        accountant.updateExchangeRate(uint96(newRate));

        vm.startPrank(liquidMultisig);
        accountant.unpause();

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
        newRate = accountant.getRate().mulDivDown(0.01e4, 1e4);
        accountant.updateExchangeRate(uint96(newRate));

        vm.expectRevert(bytes(abi.encodeWithSelector(EtherFiLiquid1.Cellar__OracleFailure.selector)));
        etherFiLiquid1.redeem(1e18, user, user);

        vm.startPrank(liquidMultisig);
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

    function testCellarMigrationWithSharePriceParity() external {
        vm.startPrank(registryMultisig);
        registry.trustAdaptor(address(migrationAdaptor));
        registry.trustPosition(ILLIQUID_MIGRATION_POSITION, address(migrationAdaptor), hex"");
        registry.setAddress(1, address(paritySharePriceOracle));
        vm.stopPrank();

        // Joint multisig only adds the first migration position/adaptor to the catalogue,
        // then adds the position ot the cellar, specifying it to be illiquid.
        // Next it gives etherfi liquid the solver role so it can rebalance.
        vm.startPrank(liquidMultisig);
        etherFiLiquid1.addAdaptorToCatalogue(address(migrationAdaptor));
        etherFiLiquid1.addPositionToCatalogue(ILLIQUID_MIGRATION_POSITION);
        etherFiLiquid1.addPosition(0, ILLIQUID_MIGRATION_POSITION, abi.encode(false), false);
        rolesAuthority.setUserRole(address(etherFiLiquid1), SOLVER_ROLE, true);
        rolesAuthority.setUserRole(address(migrator), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(migrator), BURNER_ROLE, true);
        rolesAuthority.setUserRole(address(migrator), UPDATE_EXCHANGE_RATE_ROLE, true);
        vm.stopPrank();

        // Strategist begins rebalancing positions.

        ERC20[] memory tokensToMigrate = new ERC20[](1);
        tokensToMigrate[0] = WETH;
        _migrateERC20Positions(tokensToMigrate);

        // Trying to call the complete migration function from the wrong account reverts.
        vm.expectRevert(bytes("MIGRATOR"));
        migrator.completeMigration(true, 10);

        uint256 targetBVShares = boringVault.balanceOf(address(etherFiLiquid1));

        // Remove 1 wei boring vault share from target.
        deal(address(boringVault), address(etherFiLiquid1), targetBVShares - 1);

        vm.startPrank(liquidMultisig);
        vm.expectRevert(bytes("SHARES"));
        migrator.completeMigration(true, 10);
        vm.stopPrank();

        vm.startPrank(liquidMultisig);
        vm.expectRevert(bytes("TA"));
        migrator.completeMigration(false, 0);
        vm.stopPrank();
    }

    function testParitySharePriceOracle() external {
        // Try deploying a share price oracle when the assets are mismatched.
        vm.expectRevert(bytes("ASSET_MISMATCH"));
        new ParitySharePriceOracle(address(this), address(accountant));

        uint256 currentRate = accountant.getRate();

        // Check that the oracle returns the correct rate.
        (uint256 ans, uint256 twaa, bool isNotSafeToUse) = paritySharePriceOracle.getLatest();

        assertEq(ans, currentRate, "Rate should match the current rate.");
        assertEq(twaa, currentRate, "TWAA should match the current rate.");
        assertEq(isNotSafeToUse, false, "Oracle should be safe to use.");

        // Pause accountant.
        vm.startPrank(liquidMultisig);
        accountant.pause();
        vm.stopPrank();

        (,, isNotSafeToUse) = paritySharePriceOracle.getLatest();
        assertEq(isNotSafeToUse, true, "Oracle should not be safe to use.");
    }

    function _migratePendleAssets() internal {
        EtherFiLiquid1.AdaptorCall[] memory data = new EtherFiLiquid1.AdaptorCall[](1);
        bytes[] memory adaptorCalls = new bytes[](12);
        adaptorCalls[0] =
            abi.encodeWithSignature("deposit(address,uint256,uint256)", pendleWeETHMarket, type(uint256).max, 0);
        adaptorCalls[1] =
            abi.encodeWithSignature("deposit(address,uint256,uint256)", pendleZircuitWeETHMarket, type(uint256).max, 0);
        adaptorCalls[2] =
            abi.encodeWithSignature("deposit(address,uint256,uint256)", pendleEethPt, type(uint256).max, 0);
        adaptorCalls[3] =
            abi.encodeWithSignature("deposit(address,uint256,uint256)", pendleEethYt, type(uint256).max, 0);
        adaptorCalls[4] =
            abi.encodeWithSignature("deposit(address,uint256,uint256)", pendleZircuitEethPt, type(uint256).max, 0);
        adaptorCalls[5] =
            abi.encodeWithSignature("deposit(address,uint256,uint256)", pendleZircuitEethYt, type(uint256).max, 0);
        adaptorCalls[6] = abi.encodeWithSignature(
            "deposit(address,uint256,uint256)", pendleWeETHMarketSeptember, type(uint256).max, 0
        );
        adaptorCalls[7] =
            abi.encodeWithSignature("deposit(address,uint256,uint256)", pendleEethPtSeptember, type(uint256).max, 0);
        adaptorCalls[8] =
            abi.encodeWithSignature("deposit(address,uint256,uint256)", pendleEethYtSeptember, type(uint256).max, 0);
        adaptorCalls[9] =
            abi.encodeWithSignature("deposit(address,uint256,uint256)", pendleWeETHMarketDecember, type(uint256).max, 0);
        adaptorCalls[10] =
            abi.encodeWithSignature("deposit(address,uint256,uint256)", pendleEethPtDecember, type(uint256).max, 0);
        adaptorCalls[11] =
            abi.encodeWithSignature("deposit(address,uint256,uint256)", pendleEethYtDecember, type(uint256).max, 0);

        data[0] = EtherFiLiquid1.AdaptorCall({adaptor: address(migrationAdaptor), callData: adaptorCalls});
        vm.startPrank(strategist);
        etherFiLiquid1.callOnAdaptor(data);
        vm.stopPrank();
    }

    function _migrateAuraAssets() internal {
        EtherFiLiquid1.AdaptorCall[] memory data = new EtherFiLiquid1.AdaptorCall[](2);
        bytes[] memory adaptorCalls = new bytes[](1);
        bytes[] memory adaptorCalls1 = new bytes[](1);
        adaptorCalls[0] =
            abi.encodeWithSignature("withdrawFromVault(address,uint256)", aura_reth_weeth, type(uint256).max);
        data[0] = EtherFiLiquid1.AdaptorCall({adaptor: auraERC4626Adaptor, callData: adaptorCalls});
        adaptorCalls1[0] = abi.encodeWithSignature("deposit(address,uint256,uint256)", rETH_weETH, type(uint256).max, 0);
        data[1] = EtherFiLiquid1.AdaptorCall({adaptor: address(migrationAdaptor), callData: adaptorCalls1});
        vm.startPrank(strategist);
        etherFiLiquid1.callOnAdaptor(data);
        vm.stopPrank();
    }

    function _closeUniswapV3Positions() internal {
        uint256[3] memory tokenIds = [uint256(719349), 729916, 729917];
        for (uint256 i; i < tokenIds.length; i++) {
            EtherFiLiquid1.AdaptorCall[] memory data = new EtherFiLiquid1.AdaptorCall[](1);
            bytes[] memory adaptorCalls = new bytes[](1);
            adaptorCalls[0] = abi.encodeWithSignature("closePosition(uint256,uint256,uint256)", tokenIds[i], 0, 0);
            data[0] = EtherFiLiquid1.AdaptorCall({adaptor: uniswapV3Adaptor, callData: adaptorCalls});
            vm.startPrank(strategist);
            etherFiLiquid1.callOnAdaptor(data);
            vm.stopPrank();
        }
    }

    function _closeGearBoxPosition() internal {
        EtherFiLiquid1.AdaptorCall[] memory data = new EtherFiLiquid1.AdaptorCall[](1);
        bytes[] memory adaptorCalls = new bytes[](1);
        adaptorCalls[0] = abi.encodeWithSignature("withdrawFromVault(address,uint256)", dWETHV3, type(uint256).max);
        data[0] = EtherFiLiquid1.AdaptorCall({adaptor: erc4626Adaptor, callData: adaptorCalls});
        vm.startPrank(strategist);
        etherFiLiquid1.callOnAdaptor(data);
        vm.stopPrank();
    }

    function _closeMorphoBluePosition() internal {
        uint32 morphoBlueSupplyPosition = 11;

        uint256 totalAssetsBefore = etherFiLiquid1.totalAssets();

        vm.prank(strategist);
        registry.distrustPosition(morphoBlueSupplyPosition);
        uint32[] memory creditPositions = etherFiLiquid1.getCreditPositions();

        for (uint32 i; i < creditPositions.length; i++) {
            if (creditPositions[i] == morphoBlueSupplyPosition) {
                vm.startPrank(liquidMultisig);
                etherFiLiquid1.forcePositionOut(i, morphoBlueSupplyPosition, false);
                vm.stopPrank();
                break;
            }
        }

        uint256 totalAssetsAfter = etherFiLiquid1.totalAssets();

        // Need to deal Cellar ETH to mock a successful withdraw.
        uint256 cellarWethBalance = WETH.balanceOf(address(etherFiLiquid1));

        deal(address(WETH), address(etherFiLiquid1), cellarWethBalance + (totalAssetsBefore - totalAssetsAfter));
    }

    function _migrateERC20Positions(ERC20[] memory tokensToMigrate) internal {
        for (uint256 i; i < tokensToMigrate.length; i++) {
            ERC20 token = tokensToMigrate[i];
            EtherFiLiquid1.AdaptorCall[] memory data = new EtherFiLiquid1.AdaptorCall[](1);
            bytes[] memory adaptorCalls = new bytes[](1);
            adaptorCalls[0] = abi.encodeWithSignature("deposit(address,uint256,uint256)", token, type(uint256).max, 0);
            data[0] = EtherFiLiquid1.AdaptorCall({adaptor: address(migrationAdaptor), callData: adaptorCalls});
            vm.startPrank(strategist);
            etherFiLiquid1.callOnAdaptor(data);
            vm.stopPrank();
        }
    }

    function _removeAnyPositionThatIsNotTheBoringVaultPosition(uint32 boringVaultPosition, uint32 eETHPosition)
        internal
    {
        // Remove credit positions.
        uint32[] memory creditPositions = etherFiLiquid1.getCreditPositions();
        while (creditPositions.length > 2) {
            for (uint32 i; i < creditPositions.length; i++) {
                if (creditPositions[i] != boringVaultPosition && creditPositions[i] != eETHPosition) {
                    vm.startPrank(strategist);
                    etherFiLiquid1.removePosition(i, false);
                    etherFiLiquid1.removePositionFromCatalogue(creditPositions[i]);
                    vm.stopPrank();
                    break;
                }
            }
            creditPositions = etherFiLiquid1.getCreditPositions();
        }

        // Remove debt positions.
        uint32[] memory debtPositions = etherFiLiquid1.getDebtPositions();
        while (debtPositions.length > 0) {
            for (uint32 i; i < debtPositions.length; i++) {
                if (debtPositions[i] != boringVaultPosition) {
                    vm.startPrank(strategist);
                    etherFiLiquid1.removePosition(i, true);
                    etherFiLiquid1.removePositionFromCatalogue(debtPositions[i]);
                    vm.stopPrank();
                    break;
                }
            }
            debtPositions = etherFiLiquid1.getDebtPositions();
        }
    }

    function _migrateAavePosition() internal {
        // Repay the wETH balance of the Cellar.
        uint256 amountToRepay = WETH.balanceOf(address(etherFiLiquid1));
        EtherFiLiquid1.AdaptorCall[] memory data = new EtherFiLiquid1.AdaptorCall[](1);
        bytes[] memory adaptorCalls = new bytes[](1);
        adaptorCalls[0] = abi.encodeWithSignature("repayAaveDebt(address,uint256)", WETH, amountToRepay);
        data[0] = EtherFiLiquid1.AdaptorCall({adaptor: aaveV3DebtTokenAdaptor, callData: adaptorCalls});
        vm.startPrank(strategist);
        etherFiLiquid1.callOnAdaptor(data);
        vm.stopPrank();

        // Now migrate half of the aTokens to BoringVault.
        uint256 amountToMigrate = aV3WeETH.balanceOf(address(etherFiLiquid1)) / 2;
        adaptorCalls[0] = abi.encodeWithSignature("deposit(address,uint256,uint256)", aV3WeETH, amountToMigrate, 0);
        data[0] = EtherFiLiquid1.AdaptorCall({adaptor: address(migrationAdaptor), callData: adaptorCalls});
        vm.startPrank(strategist);
        etherFiLiquid1.callOnAdaptor(data);
        vm.stopPrank();

        // Now strategist rebalances BoringVault to take out a loan of wETH.
        uint256 amountToBorrow = dV3WETH.balanceOf(address(etherFiLiquid1)) + 2;
        vm.startPrank(address(manager));
        bytes memory callData = abi.encodeWithSignature(
            "borrow(address,uint256,uint256,uint16,address)", WETH, amountToBorrow, 2, 0, address(boringVault)
        );
        boringVault.manage(v3Pool, callData, 0);
        vm.stopPrank();

        // Now that the BoringVault is holding wETH, Cellar can redeem some BV tokens for wETH.
        uint256 rate = accountant.getRate();
        uint256 amountToRedeem = amountToBorrow.mulDivDown(1e18, rate);
        adaptorCalls[0] = abi.encodeWithSignature("withdraw(address,uint256,uint256)", WETH, amountToRedeem, 0);
        data[0] = EtherFiLiquid1.AdaptorCall({adaptor: address(migrationAdaptor), callData: adaptorCalls});
        vm.startPrank(strategist);
        etherFiLiquid1.callOnAdaptor(data);
        vm.stopPrank();

        // Now that the Cellar has wETH, it can repay the loan, then deposit the remaining aTokens.
        data = new EtherFiLiquid1.AdaptorCall[](2);
        adaptorCalls = new bytes[](1);
        adaptorCalls[0] = abi.encodeWithSignature("repayAaveDebt(address,uint256)", WETH, type(uint256).max);
        data[0] = EtherFiLiquid1.AdaptorCall({adaptor: aaveV3DebtTokenAdaptor, callData: adaptorCalls});
        bytes[] memory adaptorCalls1 = new bytes[](1);
        adaptorCalls1[0] = abi.encodeWithSignature("deposit(address,uint256,uint256)", aV3WeETH, type(uint256).max, 0);
        data[1] = EtherFiLiquid1.AdaptorCall({adaptor: address(migrationAdaptor), callData: adaptorCalls1});
        vm.startPrank(strategist);
        etherFiLiquid1.callOnAdaptor(data);
        vm.stopPrank();

        assertEq(dV3WETH.balanceOf(address(etherFiLiquid1)), 0, "Cellar should have repaid the loan.");
        assertEq(aV3WeETH.balanceOf(address(etherFiLiquid1)), 0, "Cellar should have deposited all aTokens.");
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

    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
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
