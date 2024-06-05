// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {TellerWithMultiAssetSupport, ERC20} from "src/base/Roles/TellerWithMultiAssetSupport.sol";

contract CrossChainTellerWithGenericBridge is TellerWithMultiAssetSupport {
    // ========================================= STRUCTS =========================================
    // ========================================= CONSTANTS =========================================
    // ========================================= STATE =========================================
    //============================== ERRORS ===============================
    //============================== EVENTS ===============================
    //============================== IMMUTABLES ===============================

    constructor(address _owner, address _vault, address _accountant, address _weth)
        TellerWithMultiAssetSupport(_owner, _vault, _accountant, _weth)
    {}

    // ========================================= ADMIN FUNCTIONS =========================================
    // ========================================= PUBLIC FUNCTIONS =========================================

    function bridge() external requiresAuth {}

    function depositAndBridge() external requiresAuth {
        // TODO so if this is used, the shares should become locked on the destination chain.
    }

    function depositWithPermitAndBridge() external requiresAuth {
        // TODO so if this is used, the shares should become locked on the destination chain.
    }
}
