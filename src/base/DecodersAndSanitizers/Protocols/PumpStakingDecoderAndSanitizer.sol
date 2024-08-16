// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract PumpStakingDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== PUMP STAKING ===============================

    function stake(uint256 /*amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function unstakeRequest(uint256 /*amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function claimSlot(uint8 /*slot*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function claimAll() external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function unstakeInstant(uint256 /*amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
