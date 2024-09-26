// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {IBoringSolver} from "src/base/Roles/BoringQueue/IBoringSolver.sol";

contract BoringSolver is IBoringSolver {
    function boringSolve(
        address initiator,
        address boringVault,
        address solveAsset,
        uint256 totalShares,
        uint256 requiredAssets,
        bytes calldata solveData
    ) external {
        // Do something.
    }
}
