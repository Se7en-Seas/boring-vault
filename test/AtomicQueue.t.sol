// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {ILiquidityPool} from "src/interfaces/IStaking.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {AtomicSolverV3, AtomicQueue} from "src/atomic-queue/AtomicSolverV3.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AtomicSolverV3, AtomicQueue} from "src/atomic-queue/AtomicSolverV3.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract AtomicQueueTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    BoringVault public boringVault;

    uint8 public constant MINTER_ROLE = 1;
    uint8 public constant BURNER_ROLE = 2;
    uint8 public constant SOLVER_ROLE = 3;
    uint8 public constant QUEUE_ROLE = 4;

    TellerWithMultiAssetSupport public teller;
    AccountantWithRateProviders public accountant;
    AtomicQueue public atomicQueue;
    AtomicSolverV3 public atomicSolverV3;
    address public payoutAddress = vm.addr(7777777);
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    ERC20 internal constant NATIVE_ERC20 = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    RolesAuthority public rolesAuthority;
    ERC20 internal WETH;
    ERC20 internal EETH;
    ERC20 internal WEETH;
    ERC20 internal USDC;
    address internal WEETH_RATE_PROVIDER;

    address internal user = vm.addr(1);

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 20341522;
        _startFork(rpcKey, blockNumber);

        WETH = getERC20(sourceChain, "WETH");
        EETH = getERC20(sourceChain, "EETH");
        WEETH = getERC20(sourceChain, "WEETH");
        USDC = getERC20(sourceChain, "USDC");
        WEETH_RATE_PROVIDER = getAddress(sourceChain, "WEETH_RATE_PROVIDER");

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payoutAddress, 1e18, address(WETH), 1.1e4, 0.9e4, 1, 0, 0
        );

        teller =
            new TellerWithMultiAssetSupport(address(this), address(boringVault), address(accountant), address(WETH));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));

        atomicQueue = new AtomicQueue(address(this), rolesAuthority);
        atomicSolverV3 = new AtomicSolverV3(address(this), rolesAuthority);

        boringVault.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);
        rolesAuthority.setRoleCapability(
            SOLVER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkDeposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            SOLVER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
        );
        rolesAuthority.setRoleCapability(QUEUE_ROLE, address(atomicSolverV3), AtomicSolverV3.finishSolve.selector, true);
        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);
        rolesAuthority.setPublicCapability(address(atomicQueue), AtomicQueue.updateAtomicRequest.selector, true);
        rolesAuthority.setPublicCapability(address(atomicQueue), AtomicQueue.safeUpdateAtomicRequest.selector, true);
        rolesAuthority.setPublicCapability(address(atomicQueue), AtomicQueue.solve.selector, true);

        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);
        rolesAuthority.setUserRole(address(atomicSolverV3), SOLVER_ROLE, true);
        rolesAuthority.setUserRole(address(atomicQueue), QUEUE_ROLE, true);

        accountant.setRateProviderData(WEETH, false, address(WEETH_RATE_PROVIDER));

        teller.addAsset(WETH);
        teller.addAsset(WEETH);

        // User buys some BoringVault shares.
        deal(address(WETH), address(user), 1_000e18);
        deal(address(WEETH), address(user), 1_001e18);

        vm.startPrank(user);
        WETH.approve(address(boringVault), type(uint256).max);
        WEETH.approve(address(boringVault), type(uint256).max);
        WEETH.approve(address(atomicQueue), type(uint256).max);
        boringVault.approve(address(atomicQueue), type(uint256).max);
        teller.deposit(WETH, 1_000e18, 0);
        teller.deposit(WEETH, 1_000e18, 0);
        vm.stopPrank();
    }

    function testPausing() public {
        atomicQueue.pause();
        assertEq(atomicQueue.isPaused(), true, "Queue should be paused");
        atomicQueue.unpause();
        assertEq(atomicQueue.isPaused(), false, "Queue should be unpaused");

        // When the Queue is paused new atomic requests should revert.
        atomicQueue.pause();
        vm.startPrank(user);
        AtomicQueue.AtomicRequest memory req = AtomicQueue.AtomicRequest({
            deadline: uint64(block.timestamp + 1),
            atomicPrice: uint88(1e18),
            offerAmount: uint96(1e18),
            inSolve: false
        });
        vm.expectRevert(bytes(abi.encodeWithSelector(AtomicQueue.AtomicQueue__Paused.selector)));
        atomicQueue.updateAtomicRequest(boringVault, WETH, req);

        vm.expectRevert(bytes(abi.encodeWithSelector(AtomicQueue.AtomicQueue__Paused.selector)));
        atomicQueue.safeUpdateAtomicRequest(boringVault, WETH, req, accountant, 0.0001e6);
        vm.stopPrank();

        vm.expectRevert(bytes(abi.encodeWithSelector(AtomicQueue.AtomicQueue__Paused.selector)));
        atomicQueue.solve(boringVault, WETH, new address[](0), hex"", address(0));
    }

    function testSafeUpadteAtomicRequest() external {
        // User makes a safe atomic request
        AtomicQueue.AtomicRequest memory req = AtomicQueue.AtomicRequest({
            deadline: uint64(block.timestamp + 1),
            atomicPrice: uint88(0),
            offerAmount: uint96(1e18),
            inSolve: false
        });
        vm.prank(user);
        atomicQueue.safeUpdateAtomicRequest(boringVault, WEETH, req, accountant, 0.0001e6);

        // Zero out users weETH balance.
        deal(address(WEETH), user, 0);

        // Solver solves it.
        deal(address(WEETH), address(this), 1_000e18);
        WEETH.approve(address(atomicSolverV3), type(uint256).max);
        address[] memory users = new address[](1);
        users[0] = user;
        atomicSolverV3.p2pSolve(atomicQueue, boringVault, WEETH, users, 0, type(uint256).max);

        uint256 expectedWeethForUser = accountant.getRateInQuoteSafe(WEETH).mulDivDown(0.9999e4, 1e4);
        assertApproxEqAbs(WEETH.balanceOf(user), expectedWeethForUser, 2, "User should receive WEETH");
    }

    function testSafeUpdateAtomicRequestReverts() external {
        vm.startPrank(user);
        AtomicQueue.AtomicRequest memory unsafeRequest = AtomicQueue.AtomicRequest({
            deadline: uint64(block.timestamp + 1),
            atomicPrice: uint88(1e18),
            offerAmount: type(uint96).max,
            inSolve: false
        });
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    AtomicQueue.AtomicQueue__SafeRequestOfferAmountGreaterThanOfferBalance.selector,
                    unsafeRequest.offerAmount,
                    boringVault.balanceOf(user)
                )
            )
        );
        atomicQueue.safeUpdateAtomicRequest(boringVault, WETH, unsafeRequest, accountant, 0.0001e6);

        unsafeRequest = AtomicQueue.AtomicRequest({
            deadline: uint64(block.timestamp - 1),
            atomicPrice: uint88(1e18),
            offerAmount: uint96(1e18),
            inSolve: false
        });
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    AtomicQueue.AtomicQueue__SafeRequestDeadlineExceeded.selector, unsafeRequest.deadline
                )
            )
        );
        atomicQueue.safeUpdateAtomicRequest(boringVault, WETH, unsafeRequest, accountant, 0.0001e6);

        unsafeRequest = AtomicQueue.AtomicRequest({
            deadline: uint64(block.timestamp + 1),
            atomicPrice: uint88(1e18),
            offerAmount: uint96(1e18),
            inSolve: false
        });

        boringVault.approve(address(atomicQueue), 0);

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    AtomicQueue.AtomicQueue__SafeRequestInsufficientOfferAllowance.selector,
                    unsafeRequest.offerAmount,
                    0
                )
            )
        );
        atomicQueue.safeUpdateAtomicRequest(boringVault, WETH, unsafeRequest, accountant, 0.0001e6);

        boringVault.approve(address(atomicQueue), type(uint256).max);

        unsafeRequest = AtomicQueue.AtomicRequest({
            deadline: uint64(block.timestamp + 1),
            atomicPrice: uint88(1e18),
            offerAmount: uint96(0),
            inSolve: false
        });
        vm.expectRevert(bytes(abi.encodeWithSelector(AtomicQueue.AtomicQueue__SafeRequestOfferAmountZero.selector)));
        atomicQueue.safeUpdateAtomicRequest(boringVault, WETH, unsafeRequest, accountant, 0.0001e6);

        unsafeRequest = AtomicQueue.AtomicRequest({
            deadline: uint64(block.timestamp + 1),
            atomicPrice: uint88(1e18),
            offerAmount: uint96(1e18),
            inSolve: false
        });
        vm.expectRevert(bytes(abi.encodeWithSelector(AtomicQueue.AtomicQueue__SafeRequestDiscountTooLarge.selector)));
        atomicQueue.safeUpdateAtomicRequest(boringVault, WETH, unsafeRequest, accountant, 0.010001e6);

        vm.expectRevert(
            bytes(abi.encodeWithSelector(AtomicQueue.AtomicQueue__SafeRequestAccountantOfferMismatch.selector))
        );
        atomicQueue.safeUpdateAtomicRequest(WEETH, WETH, unsafeRequest, accountant, 0.0001e6);

        vm.stopPrank();
        accountant.updateExchangeRate(type(uint96).max);
        accountant.unpause();

        vm.startPrank(user);
        vm.expectRevert(bytes(abi.encodeWithSelector(AtomicQueue.AtomicQueue__SafeRequestCannotCastToUint88.selector)));
        atomicQueue.safeUpdateAtomicRequest(boringVault, WETH, unsafeRequest, accountant, 0.0001e6);
        vm.stopPrank();
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
