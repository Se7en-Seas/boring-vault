// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {IPausable} from "src/interfaces/IPausable.sol";

contract Pauser is Auth {
    // ========================================= CONSTANTS =========================================

    // ========================================= STATE =========================================

    IPausable[] internal pausables;

    /**
     * @notice Used to pause calls to `deposit` and `depositWithPermit`.
     */
    bool public isPaused;

    //============================== ERRORS ===============================

    //============================== EVENTS ===============================

    event PausablePaused(address indexed pausable);
    event PausableUnpaused(address indexed pausable);

    //============================== IMMUTABLES ===============================

    constructor(address _owner, Authority _authority, IPausable[] memory _pausables) Auth(_owner, _authority) {
        for (uint256 i = 0; i < _pausables.length; ++i) {
            pausables.push(_pausables[i]);
        }
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    // TODO function to change pausables.

    function pauseSingle(IPausable pausable) external requiresAuth {
        pausable.pause();
        emit PausablePaused(address(pausable));
    }

    function unpauseSingle(IPausable pausable) external requiresAuth {
        pausable.unpause();
        emit PausableUnpaused(address(pausable));
    }

    function pauseMultiple(IPausable[] calldata _pausables) external requiresAuth {
        for (uint256 i = 0; i < _pausables.length; ++i) {
            _pausables[i].pause();
            emit PausablePaused(address(_pausables[i]));
        }
    }

    function unpauseMultiple(IPausable[] calldata _pausables) external requiresAuth {
        for (uint256 i = 0; i < _pausables.length; ++i) {
            _pausables[i].unpause();
            emit PausableUnpaused(address(_pausables[i]));
        }
    }

    function pauseAll() external requiresAuth {
        for (uint256 i = 0; i < pausables.length; ++i) {
            pausables[i].pause();
            emit PausablePaused(address(pausables[i]));
        }
    }

    function unpauseAll() external requiresAuth {
        for (uint256 i = 0; i < pausables.length; ++i) {
            pausables[i].unpause();
            emit PausableUnpaused(address(pausables[i]));
        }
    }
}
