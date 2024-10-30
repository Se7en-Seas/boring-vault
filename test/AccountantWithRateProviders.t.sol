// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {GenericRateProvider} from "src/helper/GenericRateProvider.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract AccountantWithRateProvidersTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    BoringVault public boringVault;
    AccountantWithRateProviders public accountant;
    address public payout_address = vm.addr(7777777);
    RolesAuthority public rolesAuthority;
    GenericRateProvider public mETHRateProvider;
    GenericRateProvider public ptRateProvider;

    uint8 public constant MINTER_ROLE = 1;
    uint8 public constant ADMIN_ROLE = 2;
    uint8 public constant UPDATE_EXCHANGE_RATE_ROLE = 3;
    uint8 public constant BORING_VAULT_ROLE = 4;

    ERC20 internal WETH;
    ERC20 internal EETH;
    ERC20 internal WEETH;
    ERC20 internal ETHX;
    address internal liquidV1PriceRouter;
    address internal pendleEethPt;
    ERC20 internal METH;
    address internal mantleLspStaking;
    address internal WEETH_RATE_PROVIDER;

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19827152;
        _startFork(rpcKey, blockNumber);

        WETH = getERC20(sourceChain, "WETH");
        EETH = getERC20(sourceChain, "EETH");
        WEETH = getERC20(sourceChain, "WEETH");
        ETHX = getERC20(sourceChain, "ETHX");
        liquidV1PriceRouter = getAddress(sourceChain, "liquidV1PriceRouter");
        pendleEethPt = getAddress(sourceChain, "pendleEethPt");
        METH = getERC20(sourceChain, "METH");
        mantleLspStaking = getAddress(sourceChain, "mantleLspStaking");
        WEETH_RATE_PROVIDER = getAddress(sourceChain, "WEETH_RATE_PROVIDER");

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payout_address, 1e18, address(WETH), 1.001e4, 0.999e4, 1, 0, 0
        );

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        accountant.setAuthority(rolesAuthority);
        boringVault.setAuthority(rolesAuthority);

        // Setup roles authority.
        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
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

        // Allow the boring vault to receive ETH.
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);

        rolesAuthority.setUserRole(address(this), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(this), UPDATE_EXCHANGE_RATE_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        deal(address(WETH), address(this), 1_000e18);
        WETH.safeApprove(address(boringVault), 1_000e18);
        boringVault.enter(address(this), WETH, 1_000e18, address(address(this)), 1_000e18);

        accountant.setRateProviderData(EETH, true, address(0));
        accountant.setRateProviderData(WEETH, false, address(WEETH_RATE_PROVIDER));
    }

    function testPause() external {
        accountant.pause();

        (,,,,,,,, bool is_paused,,,) = accountant.accountantState();
        assertTrue(is_paused == true, "Accountant should be paused");

        accountant.unpause();

        (,,,,,,,, is_paused,,,) = accountant.accountantState();

        assertTrue(is_paused == false, "Accountant should be unpaused");
    }

    function testUpdateDelay() external {
        accountant.updateDelay(2);

        (,,,,,,,,, uint32 delay_in_seconds,,) = accountant.accountantState();

        assertEq(delay_in_seconds, 2, "Delay should be 2 seconds");
    }

    function testUpdateUpper() external {
        accountant.updateUpper(1.002e4);
        (,,,,, uint16 upper_bound,,,,,,) = accountant.accountantState();

        assertEq(upper_bound, 1.002e4, "Upper bound should be 1.002e4");
    }

    function testUpdateLower() external {
        accountant.updateLower(0.998e4);
        (,,,,,, uint16 lower_bound,,,,,) = accountant.accountantState();

        assertEq(lower_bound, 0.998e4, "Lower bound should be 0.9980e4");
    }

    function testUpdateManagementFee() external {
        accountant.updateManagementFee(0.09e4);
        (,,,,,,,,,, uint16 management_fee,) = accountant.accountantState();

        assertEq(management_fee, 0.09e4, "Management Fee should be 0.09e4");
    }

    function testUpdataePerformanceFee() external {
        accountant.updatePerformanceFee(0.2e4);
        (,,,,,,,,,,, uint16 performance_fee) = accountant.accountantState();

        assertEq(performance_fee, 0.2e4, "Performance Fee should be 0.2e4");
    }

    function testResetHighwaterMark() external {
        // Trying to reset the highwaterMark when exchange rate is larger than hwm should revert.
        // Change share price to 1.5.
        accountant.updateExchangeRate(1.5e18);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccountantWithRateProviders.AccountantWithRateProviders__ExchangeRateAboveHighwaterMark.selector
            )
        );
        accountant.resetHighwaterMark();

        // Set a management fee.
        accountant.updateManagementFee(0.01e4);

        // Change share price to 0.5.
        accountant.unpause();
        accountant.updateExchangeRate(0.5e18);

        // Advance time to accumualte management fees.
        skip(1 days);

        (,, uint128 feesOwedInBaseBeforeReset,,,,,,,,,) = accountant.accountantState();

        accountant.resetHighwaterMark();
        (, uint96 highwater_mark, uint128 feesOwedInBase,,,,,,,,,) = accountant.accountantState();
        assertGt(feesOwedInBase, feesOwedInBaseBeforeReset, "Management fees should have been accumulated");
        assertEq(highwater_mark, 0.5e18, "Highwater mark should be 0.5e18");
    }

    function testUpdatePayoutAddress() external {
        (address payout,,,,,,,,,,,) = accountant.accountantState();
        assertEq(payout, payout_address, "Payout address should be the same");

        address new_payout_address = vm.addr(8888888);
        accountant.updatePayoutAddress(new_payout_address);

        (payout,,,,,,,,,,,) = accountant.accountantState();
        assertEq(payout, new_payout_address, "Payout address should be the same");
    }

    function testUpdateRateProvider() external {
        (bool is_pegged_to_base, IRateProvider rate_provider) = accountant.rateProviderData(WEETH);
        assertTrue(is_pegged_to_base == false, "WEETH should not be pegged to base");
        assertEq(address(rate_provider), WEETH_RATE_PROVIDER, "WEETH rate provider should be set");
    }

    function testUpdateExchangeRateAndManagementFeeLogic() external {
        accountant.updateManagementFee(0.01e4);

        skip(1 days / 24);
        // Increase exchange rate by 5 bps.
        uint96 new_exchange_rate = uint96(1.0005e18);
        accountant.updateExchangeRate(new_exchange_rate);

        (
            ,
            ,
            uint128 fees_owed,
            uint128 total_shares,
            uint96 current_exchange_rate,
            ,
            ,
            uint64 last_update_timestamp,
            bool is_paused,
            ,
            ,
        ) = accountant.accountantState();
        assertEq(fees_owed, 0, "Fees owed should be 0");
        assertEq(total_shares, 1_000e18, "Total shares should be 1_000e18");
        assertEq(current_exchange_rate, new_exchange_rate, "Current exchange rate should be updated");
        assertEq(last_update_timestamp, uint64(block.timestamp), "Last update timestamp should be updated");
        assertTrue(is_paused == false, "Accountant should not be paused");

        skip(1 days / 24);
        // Increase exchange rate by 5 bps.
        new_exchange_rate = uint96(1.001e18);
        accountant.updateExchangeRate(new_exchange_rate);

        uint256 expected_fees_owed =
            uint256(0.01e4).mulDivDown(uint256(1 days / 24).mulDivDown(1_000.5e18, 365 days), 1e4);

        (,, fees_owed, total_shares, current_exchange_rate,,, last_update_timestamp, is_paused,,,) =
            accountant.accountantState();
        assertEq(fees_owed, expected_fees_owed, "Fees owed should equal expected");
        assertEq(total_shares, 1_000e18, "Total shares should be 1_000e18");
        assertEq(current_exchange_rate, new_exchange_rate, "Current exchange rate should be updated");
        assertEq(last_update_timestamp, uint64(block.timestamp), "Last update timestamp should be updated");
        assertTrue(is_paused == false, "Accountant should not be paused");

        skip(1 days / 24);
        // Decrease exchange rate by 5 bps.
        new_exchange_rate = uint96(1.0005e18);
        accountant.updateExchangeRate(new_exchange_rate);

        expected_fees_owed += uint256(0.01e4).mulDivDown(uint256(1 days / 24).mulDivDown(1_000.5e18, 365 days), 1e4);

        (,, fees_owed, total_shares, current_exchange_rate,,, last_update_timestamp, is_paused,,,) =
            accountant.accountantState();
        assertEq(fees_owed, expected_fees_owed, "Fees owed should equal expected");
        assertEq(total_shares, 1_000e18, "Total shares should be 1_000e18");
        assertEq(current_exchange_rate, new_exchange_rate, "Current exchange rate should be updated");
        assertEq(last_update_timestamp, uint64(block.timestamp), "Last update timestamp should be updated");
        assertTrue(is_paused == false, "Accountant should not be paused");

        // Trying to update before the minimum time should succeed but, pause the contract.
        new_exchange_rate = uint96(1.0e18);
        accountant.updateExchangeRate(new_exchange_rate);

        (,, fees_owed, total_shares, current_exchange_rate,,, last_update_timestamp, is_paused,,,) =
            accountant.accountantState();
        assertEq(fees_owed, expected_fees_owed, "Fees owed should equal expected");
        assertEq(total_shares, 1_000e18, "Total shares should be 1_000e18");
        assertEq(current_exchange_rate, new_exchange_rate, "Current exchange rate should be updated");
        assertEq(last_update_timestamp, uint64(block.timestamp), "Last update timestamp should be updated");
        assertTrue(is_paused == true, "Accountant should be paused");

        accountant.unpause();

        // Or if the next update is outside the accepted bounds it will pause.
        skip((1 days / 24));
        new_exchange_rate = uint96(10.0e18);
        accountant.updateExchangeRate(new_exchange_rate);

        (,, fees_owed, total_shares, current_exchange_rate,,, last_update_timestamp, is_paused,,,) =
            accountant.accountantState();
        assertEq(fees_owed, expected_fees_owed, "Fees owed should equal expected");
        assertEq(total_shares, 1_000e18, "Total shares should be 1_000e18");
        assertEq(current_exchange_rate, new_exchange_rate, "Current exchange rate should be updated");
        assertEq(last_update_timestamp, uint64(block.timestamp), "Last update timestamp should be updated");
        assertTrue(is_paused == true, "Accountant should be paused");
    }

    function testUpdateExchangeRateAndPerformanceFeeLogic() external {
        accountant.updatePerformanceFee(0.2e4);

        skip(1 days / 24);
        // Increase exchange rate by 5 bps.
        uint96 new_exchange_rate = uint96(1.0005e18);
        accountant.updateExchangeRate(new_exchange_rate);

        (
            ,
            uint96 highwaterMark,
            uint128 fees_owed,
            uint128 total_shares,
            uint96 current_exchange_rate,
            ,
            ,
            uint64 last_update_timestamp,
            bool is_paused,
            ,
            ,
        ) = accountant.accountantState();
        assertEq(highwaterMark, new_exchange_rate, "Highwater mark should be new_exchange_rate");
        assertEq(fees_owed, 0, "Fees owed should be 0");
        assertEq(total_shares, 1_000e18, "Total shares should be 1_000e18");
        assertEq(current_exchange_rate, new_exchange_rate, "Current exchange rate should be updated");
        assertEq(last_update_timestamp, uint64(block.timestamp), "Last update timestamp should be updated");
        assertTrue(is_paused == false, "Accountant should not be paused");

        skip(1 days / 24);
        // Increase exchange rate by 5 bps.
        new_exchange_rate = uint96(1.001e18);
        accountant.updateExchangeRate(new_exchange_rate);

        uint256 expected_fees_owed = uint256(0.0005e18).mulDivDown(total_shares, 1e18).mulDivDown(0.2e4, 1e4);

        (, highwaterMark, fees_owed, total_shares, current_exchange_rate,,, last_update_timestamp, is_paused,,,) =
            accountant.accountantState();
        assertEq(highwaterMark, new_exchange_rate, "Highwater mark should be new_exchange_rate");
        assertEq(fees_owed, expected_fees_owed, "Fees owed should equal expected");
        assertEq(total_shares, 1_000e18, "Total shares should be 1_000e18");
        assertEq(current_exchange_rate, new_exchange_rate, "Current exchange rate should be updated");
        assertEq(last_update_timestamp, uint64(block.timestamp), "Last update timestamp should be updated");
        assertTrue(is_paused == false, "Accountant should not be paused");

        skip(1 days / 24);
        // Decrease exchange rate by 5 bps.
        uint96 oldExchangeRate = new_exchange_rate;
        new_exchange_rate = uint96(1.0005e18);
        accountant.updateExchangeRate(new_exchange_rate);

        // expected_fees_owed should be the same.

        (, highwaterMark, fees_owed, total_shares, current_exchange_rate,,, last_update_timestamp, is_paused,,,) =
            accountant.accountantState();
        assertEq(highwaterMark, oldExchangeRate, "Highwater mark should not change");
        assertEq(fees_owed, expected_fees_owed, "Fees owed should not have changed");
        assertEq(total_shares, 1_000e18, "Total shares should be 1_000e18");
        assertEq(current_exchange_rate, new_exchange_rate, "Current exchange rate should be updated");
        assertEq(last_update_timestamp, uint64(block.timestamp), "Last update timestamp should be updated");
        assertTrue(is_paused == false, "Accountant should not be paused");

        // Trying to update before the minimum time should succeed but, pause the contract.
        new_exchange_rate = uint96(1.0e18);
        accountant.updateExchangeRate(new_exchange_rate);

        (, highwaterMark, fees_owed, total_shares, current_exchange_rate,,, last_update_timestamp, is_paused,,,) =
            accountant.accountantState();
        assertEq(highwaterMark, oldExchangeRate, "Highwater mark should not change");
        assertEq(fees_owed, expected_fees_owed, "Fees owed should not change");
        assertEq(total_shares, 1_000e18, "Total shares should be 1_000e18");
        assertEq(current_exchange_rate, new_exchange_rate, "Current exchange rate should be updated");
        assertEq(last_update_timestamp, uint64(block.timestamp), "Last update timestamp should be updated");
        assertTrue(is_paused == true, "Accountant should be paused");

        accountant.unpause();

        // Or if the next update is outside the accepted bounds it will pause.
        skip((1 days / 24));
        new_exchange_rate = uint96(10.0e18);
        accountant.updateExchangeRate(new_exchange_rate);

        (, highwaterMark, fees_owed, total_shares, current_exchange_rate,,, last_update_timestamp, is_paused,,,) =
            accountant.accountantState();
        assertEq(highwaterMark, oldExchangeRate, "Highwater mark should not change");
        assertEq(fees_owed, expected_fees_owed, "Fees owed should equal expected");
        assertEq(total_shares, 1_000e18, "Total shares should be 1_000e18");
        assertEq(current_exchange_rate, new_exchange_rate, "Current exchange rate should be updated");
        assertEq(last_update_timestamp, uint64(block.timestamp), "Last update timestamp should be updated");
        assertTrue(is_paused == true, "Accountant should be paused");
    }

    function testClaimFees() external {
        accountant.updateManagementFee(0.01e4);

        skip(1 days / 24);
        // Increase exchange rate by 5 bps.
        uint96 new_exchange_rate = uint96(1.0005e18);
        accountant.updateExchangeRate(new_exchange_rate);

        (,, uint128 fees_owed,,,,,,,,,) = accountant.accountantState();
        assertEq(fees_owed, 0, "Fees owed should be 0");

        skip(1 days / 24);
        // Increase exchange rate by 5 bps.
        new_exchange_rate = uint96(1.001e18);
        accountant.updateExchangeRate(new_exchange_rate);

        uint256 expected_fees_owed =
            uint256(0.01e4).mulDivDown(uint256(1 days / 24).mulDivDown(1_000.5e18, 365 days), 1e4);

        (,, fees_owed,,,,,,,,,) = accountant.accountantState();
        assertEq(fees_owed, expected_fees_owed, "Fees owed should equal expected");

        vm.startPrank(address(boringVault));
        WETH.safeApprove(address(accountant), fees_owed);
        accountant.claimFees(WETH);
        vm.stopPrank();

        assertEq(WETH.balanceOf(payout_address), fees_owed, "Payout address should have received fees");

        skip(1 days / 24);
        // Increase exchange rate by 5 bps.
        new_exchange_rate = uint96(1.0015e18);
        accountant.updateExchangeRate(new_exchange_rate);

        deal(address(WEETH), address(boringVault), 1e18);
        vm.startPrank(address(boringVault));
        WEETH.safeApprove(address(accountant), 1e18);
        accountant.claimFees(WEETH);
        vm.stopPrank();
    }

    function testRates() external {
        // getRate and getRate in quote should work.
        uint256 rate = accountant.getRate();
        uint256 expected_rate = 1e18;
        assertEq(rate, expected_rate, "Rate should be expected rate");
        rate = accountant.getRateSafe();
        assertEq(rate, expected_rate, "Rate should be expected rate");

        uint256 rate_in_quote = accountant.getRateInQuote(WEETH);
        expected_rate = uint256(1e18).mulDivDown(1e18, IRateProvider(address(WEETH_RATE_PROVIDER)).getRate());
        assertEq(rate_in_quote, expected_rate, "Rate should be expected rate");
        rate_in_quote = accountant.getRateInQuoteSafe(WEETH);
        assertEq(rate_in_quote, expected_rate, "Rate should be expected rate");
    }

    function testMETHRateProvider() external {
        // Deploy GenericRateProvider for mETH.
        bytes4 selector = bytes4(keccak256(abi.encodePacked("mETHToETH(uint256)")));
        uint256 amount = 1e18;
        mETHRateProvider = new GenericRateProvider(mantleLspStaking, selector, bytes32(amount), 0, 0, 0, 0, 0, 0, 0);

        uint256 expectedRate = MantleLspStaking(mantleLspStaking).mETHToETH(1e18);
        uint256 gas = gasleft();
        uint256 rate = mETHRateProvider.getRate();
        console.log("Gas used: ", gas - gasleft());

        assertEq(rate, expectedRate, "Rate should be expected rate");

        // Setup rate in accountant.
        accountant.setRateProviderData(METH, false, address(mETHRateProvider));

        uint256 expectedRateInMeth = accountant.getRate().mulDivDown(1e18, rate);

        uint256 rateInMeth = accountant.getRateInQuote(METH);

        assertEq(rateInMeth, expectedRateInMeth, "Rate should be expected rate");

        assertLt(rateInMeth, 1e18, "Rate should be less than 1e18");
    }

    function testPtRateProvider() external {
        // Deploy GenericRateProvider for mETH.
        bytes4 selector = bytes4(keccak256(abi.encodePacked("getValue(address,uint256,address)")));
        uint256 amount = 1e18;
        bytes32 pt = 0x000000000000000000000000c69Ad9baB1dEE23F4605a82b3354F8E40d1E5966; // pendleEethPt
        bytes32 quote = 0x000000000000000000000000C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // wETH
        ptRateProvider =
            new GenericRateProvider(liquidV1PriceRouter, selector, pt, bytes32(amount), quote, 0, 0, 0, 0, 0);

        uint256 expectedRate = PriceRouter(liquidV1PriceRouter).getValue(pendleEethPt, 1e18, address(WETH));
        uint256 rate = ptRateProvider.getRate();

        assertEq(rate, expectedRate, "Rate should be expected rate");

        // Setup rate in accountant.
        accountant.setRateProviderData(ERC20(pendleEethPt), false, address(ptRateProvider));

        uint256 expectedRateInPt = accountant.getRate().mulDivDown(1e18, rate);

        uint256 rateInPt = accountant.getRateInQuote(ERC20(pendleEethPt));

        assertEq(rateInPt, expectedRateInPt, "Rate should be expected rate");

        assertGt(rateInPt, 1e18, "Rate should be greater than 1e18");
    }

    // The fuzzing will create a variety of scenarios that would pause the accountant, and valid scenarios that would not.
    function testPreviewUpdateExchangeRate(uint96 newExchangeRate, uint256 delay) external {
        accountant.updateManagementFee(0.01e4);
        accountant.updatePerformanceFee(0.2e4);
        newExchangeRate = uint96(bound(newExchangeRate, 0.998e18, 1.002e18));
        delay = bound(delay, 1 days / 8, 7 days); // 3 hours to 7 days
        accountant.updateDelay(uint24(1 days / 4)); // 6 hours
        skip(1 days / 4);
        accountant.updateExchangeRate(1e18);

        skip(1 days);

        // Update again so we have some fees owed.
        accountant.updateExchangeRate(1e18);

        skip(delay);

        (bool updateWillPause, uint256 newFeesOwedInBase, uint256 totalFeesOwedInBase) =
            accountant.previewUpdateExchangeRate(newExchangeRate);

        accountant.updateExchangeRate(newExchangeRate);

        (,, uint128 feesOwed,,,,,, bool isPaused,,,) = accountant.accountantState();
        if (updateWillPause) {
            assertTrue(isPaused, "Accountant should be paused");
            assertEq(feesOwed, totalFeesOwedInBase, "Fees owed should not have changed");
            assertEq(newFeesOwedInBase, 0, "New fees owed in base should be 0");
        } else {
            assertTrue(!isPaused, "Accountant should not be paused");
            assertEq(feesOwed, totalFeesOwedInBase, "Fees owed should be total fees owed");
            assertGt(newFeesOwedInBase, 0, "New fees owed in base should be greater than 0");
        }
    }

    function testReverts() external {
        accountant.pause();

        vm.expectRevert(
            abi.encodeWithSelector(AccountantWithRateProviders.AccountantWithRateProviders__Paused.selector)
        );
        accountant.updateExchangeRate(0);

        address attacker = vm.addr(1);
        vm.startPrank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccountantWithRateProviders.AccountantWithRateProviders__OnlyCallableByBoringVault.selector
            )
        );
        accountant.claimFees(WETH);
        vm.stopPrank();

        vm.startPrank(address(boringVault));
        vm.expectRevert(
            abi.encodeWithSelector(AccountantWithRateProviders.AccountantWithRateProviders__Paused.selector)
        );
        accountant.claimFees(WETH);
        vm.stopPrank();

        accountant.unpause();

        vm.startPrank(address(boringVault));
        vm.expectRevert(
            abi.encodeWithSelector(AccountantWithRateProviders.AccountantWithRateProviders__ZeroFeesOwed.selector)
        );
        accountant.claimFees(WETH);
        vm.stopPrank();

        // Trying to claimFees with unsupported token should revert.
        vm.startPrank(address(boringVault));
        vm.expectRevert();
        accountant.claimFees(ETHX);
        vm.stopPrank();

        accountant.pause();

        vm.expectRevert(
            abi.encodeWithSelector(AccountantWithRateProviders.AccountantWithRateProviders__Paused.selector)
        );
        accountant.getRateSafe();

        vm.expectRevert(
            abi.encodeWithSelector(AccountantWithRateProviders.AccountantWithRateProviders__Paused.selector)
        );
        accountant.getRateInQuoteSafe(WEETH);

        // Trying to getRateInQuote with unsupported token should revert.
        vm.expectRevert();
        accountant.getRateInQuoteSafe(ETHX);

        // Updating bounds, and management fee reverts.
        vm.expectRevert(
            abi.encodeWithSelector(AccountantWithRateProviders.AccountantWithRateProviders__UpperBoundTooSmall.selector)
        );
        accountant.updateUpper(0.9999e4);

        vm.expectRevert(
            abi.encodeWithSelector(AccountantWithRateProviders.AccountantWithRateProviders__LowerBoundTooLarge.selector)
        );
        accountant.updateLower(1.0001e4);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccountantWithRateProviders.AccountantWithRateProviders__ManagementFeeTooLarge.selector
            )
        );
        accountant.updateManagementFee(0.2001e4);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccountantWithRateProviders.AccountantWithRateProviders__UpdateDelayTooLarge.selector
            )
        );
        accountant.updateDelay(14 days + 1);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

interface MantleLspStaking {
    function mETHToETH(uint256) external view returns (uint256);
}

interface PriceRouter {
    function getValue(address, uint256, address) external view returns (uint256);
}
