// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "./BaseDecoderAndSanitizer.sol";

contract IonPoolDecoderAndSanitizer is BaseDecoderAndSanitizer {
    constructor(
        address _boringVault
    ) BaseDecoderAndSanitizer(_boringVault) {}

    function supply(address recipient, uint256, bytes32[] calldata) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(recipient);
    }

    function withdraw(address receiverOfUnderlying, uint256) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiverOfUnderlying);
    }
}