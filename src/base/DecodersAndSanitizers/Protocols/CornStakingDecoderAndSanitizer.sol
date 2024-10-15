// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract CornStakingDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== CORN STAKING ===============================

    // For staking general ERC20s
    function deposit(address _token, uint256 /*_amount*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_token);
    }

    function mintAndDepositBitcorn(uint256 /*_amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    // For redeeming general ERC20s
    function redeemToken(address _token, uint256 /*_amount*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_token);
    }

    function redeemBitcorn(uint256 /*_amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
