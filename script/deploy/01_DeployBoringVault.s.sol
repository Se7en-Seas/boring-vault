// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {BoringVault} from "./../../src/base/BoringVault.sol";
import {BaseScript} from "./../Base.s.sol";
import {stdJson as StdJson} from "forge-std/StdJson.sol";

contract DeployIonBoringVaultScript is BaseScript {
    using StdJson for string;

    string path = "./deployment-config/01_DeployIonBoringVault.json";
    string config = vm.readFile(path);

    bytes32 boringVaultSalt = config.readBytes32(".boringVaultSalt");
    string boringVaultName = config.readString(".boringVaultName");
    string boringVaultSymbol = config.readString(".boringVaultSymbol");

    function run() public broadcast returns (BoringVault boringVault) {
        require(boringVaultSalt != bytes32(0));
        require(keccak256(bytes(boringVaultName)) != keccak256(bytes("")));
        require(keccak256(bytes(boringVaultSymbol)) != keccak256(bytes("")));

        bytes memory creationCode = type(BoringVault).creationCode;

        boringVault = BoringVault(
            payable(
                CREATEX.deployCreate3(
                    boringVaultSalt,
                    abi.encodePacked(
                        creationCode,
                        abi.encode(
                            broadcaster,
                            boringVaultName,
                            boringVaultSymbol,
                            18 // decimals
                        )
                    )
                )
            )
        );

        require(boringVault.owner() == broadcaster, "owner should be the deployer");
        require(address(boringVault.hook()) == address(0), "before transfer hook should be zero");
    }
}
