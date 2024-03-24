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

    struct ComplexData {
        uint256 a;
        uint256 b;
        uint256 c;
        uint256 d;
    }

    // TODO I think the issue was that calldata is pushed onto the stack when read,
    // but memory data is only pushed onto the stack when it is needed to be read.
    // So the name of the game is to make as much calldata as possible?
    function manageAndEnforceTokenBalances(
        bytes32[][] calldata manageProofs,
        address[] calldata decodersAndSanitizers,
        address[] calldata targets,
        bytes[] calldata targetData,
        uint256[] memory values,
        ERC20[] memory tokens,
        uint256[] memory minimumBalances,
        ComplexData calldata data
    ) external requiresAuth {
        require(data.a > 0);
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
