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
 *  source .env && forge script script/DeployGenericRateProviders.s.sol:DeployGenericRateProvidersScript --with-gas-price 30000000000 --slow --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
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

        rolesAuthority = RolesAuthority(deployer.getAddress(EtherFiLiquidEthRolesAuthorityName));
        accountant = AccountantWithRateProviders(deployer.getAddress(EtherFiLiquidEthAccountantName));
        teller = TellerWithMultiAssetSupport(deployer.getAddress(EtherFiLiquidEthTellerName));
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;

        bytes4 selector = bytes4(keccak256(abi.encodePacked("getValue(address,uint256,address)")));
        uint256 amount = 1e18;
        vm.startBroadcast(privateKey);

        rolesAuthority.setUserRole(dev0Address, OWNER_ROLE, true);

        creationCode = type(GenericRateProvider).creationCode;
        constructorArgs = abi.encode(
            liquidV1PriceRouter,
            selector,
            pendleWeETHMarketSeptember.toBytes32(),
            bytes32(amount),
            address(WETH).toBytes32(),
            0,
            0,
            0,
            0,
            0
        );
        pendleWeETHMarketSeptemberRateProvider = GenericRateProvider(
            deployer.deployContract(PendleWeETHMarketSeptemberRateProviderName, creationCode, constructorArgs, 0)
        );

        creationCode = type(GenericRateProvider).creationCode;
        constructorArgs = abi.encode(
            liquidV1PriceRouter,
            selector,
            pendleEethPtSeptember.toBytes32(),
            bytes32(amount),
            address(WETH).toBytes32(),
            0,
            0,
            0,
            0,
            0
        );
        pendleEethPtSeptemberRateProvider = GenericRateProvider(
            deployer.deployContract(PendleEethPtSeptemberRateProviderName, creationCode, constructorArgs, 0)
        );

        creationCode = type(GenericRateProvider).creationCode;
        constructorArgs = abi.encode(
            liquidV1PriceRouter,
            selector,
            pendleEethYtSeptember.toBytes32(),
            bytes32(amount),
            address(WETH).toBytes32(),
            0,
            0,
            0,
            0,
            0
        );
        pendleEethYtSeptemberRateProvider = GenericRateProvider(
            deployer.deployContract(PendleEethYtSeptemberRateProviderName, creationCode, constructorArgs, 0)
        );

        creationCode = type(GenericRateProvider).creationCode;
        constructorArgs = abi.encode(
            liquidV1PriceRouter,
            selector,
            pendleWeETHMarketDecember.toBytes32(),
            bytes32(amount),
            address(WETH).toBytes32(),
            0,
            0,
            0,
            0,
            0
        );
        pendleWeETHMarketDecemberRateProvider = GenericRateProvider(
            deployer.deployContract(PendleWeETHMarketDecemberRateProviderName, creationCode, constructorArgs, 0)
        );

        creationCode = type(GenericRateProvider).creationCode;
        constructorArgs = abi.encode(
            liquidV1PriceRouter,
            selector,
            pendleEethPtDecember.toBytes32(),
            bytes32(amount),
            address(WETH).toBytes32(),
            0,
            0,
            0,
            0,
            0
        );
        pendleEethPtDecemberRateProvider = GenericRateProvider(
            deployer.deployContract(PendleEethPtDecemberRateProviderName, creationCode, constructorArgs, 0)
        );

        creationCode = type(GenericRateProvider).creationCode;
        constructorArgs = abi.encode(
            liquidV1PriceRouter,
            selector,
            pendleEethYtDecember.toBytes32(),
            bytes32(amount),
            address(WETH).toBytes32(),
            0,
            0,
            0,
            0,
            0
        );
        pendleEethYtDecemberRateProvider = GenericRateProvider(
            deployer.deployContract(PendleEethYtDecemberRateProviderName, creationCode, constructorArgs, 0)
        );

        accountant.setRateProviderData(
            ERC20(pendleWeETHMarketSeptember), false, address(pendleWeETHMarketSeptemberRateProvider)
        );
        accountant.setRateProviderData(ERC20(pendleEethPtSeptember), false, address(pendleEethPtSeptemberRateProvider));
        accountant.setRateProviderData(ERC20(pendleEethYtSeptember), false, address(pendleEethYtSeptemberRateProvider));
        accountant.setRateProviderData(
            ERC20(pendleWeETHMarketDecember), false, address(pendleWeETHMarketDecemberRateProvider)
        );
        accountant.setRateProviderData(ERC20(pendleEethPtDecember), false, address(pendleEethPtDecemberRateProvider));
        accountant.setRateProviderData(ERC20(pendleEethYtDecember), false, address(pendleEethYtDecemberRateProvider));

        // teller.addAsset(ERC20(pendleWeETHMarketSeptember));
        // teller.addAsset(ERC20(pendleEethPtSeptember));
        // teller.addAsset(ERC20(pendleEethYtSeptember));
        // teller.addAsset(ERC20(pendleWeETHMarketDecember));
        // teller.addAsset(ERC20(pendleEethPtDecember));
        // teller.addAsset(ERC20(pendleEethYtDecember));

        rolesAuthority.setUserRole(dev0Address, OWNER_ROLE, false);

        rolesAuthority.transferOwnership(dev1Address);

        vm.stopBroadcast();
    }
}
