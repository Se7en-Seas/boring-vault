// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {ManagerWithMerkleVerification} from "./../../src/base/Roles/ManagerWithMerkleVerification.sol";
import {BaseScript} from "./../Base.s.sol";
import { stdJson as StdJson } from "forge-std/StdJson.sol";

contract DeployManagerWithMerkleVerification is BaseScript {
    using StdJson for string;

    bytes32 managerSalt = config.readBytes32(".managerSalt");

    string managerConfigPath = "../../deployment-config/03_DeployManagerWithMerkleVerification.json";
    string managerConfig = vm.readFile(managerConfigPath);
    
    address boringVault = managerConfig.readAddress(".boringVault");
    
    function run() public broadcast returns (ManagerWithMerkleVerification manager) {
        bytes memory creationCode = type(ManagerWithMerkleVerification).creationCode;
        
        manager = ManagerWithMerkleVerification(
            CREATEX.deployCreate3(
                managerSalt,
                abi.encodePacked(
                    creationCode,
                    abi.encode(
                        protocolAdmin,
                        boringVault, 
                        BALANCER_VAULT,
                        18 // decimals
                    )
                )
            )
        );
    }
}