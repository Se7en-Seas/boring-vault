// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {TellerWithMultiAssetSupport} from "./../../src/base/Roles/TellerWithMultiAssetSupport.sol";
import {MainnetAddresses} from "./../../test/resources/MainnetAddresses.sol";
import {BaseScript} from "./../Base.s.sol";
import { stdJson as StdJson } from "forge-std/StdJson.sol";

contract DeployoTellerWithMultiAssetSupport is BaseScript, MainnetAddresses {
    using StdJson for string;
    
    string path = "./deployment-config/04_DeployTellerWithMultiAssetSupport.json";
    string config = vm.readFile(path);

    bytes32 tellerSalt = config.readBytes32(".tellerSalt");
    address boringVault = config.readAddress(".boringVault");
    address accountant = config.readAddress(".accountant");
    
    function run() public broadcast returns (TellerWithMultiAssetSupport teller) {
        bytes memory creationCode = type(TellerWithMultiAssetSupport).creationCode;
        
        teller = TellerWithMultiAssetSupport(
            CREATEX.deployCreate3(
                tellerSalt,
                abi.encodePacked(
                    creationCode,
                    abi.encode(
                        protocolAdmin,
                        boringVault,
                        accountant,
                        address(WETH)
                    )
                )
            )
        );
    }
}