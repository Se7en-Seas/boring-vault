// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {IPausable} from "src/interfaces/IPausable.sol";

contract MockPausable is IPausable {
    bool public isPaused;

    function pause() external {
        isPaused = true;
    }

    function unpause() external {
        isPaused = false;
    }
}
