// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract CurveDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== CURVE ===============================

    function exchange(int128, int128, uint256, uint256) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function add_liquidity(uint256[] calldata, uint256) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function remove_liquidity(uint256, uint256[] calldata)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function deposit(uint256, address receiver) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver);
    }

    function withdraw(uint256) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function claim_rewards(address _addr) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_addr);
    }
}
