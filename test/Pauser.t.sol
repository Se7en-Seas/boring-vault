// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {MockPausable} from "test/mocks/MockPausable.sol";
import {Pauser, IPausable} from "src/base/Roles/Pauser.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract PauserTest is Test {
    IPausable[] public pausables;
    Pauser public pauser;

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 20083900;

        _startFork(rpcKey, blockNumber);

        // Setup pausables.
        pausables.push(new MockPausable());
        pausables.push(new MockPausable());
        pausables.push(new MockPausable());

        // Setup pauser.
        pauser = new Pauser(address(this), Authority(address(0)), pausables);
    }

    function testPauseAll() external {
        pauser.pauseAll();

        for (uint256 i = 0; i < pausables.length; ++i) {
            assertEq(MockPausable(address(pausables[i])).isPaused(), true, "MockPausable should be paused");
        }

        pauser.unpauseAll();

        for (uint256 i = 0; i < pausables.length; ++i) {
            assertEq(MockPausable(address(pausables[i])).isPaused(), false, "MockPausable should be unpaused");
        }
    }

    function testSenderPause() external {
        pauser.updateSenderToPausable(address(this), pausables[0]);

        pauser.senderPause();

        assertEq(MockPausable(address(pausables[0])).isPaused(), true, "MockPausable should be paused");

        pauser.senderUnpause();

        assertEq(MockPausable(address(pausables[0])).isPaused(), false, "MockPausable should be unpaused");
    }

    function testPauseSingle() external {
        pauser.pauseSingle(pausables[0]);

        assertEq(MockPausable(address(pausables[0])).isPaused(), true, "MockPausable should be paused");

        pauser.unpauseSingle(pausables[0]);

        assertEq(MockPausable(address(pausables[0])).isPaused(), false, "MockPausable should be unpaused");
    }

    function testPauseMultiple() external {
        pauser.pauseMultiple(pausables);

        for (uint256 i = 0; i < pausables.length; ++i) {
            assertEq(MockPausable(address(pausables[i])).isPaused(), true, "MockPausable should be paused");
        }

        pauser.unpauseMultiple(pausables);

        for (uint256 i = 0; i < pausables.length; ++i) {
            assertEq(MockPausable(address(pausables[i])).isPaused(), false, "MockPausable should be unpaused");
        }
    }

    function testGetPausables() external {
        IPausable[] memory _pausables = pauser.getPausables();

        for (uint256 i = 0; i < pausables.length; ++i) {
            assertEq(address(_pausables[i]), address(pausables[i]), "Pausables should be equal");
        }
    }

    function testUpdateSenderToPausable() external {
        pauser.updateSenderToPausable(address(this), pausables[0]);

        IPausable pausable = pauser.senderToPausable(address(this));

        assertEq(address(pausable), address(pausables[0]), "Pausables should be equal");
    }

    function testUpdatePausables() external {
        MockPausable newPausable = new MockPausable();

        pauser.addPausable(newPausable);

        pauser.removePausable(0);
        pauser.removePausable(1);
        pauser.removePausable(1);

        IPausable[] memory _pausables = pauser.getPausables();

        assertEq(_pausables.length, 1, "Pausables length should be 1");
        assertEq(address(_pausables[0]), address(newPausable), "Pausables should be equal");

        // Try removing an out of bounds index.
        vm.expectRevert(bytes(abi.encodeWithSelector(Pauser.Pauser__IndexOutOfBounds.selector)));
        pauser.removePausable(1);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
