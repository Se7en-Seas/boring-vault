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

    function manageAndEnforceTokenBalances(
        ManageData calldata manageData,
        ERC20[] calldata tokens,
        uint256[] calldata minimumBalances
    ) external requiresAuth {
        manager.manageVaultWithMerkleVerification(
            manageData.manageProofs,
            manageData.decodersAndSanitizers,
            manageData.targets,
            manageData.targetData,
            manageData.values
        );
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
