// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {IRateProvider} from "./../../src/interfaces/IRateProvider.sol";
import {EthPerWstEthRateProvider} from "./../../src/oracles/EthPerWstEthRateProvider.sol";

import {ETH_PER_STETH_CHAINLINK, WSTETH_ADDRESS} from "@ion-protocol/Constants.sol";

import {BaseScript} from "./../Base.s.sol";
import {stdJson as StdJson} from "forge-std/StdJson.sol";

/// NOTE This script must change based on the supported assets of each vault deployment.
contract DeployRateProviders is BaseScript {
    using StdJson for string;

    string path = "./deployment-config/08_DeployRateProviders.json";
    string config = vm.readFile(path);

    uint256 maxTimeFromLastUpdate = config.readUint(".maxTimeFromLastUpdate");

    function run() public broadcast returns (IRateProvider rateProvider) {
        rateProvider = new EthPerWstEthRateProvider{salt: ZERO_SALT}(
            address(ETH_PER_STETH_CHAINLINK), address(WSTETH_ADDRESS), maxTimeFromLastUpdate
        );
    }
}
