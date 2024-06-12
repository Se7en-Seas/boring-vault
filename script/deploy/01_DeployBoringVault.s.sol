// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {BoringVault} from "./../../src/base/BoringVault.sol";
import { BaseScript } from "./../Base.s.sol";
import { stdJson as StdJson } from "forge-std/StdJson.sol";

contract DeployIonBoringVaultScript is BaseScript {
    using StdJson for string;

    string path = "./deployment-config/01_DeployIonBoringVault.json";
    string config = vm.readFile(path);

    bytes32 boringVaultSalt = config.readBytes32(".boringVaultSalt");
    string boringVaultName = config.readString(".boringVaultName");
    string boringVaultSymbol = config.readString(".boringVaultSymbol");

    function run() public broadcast returns (BoringVault boringVault) {
        bytes memory creationCode = type(BoringVault).creationCode;
        
        boringVault = BoringVault(
            payable(CREATEX.deployCreate3(
                boringVaultSalt,
                abi.encodePacked(
                    creationCode,
                    abi.encode(
                        protocolAdmin,
                        boringVaultName, 
                        boringVaultSymbol,
                        18 // decimals
                    )
                )
            )
        ));
    }
}