// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {PositionManager as EigenLayerPositionManager} from "src/interfaces/EigenLayerPositionManager.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract ITBEigenLayerPositionManagerTest is Test, MainnetAddresses {
    using stdStorage for StdStorage;

    BoringVault public boringVault = BoringVault(payable(0x7985F7dAdb0Cd22e9Cc24A5f5e284f3FA939D88f));
    EigenLayerPositionManager public eigenLayerPositionManager =
        EigenLayerPositionManager(payable(0xc31BDE60f00bf1172a59B8EB699c417548Bce0C2));

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19986186;

        _startFork(rpcKey, blockNumber);
    }

    function testPositionManager() external {
        // Give position manager some mETH to stake.
        deal(address(METH), address(eigenLayerPositionManager), 1_000e18);

        vm.startPrank(address(boringVault));

        eigenLayerPositionManager.approveToken(address(METH), strategyManager, 1_000e18);
        eigenLayerPositionManager.deposit(1_000e18, 0);

        // We have successfully deposited 1_000e18 mETH into the mETH strategy.

        // Update the delegateTo address.
        (address liquidStaking, address underlying,) = eigenLayerPositionManager.positionConfig();
        address p2pOperator = 0xDbEd88D83176316fc46797B43aDeE927Dc2ff2F5;
        eigenLayerPositionManager.updatePositionConfig(liquidStaking, underlying, p2pOperator);

        // Eventhough position config is updated, trying to delegate to new operator fails.
        vm.expectRevert(bytes("DelegationManager._delegate: staker is already actively delegated"));
        eigenLayerPositionManager.delegate();

        // Try withdrawing everything.
        eigenLayerPositionManager.startWithdrawal(1_000e18);

        // Roll forward so withdraw can be claimed.
        vm.roll(block.number + 50400);

        eigenLayerPositionManager.completeNextWithdrawal(1_000e18);

        assertEq(
            METH.balanceOf(address(eigenLayerPositionManager)),
            1_000e18,
            "Position Manager should have fully withdrawn."
        );

        // Delegating again still fails.
        vm.expectRevert(bytes("DelegationManager._delegate: staker is already actively delegated"));
        eigenLayerPositionManager.delegate();

        vm.stopPrank();

        // ITB position manager needs to have an undelegate function.
        vm.startPrank(address(eigenLayerPositionManager));
        // Undelegate.
        DelegationManager(delegationManager).undelegate(address(eigenLayerPositionManager));

        vm.stopPrank();

        vm.startPrank(address(boringVault));

        // Change Delegation.
        eigenLayerPositionManager.delegate();

        vm.stopPrank();
    }

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

interface DelegationManager {
    function undelegate(address staker) external;
}
