// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {IonPoolDecoderAndSanitizer} from "./../../src/base/DecodersAndSanitizers/IonPoolDecoderAndSanitizer.sol";
import {BaseScript} from "./../Base.s.sol";
import {stdJson as StdJson} from "forge-std/StdJson.sol";

contract DeployDecoderAndSanitizer is BaseScript {
    using StdJson for string;

    string path = "./deployment-config/07_DeployDecoderAndSanitizer.json";
    string config = vm.readFile(path);

    bytes32 decoderSalt = config.readBytes32(".decoderSalt");    
    address boringVault = config.readAddress(".boringVault");    

    function run() public broadcast returns (IonPoolDecoderAndSanitizer decoder) {
        require(boringVault.code.length != 0, "boringVault must have code");
        require(decoderSalt != bytes32(0), "decoder salt must not be zero");
        require(boringVault != address(0), "boring vault must be set");

        bytes memory creationCode = type(IonPoolDecoderAndSanitizer).creationCode;

        decoder = IonPoolDecoderAndSanitizer(
            CREATEX.deployCreate3(decoderSalt, abi.encodePacked(creationCode, abi.encode(boringVault)))
        );
    }
}
