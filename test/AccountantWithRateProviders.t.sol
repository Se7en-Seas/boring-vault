// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract AccountantWithRateProvidersTest is Test, MainnetAddresses {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    BoringVault public boring_vault;
    AccountantWithRateProviders public accountant;
    address public payout_address = vm.addr(7777777);

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19363419;
        _startFork(rpcKey, blockNumber);

        boring_vault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        accountant = new AccountantWithRateProviders(
            address(this),
            address(this),
            address(this),
            address(boring_vault),
            payout_address,
            1e18,
            address(WETH),
            1.001e4,
            0.999e4,
            1,
            0,
            0
        );

        boring_vault.grantRole(boring_vault.MINTER_ROLE(), address(this));
        deal(address(WETH), address(this), 1_000e18);
        WETH.safeApprove(address(boring_vault), 1_000e18);
        boring_vault.enter(address(this), WETH, 1_000e18, address(address(this)), 1_000e18);

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

        (,,,,,,,,, uint8 delay_in_hours,,) = accountant.accountantState();

        assertEq(delay_in_hours, 2, "Delay should be 2 hours");
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

    function testUpdatePerformanceFee() external {
        accountant.updatePerformanceFee(0.2e4);
        (,,,,,,,,,, uint16 performance_fee,) = accountant.accountantState();

        assertEq(performance_fee, 0.2e4, "Performance Fee should be 0.2e4");
    }

    function testUpdateManagementFee() external {
        accountant.updateManagementFee(0.2e4);
        (,,,,,,,,,,, uint16 management_fee) = accountant.accountantState();

        assertEq(management_fee, 0.2e4, "Management Fee should be 0.2e4");
    }

    function testUpdatePayoutAddress() external {
        (address payout,,,,,,,,,,,) = accountant.accountantState();
        assertEq(payout, payout_address, "Payout address should be the same");

        address new_payout_address = vm.addr(8888888);
        accountant.updatePayoutAddress(new_payout_address);

        (payout,,,,,,,,,,,) = accountant.accountantState();
        assertEq(payout, new_payout_address, "Payout address should be the same");
    }

    function testResetHighWatermark() external {
        accountant.updatePerformanceFee(0.2e4);
        accountant.updateManagementFee(0.01e4);

        skip(1 days / 24);
        // Increase exchange rate by 5 bps.
        uint96 new_exchange_rate = uint96(1.0005e18);
        accountant.updateExchangeRate(new_exchange_rate);

        (,, uint128 fees_owed,,,,,,,,,) = accountant.accountantState();
        assertEq(fees_owed, 0, "Fees owed should be 0");

        skip(1 days / 24);
        // Decrease exchange rate by 5 bps.
        new_exchange_rate = uint96(1e18);
        accountant.updateExchangeRate(new_exchange_rate);

        accountant.resetHighWatermark();

        uint96 hwm;
        (, hwm, fees_owed,,,,,,,,,) = accountant.accountantState();
        assertEq(hwm, new_exchange_rate, "High Watermak should have been updated");
        assertEq(fees_owed, 0, "Fees owed should be 0");
    }

    function testUpdateRateProvider() external {
        (bool is_pegged_to_base, IRateProvider rate_provider) = accountant.rate_provider_data(WEETH);
        assertTrue(is_pegged_to_base == false, "WEETH should not be pegged to base");
        assertEq(address(rate_provider), WEETH_RATE_PROVIDER, "WEETH rate provider should be set");
    }

    function testUpdateExchangeRateAndFeeLogic() external {
        accountant.updatePerformanceFee(0.2e4);
        accountant.updateManagementFee(0.01e4);

        skip(1 days / 24);
        // Increase exchange rate by 5 bps.
        uint96 new_exchange_rate = uint96(1.0005e18);
        accountant.updateExchangeRate(new_exchange_rate);

        (
            ,
            uint96 hwm,
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
        assertEq(hwm, new_exchange_rate, "High Watermak should have been updated");
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
            0.1e18 + uint256(0.01e4).mulDivDown(uint256(1 days / 24).mulDivDown(1_000.5e18, 365 days), 1e4);

        (, hwm, fees_owed, total_shares, current_exchange_rate,,, last_update_timestamp, is_paused,,,) =
            accountant.accountantState();
        assertEq(hwm, new_exchange_rate, "High Watermak should have been updated");
        assertEq(fees_owed, expected_fees_owed, "Fees owed should equal expected");
        assertEq(total_shares, 1_000e18, "Total shares should be 1_000e18");
        assertEq(current_exchange_rate, new_exchange_rate, "Current exchange rate should be updated");
        assertEq(last_update_timestamp, uint64(block.timestamp), "Last update timestamp should be updated");
        assertTrue(is_paused == false, "Accountant should not be paused");

        skip(1 days / 24);
        // Decrease exchange rate by 5 bps.
        uint96 old_exchange_rate = new_exchange_rate;
        new_exchange_rate = uint96(1.0005e18);
        accountant.updateExchangeRate(new_exchange_rate);

        expected_fees_owed += uint256(0.01e4).mulDivDown(uint256(1 days / 24).mulDivDown(1_000.5e18, 365 days), 1e4);

        (, hwm, fees_owed, total_shares, current_exchange_rate,,, last_update_timestamp, is_paused,,,) =
            accountant.accountantState();
        assertEq(hwm, old_exchange_rate, "High Watermak should not have been updated");
        assertEq(fees_owed, expected_fees_owed, "Fees owed should equal expected");
        assertEq(total_shares, 1_000e18, "Total shares should be 1_000e18");
        assertEq(current_exchange_rate, new_exchange_rate, "Current exchange rate should be updated");
        assertEq(last_update_timestamp, uint64(block.timestamp), "Last update timestamp should be updated");
        assertTrue(is_paused == false, "Accountant should not be paused");

        // Trying to update before the minimum time should succeed but, pause the contract.
        skip((1 days / 24) - 1);
        new_exchange_rate = uint96(1.0e18);
        accountant.updateExchangeRate(new_exchange_rate);

        (, hwm, fees_owed, total_shares, current_exchange_rate,,, last_update_timestamp, is_paused,,,) =
            accountant.accountantState();
        assertEq(hwm, old_exchange_rate, "High Watermak should not have been updated");
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

        (, hwm, fees_owed, total_shares, current_exchange_rate,,, last_update_timestamp, is_paused,,,) =
            accountant.accountantState();
        assertEq(hwm, old_exchange_rate, "High Watermak should not have been updated");
        assertEq(fees_owed, expected_fees_owed, "Fees owed should equal expected");
        assertEq(total_shares, 1_000e18, "Total shares should be 1_000e18");
        assertEq(current_exchange_rate, new_exchange_rate, "Current exchange rate should be updated");
        assertEq(last_update_timestamp, uint64(block.timestamp), "Last update timestamp should be updated");
        assertTrue(is_paused == true, "Accountant should be paused");
    }

    function testClaimFees() external {
        accountant.updatePerformanceFee(0.2e4);
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
            0.1e18 + uint256(0.01e4).mulDivDown(uint256(1 days / 24).mulDivDown(1_000.5e18, 365 days), 1e4);

        (,, fees_owed,,,,,,,,,) = accountant.accountantState();
        assertEq(fees_owed, expected_fees_owed, "Fees owed should equal expected");

        vm.startPrank(address(boring_vault));
        WETH.safeApprove(address(accountant), fees_owed);
        accountant.claimFees(WETH);
        vm.stopPrank();

        assertEq(WETH.balanceOf(payout_address), fees_owed, "Payout address should have received fees");

        skip(1 days / 24);
        // Increase exchange rate by 5 bps.
        new_exchange_rate = uint96(1.0015e18);
        accountant.updateExchangeRate(new_exchange_rate);

        deal(address(WEETH), address(boring_vault), 1e18);
        vm.startPrank(address(boring_vault));
        WEETH.safeApprove(address(accountant), 1e18);
        accountant.claimFees(WEETH);
        vm.stopPrank();
    }

    // TODO a more thorough test of fee logic

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

    function testReverts() external {
        accountant.pause();

        vm.expectRevert(bytes("paused"));
        accountant.updateExchangeRate(0);

        vm.expectRevert(bytes("only vault"));
        accountant.claimFees(WETH);

        vm.startPrank(address(boring_vault));
        vm.expectRevert(bytes("paused"));
        accountant.claimFees(WETH);
        vm.stopPrank();

        accountant.unpause();

        vm.startPrank(address(boring_vault));
        vm.expectRevert(bytes("no fees owed"));
        accountant.claimFees(WETH);
        vm.stopPrank();

        // Trying to claimFees with unsupported token should revert.
        vm.startPrank(address(boring_vault));
        vm.expectRevert();
        accountant.claimFees(ETHX);
        vm.stopPrank();

        accountant.pause();

        vm.expectRevert(bytes("paused"));
        accountant.getRateSafe();

        vm.expectRevert(bytes("paused"));
        accountant.getRateInQuoteSafe(WEETH);

        // Trying to getRateInQuote with unsupported token should revert.
        vm.expectRevert();
        accountant.getRateInQuoteSafe(ETHX);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
