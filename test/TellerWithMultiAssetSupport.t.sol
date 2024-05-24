// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {ILiquidityPool} from "src/interfaces/IStaking.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {AtomicSolverV3, AtomicQueue} from "src/atomic-queue/AtomicSolverV3.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract TellerWithMultiAssetSupportTest is Test, MainnetAddresses {
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

    TellerWithMultiAssetSupport public teller;
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

        teller =
            new TellerWithMultiAssetSupport(address(this), address(boringVault), address(accountant), address(WETH));

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

    function testDepositReverting(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);
        // Turn on share lock period, and deposit reverting
        boringVault.setBeforeTransferHook(address(teller));

        teller.setShareLockPeriod(1 days);

        uint256 wETH_amount = amount;
        deal(address(WETH), address(this), wETH_amount);
        uint256 eETH_amount = amount;
        deal(address(this), eETH_amount + 1);
        ILiquidityPool(EETH_LIQUIDITY_POOL).deposit{value: eETH_amount + 1}();

        WETH.safeApprove(address(boringVault), wETH_amount);
        EETH.safeApprove(address(boringVault), eETH_amount);
        uint256 shares0 = teller.deposit(WETH, wETH_amount, 0);
        uint256 firstDepositTimestamp = block.timestamp;
        // Skip 1 days to finalize first deposit.
        skip(1 days + 1);
        uint256 shares1 = teller.deposit(EETH, eETH_amount, 0);
        uint256 secondDepositTimestamp = block.timestamp;

        // Even if setShareLockPeriod is set to 2 days, first deposit is still not revertable.
        teller.setShareLockPeriod(2 days);

        // If depositReverter tries to revert the first deposit, call fails.
        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__SharesAreUnLocked.selector)
        );
        teller.refundDeposit(1, address(this), address(WETH), wETH_amount, shares0, firstDepositTimestamp, 1 days);

        // However the second deposit is still revertable.
        teller.refundDeposit(2, address(this), address(EETH), eETH_amount, shares1, secondDepositTimestamp, 1 days);

        // Calling revert deposit again should revert.
        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__BadDepositHash.selector)
        );
        teller.refundDeposit(2, address(this), address(EETH), eETH_amount, shares1, secondDepositTimestamp, 1 days);
    }

    function testUserDepositPeggedAssets(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);

        uint256 wETH_amount = amount;
        deal(address(WETH), address(this), wETH_amount);
        uint256 eETH_amount = amount;
        deal(address(this), eETH_amount + 1);
        ILiquidityPool(EETH_LIQUIDITY_POOL).deposit{value: eETH_amount + 1}();

        WETH.safeApprove(address(boringVault), wETH_amount);
        EETH.safeApprove(address(boringVault), eETH_amount);

        teller.deposit(WETH, wETH_amount, 0);
        teller.deposit(EETH, eETH_amount, 0);

        uint256 expected_shares = 2 * amount;

        assertEq(boringVault.balanceOf(address(this)), expected_shares, "Should have received expected shares");
    }

    function testUserDepositNonPeggedAssets(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);

        uint256 weETH_amount = amount.mulDivDown(1e18, IRateProvider(WEETH_RATE_PROVIDER).getRate());
        deal(address(WEETH), address(this), weETH_amount);

        WEETH.safeApprove(address(boringVault), weETH_amount);

        teller.deposit(WEETH, weETH_amount, 0);

        uint256 expected_shares = amount;

        assertApproxEqRel(
            boringVault.balanceOf(address(this)), expected_shares, 0.000001e18, "Should have received expected shares"
        );
    }

    function testUserDepositNative(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);

        deal(address(this), 2 * amount);

        teller.deposit{value: amount}(ERC20(NATIVE), 0, 0);

        assertEq(boringVault.balanceOf(address(this)), amount, "Should have received expected shares");
    }

    function testUserPermitDeposit(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);

        uint256 userKey = 111;
        address user = vm.addr(userKey);

        uint256 weETH_amount = amount.mulDivDown(1e18, IRateProvider(WEETH_RATE_PROVIDER).getRate());
        deal(address(WEETH), user, weETH_amount);
        // function sign(uint256 privateKey, bytes32 digest) external pure returns (uint8 v, bytes32 r, bytes32 s);
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                WEETH.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        user,
                        address(boringVault),
                        weETH_amount,
                        WEETH.nonces(user),
                        block.timestamp
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userKey, digest);

        vm.startPrank(user);
        teller.depositWithPermit(WEETH, weETH_amount, 0, block.timestamp, v, r, s);
        vm.stopPrank();

        // and if user supplied wrong permit data, deposit will fail.
        digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                WEETH.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        user,
                        address(boringVault),
                        weETH_amount,
                        WEETH.nonces(user),
                        block.timestamp
                    )
                )
            )
        );
        (v, r, s) = vm.sign(userKey, digest);

        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__PermitFailedAndAllowanceTooLow.selector
            )
        );
        teller.depositWithPermit(WEETH, weETH_amount, 0, block.timestamp, v, r, s);
        vm.stopPrank();
    }

    function testUserPermitDepositWithFrontRunning(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);

        uint256 userKey = 111;
        address user = vm.addr(userKey);

        uint256 weETH_amount = amount.mulDivDown(1e18, IRateProvider(WEETH_RATE_PROVIDER).getRate());
        deal(address(WEETH), user, weETH_amount);
        // function sign(uint256 privateKey, bytes32 digest) external pure returns (uint8 v, bytes32 r, bytes32 s);
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                WEETH.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        user,
                        address(boringVault),
                        weETH_amount,
                        WEETH.nonces(user),
                        block.timestamp
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userKey, digest);

        // Assume attacker seems users TX in the mem pool and tries griefing them by calling `permit` first.
        address attacker = vm.addr(0xDEAD);
        vm.startPrank(attacker);
        WEETH.permit(user, address(boringVault), weETH_amount, block.timestamp, v, r, s);
        vm.stopPrank();

        // Users TX is still successful.
        vm.startPrank(user);
        teller.depositWithPermit(WEETH, weETH_amount, 0, block.timestamp, v, r, s);
        vm.stopPrank();

        assertTrue(boringVault.balanceOf(user) > 0, "Should have received shares");
    }

    function testBulkDeposit(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);

        uint256 wETH_amount = amount;
        deal(address(WETH), address(this), wETH_amount);
        uint256 eETH_amount = amount;
        deal(address(this), eETH_amount + 1);
        ILiquidityPool(EETH_LIQUIDITY_POOL).deposit{value: eETH_amount + 1}();
        uint256 weETH_amount = amount.mulDivDown(1e18, IRateProvider(WEETH_RATE_PROVIDER).getRate());
        deal(address(WEETH), address(this), weETH_amount);

        WETH.safeApprove(address(boringVault), wETH_amount);
        EETH.safeApprove(address(boringVault), eETH_amount);
        WEETH.safeApprove(address(boringVault), weETH_amount);

        teller.bulkDeposit(WETH, wETH_amount, 0, address(this));
        teller.bulkDeposit(EETH, eETH_amount, 0, address(this));
        teller.bulkDeposit(WEETH, weETH_amount, 0, address(this));

        uint256 expected_shares = 3 * amount;

        assertApproxEqRel(
            boringVault.balanceOf(address(this)), expected_shares, 0.0001e18, "Should have received expected shares"
        );
    }

    function testBulkWithdraw(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);

        uint256 wETH_amount = amount;
        deal(address(WETH), address(this), wETH_amount);
        uint256 eETH_amount = amount;
        deal(address(this), eETH_amount + 1);
        ILiquidityPool(EETH_LIQUIDITY_POOL).deposit{value: eETH_amount + 1}();
        uint256 weETH_amount = amount.mulDivDown(1e18, IRateProvider(WEETH_RATE_PROVIDER).getRate());
        deal(address(WEETH), address(this), weETH_amount);

        WETH.safeApprove(address(boringVault), wETH_amount);
        EETH.safeApprove(address(boringVault), eETH_amount);
        WEETH.safeApprove(address(boringVault), weETH_amount);

        uint256 shares_0 = teller.bulkDeposit(WETH, wETH_amount, 0, address(this));
        uint256 shares_1 = teller.bulkDeposit(EETH, eETH_amount, 0, address(this));
        uint256 shares_2 = teller.bulkDeposit(WEETH, weETH_amount, 0, address(this));

        uint256 assets_out_0 = teller.bulkWithdraw(WETH, shares_0, 0, address(this));
        uint256 assets_out_1 = teller.bulkWithdraw(EETH, shares_1, 0, address(this));
        uint256 assets_out_2 = teller.bulkWithdraw(WEETH, shares_2, 0, address(this));

        assertApproxEqAbs(assets_out_0, wETH_amount, 1, "Should have received expected wETH assets");
        assertApproxEqAbs(assets_out_1, eETH_amount, 1, "Should have received expected eETH assets");
        assertApproxEqAbs(assets_out_2, weETH_amount, 1, "Should have received expected weETH assets");
    }

    function testWithdrawWithAtomicQueue(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);

        address user = vm.addr(9);
        uint256 wETH_amount = amount;
        deal(address(WETH), user, wETH_amount);

        vm.startPrank(user);
        WETH.safeApprove(address(boringVault), wETH_amount);

        uint256 shares = teller.deposit(WETH, wETH_amount, 0);

        // Share lock period is not set, so user can submit withdraw request immediately.
        AtomicQueue.AtomicRequest memory req = AtomicQueue.AtomicRequest({
            deadline: uint64(block.timestamp + 1 days),
            atomicPrice: 1e18,
            offerAmount: uint96(shares),
            inSolve: false
        });
        boringVault.approve(address(atomicQueue), shares);
        atomicQueue.updateAtomicRequest(boringVault, WETH, req);
        vm.stopPrank();

        // Solver approves solver contract to spend enough assets to cover withdraw.
        vm.startPrank(solver);
        WETH.safeApprove(address(atomicSolverV3), wETH_amount);
        // Solve withdraw request.
        address[] memory users = new address[](1);
        users[0] = user;
        atomicSolverV3.redeemSolve(atomicQueue, boringVault, WETH, users, 0, type(uint256).max, teller);
        vm.stopPrank();
    }

    function testAssetIsSupported() external {
        assertTrue(teller.isSupported(WETH) == true, "WETH should be supported");

        teller.removeAsset(WETH);

        assertTrue(teller.isSupported(WETH) == false, "WETH should not be supported");

        teller.addAsset(WETH);

        assertTrue(teller.isSupported(WETH) == true, "WETH should be supported");
    }

    function testDenyList() external {
        boringVault.setBeforeTransferHook(address(teller));
        address attacker = vm.addr(0xDEAD);
        deal(address(boringVault), attacker, 1e18, true);
        // Transfers currently work.
        vm.prank(attacker);
        boringVault.transfer(address(this), 0.1e18);

        // But if attacker is added to the deny list, transfers should fail.
        teller.denyAll(attacker);

        vm.startPrank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferDenied.selector,
                attacker,
                address(this),
                attacker
            )
        );
        boringVault.transfer(address(this), 0.1e18);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferDenied.selector,
                attacker,
                address(this),
                address(this)
            )
        );
        boringVault.transferFrom(attacker, address(this), 0.1e18);

        // If attacker is removed from the deny list, transfers should work again.
        teller.allowAll(attacker);

        vm.prank(attacker);
        boringVault.transfer(address(this), 0.1e18);

        // Make sure we can deny certain operators.
        address operator = vm.addr(2);
        address normalUser = vm.addr(3);

        teller.denyAll(operator);

        vm.startPrank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferDenied.selector,
                normalUser,
                normalUser,
                operator
            )
        );
        boringVault.transferFrom(normalUser, normalUser, 1e18);
        vm.stopPrank();
    }

    // TODO add tests checking logic of deny from, to, operator.

    function testReverts() external {
        // Test pause logic
        teller.pause();

        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__Paused.selector)
        );
        teller.deposit(WETH, 0, 0);

        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__Paused.selector)
        );
        teller.depositWithPermit(WETH, 0, 0, 0, 0, bytes32(0), bytes32(0));

        teller.unpause();

        teller.removeAsset(WETH);

        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__AssetNotSupported.selector)
        );
        teller.deposit(WETH, 0, 0);

        teller.addAsset(WETH);

        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__ZeroAssets.selector)
        );
        teller.deposit(WETH, 0, 0);

        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__DualDeposit.selector)
        );
        teller.deposit{value: 1}(WETH, 1, 0);

        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__MinimumMintNotMet.selector)
        );
        teller.deposit(WETH, 1, type(uint256).max);

        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__ZeroAssets.selector)
        );
        teller.deposit(NATIVE_ERC20, 0, 0);

        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__MinimumMintNotMet.selector)
        );
        teller.deposit{value: 1}(NATIVE_ERC20, 1, type(uint256).max);

        // bulkDeposit reverts
        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__ZeroAssets.selector)
        );
        teller.bulkDeposit(WETH, 0, 0, address(this));

        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__MinimumMintNotMet.selector)
        );
        teller.bulkDeposit(WETH, 1, type(uint256).max, address(this));

        // bulkWithdraw reverts
        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__ZeroShares.selector)
        );
        teller.bulkWithdraw(WETH, 0, 0, address(this));

        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__MinimumAssetsNotMet.selector
            )
        );
        teller.bulkWithdraw(WETH, 1, type(uint256).max, address(this));

        // Set share lock reverts
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__ShareLockPeriodTooLong.selector
            )
        );
        teller.setShareLockPeriod(3 days + 1);

        teller.setShareLockPeriod(3 days);
        boringVault.setBeforeTransferHook(address(teller));

        // Have user deposit
        address user = vm.addr(333);
        vm.startPrank(user);
        uint256 wETH_amount = 1e18;
        deal(address(WETH), user, wETH_amount);
        WETH.safeApprove(address(boringVault), wETH_amount);

        teller.deposit(WETH, wETH_amount, 0);

        // Trying to transfer shares should revert.
        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__SharesAreLocked.selector)
        );
        boringVault.transfer(address(this), 1);

        vm.stopPrank();
        // Calling transferFrom should also revert.
        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__SharesAreLocked.selector)
        );
        boringVault.transferFrom(user, address(this), 1);

        // But if user waits 3 days.
        skip(3 days + 1);
        // They can now transfer.
        vm.prank(user);
        boringVault.transfer(address(this), 1);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
