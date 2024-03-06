// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

// Swell
interface INonFungiblePositionManager {
    function ownerOf(uint256 tokenId) external view returns (address);
}
