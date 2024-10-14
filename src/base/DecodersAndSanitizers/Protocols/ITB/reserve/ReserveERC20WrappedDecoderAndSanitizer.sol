/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.0;

abstract contract ReserveERC20WrappedDecoderAndSanitizer {
    function deposit(uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function depositTo(address _dst, uint256) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_dst);
    }

    function withdraw(uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function withdrawTo(address _dst, uint256) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_dst);
    }
}
