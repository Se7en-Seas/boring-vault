// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {ManagerWithMerkleVerification} from "./../../src/base/Roles/ManagerWithMerkleVerification.sol";
import {BaseScript} from "./../Base.s.sol";
import { stdJson as StdJson } from "forge-std/StdJson.sol";

contract DeployManagerWithMerkleVerification is BaseScript {
    using StdJson for string;


    string path = "./deployment-config/02_DeployManagerWithMerkleVerification.json";
    string config = vm.readFile(path);

    bytes32 managerSalt = config.readBytes32(".managerSalt");
    address boringVault = config.readAddress(".boringVault");
    
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