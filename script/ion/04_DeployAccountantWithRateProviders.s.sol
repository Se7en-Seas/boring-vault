// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {AccountantWithRateProviders} from "./../../src/base/Roles/AccountantWithRateProviders.sol";
import {BaseScript} from "./../Base.s.sol";
import { stdJson as StdJson } from "forge-std/StdJson.sol";

contract DeployManagerWithMerkleVerification is BaseScript {
    using StdJson for string;
    
    bytes32 accountantSalt = config.readBytes32(".accountantSalt");
    
    function run() public broadcast returns (AccountantWithRateProviders accountant) {
        bytes memory creationCode = type(AccountantWithRateProviders).creationCode;
        
        accountant = AccountantWithRateProviders(
            CREATEX.deployCreate3(
                accountantSalt,
                abi.encodePacked(
                    creationCode,
                    abi.encode(
                    
                    )
                )
            )
        );
    }
}