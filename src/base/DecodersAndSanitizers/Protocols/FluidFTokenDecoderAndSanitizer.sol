// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract FluidFTokenDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== Fluid FToken ===============================

    function deposit(uint256, /*assets_*/ address receiver_, uint256 /*minAmountOut_*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver_);
    }

    function mint(uint256, /*shares_*/ address receiver_, uint256 /*maxAssets_*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver_);
    }

    function withdraw(uint256, /*assets_*/ address receiver_, address owner_, uint256 /*maxSharesBurn_*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver_, owner_);
    }

    function redeem(uint256, /*shares_*/ address receiver_, address owner_, uint256 /*minAmountOut_*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver_, owner_);
    }

    function stake(uint256 /*amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function withdraw(uint256 /*amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function getReward() external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function exit() external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }
}
