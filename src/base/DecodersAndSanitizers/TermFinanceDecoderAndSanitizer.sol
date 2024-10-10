// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract TermFinanceDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== TERM FINANCE ===============================

    constructor(address _boringVault) BaseDecoderAndSanitizer(_boringVault) {}

    function lockOffers(DecoderCustomTypes.TermAuctionOfferSubmission[] calldata offerSubmissions) pure virtual external returns (bytes memory addressesFound) {
        for (uint256 i = 0; i < offerSubmissions.length; i++) {
            addressesFound = abi.encodePacked(
                addressesFound,
                offerSubmissions[i].offeror
            );
            addressesFound = abi.encodePacked(
                addressesFound,
                offerSubmissions[i].purchaseToken
            );
        }
    }

    function redeemTermRepoTokens(address redeemer, uint256 ) pure virtual external returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(redeemer);
    }
}