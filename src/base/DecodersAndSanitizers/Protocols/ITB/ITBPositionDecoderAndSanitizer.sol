/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.0;

import './common/BoringDecoderAndSanitizer.sol';
import './aave/AaveDecoderAndSanitizer.sol';
import './curve_and_convex/CurveAndConvexDecoderAndSanitizer.sol';
import './gearbox/GearboxDecoderAndSanitizer.sol';

contract ITBPositionDecoderAndSanitizer is BoringDecoderAndSanitizer, AaveDecoderAndSanitizer, CurveAndConvexDecoderAndSanitizer, GearboxDecoderAndSanitizer {
  constructor (address _boringVault) BoringDecoderAndSanitizer(_boringVault) {}

  function transfer(address _to, uint) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_to);
    }
}