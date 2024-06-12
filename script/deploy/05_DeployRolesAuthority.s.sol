// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ManagerWithMerkleVerification} from "./../../src/base/Roles/ManagerWithMerkleVerification.sol";
import {BoringVault} from "./../../src/base/BoringVault.sol";
import {TellerWithMultiAssetSupport} from "./../../src/base/Roles/TellerWithMultiAssetSupport.sol";
import { BaseScript } from "../Base.s.sol";

import { stdJson as StdJson } from "forge-std/StdJson.sol";

/**
 * NOTE Deploys with `Authority` set to zero bytes.
 */
contract DeployRolesAuthority is BaseScript {
    using StdJson for string;

    string path = "./deployment-config/05_DeployRolesAuthority.json";
    string config = vm.readFile(path);

    bytes32 rolesAuthoritySalt = config.readBytes32(".rolesAuthoritySalt");
    address initialRolesAuthorityOwner = config.readAddress(".initialRolesAuthorityOwner");

    // TODO Refactor deployed addresses in multiple .json file to a single one
    address boringVault = config.readAddress(".boringVault");
    address manager = config.readAddress(".manager");
    address teller = config.readAddress(".teller");
    address strategist = config.readAddress(".strategist");

    uint8 public constant STRATEGIST_ROLE = 1; 
    uint8 public constant MANAGER_ROLE = 2;
    uint8 public constant TELLER_ROLE = 3;

    function run() public broadcast returns (RolesAuthority rolesAuthority) {
        bytes memory creationCode = type(RolesAuthority).creationCode;
        
        rolesAuthority = RolesAuthority(
            CREATEX.deployCreate3(
                rolesAuthoritySalt,
                abi.encodePacked(
                    creationCode,
                    abi.encode(
                        initialRolesAuthorityOwner,
                        address(0) // `Authority`
                    )
                )
            )
        );

        // Setup initial roles configurations
        // --- Users ---
        // 1. VAULT_STRATEGIST (BOT)
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
            STRATEGIST_ROLE,
            manager,
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );

        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            boringVault,
            bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)"))),
            true
        );

        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            boringVault,
            bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])"))),
            true
        );

        rolesAuthority.setRoleCapability(
            TELLER_ROLE,
            boringVault,
            BoringVault.enter.selector,
            true
        );

        rolesAuthority.setRoleCapability(
            TELLER_ROLE,
            boringVault,
            BoringVault.exit.selector,
            true
        );

        rolesAuthority.setPublicCapability(
            teller, 
            TellerWithMultiAssetSupport.deposit.selector, 
            true
        );

        // --- Assign roles to users ---

        rolesAuthority.setUserRole(
            strategist,
            STRATEGIST_ROLE,
            true
        );

        rolesAuthority.setUserRole(
            manager,
            MANAGER_ROLE,
            true
        );

        rolesAuthority.setUserRole(
            teller,
            TELLER_ROLE,
            true
        );
    }
}