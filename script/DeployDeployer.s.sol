// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 * @dev to deploy on mantle add a -g 60000 to the command line else it will fail
 *  source .env && forge script script/DeployDeployer.s.sol:DeployDeployerScript --evm-version london --broadcast --etherscan-api-key $LINEASCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployDeployerScript is Script, ContractNames, MainnetAddresses {
    uint256 public privateKey;

    // Contracts to deploy
    RolesAuthority public rolesAuthority;
    Deployer public deployer;
    address public boringDeployer = 0x21f490e1F3b70eD2BdBE8E3d9cA7290Ff7f129d5;

    uint8 public DEPLOYER_ROLE = 1;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEPLOYER");
        vm.createSelectFork("linea");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        deployer = Deployer(0xFD65ADF7d2f9ea09287543520a703522E0a360C9);
        require(address(deployer) == 0xFD65ADF7d2f9ea09287543520a703522E0a360C9, "bad deployer address");
        creationCode = type(RolesAuthority).creationCode;
        constructorArgs = abi.encode(boringDeployer, Authority(address(0)));
        rolesAuthority =
            RolesAuthority(deployer.deployContract(SevenSeasRolesAuthorityName, creationCode, constructorArgs, 0));

        deployer.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(DEPLOYER_ROLE, address(deployer), Deployer.deployContract.selector, true);
        rolesAuthority.setUserRole(dev0Address, DEPLOYER_ROLE, true);
        rolesAuthority.setUserRole(dev1Address, DEPLOYER_ROLE, true);

        deployer.transferOwnership(dev0Address);
        rolesAuthority.transferOwnership(dev0Address);

        vm.stopBroadcast();
    }
}
