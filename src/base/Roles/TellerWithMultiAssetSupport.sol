// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {AccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";

contract TellerWithMultiAssetSupport is AccessControlDefaultAdminRules {
    // This contract will be in charge of mint and redeem
    // Somm governance will have nothing to do with this one.

    bytes32 public constant ON_RAMP_ROLE = keccak256("ON_RAMP_ROLE"); // bulk user deposits
    bytes32 public constant OFF_RAMP_ROLE = keccak256("OFF_RAMP_ROLE"); // bulk user withdraws with no waiting period.
    bytes32 public constant WITHDRAW_FINALIZER_ROLE = keccak256("WITHDRAW_FINALIZER_ROLE"); // can finalize user withdraws
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE"); // can turn off normal user deposits and withdraws
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE"); // can turn off normal user deposits and withdraws

    constructor(address _owner) AccessControlDefaultAdminRules(3 days, _owner) {}

    // Roles
    // a strategist that can turn off normal user deposits and withdraws, and finalize user withdraws
    // an entity that can do bulk deposit and withdraws with no waiting period, Atomic Queue solver.

    // normal depsits
    bool public is_paused;

    // For user functions add min share out values
    function deposit(ERC20 deposit_asset) external {
        require(!is_paused, "paused");
        // TODO support eth
    }

    function bulkDeposit(ERC20 deposit_asset) external onlyRole(ON_RAMP_ROLE) {}
    function bulkWithdraw(ERC20 withdraw_asset) external onlyRole(OFF_RAMP_ROLE) {}
}
