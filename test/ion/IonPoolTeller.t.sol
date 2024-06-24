// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {BoringVault} from "./../../src/base/BoringVault.sol";
import {EthPerWstEthRateProvider} from "./../../src/oracles/EthPerWstEthRateProvider.sol";
import {ETH_PER_STETH_CHAINLINK, WSTETH_ADDRESS} from "@ion-protocol/Constants.sol";
import {IonPoolSharedSetup} from "./IonPoolSharedSetup.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {console2} from "forge-std/console2.sol";

contract IonPoolTellerTest is IonPoolSharedSetup {
    using FixedPointMathLib for uint256;

    EthPerWstEthRateProvider ethPerWstEthRateProvider;

    function setUp() public override {
        super.setUp();

        WETH.approve(address(boringVault), type(uint256).max);
        WSTETH.approve(address(boringVault), type(uint256).max);

        vm.startPrank(TELLER_OWNER);
        teller.addAsset(WETH);
        teller.addAsset(WSTETH);
        vm.stopPrank();

        // Setup accountant

        ethPerWstEthRateProvider =
            new EthPerWstEthRateProvider(address(ETH_PER_STETH_CHAINLINK), address(WSTETH_ADDRESS), 1 days);
        bool isPeggedToBase = false;

        vm.prank(ACCOUNTANT_OWNER);
        accountant.setRateProviderData(
            ERC20(address(WSTETH_ADDRESS)), isPeggedToBase, address(ethPerWstEthRateProvider)
        );
    }

    function test_Deposit_BaseAsset() public {
        uint256 depositAmt = 100 ether;
        uint256 minimumMint = 100 ether;

        // base / deposit asset
        uint256 exchangeRate = accountant.getRateInQuoteSafe(WETH);

        uint256 shares = depositAmt.mulDivDown(1e18, exchangeRate);

        // mint amount = deposit amount * exchangeRate
        deal(address(WETH), address(this), depositAmt);
        teller.deposit(WETH, depositAmt, minimumMint);

        assertEq(exchangeRate, 1e18, "base asset exchange rate must be pegged");
        assertEq(boringVault.balanceOf(address(this)), shares, "shares minted");
        assertEq(WETH.balanceOf(address(this)), 0, "WSTETH transferred from user");
        assertEq(WETH.balanceOf(address(boringVault)), depositAmt, "WSTETH transferred to vault");
    }

    function test_Deposit_NewAsset() public {
        uint256 depositAmt = 100 ether;
        uint256 minimumMint = 100 ether;

        // base / deposit asset
        uint256 basePerQuote = ethPerWstEthRateProvider.getRate(); // base / quote
        uint256 quotePerShare = accountant.getRateInQuoteSafe(WSTETH); // quote / share

        uint256 basePerShare = accountant.getRate();
        uint256 expectedQuotePerShare = basePerShare * 1e18 / basePerQuote; // (base / share) / (base / quote) = quote / share

        uint256 shares = depositAmt.mulDivDown(1e18, quotePerShare);
        // mint amount = deposit amount * exchangeRate

        deal(address(WSTETH), address(this), depositAmt);
        teller.deposit(WSTETH, depositAmt, minimumMint);

        assertEq(quotePerShare, expectedQuotePerShare, "exchange rate must read from price oracle");
        assertEq(boringVault.balanceOf(address(this)), shares, "shares minted");
        assertEq(WSTETH.balanceOf(address(this)), 0, "WSTETH transferred from user");
        assertEq(WSTETH.balanceOf(address(boringVault)), depositAmt, "WSTETH transferred to vault");
    }
}
