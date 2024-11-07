// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

interface IBoringSolver {
    function boringSolve(
        address initiator,
        address boringVault,
        address solveAsset,
        uint256 totalShares,
        uint256 requiredAssets,
        bytes calldata solveData
    ) external;
}
