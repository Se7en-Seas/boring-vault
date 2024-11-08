// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {
    ERC4626DecoderAndSanitizer,
    DecoderCustomTypes
} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";

abstract contract FraxDecoderAndSanitizer is ERC4626DecoderAndSanitizer {
    //============================== FRAX ===============================

    // Call submit() on 0xbAFA44EFE7901E04E39Dad13167D089C559c1138
    // Example TX https://etherscan.io/tx/0x4f37e0b77a88a9c0b89efa2aecc38345c14a6d88dbd833b69d5740ebd5ec6f45
    function submit() external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    // Call enterRedemptionQueue on 0x82bA8da44Cd5261762e629dd5c605b17715727bd
    // Example TX https://etherscan.io/tx/0xf5d8df0a082cfb667b955057cc7e763168233905b37062426637f7b2aa490d62
    function enterRedemptionQueue(address _recipient, uint120 /*_amountOfFrxEth*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_recipient);
    }

    function enterRedemptionQueueViaSfrxEth(address _recipient, uint120 /*_amountOfSfrxETH*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_recipient);
    }

    function burnRedemptionTicketNft(uint256, /*_nftId*/ address _recipient)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_recipient);
    }

    // returns frxETH minus penalty
    function earlyBurnRedemptionTicketNft(address _recipient, uint256 /*_nftId*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_recipient);
    }
}
