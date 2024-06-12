// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {AccountantWithRateProviders} from "./../../src/base/Roles/AccountantWithRateProviders.sol";
import {BaseScript} from "./../Base.s.sol";
import { stdJson as StdJson } from "forge-std/StdJson.sol";

contract DeployAccountantWithRateProviders is BaseScript {
    using StdJson for string;
    
    string path = "./deployment-config/03_DeployAccountantWithRateProviders.json";
    string config = vm.readFile(path);

    bytes32 accountantSalt = config.readBytes32(".accountantSalt");
    address boringVault = config.readAddress(".boringVault");
    address payoutAddress = config.readAddress(".payoutAddress");
    uint96 startingExchangeRate = uint96(config.readUint(".startingExchangeRate"));
    address base = config.readAddress(".base");
    uint16 allowedExchangeRateChangeUpper = uint16(config.readUint(".allowedExchangeRateChangeUpper"));
    uint16 allowedExchangeRateChangeLower = uint16(config.readUint(".allowedExchangeRateChangeLower"));
    uint32 minimumUpdateDelayInSeconds = uint32(config.readUint(".minimumUpdateDelayInSeconds"));
    uint16 managementFee = uint16(config.readUint(".managementFee"));
    
    function run() public broadcast returns (AccountantWithRateProviders accountant) {
        bytes memory creationCode = type(AccountantWithRateProviders).creationCode;
        
        accountant = AccountantWithRateProviders(
            CREATEX.deployCreate3(
                accountantSalt,
                abi.encodePacked(
                    creationCode,
                    abi.encode(
                        protocolAdmin,
                        boringVault, 
                        payoutAddress,
                        startingExchangeRate,
                        base,
                        allowedExchangeRateChangeUpper,
                        allowedExchangeRateChangeLower,
                        minimumUpdateDelayInSeconds,
                        managementFee
                    )
                )
            )
        );
    }
}