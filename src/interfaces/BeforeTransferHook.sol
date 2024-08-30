// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

interface BeforeTransferHook {
    function beforeTransfer(address from, address to, address operator) external view;
}
