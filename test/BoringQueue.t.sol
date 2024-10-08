// SPDX-License-Identifier: UNLICENSED
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
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract BoringQueueTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    BoringVault public boringVault;

    uint8 public constant MINTER_ROLE = 1;
    uint8 public constant BURNER_ROLE = 2;
    uint8 public constant SOLVER_ROLE = 3;
    uint8 public constant QUEUE_ROLE = 4;

    address public weETHs = 0x917ceE801a67f933F2e6b33fC0cD1ED2d5909D88;
    AccountantWithRateProviders public weETHs_accountant =
        AccountantWithRateProviders(0xbe16605B22a7faCEf247363312121670DFe5afBE);
    address public weETHs_teller = 0x99dE9e5a3eC2750a6983C8732E6e795A35e7B861;
    RolesAuthority public weETHs_roles_authority = RolesAuthority(0x402DFF43b4f24b006BBD6520a11C169f81085039);

    address public liquidEth = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C;
    AccountantWithRateProviders public liquidEth_accountant =
        AccountantWithRateProviders(0x0d05D94a5F1E76C18fbeB7A13d17C8a314088198);
    address public liquidEth_teller = 0x5c135e8eC99557b412b9B4492510dCfBD36066F5;
    RolesAuthority public liquidEth_roles_authority = RolesAuthority(0x485Bde66Bb668a51f2372E34e45B1c6226798122);

    address public testUser = vm.addr(1);

    BoringOnChainQueue public boringQueue;
    BoringSolver public boringSolver;
    ERC20 internal WETH;
    ERC20 internal EETH;
    ERC20 internal WEETH;
    ERC20 internal USDC;
    address internal WEETH_RATE_PROVIDER;

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 20842935;
        _startFork(rpcKey, blockNumber);

        WETH = getERC20(sourceChain, "WETH");
        EETH = getERC20(sourceChain, "EETH");
        WEETH = getERC20(sourceChain, "WEETH");
        USDC = getERC20(sourceChain, "USDC");
        WEETH_RATE_PROVIDER = getAddress(sourceChain, "WEETH_RATE_PROVIDER");

        boringQueue = new BoringOnChainQueue(
            address(this), address(liquidEth_roles_authority), payable(liquidEth), address(liquidEth_accountant), true
        );
        boringSolver = new BoringSolver(address(this), address(liquidEth_roles_authority));

        // Grant BoringSolver SOLVER_ROLES for on both vaults.
        vm.startPrank(weETHs_roles_authority.owner());
        weETHs_roles_authority.setUserRole(address(boringSolver), 12, true);
        vm.stopPrank();
        // Also add weETHs to liquid Eths accountant.
        vm.startPrank(liquidEth_roles_authority.owner());
        liquidEth_roles_authority.setUserRole(address(boringSolver), 12, true);
        liquidEth_accountant.setRateProviderData(ERC20(weETHs), false, address(weETHs_accountant));
        liquidEth_roles_authority.setPublicCapability(
            address(boringQueue), BoringOnChainQueue.requestOnChainWithdraw.selector, true
        );
        liquidEth_roles_authority.setPublicCapability(
            address(boringQueue), BoringOnChainQueue.requestOnChainWithdrawWithPermit.selector, true
        );
        liquidEth_roles_authority.setPublicCapability(
            address(boringQueue), BoringOnChainQueue.cancelOnChainWithdraw.selector, true
        );
        liquidEth_roles_authority.setPublicCapability(
            address(boringQueue), BoringOnChainQueue.cancelOnChainWithdrawUsingRequestId.selector, true
        );
        liquidEth_roles_authority.setPublicCapability(
            address(boringQueue), BoringOnChainQueue.replaceOnChainWithdraw.selector, true
        );
        liquidEth_roles_authority.setPublicCapability(
            address(boringQueue), BoringOnChainQueue.replaceOnChainWithdrawUsingRequestId.selector, true
        );
        liquidEth_roles_authority.setPublicCapability(
            address(boringQueue), BoringOnChainQueue.solveOnChainWithdraws.selector, true
        );
        liquidEth_roles_authority.setPublicCapability(
            address(boringSolver), BoringSolver.boringRedeemSelfSolve.selector, true
        );
        liquidEth_roles_authority.setRoleCapability(222, address(boringSolver), BoringSolver.boringSolve.selector, true);
        liquidEth_roles_authority.setUserRole(address(boringQueue), 222, true);
        vm.stopPrank();

        // Give test user some Liquid ETH shares.
        deal(liquidEth, testUser, 1_000e18);

        // Make sure liquidEth has wETH.
        deal(address(WETH), liquidEth, 10_000e18);

        // Make sure this address has wETH.
        deal(address(WETH), address(this), 10_000e18);

        // Add wETH as a withdraw asset on the boringQueue.
        boringQueue.setupWithdrawAsset(address(WETH), 3 days, 1 days, 1, 100, 0.01e18);

        // Add weETHs as a withdraw asset on the boringQueue.
        boringQueue.setupWithdrawAsset(weETHs, 0, 1 days, 1, 100, 0.01e18);

        deal(address(liquidEth), address(boringQueue), 1);
    }

    // User interacts with atomic queue directly to "buy" shares
    function testP2PSolve(uint128 amountOfShares, uint16 discount) external {
        amountOfShares = uint128(bound(amountOfShares, 0.01e18, 1_000e18));
        discount = uint16(bound(discount, 1, 100));
        uint24 secondsToDeadline = 1 days;
        _haveUserCreateRequest(testUser, address(WETH), amountOfShares, discount, secondsToDeadline);

        skip(3 days);

        // Solve users request using p2p solve.
        (, BoringOnChainQueue.OnChainWithdraw[] memory requests) = boringQueue.getWithdrawRequests();

        // Approve queue to spend wETH.
        WETH.safeApprove(address(boringQueue), type(uint256).max);

        // Call solveOnChainWithdraws with empty solveData.
        boringQueue.solveOnChainWithdraws(requests, hex"", address(this));

        assertEq(
            ERC20(liquidEth).balanceOf(address(this)),
            amountOfShares,
            "This address should have received `amountOfShares` of liquidEth shares."
        );
        assertEq(WETH.balanceOf(testUser), requests[0].amountOfAssets, "User should have received their wETH.");
    }

    function testRedeemSolve(uint128 amountOfShares, uint16 discount) external {
        amountOfShares = uint128(bound(amountOfShares, 0.01e18, 1_000e18));
        discount = uint16(bound(discount, 1, 100));
        uint24 secondsToDeadline = 1 days;
        _haveUserCreateRequest(testUser, address(WETH), amountOfShares, discount, secondsToDeadline);

        skip(3 days);

        // Solve users request using p2p solve.
        (, BoringOnChainQueue.OnChainWithdraw[] memory requests) = boringQueue.getWithdrawRequests();

        uint256 wETHDelta = WETH.balanceOf(address(this));
        boringSolver.boringRedeemSolve(boringQueue, requests, liquidEth_teller);
        wETHDelta = WETH.balanceOf(address(this)) - wETHDelta;

        assertEq(WETH.balanceOf(testUser), requests[0].amountOfAssets, "User should have received their wETH.");
        assertGt(wETHDelta, 0, "This address should have received some wETH.");
    }

    function testRedeemMintSolve(uint128 amountOfShares, uint16 discount) external {
        amountOfShares = uint128(bound(amountOfShares, 0.01e18, 1_000e18));
        discount = uint16(bound(discount, 1, 100));
        uint24 secondsToDeadline = 1 days;
        _haveUserCreateRequest(testUser, weETHs, amountOfShares, discount, secondsToDeadline);

        // No need to skip since maturity is 0.

        // Solve users request using p2p solve.
        (, BoringOnChainQueue.OnChainWithdraw[] memory requests) = boringQueue.getWithdrawRequests();

        uint256 wETHDelta = WETH.balanceOf(address(this));
        boringSolver.boringRedeemMintSolve(boringQueue, requests, liquidEth_teller, weETHs_teller, address(WETH));
        wETHDelta = WETH.balanceOf(address(this)) - wETHDelta;

        assertEq(
            ERC20(weETHs).balanceOf(testUser), requests[0].amountOfAssets, "User should have received their weETHs."
        );
        assertGt(wETHDelta, 0, "This address should have received some wETH.");
    }

    function testUserRequestsThenCancels(uint128 amountOfShares, uint16 discount) external {
        amountOfShares = uint128(bound(amountOfShares, 0.01e18, 1_000e18));
        discount = uint16(bound(discount, 1, 100));
        uint24 secondsToDeadline = 1 days;
        uint256 startingShares = ERC20(liquidEth).balanceOf(testUser);
        _haveUserCreateRequest(testUser, address(WETH), amountOfShares, discount, secondsToDeadline);

        (, BoringOnChainQueue.OnChainWithdraw[] memory requests) = boringQueue.getWithdrawRequests();

        // Cancel the request.
        vm.prank(testUser);
        boringQueue.cancelOnChainWithdraw(requests[0]);

        uint256 endingShares = ERC20(liquidEth).balanceOf(testUser);

        assertEq(WETH.balanceOf(testUser), 0, "User should not have received any wETH.");
        assertEq(endingShares, startingShares, "User should have received their shares back.");
    }

    function testUserRequestsThenCancelsUsingRequestId(uint128 amountOfShares, uint16 discount) external {
        amountOfShares = uint128(bound(amountOfShares, 0.01e18, 1_000e18));
        discount = uint16(bound(discount, 1, 100));
        uint24 secondsToDeadline = 1 days;
        uint256 startingShares = ERC20(liquidEth).balanceOf(testUser);
        bytes32 requestId = _haveUserCreateRequest(testUser, address(WETH), amountOfShares, discount, secondsToDeadline);

        // Cancel the request.
        vm.prank(testUser);
        boringQueue.cancelOnChainWithdrawUsingRequestId(requestId);

        uint256 endingShares = ERC20(liquidEth).balanceOf(testUser);

        assertEq(WETH.balanceOf(testUser), 0, "User should not have received any wETH.");
        assertEq(endingShares, startingShares, "User should have received their shares back.");
    }

    function testUserRequestsThenReplaces(uint128 amountOfShares, uint16 discount, uint16 newDiscount) external {
        amountOfShares = uint128(bound(amountOfShares, 0.01e18, 1_000e18));
        discount = uint16(bound(discount, 1, 100));
        newDiscount = uint16(bound(newDiscount, 1, 100));
        uint24 secondsToDeadline = 1 days;
        _haveUserCreateRequest(testUser, address(WETH), amountOfShares, discount, secondsToDeadline);

        (, BoringOnChainQueue.OnChainWithdraw[] memory requests) = boringQueue.getWithdrawRequests();

        // Repalce the request.
        uint256 startingShares = ERC20(liquidEth).balanceOf(testUser);
        vm.prank(testUser);
        boringQueue.replaceOnChainWithdraw(requests[0], newDiscount, secondsToDeadline);

        uint256 endingShares = ERC20(liquidEth).balanceOf(testUser);

        assertEq(WETH.balanceOf(testUser), 0, "User should not have received any wETH.");
        assertEq(endingShares, startingShares, "User should have not gotten any shares back.");
    }

    function testUserRequestsThenReplacesUsingRequestId(uint128 amountOfShares, uint16 discount, uint16 newDiscount)
        external
    {
        amountOfShares = uint128(bound(amountOfShares, 0.01e18, 1_000e18));
        discount = uint16(bound(discount, 1, 100));
        newDiscount = uint16(bound(newDiscount, 1, 100));
        uint24 secondsToDeadline = 1 days;
        bytes32 requestId = _haveUserCreateRequest(testUser, address(WETH), amountOfShares, discount, secondsToDeadline);

        // Repalce the request.
        uint256 startingShares = ERC20(liquidEth).balanceOf(testUser);
        vm.prank(testUser);
        boringQueue.replaceOnChainWithdrawUsingRequestId(requestId, newDiscount, secondsToDeadline);

        uint256 endingShares = ERC20(liquidEth).balanceOf(testUser);

        assertEq(WETH.balanceOf(testUser), 0, "User should not have received any wETH.");
        assertEq(endingShares, startingShares, "User should have not gotten any shares back.");
    }

    function testUserRequestsThenSelfSolves(uint128 amountOfShares, uint16 discount) external {
        amountOfShares = uint128(bound(amountOfShares, 0.01e18, 1_000e18));
        discount = uint16(bound(discount, 1, 100));
        uint24 secondsToDeadline = 1 days;
        uint256 startingShares = ERC20(liquidEth).balanceOf(testUser);
        bytes32 requestId = _haveUserCreateRequest(testUser, address(WETH), amountOfShares, discount, secondsToDeadline);

        (, BoringOnChainQueue.OnChainWithdraw[] memory requests) = boringQueue.getWithdrawRequests();

        // Fast forward 3 days so request is matured.
        skip(3 days);

        // Self Solve the request.
        vm.prank(testUser);
        boringSolver.boringRedeemSelfSolve(boringQueue, requestId, liquidEth_teller);

        uint256 endingShares = ERC20(liquidEth).balanceOf(testUser);

        assertEq(WETH.balanceOf(testUser), requests[0].amountOfAssets, "User should have received any wETH.");
        assertEq(startingShares - endingShares, amountOfShares, "User should have had shares removed..");
    }

    function testUserMakingMultipleWithdraws(uint128[4] memory amountOfShares, uint16[4] memory discount) external {
        uint24 secondsToDeadline = 1 days;
        bytes32[4] memory requestIds;
        uint256 startingShares = ERC20(liquidEth).balanceOf(testUser);
        uint256 shareSum;
        uint256 assetSum;
        for (uint256 i; i < 4; ++i) {
            amountOfShares[i] = uint128(bound(amountOfShares[i], 0.01e18, 100e18));
            shareSum += amountOfShares[i];
            discount[i] = uint16(bound(discount[i], 1, 100));
            // Make request.
            requestIds[i] =
                _haveUserCreateRequest(testUser, address(WETH), amountOfShares[i], discount[i], secondsToDeadline);
        }

        (, BoringOnChainQueue.OnChainWithdraw[] memory requests) = boringQueue.getWithdrawRequests();

        for (uint256 i; i < 4; ++i) {
            assetSum += requests[i].amountOfAssets;
        }

        // Fast forward 3 days so request is matured.
        skip(3 days);

        uint256 wETHDelta = WETH.balanceOf(address(this));
        boringSolver.boringRedeemSolve(boringQueue, requests, liquidEth_teller);
        wETHDelta = WETH.balanceOf(address(this)) - wETHDelta;
        uint256 endingShares = ERC20(liquidEth).balanceOf(testUser);

        assertEq(shareSum, startingShares - endingShares, "User should have had all requests solved.");
        assertEq(WETH.balanceOf(testUser), assetSum, "User should have received all wETH.");
    }

    function testQueueAdminCalls() external {
        // Check pause effects.
        assertEq(boringQueue.isPaused(), false, "Queue should not be paused.");
        boringQueue.pause();
        assertEq(boringQueue.isPaused(), true, "Queue should be paused.");
        boringQueue.unpause();
        assertEq(boringQueue.isPaused(), false, "Queue should not be paused.");

        // Check toggle track withdraw onchain effects.
        assertEq(boringQueue.trackWithdrawsOnChain(), true, "Queue should be tracking onchain withdraws.");
        boringQueue.toggleTrackWithdrawsOnChain();
        assertEq(boringQueue.trackWithdrawsOnChain(), false, "Queue should not be tracking onchain withdraws.");
        boringQueue.toggleTrackWithdrawsOnChain();
        assertEq(boringQueue.trackWithdrawsOnChain(), true, "Queue should be tracking onchain withdraws.");

        // Check setup withdraw asset effects.
        boringQueue.setupWithdrawAsset(address(EETH), 1 days, 2 days, 3, 25, 0.03e18);
        (
            bool allowWithdraws,
            uint24 secondsToMaturity,
            uint24 minimumSecondsToDeadline,
            uint16 minDiscount,
            uint16 maxDiscount,
            uint96 minimumShares
        ) = boringQueue.withdrawAssets(address(EETH));
        assertEq(allowWithdraws, true, "EETH should allow withdraws.");
        assertEq(secondsToMaturity, 1 days, "EETH should have 1 day maturity.");
        assertEq(minimumSecondsToDeadline, 2 days, "EETH should have 2 days minimum deadline.");
        assertEq(minDiscount, 3, "EETH should have 3 bps min discount.");
        assertEq(maxDiscount, 25, "EETH should have 25 bps max discount.");
        assertEq(minimumShares, 0.03e18, "EETH should have 0.03e18 minimum shares.");

        // Check update withdraw asset effects.
        boringQueue.updateWithdrawAsset(address(EETH), 2 days, 3 days, 4, 50, 0.05e18);
        (allowWithdraws, secondsToMaturity, minimumSecondsToDeadline, minDiscount, maxDiscount, minimumShares) =
            boringQueue.withdrawAssets(address(EETH));
        assertEq(allowWithdraws, true, "EETH should allow withdraws.");
        assertEq(secondsToMaturity, 2 days, "EETH should have 2 day maturity.");
        assertEq(minimumSecondsToDeadline, 3 days, "EETH should have 3 days minimum deadline.");
        assertEq(minDiscount, 4, "EETH should have 4 bps min discount.");
        assertEq(maxDiscount, 50, "EETH should have 50 bps max discount.");
        assertEq(minimumShares, 0.05e18, "EETH should have 0.05e18 minimum shares.");

        // Check stop withdraw in asset effects.
        boringQueue.stopWithdrawsInAsset(address(EETH));
        (allowWithdraws,,,,,) = boringQueue.withdrawAssets(address(EETH));
        assertEq(allowWithdraws, false, "EETH should not allow withdraws.");

        address userA = vm.addr(2);
        address userB = vm.addr(3);
        deal(address(liquidEth), userA, 1e18);
        deal(address(liquidEth), userB, 1e18);
        _haveUserCreateRequest(userA, address(WETH), 1e18, 100, 1 days);
        _haveUserCreateRequest(userB, address(WETH), 1e18, 100, 1 days);
        (, BoringOnChainQueue.OnChainWithdraw[] memory requests) = boringQueue.getWithdrawRequests();

        boringQueue.cancelUserWithdraws(requests);

        assertEq(WETH.balanceOf(userA), 0, "User A should not have received any wETH.");
        assertEq(WETH.balanceOf(userB), 0, "User B should not have received any wETH.");
        assertEq(ERC20(liquidEth).balanceOf(userA), 1e18, "User A should have their shares back.");
        assertEq(ERC20(liquidEth).balanceOf(userB), 1e18, "User B should have their shares back.");
    }

    function testQueueRescueTokens() external {
        // Remove the 1 wei of shares we sent the queue in the setup.
        deal(address(liquidEth), address(boringQueue), 0);
        (, BoringOnChainQueue.OnChainWithdraw[] memory requests) = boringQueue.getWithdrawRequests();
        address userWhoMadeAnHonestMistake = vm.addr(34);

        // Check rescue tokens effects.
        deal(address(WETH), address(boringQueue), 1e18);
        boringQueue.rescueTokens(WETH, 1e18, address(this), requests);
        assertEq(WETH.balanceOf(address(boringQueue)), 0, "Queue should not have any wETH.");

        // We can also rescue shares from the queue, if they are transferred to it.
        address userA = vm.addr(2);
        address userB = vm.addr(3);
        deal(address(liquidEth), userA, 1e18);
        deal(address(liquidEth), userB, 1e18);
        _haveUserCreateRequest(userA, address(WETH), 1e18, 100, 1 days);
        _haveUserCreateRequest(userB, address(WETH), 1e18, 100, 1 days);
        deal(address(liquidEth), userWhoMadeAnHonestMistake, 1e18);
        vm.prank(userWhoMadeAnHonestMistake);
        ERC20(liquidEth).safeTransfer(address(boringQueue), 1e18);

        (, requests) = boringQueue.getWithdrawRequests();

        // Trying to rescue shares that are from active requests should revert.
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    BoringOnChainQueue.BoringOnChainQueue__RescueCannotTakeSharesFromActiveRequests.selector
                )
            )
        );
        boringQueue.rescueTokens(ERC20(liquidEth), 1.001e18, userWhoMadeAnHonestMistake, requests);

        // But succeeds if a a valid amount is used.
        boringQueue.rescueTokens(ERC20(liquidEth), 0.1e18, userWhoMadeAnHonestMistake, requests);
        assertEq(ERC20(liquidEth).balanceOf(userWhoMadeAnHonestMistake), 0.1e18, "User should have 0.1 shares.");

        // Or if type(uint256).max is passed.
        boringQueue.rescueTokens(ERC20(liquidEth), type(uint256).max, userWhoMadeAnHonestMistake, requests);
        assertEq(ERC20(liquidEth).balanceOf(userWhoMadeAnHonestMistake), 1e18, "User should have 1 share.");
    }

    function testQueueRescueTokenReverts() external {
        (, BoringOnChainQueue.OnChainWithdraw[] memory requests) = boringQueue.getWithdrawRequests();
        address userWhoMadeAnHonestMistake = vm.addr(34);

        address userA = vm.addr(2);
        address userB = vm.addr(3);
        deal(address(liquidEth), userA, 1e18);
        deal(address(liquidEth), userB, 1e18);
        _haveUserCreateRequest(userA, address(WETH), 1e18, 100, 1 days);
        _haveUserCreateRequest(userB, address(WETH), 1e18, 100, 1 days);
        deal(address(liquidEth), userWhoMadeAnHonestMistake, 1e18);
        vm.prank(userWhoMadeAnHonestMistake);
        ERC20(liquidEth).safeTransfer(address(boringQueue), 1e18);

        (, requests) = boringQueue.getWithdrawRequests();

        // Trying to rescue shares that are from active requests should revert.
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    BoringOnChainQueue.BoringOnChainQueue__RescueCannotTakeSharesFromActiveRequests.selector
                )
            )
        );
        boringQueue.rescueTokens(ERC20(liquidEth), 1.001e18, userWhoMadeAnHonestMistake, requests);

        // Altering a request also reverts.
        requests[0].amountOfShares = 0;

        vm.expectRevert(bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__BadInput.selector)));
        boringQueue.rescueTokens(ERC20(liquidEth), 1e18, userWhoMadeAnHonestMistake, requests);

        // Making request array wrong length reverts.
        requests = new BoringOnChainQueue.OnChainWithdraw[](3);
        vm.expectRevert(bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__BadInput.selector)));
        boringQueue.rescueTokens(ERC20(liquidEth), 1e18, userWhoMadeAnHonestMistake, requests);
    }

    function testQueueSetupWithdrawAssetReverts() external {
        vm.expectRevert(bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__MAX_DISCOUNT.selector)));
        boringQueue.setupWithdrawAsset(address(WETH), 1 days, 2 days, 3, 0.3001e4, 0.03e18);

        vm.expectRevert(
            bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__MAXIMUM_SECONDS_TO_MATURITY.selector))
        );
        boringQueue.setupWithdrawAsset(address(WETH), 31 days, 2 days, 3, 25, 0.03e18);

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    BoringOnChainQueue.BoringOnChainQueue__MAXIMUM_MINIMUM_SECONDS_TO_DEADLINE.selector
                )
            )
        );
        boringQueue.setupWithdrawAsset(address(WETH), 1 days, 31 days, 3, 25, 0.03e18);

        vm.expectRevert(bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__BadDiscount.selector)));
        boringQueue.setupWithdrawAsset(address(WETH), 1 days, 2 days, 30, 25, 0.03e18);
    }

    function testQueueUpdateWithdrawAssetReverts() external {
        vm.expectRevert(bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__MAX_DISCOUNT.selector)));
        boringQueue.updateWithdrawAsset(address(WETH), 1 days, 2 days, 3, 0.3001e4, 0.03e18);

        vm.expectRevert(
            bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__MAXIMUM_SECONDS_TO_MATURITY.selector))
        );
        boringQueue.updateWithdrawAsset(address(WETH), 31 days, 2 days, 3, 25, 0.03e18);

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    BoringOnChainQueue.BoringOnChainQueue__MAXIMUM_MINIMUM_SECONDS_TO_DEADLINE.selector
                )
            )
        );
        boringQueue.updateWithdrawAsset(address(WETH), 1 days, 31 days, 3, 25, 0.03e18);

        vm.expectRevert(bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__BadDiscount.selector)));
        boringQueue.updateWithdrawAsset(address(WETH), 1 days, 2 days, 30, 25, 0.03e18);

        vm.expectRevert(
            bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__WithdrawsNotAllowedForAsset.selector))
        );
        boringQueue.updateWithdrawAsset(address(EETH), 1 days, 2 days, 3, 25, 0.03e18);
    }

    function testQueueRequestCreationReverts() external {
        // Reverts if queue is paused.
        boringQueue.pause();
        vm.expectRevert(bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__Paused.selector)));
        boringQueue.requestOnChainWithdraw(address(WETH), 0, 0, 0);

        boringQueue.unpause();

        // Reverts if withdraw asset is not allowed.
        vm.expectRevert(
            bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__WithdrawsNotAllowedForAsset.selector))
        );
        boringQueue.requestOnChainWithdraw(address(EETH), 0, 0, 0);

        // Reverts if discount is too high.
        vm.expectRevert(bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__BadDiscount.selector)));
        boringQueue.requestOnChainWithdraw(address(WETH), 0, 101, 0);

        // Reverts if discount is too low.
        vm.expectRevert(bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__BadDiscount.selector)));
        boringQueue.requestOnChainWithdraw(address(WETH), 0, 0, 0);

        // Reverts if amount of shares is too low.
        vm.expectRevert(bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__BadShareAmount.selector)));
        boringQueue.requestOnChainWithdraw(address(WETH), 0, 5, 0);

        // Reverts if deadline is too low.
        vm.expectRevert(bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__BadDeadline.selector)));
        boringQueue.requestOnChainWithdraw(address(WETH), 0.1e18, 100, 0);

        // Reverts if share transferFrom fails.
        vm.expectRevert(bytes("TRANSFER_FROM_FAILED"));
        boringQueue.requestOnChainWithdraw(address(WETH), 0.1e18, 100, 2 days);
    }

    function testQueueRequestCancellationReverts() external {
        // If one user tries to cancel another users withdraw it reverts.
        bytes32 requestId = _haveUserCreateRequest(testUser, address(WETH), 1e18, 3, 2 days);

        address evilUser = vm.addr(22);

        vm.startPrank(evilUser);
        vm.expectRevert(bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__BadUser.selector)));
        boringQueue.cancelOnChainWithdrawUsingRequestId(requestId);
        vm.stopPrank();

        // If test user edits the request data it reverts.
        (, BoringOnChainQueue.OnChainWithdraw[] memory requests) = boringQueue.getWithdrawRequests();
        requests[0].amountOfShares = 100e18;
        vm.startPrank(testUser);
        vm.expectRevert(bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__RequestNotFound.selector)));
        boringQueue.cancelOnChainWithdraw(requests[0]);
        vm.stopPrank();
    }

    function testQueueRequestReplacingReverts() external {
        // If one user tries to replace another users withdraw it reverts.
        bytes32 requestId = _haveUserCreateRequest(testUser, address(WETH), 1e18, 3, 2 days);

        address evilUser = vm.addr(22);

        vm.startPrank(evilUser);
        vm.expectRevert(bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__BadUser.selector)));
        boringQueue.replaceOnChainWithdrawUsingRequestId(requestId, 3, 2 days);
        vm.stopPrank();
    }

    function testQueueGetOnChainWithdrawRevert() external {
        // If queue is not tracking withdraws onchain.
        boringQueue.toggleTrackWithdrawsOnChain();

        // And a user makes a request.
        bytes32 requestId = _haveUserCreateRequest(testUser, address(WETH), 1e18, 3, 2 days);

        // Then if they try to get the request it reverts.
        vm.expectRevert(bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__ZeroNonce.selector)));
        boringQueue.getOnChainWithdraw(requestId);
    }

    function testQueueSolveOnChainWithdrawsReverts() external {
        boringQueue.setupWithdrawAsset(address(EETH), 2 days, 1 days, 1, 100, 0.01e18);

        // Have test user make 2 requests, one for wETH and one for eETH.
        _haveUserCreateRequest(testUser, address(WETH), 1e18, 3, 2 days);
        _haveUserCreateRequest(testUser, address(EETH), 1e18, 3, 1 days);

        // Read requests from queue.
        (, BoringOnChainQueue.OnChainWithdraw[] memory requests) = boringQueue.getWithdrawRequests();

        // Trying to solve when not all requests are matured reverts.
        vm.expectRevert(bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__NotMatured.selector)));
        boringQueue.solveOnChainWithdraws(requests, hex"", address(this));

        skip(3 days + 1);

        // Trying to solve both requests in same call reverts because the assetOut is different.
        vm.expectRevert(
            bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__SolveAssetMismatch.selector))
        );
        boringQueue.solveOnChainWithdraws(requests, hex"", address(this));

        // Trying to solve a request past its deadline reverts.
        BoringOnChainQueue.OnChainWithdraw[] memory requestsWithDeadlinePassed =
            new BoringOnChainQueue.OnChainWithdraw[](1);
        requestsWithDeadlinePassed[0] = requests[1];

        vm.expectRevert(bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__DeadlinePassed.selector)));
        boringQueue.solveOnChainWithdraws(requestsWithDeadlinePassed, hex"", address(this));

        // Trying to solve requests with madeup data reverts.
        requests[0].amountOfAssets = 1;
        vm.expectRevert(bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__RequestNotFound.selector)));
        boringQueue.solveOnChainWithdraws(requests, hex"", address(this));
    }

    // TODO finish
    function testSolverAdminCalls() external {
        // Check rescue tokens effects.
        deal(address(WETH), address(boringSolver), 1e18);
        boringSolver.rescueTokens(WETH, 1e18);
        assertEq(WETH.balanceOf(address(boringSolver)), 0, "Solver should not have any wETH.");
    }

    function testQueueReverts() external {}
    function testSolverReverts() external {}

    // TODO full function coverage in both

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }

    function _haveUserCreateRequest(
        address user,
        address assetOut,
        uint128 amountOfShares,
        uint16 discount,
        uint24 secondsToDeadline
    ) internal returns (bytes32 requestId) {
        vm.startPrank(user);
        ERC20(liquidEth).safeApprove(address(boringQueue), amountOfShares);
        requestId = boringQueue.requestOnChainWithdraw(assetOut, amountOfShares, discount, secondsToDeadline);
        vm.stopPrank();
    }
}
