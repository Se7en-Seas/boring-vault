/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.0;

abstract contract ConvexDecoderAndSanitizer {
    function addLiquidityAllCoinsAndStakeConvex(address _pool, uint[] memory, uint _convex_pool_id, uint) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_pool, address(uint160(_convex_pool_id)));
    }

    function unstakeAndRemoveLiquidityAllCoinsConvex(address _pool, uint, uint _convex_pool_id, uint[] memory) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_pool, address(uint160(_convex_pool_id)));
    }
}
