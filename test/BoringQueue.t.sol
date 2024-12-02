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
import {Test, stdStorage, StdStorage, stdError, console, Vm} from "@forge-std/Test.sol";

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
            address(this), address(liquidEth_roles_authority), payable(liquidEth), address(liquidEth_accountant)
        );
        boringSolver = new BoringSolver(address(this), address(liquidEth_roles_authority), address(boringQueue));

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
            address(boringQueue), BoringOnChainQueue.replaceOnChainWithdraw.selector, true
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
        boringQueue.updateWithdrawAsset(address(WETH), 3 days, 1 days, 1, 100, 0.01e18);

        // Add weETHs as a withdraw asset on the boringQueue.
        boringQueue.updateWithdrawAsset(weETHs, 0, 1 days, 1, 100, 0.01e18);

        deal(address(liquidEth), address(boringQueue), 1);
    }

    // User interacts with atomic queue directly to "buy" shares
    function testP2PSolve(uint128 amountOfShares, uint16 discount) external {
        amountOfShares = uint128(bound(amountOfShares, 0.01e18, 1_000e18));
        discount = uint16(bound(discount, 1, 100));
        uint24 secondsToDeadline = 1 days;
        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](1);
        (, requests[0]) = _haveUserCreateRequest(testUser, address(WETH), amountOfShares, discount, secondsToDeadline);

        skip(3 days);

        // Solve users request using p2p solve.

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

    function testUsingPermitToCreateRequest(uint128 amountOfShares, uint16 discount) external {
        amountOfShares = uint128(bound(amountOfShares, 0.01e18, 1_000e18));
        discount = uint16(bound(discount, 1, 100));
        uint24 secondsToDeadline = 1 days;

        uint256 userKey = 111;
        address user = vm.addr(userKey);
        deal(liquidEth, user, amountOfShares);

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                ERC20(liquidEth).DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        user,
                        address(boringQueue),
                        amountOfShares,
                        ERC20(liquidEth).nonces(user),
                        block.timestamp
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userKey, digest);
        vm.startPrank(user);
        uint256 shareDelta = ERC20(liquidEth).balanceOf(user);
        boringQueue.requestOnChainWithdrawWithPermit(
            address(WETH), amountOfShares, discount, secondsToDeadline, block.timestamp, v, r, s
        );
        shareDelta = shareDelta - ERC20(liquidEth).balanceOf(user);
        vm.stopPrank();

        assertEq(shareDelta, amountOfShares, "User should have had their shares removed.");
    }

    function testUsingPermitToCreateRequestWithFrontRunning(uint128 amountOfShares, uint16 discount) external {
        amountOfShares = uint128(bound(amountOfShares, 0.01e18, 1_000e18));
        discount = uint16(bound(discount, 1, 100));
        uint24 secondsToDeadline = 1 days;

        uint256 userKey = 111;
        address user = vm.addr(userKey);
        deal(liquidEth, user, amountOfShares);

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                ERC20(liquidEth).DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        user,
                        address(boringQueue),
                        amountOfShares,
                        ERC20(liquidEth).nonces(user),
                        block.timestamp
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userKey, digest);

        address attacker = vm.addr(0xDEAD);
        vm.startPrank(attacker);
        ERC20(liquidEth).permit(user, address(boringQueue), amountOfShares, block.timestamp, v, r, s);
        vm.stopPrank();

        // User TX is still successful.
        vm.startPrank(user);
        boringQueue.requestOnChainWithdrawWithPermit(
            address(WETH), amountOfShares, discount, secondsToDeadline, block.timestamp, v, r, s
        );
        vm.stopPrank();
    }

    function testRedeemSolve(uint128 amountOfShares, uint16 discount) external {
        amountOfShares = uint128(bound(amountOfShares, 0.01e18, 1_000e18));
        discount = uint16(bound(discount, 1, 100));
        uint24 secondsToDeadline = 1 days;
        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](1);
        (, requests[0]) = _haveUserCreateRequest(testUser, address(WETH), amountOfShares, discount, secondsToDeadline);

        skip(3 days);

        // Solve users request using p2p solve.

        uint256 wETHDelta = WETH.balanceOf(address(this));
        boringSolver.boringRedeemSolve(requests, liquidEth_teller, false);
        wETHDelta = WETH.balanceOf(address(this)) - wETHDelta;

        assertEq(WETH.balanceOf(testUser), requests[0].amountOfAssets, "User should have received their wETH.");
        assertGt(wETHDelta, 0, "This address should have received some wETH.");
    }

    function testRedeemSolveCoverDeficit() external {
        uint128 amountOfShares = 1_000e18;
        uint16 sharePriceBpsDecrease = 2;
        uint16 discount = 1;
        uint24 secondsToDeadline = 1 days;
        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](1);
        (, requests[0]) = _haveUserCreateRequest(testUser, address(WETH), amountOfShares, discount, secondsToDeadline);

        // Update liquidEth share price.
        vm.startPrank(liquidEth_accountant.owner());
        uint256 newRate = liquidEth_accountant.getRate();
        newRate = newRate * (1e4 - sharePriceBpsDecrease) / 1e4;
        liquidEth_accountant.updateExchangeRate(uint96(newRate));
        vm.stopPrank();

        skip(3 days);

        uint256 expectedDeficit = 103525308149087000; // Pulled from logs of revert.
        vm.expectRevert(
            abi.encodeWithSelector(BoringSolver.BoringSolver___CannotCoverDeficit.selector, expectedDeficit)
        );
        boringSolver.boringRedeemSolve(requests, liquidEth_teller, false);

        uint256 wETHDeficit = WETH.balanceOf(address(this));
        WETH.approve(address(boringSolver), expectedDeficit);
        boringSolver.boringRedeemSolve(requests, liquidEth_teller, true);

        wETHDeficit = wETHDeficit - WETH.balanceOf(address(this));

        assertEq(WETH.balanceOf(testUser), requests[0].amountOfAssets, "User should have received their wETH.");
        assertEq(wETHDeficit, expectedDeficit, "Bad Deficit.");
    }

    function testRedeemMintSolve(uint128 amountOfShares, uint16 discount) external {
        amountOfShares = uint128(bound(amountOfShares, 0.01e18, 1_000e18));
        discount = uint16(bound(discount, 1, 100));
        uint24 secondsToDeadline = 1 days;
        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](1);
        (, requests[0]) = _haveUserCreateRequest(testUser, weETHs, amountOfShares, discount, secondsToDeadline);

        // No need to skip since maturity is 0.

        // Solve users request using p2p solve.

        uint256 wETHDelta = WETH.balanceOf(address(this));
        boringSolver.boringRedeemMintSolve(requests, liquidEth_teller, weETHs_teller, address(WETH), false);
        wETHDelta = WETH.balanceOf(address(this)) - wETHDelta;

        assertEq(
            ERC20(weETHs).balanceOf(testUser), requests[0].amountOfAssets, "User should have received their weETHs."
        );
        assertGt(wETHDelta, 0, "This address should have received some wETH.");
    }

    function testRedeemMintSolveCoverDeficit() external {
        uint128 amountOfShares = 1_000e18;
        uint16 sharePriceBpsDecrease = 2;
        uint16 discount = 1;
        uint24 secondsToDeadline = 1 days;
        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](1);
        (, requests[0]) = _haveUserCreateRequest(testUser, weETHs, amountOfShares, discount, secondsToDeadline);

        // Update liquidEth share price.
        vm.startPrank(liquidEth_accountant.owner());
        uint256 newRate = liquidEth_accountant.getRate();
        newRate = newRate * (1e4 - sharePriceBpsDecrease) / 1e4;
        liquidEth_accountant.updateExchangeRate(uint96(newRate));
        vm.stopPrank();

        // No need to skip since maturity is 0.

        // Solve users request using p2p solve.

        uint256 expectedDeficit = 103525308149085736; // Pulled from logs of revert.
        vm.expectRevert(
            abi.encodeWithSelector(BoringSolver.BoringSolver___CannotCoverDeficit.selector, expectedDeficit)
        );
        boringSolver.boringRedeemMintSolve(requests, liquidEth_teller, weETHs_teller, address(WETH), false);

        uint256 wETHDeficit = WETH.balanceOf(address(this));
        WETH.approve(address(boringSolver), expectedDeficit);
        boringSolver.boringRedeemMintSolve(requests, liquidEth_teller, weETHs_teller, address(WETH), true);

        wETHDeficit = wETHDeficit - WETH.balanceOf(address(this));

        assertEq(
            ERC20(weETHs).balanceOf(testUser), requests[0].amountOfAssets, "User should have received their weETHs."
        );
        assertEq(wETHDeficit, expectedDeficit, "Bad Deficit.");
    }

    function testUserRequestsThenCancels(uint128 amountOfShares, uint16 discount) external {
        amountOfShares = uint128(bound(amountOfShares, 0.01e18, 1_000e18));
        discount = uint16(bound(discount, 1, 100));
        uint24 secondsToDeadline = 1 days;
        uint256 startingShares = ERC20(liquidEth).balanceOf(testUser);
        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](1);
        (, requests[0]) = _haveUserCreateRequest(testUser, address(WETH), amountOfShares, discount, secondsToDeadline);

        // Cancel the request.
        vm.prank(testUser);
        boringQueue.cancelOnChainWithdraw(requests[0]);

        uint256 endingShares = ERC20(liquidEth).balanceOf(testUser);

        assertEq(WETH.balanceOf(testUser), 0, "User should not have received any wETH.");
        assertEq(endingShares, startingShares, "User should have received their shares back.");
    }

    function testUserRequestsThenReplaces(uint128 amountOfShares, uint16 discount, uint16 newDiscount) external {
        amountOfShares = uint128(bound(amountOfShares, 0.01e18, 1_000e18));
        discount = uint16(bound(discount, 1, 100));
        newDiscount = uint16(bound(newDiscount, 1, 100));
        uint24 secondsToDeadline = 1 days;
        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](1);
        (, requests[0]) = _haveUserCreateRequest(testUser, address(WETH), amountOfShares, discount, secondsToDeadline);

        // Replace the request.
        uint256 startingShares = ERC20(liquidEth).balanceOf(testUser);
        vm.prank(testUser);
        boringQueue.replaceOnChainWithdraw(requests[0], newDiscount, secondsToDeadline);

        uint256 endingShares = ERC20(liquidEth).balanceOf(testUser);

        assertEq(WETH.balanceOf(testUser), 0, "User should not have received any wETH.");
        assertEq(endingShares, startingShares, "User should have not gotten any shares back.");
    }

    function testUserRequestsThenSelfSolves(uint128 amountOfShares, uint16 discount) external {
        amountOfShares = uint128(bound(amountOfShares, 0.01e18, 1_000e18));
        discount = uint16(bound(discount, 1, 100));
        uint24 secondsToDeadline = 1 days;
        uint256 startingShares = ERC20(liquidEth).balanceOf(testUser);
        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](1);
        (, requests[0]) = _haveUserCreateRequest(testUser, address(WETH), amountOfShares, discount, secondsToDeadline);

        // Fast forward 3 days so request is matured.
        skip(3 days);

        // Self Solve the request.
        vm.prank(testUser);
        boringSolver.boringRedeemSelfSolve(requests[0], liquidEth_teller);

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
        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](4);
        for (uint256 i; i < 4; ++i) {
            amountOfShares[i] = uint128(bound(amountOfShares[i], 0.01e18, 100e18));
            shareSum += amountOfShares[i];
            discount[i] = uint16(bound(discount[i], 1, 100));
            // Make request.
            (requestIds[i], requests[i]) =
                _haveUserCreateRequest(testUser, address(WETH), amountOfShares[i], discount[i], secondsToDeadline);
        }

        for (uint256 i; i < 4; ++i) {
            assetSum += requests[i].amountOfAssets;
        }

        // Fast forward 3 days so request is matured.
        skip(3 days);

        uint256 wETHDelta = WETH.balanceOf(address(this));
        boringSolver.boringRedeemSolve(requests, liquidEth_teller, false);
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

        // Check setup withdraw asset effects.
        boringQueue.updateWithdrawAsset(address(EETH), 1 days, 2 days, 3, 25, 0.03e18);
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
        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](2);
        (, requests[0]) = _haveUserCreateRequest(userA, address(WETH), 1e18, 100, 1 days);
        (, requests[1]) = _haveUserCreateRequest(userB, address(WETH), 1e18, 100, 1 days);

        boringQueue.cancelUserWithdraws(requests);

        assertEq(WETH.balanceOf(userA), 0, "User A should not have received any wETH.");
        assertEq(WETH.balanceOf(userB), 0, "User B should not have received any wETH.");
        assertEq(ERC20(liquidEth).balanceOf(userA), 1e18, "User A should have their shares back.");
        assertEq(ERC20(liquidEth).balanceOf(userB), 1e18, "User B should have their shares back.");
    }

    function testQueueRescueTokens() external {
        // Remove the 1 wei of shares we sent the queue in the setup.
        deal(address(liquidEth), address(boringQueue), 0);
        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](2);
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
        (, requests[0]) = _haveUserCreateRequest(userA, address(WETH), 1e18, 100, 1 days);
        (, requests[1]) = _haveUserCreateRequest(userB, address(WETH), 1e18, 100, 1 days);
        deal(address(liquidEth), userWhoMadeAnHonestMistake, 1e18);
        vm.prank(userWhoMadeAnHonestMistake);
        ERC20(liquidEth).safeTransfer(address(boringQueue), 1e18);

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
        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](2);

        address userWhoMadeAnHonestMistake = vm.addr(34);

        address userA = vm.addr(2);
        address userB = vm.addr(3);
        deal(address(liquidEth), userA, 1e18);
        deal(address(liquidEth), userB, 1e18);
        (, requests[0]) = _haveUserCreateRequest(userA, address(WETH), 1e18, 100, 1 days);
        (, requests[1]) = _haveUserCreateRequest(userB, address(WETH), 1e18, 100, 1 days);
        deal(address(liquidEth), userWhoMadeAnHonestMistake, 1e18);
        vm.prank(userWhoMadeAnHonestMistake);
        ERC20(liquidEth).safeTransfer(address(boringQueue), 1e18);

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

        // Reverts if permit fails and allowance is too low.
        uint128 amountOfShares = 1e18;
        uint16 discount = 3;
        uint24 secondsToDeadline = 1 days;

        uint256 userKey = 111;
        address user = vm.addr(userKey);
        deal(liquidEth, user, amountOfShares);

        // Make malformed permit data.
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x02", // should be x01, not x02.
                ERC20(liquidEth).DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        user,
                        address(boringQueue),
                        amountOfShares,
                        ERC20(liquidEth).nonces(user),
                        block.timestamp
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userKey, digest);
        vm.startPrank(user);
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__PermitFailedAndAllowanceTooLow.selector)
            )
        );
        boringQueue.requestOnChainWithdrawWithPermit(
            address(WETH), amountOfShares, discount, secondsToDeadline, block.timestamp, v, r, s
        );
        vm.stopPrank();
    }

    function testQueueRequestCancellationReverts() external {
        // If one user tries to cancel another users withdraw it reverts.
        (, BoringOnChainQueue.OnChainWithdraw memory req) =
            _haveUserCreateRequest(testUser, address(WETH), 1e18, 3, 2 days);

        address evilUser = vm.addr(22);

        vm.startPrank(evilUser);
        vm.expectRevert(bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__BadUser.selector)));
        boringQueue.cancelOnChainWithdraw(req);
        vm.stopPrank();

        // If test user edits the request data it reverts.
        req.amountOfShares = 100e18;
        vm.startPrank(testUser);
        vm.expectRevert(bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__RequestNotFound.selector)));
        boringQueue.cancelOnChainWithdraw(req);
        vm.stopPrank();
    }

    function testQueueRequestReplacingReverts() external {
        // If one user tries to replace another users withdraw it reverts.
        (, BoringOnChainQueue.OnChainWithdraw memory req) =
            _haveUserCreateRequest(testUser, address(WETH), 1e18, 3, 2 days);

        address evilUser = vm.addr(22);

        vm.startPrank(evilUser);
        vm.expectRevert(bytes(abi.encodeWithSelector(BoringOnChainQueue.BoringOnChainQueue__BadUser.selector)));
        boringQueue.replaceOnChainWithdraw(req, 3, 2 days);
        vm.stopPrank();
    }

    function testQueueSolveOnChainWithdrawsReverts() external {
        boringQueue.updateWithdrawAsset(address(EETH), 2 days, 1 days, 1, 100, 0.01e18);

        // Have test user make 2 requests, one for wETH and one for eETH.
        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](2);
        (, requests[0]) = _haveUserCreateRequest(testUser, address(WETH), 1e18, 3, 2 days);
        (, requests[1]) = _haveUserCreateRequest(testUser, address(EETH), 1e18, 3, 1 days);

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

    function testSolverAdminCalls() external {
        // Check rescue tokens effects.
        deal(address(WETH), address(boringSolver), 1e18);
        boringSolver.rescueTokens(WETH, 1e18);
        assertEq(WETH.balanceOf(address(boringSolver)), 0, "Solver should not have any wETH.");

        // User makes redeem solve request for wETH.
        address userA = vm.addr(2);
        deal(address(liquidEth), userA, 1e18);
        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](1);
        (, requests[0]) = _haveUserCreateRequest(userA, address(WETH), 1e18, 100, 1 days);

        skip(3 days);

        // Solve request using boringSolver.
        boringSolver.boringRedeemSolve(requests, liquidEth_teller, false);

        // User makes a redeem mint solve request for weETHs.
        address userB = vm.addr(3);
        deal(address(liquidEth), userB, 1e18);
        (, requests[0]) = _haveUserCreateRequest(userB, weETHs, 1e18, 100, 1 days);

        // Solve request using boringSolver.
        boringSolver.boringRedeemMintSolve(requests, liquidEth_teller, weETHs_teller, address(WETH), false);

        // User A and user B should not have any shares.
        assertEq(ERC20(liquidEth).balanceOf(userA), 0, "User A should have had their shares solved.");
        assertEq(ERC20(liquidEth).balanceOf(userB), 0, "User B should have had their shares solved.");
        assertGt(WETH.balanceOf(userA), 0, "User A should have received some wETH.");
        assertGt(ERC20(weETHs).balanceOf(userB), 0, "User B should have received some weETHs.");
    }

    function testSolverReverts() external {
        address evilUser = vm.addr(22);

        vm.expectRevert(bytes(abi.encodeWithSelector(BoringSolver.BoringSolver___OnlyQueue.selector)));
        boringSolver.boringSolve(address(0), address(0), address(0), 0, 0, hex"");

        vm.startPrank(address(boringQueue));

        // Wrong initiator revert.
        vm.expectRevert(bytes(abi.encodeWithSelector(BoringSolver.BoringSolver___WrongInitiator.selector)));
        boringSolver.boringSolve(evilUser, address(0), address(0), 0, 0, hex"");

        // Redeem Solve teller mismatch revert.
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    BoringSolver.BoringSolver___BoringVaultTellerMismatch.selector, liquidEth, weETHs_teller
                )
            )
        );
        boringSolver.boringSolve(
            address(boringSolver),
            liquidEth,
            address(WETH),
            0,
            0,
            abi.encode(0, address(this), weETHs_teller, true, false)
        );

        // Redeem Mint Solve teller mismatch revert.
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    BoringSolver.BoringSolver___BoringVaultTellerMismatch.selector, liquidEth, weETHs_teller
                )
            )
        );
        boringSolver.boringSolve(
            address(boringSolver),
            liquidEth,
            address(WETH),
            0,
            0,
            abi.encode(1, address(this), weETHs_teller, liquidEth_teller, WETH, true, false)
        );

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    BoringSolver.BoringSolver___BoringVaultTellerMismatch.selector, weETHs, liquidEth_teller
                )
            )
        );
        boringSolver.boringSolve(
            address(boringSolver),
            weETHs,
            address(WETH),
            0,
            0,
            abi.encode(1, address(this), liquidEth_teller, weETHs_teller, WETH, true, false)
        );
        vm.stopPrank();

        // Calling self solve functions with a different user address reverts.
        vm.startPrank(testUser);
        BoringOnChainQueue.OnChainWithdraw memory request;
        (, request) = _haveUserCreateRequest(testUser, address(WETH), 1e18, 100, 1 days);
        vm.stopPrank();

        vm.expectRevert(bytes(abi.encodeWithSelector(BoringSolver.BoringSolver___OnlySelf.selector)));
        boringSolver.boringRedeemSelfSolve(request, liquidEth_teller);
        vm.expectRevert(bytes(abi.encodeWithSelector(BoringSolver.BoringSolver___OnlySelf.selector)));
        boringSolver.boringRedeemMintSelfSolve(request, liquidEth_teller, weETHs_teller, address(WETH));
    }

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
    ) internal returns (bytes32 requestId, BoringOnChainQueue.OnChainWithdraw memory request) {
        uint96 nonceBefore = boringQueue.nonce();
        vm.startPrank(user);
        ERC20(liquidEth).safeApprove(address(boringQueue), amountOfShares);
        vm.recordLogs();
        requestId = boringQueue.requestOnChainWithdraw(assetOut, amountOfShares, discount, secondsToDeadline);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        vm.stopPrank();
        assertEq(boringQueue.nonce(), nonceBefore + 1, "Nonce should have increased by 1.");
        // Iterate through logs unitl we find the one we want.
        for (uint256 i; i < entries.length; ++i) {
            if (
                entries[i].topics[0]
                    == keccak256(
                        "OnChainWithdrawRequested(bytes32,address,address,uint96,uint128,uint128,uint40,uint24,uint24)"
                    )
            ) {
                assertEq(requestId, entries[i].topics[1], "Request Id should match.");
                request.user = address(bytes20(entries[i].topics[2] << 96));
                request.assetOut = address(bytes20(entries[i].topics[3] << 96));
                (
                    request.nonce,
                    request.amountOfShares,
                    request.amountOfAssets,
                    request.creationTime,
                    request.secondsToMaturity,
                    request.secondsToDeadline
                ) = abi.decode(entries[i].data, (uint96, uint128, uint128, uint40, uint24, uint24));
            }
        }
    }
}
