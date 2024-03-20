// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

interface BeforeTransferHook {
    function beforeTransfer(address from) external view;
}
