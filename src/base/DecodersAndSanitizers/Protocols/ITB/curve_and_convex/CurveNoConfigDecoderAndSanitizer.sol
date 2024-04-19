/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.0;

abstract contract CurveNoConfigDecoderAndSanitizer {
    function addLiquidityAllCoinsAndStake(address _pool, uint[] memory, address _gauge, uint) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_pool, _gauge);
    }

    function unstakeAndRemoveLiquidityAllCoins(address _pool, uint, address _gauge, uint[] memory) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_pool, _gauge);
    }
}
