// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract AccountantWithRateProvidersUsingDifferentDecimalTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    BoringVault public boringVault;
    AccountantWithRateProviders public accountant;
    address public payoutAddress = vm.addr(7777777);
    RolesAuthority public rolesAuthority;

    address public usdcWhale = 0x28C6c06298d514Db089934071355E5743bf21d60;

    uint8 public constant MINTER_ROLE = 1;
    uint8 public constant ADMIN_ROLE = 2;
    uint8 public constant UPDATE_EXCHANGE_RATE_ROLE = 3;
    uint8 public constant BORING_VAULT_ROLE = 4;

    ERC20 internal USDC;
    ERC20 internal USDT;
    ERC20 internal DAI;
    ERC20 internal SDAI;
    address internal sDaiRateProvider;

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19618964;
        _startFork(rpcKey, blockNumber);

        USDC = getERC20(sourceChain, "USDC");
        USDT = getERC20(sourceChain, "USDT");
        DAI = getERC20(sourceChain, "DAI");
        SDAI = getERC20(sourceChain, "SDAI");
        sDaiRateProvider = getAddress(sourceChain, "sDaiRateProvider");

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 6);

        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payoutAddress, 1e6, address(USDC), 1.001e4, 0.999e4, 1, 0, 0
        );

        vm.startPrank(usdcWhale);
        USDC.safeTransfer(address(this), 1_000_000e6);
        vm.stopPrank();
        USDC.safeApprove(address(boringVault), 1_000_000e6);
        boringVault.enter(address(this), USDC, 1_000_000e6, address(this), 1_000_000e6);

        accountant.setRateProviderData(DAI, true, address(0));
        accountant.setRateProviderData(USDT, true, address(0));
        accountant.setRateProviderData(SDAI, false, sDaiRateProvider);

        // Start accounting so we can claim fees during a test.
        accountant.updateManagementFee(0.01e4);

        skip(1 days / 24);
        // Increase exchange rate by 5 bps.
        uint96 newExchangeRate = uint96(1.0005e6);
        accountant.updateExchangeRate(newExchangeRate);

        skip(1 days);

        accountant.updateExchangeRate(newExchangeRate);

        skip(1 days);
    }

    function testClaimFeesUsingBase() external {
        // Set exchangeRate back to 1e6.
        uint96 newExchangeRate = uint96(1e6);
        accountant.updateExchangeRate(newExchangeRate);

        (,, uint128 feesOwed,,,,,,,,,) = accountant.accountantState();

        vm.startPrank(address(boringVault));
        USDC.safeApprove(address(accountant), type(uint256).max);
        // Claim fees.
        accountant.claimFees(USDC);
        vm.stopPrank();

        assertEq(USDC.balanceOf(payoutAddress), feesOwed, "Should have claimed fees in USDC");
    }

    function testClaimFeesUsingPegged() external {
        // Set exchangeRate back to 1e6.
        uint96 newExchangeRate = uint96(1e6);
        accountant.updateExchangeRate(newExchangeRate);

        (,, uint128 feesOwed,,,,,,,,,) = accountant.accountantState();

        deal(address(USDT), address(boringVault), 1_000_000e6);
        vm.startPrank(address(boringVault));
        USDT.safeApprove(address(accountant), type(uint256).max);
        // Claim fees.
        accountant.claimFees(USDT);
        vm.stopPrank();

        assertEq(USDT.balanceOf(payoutAddress), feesOwed, "Should have claimed fees in USDT");
    }

    function testClaimFeesUsingPeggedDifferentDecimals() external {
        // Set exchangeRate back to 1e6.
        uint96 newExchangeRate = uint96(1e6);
        accountant.updateExchangeRate(newExchangeRate);

        (,, uint128 feesOwed,,,,,,,,,) = accountant.accountantState();

        deal(address(DAI), address(boringVault), 1_000_000e18);
        vm.startPrank(address(boringVault));
        DAI.safeApprove(address(accountant), type(uint256).max);
        // Claim fees.
        accountant.claimFees(DAI);
        vm.stopPrank();

        uint256 expectedFeesOwed = uint256(feesOwed).mulDivDown(1e18, 1e6);
        assertEq(DAI.balanceOf(payoutAddress), expectedFeesOwed, "Should have claimed fees in DAI");
    }

    function testClaimFeesUsingRateProviderAsset() external {
        // Set exchangeRate back to 1e6.
        uint96 newExchangeRate = uint96(1e6);
        accountant.updateExchangeRate(newExchangeRate);

        (,, uint128 feesOwed,,,,,,,,,) = accountant.accountantState();

        deal(address(SDAI), address(boringVault), 1_000_000e18);
        vm.startPrank(address(boringVault));
        SDAI.safeApprove(address(accountant), type(uint256).max);
        // Claim fees.
        accountant.claimFees(SDAI);
        vm.stopPrank();

        uint256 expectedFeesOwed = uint256(feesOwed).mulDivDown(1e18, 1e6);
        expectedFeesOwed = expectedFeesOwed.mulDivDown(1e18, IRateProvider(sDaiRateProvider).getRate());
        uint256 sDaiFees = SDAI.balanceOf(payoutAddress);
        assertEq(sDaiFees, expectedFeesOwed, "Should have claimed fees in SDAI");

        // Convert fees received to USDC.
        uint256 feesConvertedToUsdc = sDaiFees.mulDivDown(IRateProvider(sDaiRateProvider).getRate(), 1e18);
        feesConvertedToUsdc = feesConvertedToUsdc.mulDivDown(1e6, 1e18);
        assertApproxEqAbs(
            feesOwed, feesConvertedToUsdc, 1, "sDAI fees converted to USDC should be equal to fees owed in USDC"
        );
    }

    function testRates() external {
        // Set exchangeRate back to 1e6.
        uint96 newExchangeRate = uint96(1e6);
        accountant.updateExchangeRate(newExchangeRate);

        // getRate and getRate in quote should work.
        uint256 rate = accountant.getRate();
        uint256 expected_rate = 1e6;
        assertEq(rate, expected_rate, "Rate should be expected rate");
        rate = accountant.getRateSafe();
        assertEq(rate, expected_rate, "Rate should be expected rate");

        uint256 rateInQuote = accountant.getRateInQuote(USDC);
        expected_rate = 1e6;
        assertEq(rateInQuote, expected_rate, "Rate should be expected rate");

        rateInQuote = accountant.getRateInQuote(DAI);
        expected_rate = 1e18;
        assertEq(rateInQuote, expected_rate, "Rate should be expected rate");

        rateInQuote = accountant.getRateInQuote(USDT);
        expected_rate = 1e6;
        assertEq(rateInQuote, expected_rate, "Rate should be expected rate");

        rateInQuote = accountant.getRateInQuote(SDAI);
        expected_rate = uint256(1e18).mulDivDown(1e18, IRateProvider(sDaiRateProvider).getRate());
        assertEq(rateInQuote, expected_rate, "Rate should be expected rate for sDAI");
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
