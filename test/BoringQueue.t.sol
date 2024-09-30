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

        // Approve solver to spend wETH.
        WETH.safeApprove(address(boringSolver), type(uint256).max);

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

        // Approve solver to spend weETHs.
        ERC20(weETHs).safeApprove(address(boringSolver), type(uint256).max);

        uint256 wETHDelta = WETH.balanceOf(address(this));
        boringSolver.boringRedeemMintSolve(boringQueue, requests, liquidEth_teller, weETHs_teller, address(WETH));
        wETHDelta = WETH.balanceOf(address(this)) - wETHDelta;

        assertEq(
            ERC20(weETHs).balanceOf(testUser), requests[0].amountOfAssets, "User should have received their weETHs."
        );
        assertGt(wETHDelta, 0, "This address should have received some wETH.");
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
    ) internal returns (bytes32 requestId) {
        vm.startPrank(user);
        ERC20(liquidEth).safeApprove(address(boringQueue), amountOfShares);
        requestId = boringQueue.requestOnChainWithdraw(assetOut, amountOfShares, discount, secondsToDeadline);
        vm.stopPrank();
    }
}
