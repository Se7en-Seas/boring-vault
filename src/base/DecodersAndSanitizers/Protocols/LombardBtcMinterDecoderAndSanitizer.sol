// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract LombardBTCMinterDecoderAndSanitizer is BaseDecoderAndSanitizer {
    
    /// @notice for permissioned users
    function mint(address to, uint256 /*amount*/) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(to); 
    }
    
   /// @notice minting directly via LTBC contract 
    function mint(bytes calldata data, bytes calldata /*proofSignature*/) external pure virtual returns (bytes memory addressesFound) {
        (, address to, , ,) = abi.decode(data, (uint256, address, uint64, bytes32, uint32));
        addressesFound = abi.encodePacked(to); 
    }
    
    /// @notice for minting using cbBTCPPM contract (on Base)
    function swapCBBTCToLBTC(uint256 /*amount*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    }
    
    /// @notice for minting using btcbPMM contract (on BSC)
    function swapBTCBToLBTC(uint256 /*amount*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    }

}
