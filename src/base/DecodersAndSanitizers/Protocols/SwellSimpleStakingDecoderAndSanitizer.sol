// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract SwellSimpleStakingDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== SWELL SIMPLE STAKING ===============================

    function deposit(address _token, uint256, /*_amount*/ address _receiver)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_token, _receiver);
        addressesFound = appendPuppetTargetIfPresent(addressesFound);
    }

    function withdraw(address _token, uint256, /*_amount*/ address _receiver)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_token, _receiver);
        addressesFound = appendPuppetTargetIfPresent(addressesFound);
    }
}
