// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import { BaseScript } from "../Base.s.sol";

import { stdJson as StdJson } from "forge-std/StdJson.sol";

/**
 * NOTE Deploys with `Authority` set to zero bytes.
 */
contract DeployRolesAuthority is BaseScript {
    using StdJson for string;

    bytes32 rolesAuthoritySalt = config.readBytes32(".rolesAuthoritySalt");
    address initialRolesAuthorityOwner = config.readAddress(".initialRolesAuthorityOwner");

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
    }
}