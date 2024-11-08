// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

interface ShareLocker {
    /**
     * @notice Should revert if the transfer should not be allowed.
     */
    function canTransfer(address from, address to, address operator, uint256 balanceOfFrom, uint256 transferAmount)
        external
        view;
}
