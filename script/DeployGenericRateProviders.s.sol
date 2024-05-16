// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {GenericRateProvider} from "src/helper/GenericRateProvider.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployGenericRateProviders.s.sol:DeployGenericRateProvidersScript --with-gas-price 30000000000 --slow --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployGenericRateProvidersScript is Script, ContractNames, MainnetAddresses {
    using AddressToBytes32Lib for address;

    uint256 public privateKey;

    // Contracts to deploy
    Deployer public deployer = Deployer(deployerAddress);
    GenericRateProvider public auraRETHWeETHBptRateProvider;
    GenericRateProvider public wstethRateProvider;

    // Dont need an aweETH rate provider as aweETH is 1:1 with weETH so we can just use the weETH rate provider.

    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;

        bytes4 selector = bytes4(keccak256(abi.encodePacked("getValue(address,uint256,address)")));
        uint256 amount = 1e18;
        vm.startBroadcast(privateKey);

        creationCode = type(GenericRateProvider).creationCode;
        constructorArgs = abi.encode(
            liquidV1PriceRouter,
            selector,
            address(rETH_weETH).toBytes32(),
            bytes32(amount),
            address(WETH).toBytes32(),
            0,
            0,
            0,
            0,
            0
        );
        auraRETHWeETHBptRateProvider = GenericRateProvider(
            deployer.deployContract(AuraRETHWeETHBptRateProviderName, creationCode, constructorArgs, 0)
        );

        creationCode = type(GenericRateProvider).creationCode;
        constructorArgs = abi.encode(
            liquidV1PriceRouter,
            selector,
            address(WSTETH).toBytes32(),
            bytes32(amount),
            address(WETH).toBytes32(),
            0,
            0,
            0,
            0,
            0
        );
        wstethRateProvider =
            GenericRateProvider(deployer.deployContract(WstETHRateProviderName, creationCode, constructorArgs, 0));

        vm.stopBroadcast();
    }
}
