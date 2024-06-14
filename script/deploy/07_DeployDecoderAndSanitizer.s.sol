// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {IonPoolDecoderAndSanitizer} from "./../../src/base/DecodersAndSanitizers/IonPoolDecoderAndSanitizer.sol";
import {BaseScript} from "./../Base.s.sol";
import { stdJson as StdJson } from "forge-std/StdJson.sol";

contract DeployDecoderAndSanitizer is BaseScript {
    using StdJson for string;

    bytes32 decoderSalt = 0x48b53893da2e0b0248268c000000000000000000000000000000000000000000;
    address boringVault = 0x0000000000E7Ab44153eEBEF2343ba5289F65dAC;

    function run() public broadcast returns (IonPoolDecoderAndSanitizer decoder) {

        bytes memory creationCode = type(IonPoolDecoderAndSanitizer).creationCode;
        
        decoder = IonPoolDecoderAndSanitizer(
            CREATEX.deployCreate3(
                decoderSalt,
                abi.encodePacked(
                    creationCode,
                    abi.encode(
                        boringVault
                    )
                )
            )
        );
    }
}