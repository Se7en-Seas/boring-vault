// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {TellerWithRemediation, TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithRemediation.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {ILiquidityPool} from "src/interfaces/IStaking.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {AtomicSolverV3, AtomicQueue} from "src/atomic-queue/AtomicSolverV3.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract TellerWithRemediationTest is Test, MainnetAddresses {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    BoringVault public boringVault;

    uint8 public constant ADMIN_ROLE = 1;
    uint8 public constant MINTER_ROLE = 7;
    uint8 public constant BURNER_ROLE = 8;
    uint8 public constant SOLVER_ROLE = 9;
    uint8 public constant QUEUE_ROLE = 10;
    uint8 public constant CAN_SOLVE_ROLE = 11;

    TellerWithRemediation public teller;
    AccountantWithRateProviders public accountant;
    address public payout_address = vm.addr(7777777);
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    ERC20 internal constant NATIVE_ERC20 = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    RolesAuthority public rolesAuthority;
    AtomicQueue public atomicQueue;
    AtomicSolverV3 public atomicSolverV3;

    address public solver = vm.addr(54);

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19363419;
        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payout_address, 1e18, address(WETH), 1.001e4, 0.999e4, 1, 0, 0
        );

        teller = new TellerWithRemediation(address(this), address(boringVault), address(accountant), address(WETH));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));

        atomicQueue = new AtomicQueue();
        atomicSolverV3 = new AtomicSolverV3(address(this), rolesAuthority);

        boringVault.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.addAsset.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.removeAsset.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.bulkDeposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.refundDeposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            SOLVER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
        );
        rolesAuthority.setRoleCapability(QUEUE_ROLE, address(atomicSolverV3), AtomicSolverV3.finishSolve.selector, true);
        rolesAuthority.setRoleCapability(
            CAN_SOLVE_ROLE, address(atomicSolverV3), AtomicSolverV3.redeemSolve.selector, true
        );
        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);
        rolesAuthority.setPublicCapability(
            address(teller), TellerWithMultiAssetSupport.depositWithPermit.selector, true
        );

        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);
        rolesAuthority.setUserRole(address(atomicSolverV3), SOLVER_ROLE, true);
        rolesAuthority.setUserRole(address(atomicQueue), QUEUE_ROLE, true);
        rolesAuthority.setUserRole(solver, CAN_SOLVE_ROLE, true);

        teller.addAsset(WETH);
        teller.addAsset(ERC20(NATIVE));
        teller.addAsset(EETH);
        teller.addAsset(WEETH);

        accountant.setRateProviderData(EETH, true, address(0));
        accountant.setRateProviderData(WEETH, false, address(WEETH_RATE_PROVIDER));
    }

    function testRemediation() external {
        boringVault.setBeforeTransferHook(address(teller));

        uint256 amountOfSharesStolen = 1e18;
        address phisher = vm.addr(0xDEAD);
        address victim0 = vm.addr(0xBEEF);
        deal(address(boringVault), victim0, amountOfSharesStolen, true);

        // Assume phisher is able to steal victim0s shares.
        vm.prank(victim0);
        boringVault.transfer(phisher, amountOfSharesStolen);

        // Calling completeRemediation should revert since it has not been started.
        vm.expectRevert(
            abi.encodeWithSelector(TellerWithRemediation.TellerWithRemediation__RemediationNotStarted.selector)
        );
        teller.completeRemediation(phisher);

        // Remediator starts remediation process.
        teller.freezeSharesAndStartRemediation(phisher, victim0, amountOfSharesStolen);

        // Phisher is not able to transfer shares.
        vm.startPrank(phisher);
        vm.expectRevert(
            abi.encodeWithSelector(TellerWithRemediation.TellerWithRemediation__RemediationInProgress.selector, phisher)
        );
        boringVault.transfer(vm.addr(1), amountOfSharesStolen);
        vm.stopPrank();

        // Remediator is not able to complete remediation until REMEDIATION_PERIOD has passed.
        vm.expectRevert(
            abi.encodeWithSelector(TellerWithRemediation.TellerWithRemediation__RemediationTimeNotMet.selector)
        );
        teller.completeRemediation(phisher);

        skip(3 days + 1);

        // Remediation can now be completed.
        teller.completeRemediation(phisher);

        assertEq(boringVault.balanceOf(phisher), 0, "Phisher should have had shares removed.");
        assertEq(boringVault.balanceOf(victim0), amountOfSharesStolen, "Victim0 should have had shares returned.");

        // Assume phisher was able to trick victim0 again.
        vm.prank(victim0);
        boringVault.transfer(phisher, amountOfSharesStolen);

        // Calling completeRemediation should revert since it has not been started.
        vm.expectRevert(
            abi.encodeWithSelector(TellerWithRemediation.TellerWithRemediation__RemediationNotStarted.selector)
        );
        teller.completeRemediation(phisher);

        // Since phisher has constantly done this, shares will be remediated to a remediator address, where from there
        // they can distributed.
        address remediator = vm.addr(777);

        address victim1 = vm.addr(0xCAFEBABE);
        deal(address(boringVault), victim1, amountOfSharesStolen, true);

        // Assume phisher is able to steal victim1s shares.
        vm.prank(victim1);
        boringVault.transfer(phisher, amountOfSharesStolen);

        // Start a new remediation but use type(uint256).max as amount of shares stolen.
        teller.freezeSharesAndStartRemediation(phisher, remediator, type(uint256).max);

        // Eventhough we already started a remediation, since we used type(uint256).max as amount, we do not need to start another one.

        skip(3 days + 1);

        // Remediation can now be completed.
        teller.completeRemediation(phisher);

        assertEq(boringVault.balanceOf(phisher), 0, "Phisher should have had shares removed.");
        assertEq(
            boringVault.balanceOf(remediator),
            2 * amountOfSharesStolen,
            "Remediator should have received all phishers shares."
        );
        (bool isFrozen, uint64 time, address a, uint256 amount) = teller.remediationInfo(phisher);
        assertEq(isFrozen, false, "User should not be frozen.");
        assertEq(time, 0, "Time should be 0");
        assertEq(a, address(0), "Address should be 0");
        assertEq(amount, 0, "Amount should be 0");
    }

    function testRemediationForUserNotUnderogingRemediation() external {
        address user = vm.addr(1);

        vm.expectRevert(
            abi.encodeWithSelector(TellerWithRemediation.TellerWithRemediation__RemediationNotStarted.selector)
        );
        teller.completeRemediation(user);
    }

    function testCancellingRemediation() external {
        boringVault.setBeforeTransferHook(address(teller));

        address user = vm.addr(1);
        deal(address(boringVault), user, 1e18, true);

        teller.freezeSharesAndStartRemediation(user, address(this), 1e18);

        // User can not transfer shares now.
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(TellerWithRemediation.TellerWithRemediation__RemediationInProgress.selector, user)
        );
        boringVault.transfer(address(this), 1e18);
        vm.stopPrank();

        // User gets in touch with us and we learn that they were not phished.
        teller.cancelRemediationAndUnlockShares(user);

        (bool isFrozen, uint64 time, address a, uint256 amount) = teller.remediationInfo(user);
        assertEq(isFrozen, false, "User should not be frozen.");
        assertEq(time, 0, "Time should be 0");
        assertEq(a, address(0), "Address should be 0");
        assertEq(amount, 0, "Amount should be 0");

        // User should be able to transfer shares now.
        vm.prank(user);
        boringVault.transfer(address(this), 1e18);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
