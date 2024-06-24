// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {AccountantWithRateProviders} from "./../../src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport} from "./../../src/base/Roles/TellerWithMultiAssetSupport.sol";
import {MainnetAddresses} from "./../../test/resources/MainnetAddresses.sol";
import {BaseScript} from "./../Base.s.sol";
import {stdJson as StdJson} from "forge-std/StdJson.sol";

contract DeployTellerWithMultiAssetSupport is BaseScript, MainnetAddresses {
    using StdJson for string;

    string path = "./deployment-config/04_DeployTellerWithMultiAssetSupport.json";
    string config = vm.readFile(path);

    bytes32 tellerSalt = config.readBytes32(".tellerSalt");
    address boringVault = config.readAddress(".boringVault");
    address accountant = config.readAddress(".accountant");

    function run() public broadcast returns (TellerWithMultiAssetSupport teller) {
        require(boringVault.code.length != 0, "boringVault must have code");
        require(accountant.code.length != 0, "accountant must have code");
        
        require(tellerSalt != bytes32(0), "tellerSalt");
        require(boringVault != address(0), "boringVault");
        require(accountant != address(0), "accountant");

        bytes memory creationCode = type(TellerWithMultiAssetSupport).creationCode;

        teller = TellerWithMultiAssetSupport(
            CREATEX.deployCreate3(
                tellerSalt,
                abi.encodePacked(creationCode, abi.encode(broadcaster, boringVault, accountant, address(WETH)))
            )
        );

        require(teller.shareLockPeriod() == 0, "share lock period must be zero");
        require(teller.isPaused() == false, "the teller must not be paused");
        require(
            AccountantWithRateProviders(teller.accountant()).vault() == teller.vault(),
            "the accountant vault must be the teller vault"
        );
    }
}
