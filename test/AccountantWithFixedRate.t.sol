// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithFixedRate} from "src/base/Roles/AccountantWithFixedRate.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {GenericRateProvider} from "src/helper/GenericRateProvider.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract AccountantWithFixedRateTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    BoringVault public boringVault;
    AccountantWithFixedRate public accountant;
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

    uint16 managementFee = 0.01e4;
    uint16 performanceFee = 0.2e4;
    address yieldDistributor = vm.addr(3);

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

        accountant = new AccountantWithFixedRate(
            address(this),
            address(boringVault),
            payout_address,
            1e18,
            address(WETH),
            6.05e4,
            0.95e4,
            1,
            managementFee,
            performanceFee
        );

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        accountant.setAuthority(rolesAuthority);
        boringVault.setAuthority(rolesAuthority);

        // Setup roles authority.
        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
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

        accountant.setYieldDistributor(yieldDistributor);

        skip(1 days);
        // Perform first update so totalSupply saved is correct.
        accountant.updateExchangeRate(1e18);
    }

    function testUpdateExchangeRateLogic(
        uint96 firstUpdate,
        uint96 secondUpdate,
        uint256 firstDelay,
        uint256 secondDelay
    ) external {
        firstUpdate = uint96(bound(firstUpdate, 1.001e18, 1.01e18));
        secondUpdate = uint96(bound(secondUpdate, 0.99e18, 1e18));
        firstDelay = bound(firstDelay, 1 days, 7 days);
        secondDelay = bound(secondDelay, 1 days, 7 days);

        (uint96 startingYield,) = accountant.fixedRateAccountantState();

        assertEq(startingYield, 0, "Starting yield should be 0");

        skip(firstDelay);
        accountant.updateExchangeRate(firstUpdate);

        (uint96 firstYield,) = accountant.fixedRateAccountantState();

        uint256 totalSupply = boringVault.totalSupply(); // Also equal to min assets since exchange rate started at 1e18.
        uint256 grossYield = uint256(firstUpdate - 1e18).mulDivDown(totalSupply, 1e18);
        // Calculate management fee.
        uint256 expectedFee = totalSupply.mulDivDown(managementFee, 1e4);
        expectedFee = expectedFee.mulDivDown(firstDelay, 365 days);

        // Calculate performance fee.
        expectedFee += grossYield.mulDivDown(performanceFee, 1e4);

        assertEq(firstYield, uint96(grossYield - expectedFee), "First yield should be correct");

        // Accountant rate should still be 1e18.
        assertEq(accountant.getRate(), 1e18, "Accountant rate should still be 1e18");

        // Accountant highwater mark should be the same as the fixed rate.
        (, uint96 highwater_mark,,,,,,,,,,) = accountant.accountantState();
        assertEq(highwater_mark, 1e18, "Accountant highwater mark should be the fixed rate");

        skip(secondDelay);
        accountant.updateExchangeRate(secondUpdate);

        (uint96 secondYield,) = accountant.fixedRateAccountantState();

        // Update was not above fixed rate, so no yield should be earned.
        assertEq(secondYield, firstYield, "Second yield should be the same as first yield");

        // Accountant rate should be the same as the second update.
        assertEq(accountant.getRate(), secondUpdate, "Accountant rate should be the same as the second update");
    }

    function testClaimYield() external {
        skip(1 days);
        accountant.updateExchangeRate(1.01e18);

        (uint96 yieldEarned, address distributor) = accountant.fixedRateAccountantState();
        assertGt(yieldEarned, 0, "Yield earned should be greater than 0");

        // Boring Vault approves accountant to spend wETH.
        vm.prank(address(boringVault));
        WETH.approve(address(accountant), yieldEarned);

        uint256 boringVaultBalance = WETH.balanceOf(address(boringVault));

        // Distributor calls claimYield.
        vm.prank(distributor);
        accountant.claimYield(WETH);

        assertEq(
            WETH.balanceOf(address(boringVault)),
            boringVaultBalance - yieldEarned,
            "Boring Vault balance should decrease"
        );
        assertEq(WETH.balanceOf(yieldDistributor), yieldEarned, "Yield distributor balance should increase");

        (yieldEarned,) = accountant.fixedRateAccountantState();

        assertEq(yieldEarned, 0, "Yield earned should be zero after claim");
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
            if (newExchangeRate > 1e18) {
                assertGt(newFeesOwedInBase, 0, "New fees owed in base should be greater than 0");
            } else {
                assertEq(newFeesOwedInBase, 0, "New fees owed in base should be 0");
            }
        }
    }

    function testUpdateExchangeRateWhenFeesOutweighYieldEarned(uint96 newExchangeRate) external {
        newExchangeRate = uint96(bound(newExchangeRate, 1e18, 1.05e18));

        // Update management fee to 10%.
        accountant.updateManagementFee(0.1e4);

        // Wait 1 year.
        skip(365 days);

        // Update exchange rate to newExchangeRate.
        accountant.updateExchangeRate(newExchangeRate);

        (uint96 yieldEarned,) = accountant.fixedRateAccountantState();

        // The management fee should be forfeited, but yield and performance fees should be calculated.
        uint256 totalSupply = boringVault.totalSupply(); // Also equal to min assets since exchange rate started at 1e18.
        uint256 grossYield = uint256(newExchangeRate - 1e18).mulDivDown(totalSupply, 1e18);
        uint256 expectedFee = grossYield.mulDivDown(performanceFee, 1e4);

        assertEq(yieldEarned, uint96(grossYield - expectedFee), "Yield earned should be correct");

        (,, uint128 actualFeesOwedInBase,,,,,,,,,) = accountant.accountantState();
        assertEq(actualFeesOwedInBase, expectedFee, "Fees owed in base should be correct");
    }

    function testMassiveYieldEarned() external {
        // Update allowed change upper to maximum possible value.
        accountant.updateUpper(type(uint16).max);

        // Set the fees to 0.
        accountant.updatePerformanceFee(0);
        accountant.updateManagementFee(0);

        skip(1 days);

        // Now we need to make the share supply so large that casting the yield earned to uint96 overflows.
        uint256 sharesToAdd = 15_000_000_000e18;
        deal(address(WETH), address(this), sharesToAdd);
        WETH.safeApprove(address(boringVault), sharesToAdd);
        boringVault.enter(address(this), WETH, sharesToAdd, address(address(this)), sharesToAdd);

        accountant.updateExchangeRate(1e18);

        skip(1 days);

        // Perform the largest possible exchange rate update.
        uint96 maxUpdate = uint96(uint256(1e18).mulDivDown(type(uint16).max, 1e4));
        vm.expectRevert(
            abi.encodeWithSelector(AccountantWithFixedRate.AccountantWithFixedRate__UnsafeUint96Cast.selector)
        );
        accountant.updateExchangeRate(maxUpdate);

        // If this was a legitmate update, then it needs to be split into two calls.
        accountant.updateExchangeRate(maxUpdate / 2);

        skip(1 days);

        accountant.updateExchangeRate(maxUpdate / 2);
    }

    function testUpdateExchangeRateWithZeroPerformanceFee() external {
        // Set performance fee to 0 but keep management fee
        accountant.updatePerformanceFee(0);

        // Skip some time to accrue management fees
        uint256 timeSkip = 30 days;
        skip(timeSkip);

        // Update with 2% increase
        uint256 newRate = 1.02e18;
        accountant.updateExchangeRate(uint96(newRate));

        uint256 totalSupply = boringVault.totalSupply();
        uint256 grossYield = uint256(newRate - 1e18).mulDivDown(totalSupply, 1e18);

        // Calculate expected management fee
        uint256 expectedManagementFee = totalSupply.mulDivDown(managementFee, 1e4);
        expectedManagementFee = expectedManagementFee.mulDivDown(timeSkip, 365 days);

        // Check yield earned
        (uint96 yieldEarned,) = accountant.fixedRateAccountantState();
        assertEq(yieldEarned, uint96(grossYield - expectedManagementFee), "Incorrect yield earned");

        // Check fees owed
        (,, uint128 actualFeesOwedInBase,,,,,,,,,) = accountant.accountantState();
        assertEq(actualFeesOwedInBase, expectedManagementFee, "Incorrect fees owed");
    }

    function testUpdateExchangeRateWithZeroManagementFee() external {
        // Set management fee to 0 but keep performance fee
        accountant.updateManagementFee(0);

        // Skip some time (this shouldn't affect fees since management fee is 0)
        uint256 timeSkip = 30 days;
        skip(timeSkip);

        // Update with 2% increase
        uint256 newRate = 1.02e18;
        accountant.updateExchangeRate(uint96(newRate));

        uint256 totalSupply = boringVault.totalSupply();
        uint256 grossYield = uint256(newRate - 1e18).mulDivDown(totalSupply, 1e18);

        // Calculate expected performance fee
        uint256 expectedPerformanceFee = grossYield.mulDivDown(performanceFee, 1e4);

        // Check yield earned
        (uint96 yieldEarned,) = accountant.fixedRateAccountantState();
        assertEq(yieldEarned, uint96(grossYield - expectedPerformanceFee), "Incorrect yield earned");

        // Check fees owed
        (,, uint128 actualFeesOwedInBase,,,,,,,,,) = accountant.accountantState();
        assertEq(actualFeesOwedInBase, expectedPerformanceFee, "Incorrect fees owed");
    }

    function testUpdateExchangeRateWithZeroFees() external {
        // Set both fees to 0
        accountant.updateManagementFee(0);
        accountant.updatePerformanceFee(0);

        // Skip some time (should have no effect since both fees are 0)
        uint256 timeSkip = 30 days;
        skip(timeSkip);

        // Update with 2% increase
        uint256 newRate = 1.02e18;
        accountant.updateExchangeRate(uint96(newRate));

        uint256 totalSupply = boringVault.totalSupply();
        uint256 grossYield = uint256(newRate - 1e18).mulDivDown(totalSupply, 1e18);

        // Check yield earned - should equal gross yield since no fees
        (uint96 yieldEarned,) = accountant.fixedRateAccountantState();
        assertEq(yieldEarned, uint96(grossYield), "Incorrect yield earned");

        // Check fees owed - should be 0
        (,, uint128 actualFeesOwedInBase,,,,,,,,,) = accountant.accountantState();
        assertEq(actualFeesOwedInBase, 0, "Fees owed should be 0");
    }

    function testSetYieldDistributor() external {
        address newYieldDistributor = vm.addr(4);
        accountant.setYieldDistributor(newYieldDistributor);
        (, address setDistributor) = accountant.fixedRateAccountantState();
        assertEq(setDistributor, newYieldDistributor, "Yield distributor should be set");
    }

    function testReverts() external {
        // Calling resetHighwaterMark should revert.
        vm.expectRevert(
            abi.encodeWithSelector(AccountantWithFixedRate.AccountantWithFixedRate__HighWaterMarkCannotChange.selector)
        );
        accountant.resetHighwaterMark();

        // Deploying a new fixed rate accountant with a starting exchange rate greater than fixed should revert.
        vm.expectRevert(
            abi.encodeWithSelector(
                AccountantWithFixedRate.AccountantWithFixedRate__StartingExchangeRateCannotBeGreaterThanFixed.selector
            )
        );
        new AccountantWithFixedRate(
            address(this),
            address(boringVault),
            payout_address,
            1.01e18,
            address(WETH),
            1.05e4,
            0.95e4,
            1,
            managementFee,
            performanceFee
        );

        // It should revert if the address calling claimYield is not the yield distributor.
        vm.expectRevert(
            abi.encodeWithSelector(
                AccountantWithFixedRate.AccountantWithFixedRate__OnlyCallableByYieldDistributor.selector
            )
        );
        accountant.claimYield(WETH);

        // It should revert if claimYield is called when no yield is owed.
        vm.expectRevert(abi.encodeWithSelector(AccountantWithFixedRate.AccountantWithFixedRate__ZeroYieldOwed.selector));
        vm.prank(yieldDistributor);
        accountant.claimYield(WETH);
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
