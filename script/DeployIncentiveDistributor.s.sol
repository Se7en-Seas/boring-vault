// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {IncentiveDistributor} from "src/helper/IncentiveDistributor.sol";
import {ContractNames} from "resources/ContractNames.sol";

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";

import "forge-std/Script.sol";

/**
 * @dev Run
 *      source .env && forge script script/DeployIncentiveDistributor.s.sol:DeployIncentiveDistributorScript --evm-version london --with-gas-price 10000000 --broadcast --etherscan-api-key $BASESCAN_KEY --verify
 */
contract DeployIncentiveDistributorScript is Script, ContractNames, MainnetAddresses {
    address public devStrategist = 0x2322ba43eFF1542b6A7bAeD35e66099Ea0d12Bd1;
    IncentiveDistributor public distributor;
    Deployer public deployer;
    uint256 privateKey;

    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("base");
        deployer = Deployer(deployerAddress);
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        creationCode = type(IncentiveDistributor).creationCode;
        constructorArgs = abi.encode(dev1Address);
        distributor =
            IncentiveDistributor(deployer.deployContract(IncentiveDistributorName, creationCode, constructorArgs, 0));

        require(distributor.owner() == dev1Address);

        vm.stopBroadcast();
    }
}
