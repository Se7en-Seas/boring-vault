// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {GenericRateProvider} from "src/helper/GenericRateProvider.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployGenericRateProviders.s.sol:DeployGenericRateProvidersScript --with-gas-price 30000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployGenericRateProvidersScript is Script, ContractNames, MainnetAddresses {
    using AddressToBytes32Lib for address;

    uint256 public privateKey;

    // Contracts to deploy
    Deployer public deployer = Deployer(deployerAddress);
    AccountantWithRateProviders public accountant;
    TellerWithMultiAssetSupport public teller;
    RolesAuthority public rolesAuthority;
    GenericRateProvider public pendleWeETHMarketSeptemberRateProvider;
    GenericRateProvider public pendleEethPtSeptemberRateProvider;
    GenericRateProvider public pendleEethYtSeptemberRateProvider;
    GenericRateProvider public pendleWeETHMarketDecemberRateProvider;
    GenericRateProvider public pendleEethPtDecemberRateProvider;
    GenericRateProvider public pendleEethYtDecemberRateProvider;

    address public eBTCAccountant = 0x1b293DC39F94157fA0D1D36d7e0090C8B8B8c13F;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant MINTER_ROLE = 2;
    uint8 public constant BURNER_ROLE = 3;
    uint8 public constant MANAGER_INTERNAL_ROLE = 4;
    uint8 public constant SOLVER_ROLE = 12;
    uint8 public constant OWNER_ROLE = 8;
    uint8 public constant MULTISIG_ROLE = 9;
    uint8 public constant STRATEGIST_MULTISIG_ROLE = 10;
    uint8 public constant STRATEGIST_ROLE = 7;
    uint8 public constant UPDATE_EXCHANGE_RATE_ROLE = 11;

    // Dont need an aweETH rate provider as aweETH is 1:1 with weETH so we can just use the weETH rate provider.

    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;

        bytes4 selector = bytes4(keccak256(abi.encodePacked("getRateSafe()")));
        vm.startBroadcast(privateKey);

        creationCode = type(GenericRateProvider).creationCode;
        constructorArgs = abi.encode(eBTCAccountant, selector, 0, 0, 0, 0, 0, 0, 0, 0);
        deployer.deployContract("eBTC Rate Provider V0.0", creationCode, constructorArgs, 0);

        vm.stopBroadcast();
    }
}
