// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

interface IShareLocker {
    function revertIfLocked(address from) external view;
}
