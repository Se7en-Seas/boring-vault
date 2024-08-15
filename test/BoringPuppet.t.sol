// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {BoringPuppet} from "src/base/Puppets/BoringPuppet.sol";
import {PuppetLib} from "src/base/Puppets/PuppetLib.sol";
import {MerkleTreeHelper, ERC20} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract BoringPuppetTest is Test, MerkleTreeHelper {
    using Address for address;

    BoringPuppet public boringPuppet;

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 20083900;

        _startFork(rpcKey, blockNumber);
        setSourceChainName("mainnet");

        boringPuppet = new BoringPuppet(address(this));
    }

    function testPuppet() external {
        // Make the puppet approve this address to spend USDC
        bytes memory callData = abi.encodeWithSelector(
            ERC20.approve.selector, address(this), 777, getAddress(sourceChain, "USDC"), PuppetLib.TARGET_FLAG
        );

        address(boringPuppet).functionCall(callData);

        assertEq(
            getERC20(sourceChain, "USDC").allowance(address(boringPuppet), address(this)), 777, "USDC allowance not set"
        );
    }
    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
