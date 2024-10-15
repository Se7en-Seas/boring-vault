// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployTeller.s.sol:DeployTellerScript --with-gas-price 30000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployTellerScript is Script, ContractNames, MainnetAddresses {
    uint256 public privateKey;
    Deployer public deployer = Deployer(deployerAddress);

    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        creationCode = type(TellerWithMultiAssetSupport).creationCode;
        constructorArgs =
            hex"0000000000000000000000000463e60c7ce10e57911ab7bd1667eaa21de3e79b0000000000000000000000005401b8620e5fb570064ca9114fd1e135fd77d57c00000000000000000000000028634d0c5edc67cf2450e74dea49b90a4ff93dce000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2";
        TellerWithMultiAssetSupport teller = TellerWithMultiAssetSupport(
            deployer.deployContract(
                "Lombard BTC Teller With Multi Asset Support V0.2", creationCode, constructorArgs, 0
            )
        );
        teller.updateAssetData(WBTC, true, true, 40);
        teller.updateAssetData(LBTC, true, true, 0);
        teller.updateAssetData(cbBTC, true, true, 0);
        teller.setAuthority(Authority(0xF3E03eF7df97511a52f31ea7a22329619db2bdF4));
        teller.transferOwnership(address(0));

        vm.stopBroadcast();
    }
}
