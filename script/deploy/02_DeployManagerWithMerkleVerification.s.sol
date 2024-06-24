// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {ManagerWithMerkleVerification} from "./../../src/base/Roles/ManagerWithMerkleVerification.sol";
import {BaseScript} from "./../Base.s.sol";
import {stdJson as StdJson} from "forge-std/StdJson.sol";

contract DeployManagerWithMerkleVerification is BaseScript {
    using StdJson for string;

    string path = "./deployment-config/02_DeployManagerWithMerkleVerification.json";
    string config = vm.readFile(path);

    bytes32 managerSalt = config.readBytes32(".managerSalt");
    address boringVault = config.readAddress(".boringVault");

    function run() public broadcast returns (ManagerWithMerkleVerification manager) {
        require(managerSalt != bytes32(0), "manager salt must not be zero");
        require(boringVault != address(0), "boring vault address must not be zero");

        require(address(boringVault).code.length != 0, "boring vault must have code");
        require(address(BALANCER_VAULT).code.length != 0, "balancer vault must have code");

        bytes memory creationCode = type(ManagerWithMerkleVerification).creationCode;

        manager = ManagerWithMerkleVerification(
            CREATEX.deployCreate3(
                managerSalt,
                abi.encodePacked(
                    creationCode,
                    abi.encode(
                        broadcaster,
                        boringVault,
                        BALANCER_VAULT,
                        18 // decimals
                    )
                )
            )
        );

        require(manager.isPaused() == false, "the manager must not be paused");
        require(address(manager.vault()) == boringVault, "the manager vault must be the boring vault");
        require(address(manager.balancerVault()) == BALANCER_VAULT, "the manager balancer vault must be the balancer vault");
    }
}
