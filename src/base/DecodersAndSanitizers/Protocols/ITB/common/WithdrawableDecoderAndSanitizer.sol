// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/// @title Decoder and sanitizer for Withdrawable
/// @author IntoTheBlock Corp
abstract contract WithdrawableDecoderAndSanitizer {
    function withdraw(address, /*_asset_address*/ uint256) external pure returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function withdrawAll(address /*_asset_address*/ ) external pure returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
