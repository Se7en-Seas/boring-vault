// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import { ERC20 } from "@solmate/tokens/ERC20.sol";

interface IAtomicSolver {
    /**
     * @notice This function must be implemented in order for an address to be a `solver`
     *         for the AtomicQueue
     * @param runData arbitrary bytes data that is dependent on how each solver is setup
     *        it could contain swap data, or flash loan data, etc..
     * @param initiator the address that initiated a solve
     * @param offer the ERC20 asset sent to the solver
     * @param want the ERC20 asset the solver must approve the queue for
     * @param assetsToOffer the amount of `offer` sent to the solver
     * @param assetsForWant the amount of `want` the solver must approve the queue for
     */
    function finishSolve(
        bytes calldata runData,
        address initiator,
        ERC20 offer,
        ERC20 want,
        uint256 assetsToOffer,
        uint256 assetsForWant
    ) external;
}
