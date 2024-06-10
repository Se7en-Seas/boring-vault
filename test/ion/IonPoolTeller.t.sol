// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {BoringVault} from "./../../src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "./../../src/base/Roles/ManagerWithMerkleVerification.sol";
import {IonPoolDecoderAndSanitizer} from "./../../src/base/DecodersAndSanitizers/IonPoolDecoderAndSanitizer.sol";
import {IonPoolSharedSetup} from "./IonPoolSharedSetup.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

contract IonPoolTeller is IonPoolSharedSetup {
    using FixedPointMathLib for uint256;

    function setUp() public override {
        super.setUp();
        WSTETH.approve(address(boringVault), type(uint256).max);

        vm.prank(TELLER_OWNER);
        teller.addAsset(WSTETH); 
    }

    function test_Deposit() public {
        uint256 depositAmt = 100 ether;
        uint256 minimumMint = 100 ether;

        // base / deposit asset
        uint256 exchangeRate = accountant.getRateInQuoteSafe(WSTETH);

        uint256 shares = depositAmt.mulDivDown(1e18, exchangeRate);
        // mint amount = deposit amount * exchangeRate 
        
        deal(address(WSTETH), address(this), depositAmt);
        teller.deposit(WSTETH, depositAmt, minimumMint);

        assertEq(boringVault.balanceOf(address(this)), shares, "shared minted");
        assertEq(WSTETH.balanceOf(address(this)), 0, "WSTETH transferred from user");
        assertEq(WSTETH.balanceOf(address(boringVault)), depositAmt, "WSTETH transferred to vault");
    }

    function test_AddAsset() public {

    }
}