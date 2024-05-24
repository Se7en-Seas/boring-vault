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
            address(this), address(boringVault), payoutAddress, 1e18, address(WETH), 1.001e4, 0.999e4, 1, 0, 0
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

        // SImulate user deposit by minting 1_000 shares to them, and giving BoringVault 1_000 WETH/.
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

    // TODO test where exchange rate is updated up after request is made
    // TODO test where exchange rate is updated down after request is made
    // TODO test where we make sure a request can be cancelled even if the asset is no longer allowed for withdraws, or if the accountant drops the asset
    // TODO tests where we check if the maxLoss logic works
    // TODO revert tests user functions
    // TODO revert tests admin functions
    // TODO tests where we check the effects of the admin functions
    // TODO malicious exchange rate update to zero should cause max loss to proc
    // TODO check that fees work as expected.

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
