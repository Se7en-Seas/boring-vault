// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {AtomicQueue} from "src/atomic-queue/AtomicQueue.sol";
import {AtomicSolverV4} from "src/atomic-queue/AtomicSolverV4.sol";
import {ContractNames} from "resources/ContractNames.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployAtomicQueue.s.sol:DeployAtomicQueueScript --with-gas-price 8000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployAtomicQueueScript is Script, ContractNames, MainnetAddresses {
    uint256 public privateKey;

    // Contracts to deploy
    Deployer public deployer = Deployer(deployerAddress);
    RolesAuthority public rolesAuthority;
    AtomicQueue public atomicQueue;
    AtomicSolverV4 public atomicSolver;
    address public owner = dev1Address;

    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        rolesAuthority = RolesAuthority(deployer.getAddress(SevenSeasRolesAuthorityName));

        creationCode = type(AtomicQueue).creationCode;
        constructorArgs = abi.encode(owner, rolesAuthority);
        atomicQueue = AtomicQueue(deployer.deployContract(AtomicQueueName, creationCode, constructorArgs, 0));

        // creationCode = type(AtomicSolverV4).creationCode;
        // constructorArgs = abi.encode(owner, rolesAuthority);
        // atomicSolver = AtomicSolverV4(deployer.deployContract(AtomicSolverName, creationCode, constructorArgs, 0));

        vm.stopBroadcast();
    }
}
