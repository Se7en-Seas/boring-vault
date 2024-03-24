// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";

contract ExpectedTokenBalancesUManager is Auth {
    struct ManageData {
        bytes32[][] manageProofs;
        address[] decodersAndSanitizers;
        address[] targets;
        bytes[] targetData;
        uint256[] values;
    }

    error ExpectedTokenBalancesUManager__MinimumTokenBalanceNotMet(
        address token, uint256 minimumBalance, uint256 actualBalance
    );

    ManagerWithMerkleVerification internal immutable manager;
    address internal immutable boringVault;

    constructor(address _owner, address _manager) Auth(_owner, Authority(address(0))) {
        manager = ManagerWithMerkleVerification(_manager);
        boringVault = address(manager.vault());
    }

    // What about using multicall? So we make the call then the follow up TX is balance check?

    function manageAndEnforceTokenBalances(
        bytes32[][] calldata manageProofs,
        address[] calldata decodersAndSanitizers,
        address[] calldata targets,
        bytes[] calldata targetData,
        uint256[] memory values,
        ERC20[] memory tokens,
        uint256[] memory minimumBalances
    ) external requiresAuth {
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        for (uint256 i = 0; i < tokens.length; ++i) {
            uint256 tokenBalance = tokens[i].balanceOf(boringVault);
            if (tokenBalance < minimumBalances[i]) {
                revert ExpectedTokenBalancesUManager__MinimumTokenBalanceNotMet(
                    address(tokens[i]), minimumBalances[i], tokenBalance
                );
            }
        }
    }
}
