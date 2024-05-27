// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {DelayedWithdraw} from "src/base/Roles/DelayedWithdraw.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {ILiquidityPool} from "src/interfaces/IStaking.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {AtomicSolverV3, AtomicQueue} from "src/atomic-queue/AtomicSolverV3.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract DelayedWithdrawTest is Test, MainnetAddresses {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    BoringVault public boringVault;

    uint8 public constant BURNER_ROLE = 8;

    DelayedWithdraw public withdrawer;
    AccountantWithRateProviders public accountant;
    address public payoutAddress = vm.addr(7777777);
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    ERC20 internal constant NATIVE_ERC20 = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    RolesAuthority public rolesAuthority;

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19363419;
        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payoutAddress, 1e18, address(WETH), 1.1e4, 0.9e4, 1, 0, 0
        );

        withdrawer = new DelayedWithdraw(address(this), address(boringVault), address(accountant), payoutAddress);

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));

        boringVault.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        withdrawer.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);
        rolesAuthority.setPublicCapability(address(withdrawer), DelayedWithdraw.cancelWithdraw.selector, true);
        rolesAuthority.setPublicCapability(address(withdrawer), DelayedWithdraw.requestWithdraw.selector, true);
        rolesAuthority.setPublicCapability(address(withdrawer), DelayedWithdraw.completeWithdraw.selector, true);

        rolesAuthority.setUserRole(address(withdrawer), BURNER_ROLE, true);

        accountant.setRateProviderData(EETH, true, address(0));
        accountant.setRateProviderData(WEETH, false, address(WEETH_RATE_PROVIDER));
    }

    function testHappyPath() external {
        withdrawer.setupWithdrawAsset(WETH, 1 days, 0, 0);

        address user = vm.addr(1);

        // Simulate user deposit by minting 1_000 shares to them, and giving BoringVault 1_000 WETH/.
        deal(address(boringVault), user, 1_000e18, true);
        deal(address(WETH), address(boringVault), 1_000e18);

        uint96 sharesToWithdraw = 100e18;
        vm.startPrank(user);
        boringVault.approve(address(withdrawer), sharesToWithdraw);
        withdrawer.requestWithdraw(WETH, sharesToWithdraw);
        vm.stopPrank();

        uint256 expectedOutstandingShraes = 100e18;
        (,, uint128 outstandingShares,,) = withdrawer.withdrawAssets(WETH);
        assertEq(outstandingShares, expectedOutstandingShraes, "Outstanding shares should be 100e18");

        uint256 expectedOustandingDebt = 100e18;
        uint256 outstandingDebt = withdrawer.viewOutstandingDebt(WETH);
        assertEq(outstandingDebt, expectedOustandingDebt, "Outstanding debt should be 100e18");

        // User waits 1 day.
        skip(1 days);

        vm.startPrank(user);
        withdrawer.completeWithdraw(WETH, user);
        vm.stopPrank();

        (,, outstandingShares,,) = withdrawer.withdrawAssets(WETH);
        assertEq(outstandingShares, 0, "Outstanding shares should be 0");
    }

    function testExchangeRateIncreasesAfterRequest() external {
        withdrawer.setupWithdrawAsset(WETH, 1 days, 0, 0.1e4);

        address user = vm.addr(1);

        // Simulate user deposit by minting 1_000 shares to them, and giving BoringVault 1_000 WETH.
        deal(address(boringVault), user, 1_000e18, true);
        deal(address(WETH), address(boringVault), 1_000e18);

        uint96 sharesToWithdraw = 100e18;
        vm.startPrank(user);
        boringVault.approve(address(withdrawer), sharesToWithdraw);
        withdrawer.requestWithdraw(WETH, sharesToWithdraw);
        vm.stopPrank();

        // Fast forward time so that user request is valid, and the exchange rate can be updated without pausing.
        skip(1 days);

        // Update exchnage rate.
        uint96 newExchangeRate = 1.01e18;
        accountant.updateExchangeRate(newExchangeRate);

        uint256 assetsOut = withdrawer.completeWithdraw(WETH, user);

        uint256 expectedAssetsOut = sharesToWithdraw;
        assertEq(assetsOut, expectedAssetsOut, "assetsOut should equal expectedAssetsOut.");
        assertEq(WETH.balanceOf(user), assetsOut, "User should have received assetsOut of WETH");
    }

    function testExchangeRateDecreasesAfterRequest() external {
        withdrawer.setupWithdrawAsset(WETH, 1 days, 0, 0.1e4);

        address user = vm.addr(1);

        // Simulate user deposit by minting 1_000 shares to them, and giving BoringVault 1_000 WETH.
        deal(address(boringVault), user, 1_000e18, true);
        deal(address(WETH), address(boringVault), 1_000e18);

        uint96 sharesToWithdraw = 100e18;
        vm.startPrank(user);
        boringVault.approve(address(withdrawer), sharesToWithdraw);
        withdrawer.requestWithdraw(WETH, sharesToWithdraw);
        vm.stopPrank();

        // Fast forward time so that user request is valid, and the exchange rate can be updated without pausing.
        skip(1 days);

        // Update exchnage rate.
        uint96 newExchangeRate = 0.99e18;
        accountant.updateExchangeRate(newExchangeRate);

        uint256 assetsOut = withdrawer.completeWithdraw(WETH, user);

        uint256 expectedAssetsOut = sharesToWithdraw * 0.99e4 / 1e4;
        assertEq(assetsOut, expectedAssetsOut, "assetsOut should equal expectedAssetsOut.");
        assertEq(WETH.balanceOf(user), assetsOut, "User should have received assetsOut of WETH");
    }

    function testCancellingRequestOnceAssetIsRemoved() external {
        withdrawer.setupWithdrawAsset(WETH, 1 days, 0, 0.1e4);
        withdrawer.setupWithdrawAsset(EETH, 1 days, 0, 0.1e4);

        address user = vm.addr(1);

        // Simulate user deposit by minting 1_000 shares to them, and giving BoringVault 1_000 WETH.
        deal(address(boringVault), user, 1_000e18, true);
        deal(address(WETH), address(boringVault), 1_000e18);

        uint256 userShareBalance = boringVault.balanceOf(user);

        uint96 sharesToWithdraw = 100e18;
        vm.startPrank(user);
        boringVault.approve(address(withdrawer), 2 * sharesToWithdraw);
        withdrawer.requestWithdraw(WETH, sharesToWithdraw);
        withdrawer.requestWithdraw(EETH, sharesToWithdraw);
        vm.stopPrank();

        // wETH is removed as a withdrawable asset.
        withdrawer.stopWithdrawalsInAsset(WETH);

        // eETH is removed as a withdrawable asset, and is removed from accountant.
        withdrawer.stopWithdrawalsInAsset(EETH);
        accountant.setRateProviderData(EETH, false, address(0));

        // Both requests can still be cancelled, and user recieves shares back.
        vm.startPrank(user);
        withdrawer.cancelWithdraw(WETH);
        withdrawer.cancelWithdraw(EETH);
        vm.stopPrank();

        assertEq(boringVault.balanceOf(user), userShareBalance, "User should have received their shares back.");
    }

    function testMaxLossLogic() external {
        withdrawer.setupWithdrawAsset(WETH, 1 days, 0, 0.01e4);

        address user = vm.addr(1);

        // Simulate user deposit by minting 1_000 shares to them, and giving BoringVault 1_000 WETH.
        deal(address(boringVault), user, 1_000e18, true);
        deal(address(WETH), address(boringVault), 1_000e18);

        uint96 sharesToWithdraw = 100e18;
        vm.startPrank(user);
        boringVault.approve(address(withdrawer), sharesToWithdraw);
        withdrawer.requestWithdraw(WETH, sharesToWithdraw);
        vm.stopPrank();

        // Fast forward time so the exchange rate can be updated without pausing.
        skip(1 days);

        // Update exchnage rate so it is too high.
        uint96 newExchangeRate = 1.02e18;
        accountant.updateExchangeRate(newExchangeRate);

        vm.expectRevert(bytes(abi.encodeWithSelector(DelayedWithdraw.DelayedWithdraw__MaxLossExceeded.selector)));
        withdrawer.completeWithdraw(WETH, user);

        // Fast forward time so the exchange rate can be updated without pausing.
        skip(1 days);

        // Update exchnage rate so it is too low.
        newExchangeRate = 0.98e18;
        accountant.updateExchangeRate(newExchangeRate);

        vm.expectRevert(bytes(abi.encodeWithSelector(DelayedWithdraw.DelayedWithdraw__MaxLossExceeded.selector)));
        withdrawer.completeWithdraw(WETH, user);

        // Fast forward time so the exchange rate can be updated without pausing.
        skip(1 days);

        // Update exchnage rate so it stabilizes at 1:1.
        newExchangeRate = 1e18;
        accountant.updateExchangeRate(newExchangeRate);

        // Request can now be completed.
        withdrawer.completeWithdraw(WETH, user);
    }
    // TODO tests where we check the effects of the admin functions
    // TODO check that fees work as expected.

    function testUserFunctionReverts() external {
        address user = vm.addr(1);

        // Simulate user deposit by minting 1_000 shares to them, and giving BoringVault 1_000 WETH.
        deal(address(boringVault), user, 1_000e18, true);
        deal(address(WETH), address(boringVault), 1_000e18);

        // Requeting withdraws in an asset that is not withdrawable.
        ERC20 nonWithdrawableAsset = USDC;
        vm.expectRevert(bytes(abi.encodeWithSelector(DelayedWithdraw.DelayedWithdraw__WithdrawsNotAllowed.selector)));
        withdrawer.requestWithdraw(nonWithdrawableAsset, 100e18);

        // Cancelling a request with zero shares.
        vm.expectRevert(bytes(abi.encodeWithSelector(DelayedWithdraw.DelayedWithdraw__NoSharesToWithdraw.selector)));
        withdrawer.cancelWithdraw(WETH);

        // Completing a withdraw with an asset that is not allowed.
        withdrawer.setupWithdrawAsset(WETH, 1 days, 0, 0.01e4);
        // Requesting withdraws
        uint96 sharesToWithdraw = 100e18;
        vm.startPrank(user);
        boringVault.approve(address(withdrawer), sharesToWithdraw);
        withdrawer.requestWithdraw(WETH, sharesToWithdraw);
        vm.stopPrank();

        // The asset is removed from the withdrawable assets.
        withdrawer.stopWithdrawalsInAsset(WETH);

        vm.expectRevert(bytes(abi.encodeWithSelector(DelayedWithdraw.DelayedWithdraw__WithdrawsNotAllowed.selector)));
        withdrawer.completeWithdraw(WETH, user);

        withdrawer.setupWithdrawAsset(WETH, 1 days, 0, 0.01e4);

        // Withdraw is not matured.
        vm.expectRevert(bytes(abi.encodeWithSelector(DelayedWithdraw.DelayedWithdraw__WithdrawNotMatured.selector)));
        withdrawer.completeWithdraw(WETH, user);

        skip(1 days);

        // Withdraw can now be completed.
        withdrawer.completeWithdraw(WETH, user);

        // But if user tries to withdraw again it reverts.
        vm.expectRevert(bytes(abi.encodeWithSelector(DelayedWithdraw.DelayedWithdraw__NoSharesToWithdraw.selector)));
        withdrawer.completeWithdraw(WETH, user);
    }

    function testAdminFunctionReverts() external {
        vm.expectRevert(bytes(abi.encodeWithSelector(DelayedWithdraw.DelayedWithdraw__WithdrawsNotAllowed.selector)));
        withdrawer.stopWithdrawalsInAsset(WETH);

        vm.expectRevert(bytes(abi.encodeWithSelector(DelayedWithdraw.DelayedWithdraw__WithdrawFeeTooHigh.selector)));
        withdrawer.setupWithdrawAsset(WETH, 1 days, 0.2001e4, 0);

        vm.expectRevert(bytes(abi.encodeWithSelector(DelayedWithdraw.DelayedWithdraw__MaxLossTooLarge.selector)));
        withdrawer.setupWithdrawAsset(WETH, 1 days, 0, 0.5001e4);

        withdrawer.setupWithdrawAsset(WETH, 1 days, 0, 0);

        vm.expectRevert(bytes(abi.encodeWithSelector(DelayedWithdraw.DelayedWithdraw__AlreadySetup.selector)));
        withdrawer.setupWithdrawAsset(WETH, 1 days, 0, 0);

        vm.expectRevert(bytes(abi.encodeWithSelector(DelayedWithdraw.DelayedWithdraw__WithdrawsNotAllowed.selector)));
        withdrawer.changeWithdrawDelay(EETH, 1 days);

        vm.expectRevert(bytes(abi.encodeWithSelector(DelayedWithdraw.DelayedWithdraw__WithdrawsNotAllowed.selector)));
        withdrawer.changeWithdrawFee(EETH, 0);

        vm.expectRevert(bytes(abi.encodeWithSelector(DelayedWithdraw.DelayedWithdraw__WithdrawFeeTooHigh.selector)));
        withdrawer.changeWithdrawFee(WETH, 0.2001e4);

        vm.expectRevert(bytes(abi.encodeWithSelector(DelayedWithdraw.DelayedWithdraw__WithdrawsNotAllowed.selector)));
        withdrawer.changeMaxLoss(EETH, 0);

        vm.expectRevert(bytes(abi.encodeWithSelector(DelayedWithdraw.DelayedWithdraw__MaxLossTooLarge.selector)));
        withdrawer.changeMaxLoss(WETH, 0.5001e4);

        vm.expectRevert(bytes(abi.encodeWithSelector(DelayedWithdraw.DelayedWithdraw__BadAddress.selector)));
        withdrawer.setFeeAddress(address(0));
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
