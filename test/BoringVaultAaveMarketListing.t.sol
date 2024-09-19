// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {BoringDrone} from "src/base/Drones/BoringDrone.sol";
import {DroneLib} from "src/base/Drones/DroneLib.sol";
import {MerkleTreeHelper, ERC20} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract BoringDroneTest is Test, MerkleTreeHelper {
    using Address for address;

    BoringDrone public boringDrone;

    address public aavePayloadController = 0xdAbad81aF85554E9ae636395611C58F7eC1aAEc5;
    address public aaveExecutePayloadCaller = 0x3Cbded22F878aFC8d39dCD744d3Fe62086B76193;

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 20713916; // The block number before execute payload was called
        // https://etherscan.io/tx/0x8dce3e22688d50eaba48fbd1805623e7b7b9cb8910c96e609f279906c3d6ef67

        // Then this is the tx where the payload was created.
        // https://etherscan.io/tx/0x025defc34c08bbe6c0fe56213cd11ec5d5dad8f66c817155a09de33d4f06e431
        _startFork(rpcKey, blockNumber);
        setSourceChainName("mainnet");

        boringDrone = new BoringDrone(address(this), 0);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    receive() external payable {}

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
