// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/// @title Decoder and sanitizer for Ownable2Step from @openzeppelin/contracts/access/Ownable2Step.sol
/// @author IntoTheBlock Corp
abstract contract Ownable2StepDecoderAndSanitizer {
    function acceptOwnership() external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }
}
