// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ManagerWithMerkleVerification} from "./../../src/base/Roles/ManagerWithMerkleVerification.sol";
import {BoringVault} from "./../../src/base/BoringVault.sol";
import {TellerWithMultiAssetSupport} from "./../../src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithRateProviders} from "./../../src/base/Roles/AccountantWithRateProviders.sol";
import {BaseScript} from "../Base.s.sol";

import {stdJson as StdJson} from "forge-std/StdJson.sol";

/**
 * NOTE Deploys with `Authority` set to zero bytes.
 */
contract DeployRolesAuthority is BaseScript {
    using StdJson for string;

    string path = "./deployment-config/05_DeployRolesAuthority.json";
    string config = vm.readFile(path);

    bytes32 rolesAuthoritySalt = config.readBytes32(".rolesAuthoritySalt");

    address boringVault = config.readAddress(".boringVault");
    address manager = config.readAddress(".manager");
    address teller = config.readAddress(".teller");
    address accountant = config.readAddress(".accountant");
    address strategist = config.readAddress(".strategist");
    address exchangeRateBot = config.readAddress(".exchangeRateBot");

    uint8 public constant STRATEGIST_ROLE = 1;
    uint8 public constant MANAGER_ROLE = 2;
    uint8 public constant TELLER_ROLE = 3;
    uint8 public constant UPDATE_EXCHANGE_RATE_ROLE = 4;

    function run() public broadcast returns (RolesAuthority rolesAuthority) {
        require(boringVault.code.length != 0, "boringVault must have code");
        require(manager.code.length != 0, "manager must have code");
        require(teller.code.length != 0, "teller must have code");
        require(accountant.code.length != 0, "accountant must have code");
        
        require(boringVault != address(0), "boringVault");
        require(manager != address(0), "manager");
        require(teller != address(0), "teller");
        require(accountant != address(0), "accountant");
        require(strategist != address(0), "strategist");
        
        bytes memory creationCode = type(RolesAuthority).creationCode;

        rolesAuthority = RolesAuthority(
            CREATEX.deployCreate3(
                rolesAuthoritySalt,
                abi.encodePacked(
                    creationCode,
                    abi.encode(
                        broadcaster,
                        address(0) // `Authority`
                    )
                )
            )
        );

        // Setup initial roles configurations
        // --- Users ---
        // 1. VAULT_STRATEGIST (BOT EOA)
        // 2. MANAGER (CONTRACT)
        // 3. TELLER (CONTRACT)
        // --- Roles ---
        // 1. STRATEGIST_ROLE
        //     - manager.manageVaultWithMerkleVerification
        //     - assigned to VAULT_STRATEGIST
        // 2. MANAGER_ROLE
        //     - boringVault.manage()
        //     - assigned to MANAGER
        // 3. TELLER_ROLE
        //     - boringVault.enter()
        //     - boringVault.exit()
        //     - assigned to TELLER
        // --- Public ---
        // 1. teller.deposit

        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE, manager, ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector, true
        );

        rolesAuthority.setRoleCapability(
            MANAGER_ROLE, boringVault, bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)"))), true
        );

        rolesAuthority.setRoleCapability(
            MANAGER_ROLE, boringVault, bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])"))), true
        );

        rolesAuthority.setRoleCapability(TELLER_ROLE, boringVault, BoringVault.enter.selector, true);

        rolesAuthority.setRoleCapability(TELLER_ROLE, boringVault, BoringVault.exit.selector, true);

        rolesAuthority.setPublicCapability(teller, TellerWithMultiAssetSupport.deposit.selector, true);

        rolesAuthority.setRoleCapability(
            UPDATE_EXCHANGE_RATE_ROLE, accountant, AccountantWithRateProviders.updateExchangeRate.selector, true
        );

        // --- Assign roles to users ---

        rolesAuthority.setUserRole(strategist, STRATEGIST_ROLE, true);

        rolesAuthority.setUserRole(manager, MANAGER_ROLE, true);

        rolesAuthority.setUserRole(teller, TELLER_ROLE, true);

        rolesAuthority.setUserRole(exchangeRateBot, UPDATE_EXCHANGE_RATE_ROLE, true);

        require(rolesAuthority.doesUserHaveRole(strategist, STRATEGIST_ROLE), "strategist should have STRATEGIST_ROLE");
        require(rolesAuthority.doesUserHaveRole(manager, MANAGER_ROLE), "manager should have MANAGER_ROLE");
        require(rolesAuthority.doesUserHaveRole(teller, TELLER_ROLE), "teller should have TELLER_ROLE");
        require(rolesAuthority.doesUserHaveRole(exchangeRateBot, UPDATE_EXCHANGE_RATE_ROLE), "exchangeRateBot should have UPDATE_EXCHANGE_RATE_ROLE");
        
        require(rolesAuthority.canCall(strategist, manager, ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector), "strategist should be able to call manageVaultWithMerkleVerification");
        require(rolesAuthority.canCall(manager, boringVault, bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)")))), "manager should be able to call boringVault.manage");
        require(rolesAuthority.canCall(manager, boringVault, bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])")))), "manager should be able to call boringVault.manage");
        require(rolesAuthority.canCall(teller, boringVault, BoringVault.enter.selector), "teller should be able to call boringVault.enter");
        require(rolesAuthority.canCall(teller, boringVault, BoringVault.exit.selector), "teller should be able to call boringVault.exit");
        require(rolesAuthority.canCall(exchangeRateBot, accountant, AccountantWithRateProviders.updateExchangeRate.selector), "exchangeRateBot should be able to call accountant.updateExchangeRate");

        require(rolesAuthority.canCall(address(1), teller, TellerWithMultiAssetSupport.deposit.selector), "anyone should be able to call teller.deposit");
    }
}
