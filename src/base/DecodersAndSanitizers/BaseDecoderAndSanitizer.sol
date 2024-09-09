// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract BaseDecoderAndSanitizer {
    error BaseDecoderAndSanitizer__FunctionSelectorNotSupported();
    //============================== IMMUTABLES ===============================

    /**
     * @notice The BoringVault contract address.
     */
    address internal immutable boringVault;

    constructor(address _boringVault) {
        boringVault = _boringVault;
    }

    function approve(address spender, uint256) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(spender);
    }

    function transfer(address _to, uint256) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_to);
    }

    function claimFees(address feeAsset) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(feeAsset);
    }

    function withdrawNonBoringToken(address token, uint256 /*amount*/ )
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(token);
    }

    function withdrawNativeFromDrone() external pure returns (bytes memory addressesFound) {
        return addressesFound;
    }

    //============================== FALLBACK ===============================
    /**
     * @notice The purpose of this function is to revert with a known error,
     *         so that during merkle tree creation we can verify that a
     *         leafs decoder and sanitizer implments the required function
     *         selector.
     */
    fallback() external {
        revert BaseDecoderAndSanitizer__FunctionSelectorNotSupported();
    }
}
