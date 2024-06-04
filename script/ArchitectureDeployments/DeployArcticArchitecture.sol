// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault, Auth} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {EtherFiLiquidEthDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidEthDecoderAndSanitizer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {ArcticArchitectureLens} from "src/helper/ArcticArchitectureLens.sol";
import {AtomicQueue} from "src/atomic-queue/AtomicQueue.sol";
import {AtomicSolverV2} from "src/atomic-queue/AtomicSolverV2.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {EtherFiLiquid1} from "src/interfaces/EtherFiLiquid1.sol";
import {GenericRateProvider} from "src/helper/GenericRateProvider.sol";
import {CellarMigrationAdaptor} from "src/migration/CellarMigrationAdaptor.sol";
import {CellarMigrationAdaptor2} from "src/migration/CellarMigrationAdaptor2.sol";
import {ParitySharePriceOracle} from "src/migration/ParitySharePriceOracle.sol";
import {CellarMigratorWithSharePriceParity, ERC4626} from "src/migration/CellarMigratorWithSharePriceParity.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployBoringVaultArctic.s.sol:DeployBoringVaultArcticScript --with-gas-price 30000000000 --slow --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployArcticArchitecture is Script, ContractNames, MainnetAddresses {
    struct ArchitectureNames {
        string rolesAuthority;
        string lens;
        string boringVault;
        string manager;
        string accountant;
        string teller;
        string rawDataDecoderAndSanitizer;
    }

    ArchitectureNames public names;

    struct AccountantParameters {
        address payoutAddress;
        uint16 allowedExchangeRateChangeUpper;
        uint16 allowedExchangeRateChangeLower;
        uint32 minimumUpateDelayInSeconds; // TODO once merged this will need to have its type changed to uint24.
        uint16 managementFee; // TODO performance fee
        uint96 startingExchangeRate;
        ERC20 base;
    }

    AccountantParameters public accountantParameters;

    struct AlternativeAsset {
        ERC20 asset;
        bool isPeggedToBase;
        address rateProvider;
        string genericRateProviderName;
        address target;
        bytes4 selector;
        bytes32[8] params;
    }

    AlternativeAsset[] public alternativeAssets;

    // Contracts to deploy
    Deployer public deployer = Deployer(deployerAddress);
    ArcticArchitectureLens public lens;
    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    RolesAuthority public rolesAuthority;
    address public rawDataDecoderAndSanitizer;
    TellerWithMultiAssetSupport public teller;
    AccountantWithRateProviders public accountant;
    AtomicQueue public atomicQueue;
    AtomicSolverV2 public atomicSolver;

    // Roles
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

    function _getAddressIfDeployed(string memory name) internal view returns (address) {
        address deployedAt = deployer.getAddress(name);
        uint256 size;
        assembly {
            size := extcodesize(deployedAt)
        }
        return size > 0 ? deployedAt : address(0);
    }

    // TODO this should save all the addresses in a JSON file, using the name provided.
    function _deploy(
        string memory deploymentFileName,
        address owner,
        string memory boringVaultName,
        string memory boringVaultSymbol,
        uint8 boringVaultDecimals,
        bytes memory decoderAndSanitizerCreationCode,
        bytes memory decoderAndSanitizerConstructorArgs,
        bool allowPublicDeposits,
        uint64 shareLockPeriod,
        address developmentAddress
    ) internal {
        bytes memory creationCode;
        bytes memory constructorArgs;
        address deployedAddress;

        deployedAddress = _getAddressIfDeployed(names.rolesAuthority);
        if (deployedAddress == address(0)) {
            creationCode = type(RolesAuthority).creationCode;
            constructorArgs = abi.encode(owner, Authority(address(0)));
            rolesAuthority =
                RolesAuthority(deployer.deployContract(names.rolesAuthority, creationCode, constructorArgs, 0));
        } else {
            rolesAuthority = RolesAuthority(deployedAddress);
        }

        deployedAddress = _getAddressIfDeployed(names.lens);
        if (deployedAddress == address(0)) {
            creationCode = type(ArcticArchitectureLens).creationCode;
            lens = ArcticArchitectureLens(deployer.deployContract(names.lens, creationCode, hex"", 0));
        } else {
            lens = ArcticArchitectureLens(deployedAddress);
        }

        deployedAddress = _getAddressIfDeployed(names.boringVault);
        if (deployedAddress == address(0)) {
            creationCode = type(BoringVault).creationCode;
            constructorArgs = abi.encode(owner, boringVaultName, boringVaultSymbol, boringVaultDecimals);
            boringVault =
                BoringVault(payable(deployer.deployContract(names.boringVault, creationCode, constructorArgs, 0)));
        } else {
            boringVault = BoringVault(payable(deployedAddress));
        }

        deployedAddress = _getAddressIfDeployed(names.manager);
        if (deployedAddress == address(0)) {
            creationCode = type(ManagerWithMerkleVerification).creationCode;
            constructorArgs = abi.encode(owner, address(boringVault), balancerVault);
            manager =
                ManagerWithMerkleVerification(deployer.deployContract(names.manager, creationCode, constructorArgs, 0));
        } else {
            manager = ManagerWithMerkleVerification(deployedAddress);
        }

        deployedAddress = _getAddressIfDeployed(names.accountant);
        if (deployedAddress == address(0)) {
            creationCode = type(AccountantWithRateProviders).creationCode;
            constructorArgs = abi.encode(
                owner,
                address(boringVault),
                accountantParameters.payoutAddress,
                accountantParameters.startingExchangeRate,
                accountantParameters.base,
                accountantParameters.allowedExchangeRateChangeUpper,
                accountantParameters.allowedExchangeRateChangeLower,
                accountantParameters.minimumUpateDelayInSeconds,
                accountantParameters.managementFee
            );
            accountant =
                AccountantWithRateProviders(deployer.deployContract(names.accountant, creationCode, constructorArgs, 0));
        } else {
            accountant = AccountantWithRateProviders(deployedAddress);
        }

        deployedAddress = _getAddressIfDeployed(names.teller);
        if (deployedAddress == address(0)) {
            creationCode = type(TellerWithMultiAssetSupport).creationCode;
            constructorArgs = abi.encode(owner, address(boringVault), address(accountant), WETH);
            teller = TellerWithMultiAssetSupport(
                payable(deployer.deployContract(names.teller, creationCode, constructorArgs, 0))
            );
        } else {
            teller = TellerWithMultiAssetSupport(payable(deployedAddress));
        }

        deployedAddress = _getAddressIfDeployed(names.rawDataDecoderAndSanitizer);
        if (deployedAddress == address(0)) {
            rawDataDecoderAndSanitizer = deployer.deployContract(
                names.rawDataDecoderAndSanitizer, decoderAndSanitizerCreationCode, decoderAndSanitizerConstructorArgs, 0
            );
        } else {
            rawDataDecoderAndSanitizer = deployedAddress;
        }

        // Setup roles.
        // MANAGER_ROLE
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE, address(boringVault), bytes4(abi.encodeWithSignature("manage(address,bytes,uint256)")), true
        );
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(abi.encodeWithSignature("manage(address[],bytes[],uint256[])")),
            true
        );
        // MINTER_ROLE
        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
        // BURNER_ROLE
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);
        // MANAGER_INTERNAL_ROLE
        rolesAuthority.setRoleCapability(
            MANAGER_INTERNAL_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        // SOLVER_ROLE
        rolesAuthority.setRoleCapability(
            SOLVER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkDeposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            SOLVER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
        );
        // OWNER_ROLE
        rolesAuthority.setRoleCapability(OWNER_ROLE, address(boringVault), Auth.setAuthority.selector, true);
        rolesAuthority.setRoleCapability(OWNER_ROLE, address(boringVault), Auth.transferOwnership.selector, true);
        rolesAuthority.setRoleCapability(
            OWNER_ROLE, address(boringVault), BoringVault.setBeforeTransferHook.selector, true
        );
        rolesAuthority.setRoleCapability(OWNER_ROLE, address(accountant), Auth.setAuthority.selector, true);
        rolesAuthority.setRoleCapability(OWNER_ROLE, address(accountant), Auth.transferOwnership.selector, true);
        rolesAuthority.setRoleCapability(
            OWNER_ROLE, address(accountant), AccountantWithRateProviders.updateDelay.selector, true
        );
        rolesAuthority.setRoleCapability(
            OWNER_ROLE, address(accountant), AccountantWithRateProviders.updateUpper.selector, true
        );
        rolesAuthority.setRoleCapability(
            OWNER_ROLE, address(accountant), AccountantWithRateProviders.updateLower.selector, true
        );
        rolesAuthority.setRoleCapability(
            OWNER_ROLE, address(accountant), AccountantWithRateProviders.updateManagementFee.selector, true
        );
        rolesAuthority.setRoleCapability(
            OWNER_ROLE, address(accountant), AccountantWithRateProviders.updatePayoutAddress.selector, true
        );
        rolesAuthority.setRoleCapability(
            OWNER_ROLE, address(accountant), AccountantWithRateProviders.setRateProviderData.selector, true
        );
        rolesAuthority.setRoleCapability(OWNER_ROLE, address(manager), Auth.setAuthority.selector, true);
        rolesAuthority.setRoleCapability(OWNER_ROLE, address(manager), Auth.transferOwnership.selector, true);
        rolesAuthority.setRoleCapability(
            OWNER_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector, true
        );
        rolesAuthority.setRoleCapability(OWNER_ROLE, address(teller), Auth.setAuthority.selector, true);
        rolesAuthority.setRoleCapability(OWNER_ROLE, address(teller), Auth.transferOwnership.selector, true);
        rolesAuthority.setRoleCapability(
            OWNER_ROLE, address(teller), TellerWithMultiAssetSupport.addAsset.selector, true
        );
        rolesAuthority.setRoleCapability(
            OWNER_ROLE, address(teller), TellerWithMultiAssetSupport.removeAsset.selector, true
        );
        rolesAuthority.setRoleCapability(
            OWNER_ROLE, address(teller), TellerWithMultiAssetSupport.setShareLockPeriod.selector, true
        );
        // MULTISIG_ROLE
        rolesAuthority.setRoleCapability(
            MULTISIG_ROLE, address(accountant), AccountantWithRateProviders.pause.selector, true
        );
        rolesAuthority.setRoleCapability(
            MULTISIG_ROLE, address(accountant), AccountantWithRateProviders.unpause.selector, true
        );
        rolesAuthority.setRoleCapability(
            MULTISIG_ROLE, address(teller), TellerWithMultiAssetSupport.pause.selector, true
        );
        rolesAuthority.setRoleCapability(
            MULTISIG_ROLE, address(teller), TellerWithMultiAssetSupport.unpause.selector, true
        );
        rolesAuthority.setRoleCapability(
            MULTISIG_ROLE, address(manager), ManagerWithMerkleVerification.pause.selector, true
        );
        rolesAuthority.setRoleCapability(
            MULTISIG_ROLE, address(manager), ManagerWithMerkleVerification.unpause.selector, true
        );
        // STRATEGIST_MULTISIG_ROLE
        rolesAuthority.setRoleCapability(
            STRATEGIST_MULTISIG_ROLE, address(teller), TellerWithMultiAssetSupport.refundDeposit.selector, true
        );
        // STRATEGIST_ROLE
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        // UPDATE_EXCHANGE_RATE_ROLE
        rolesAuthority.setRoleCapability(
            UPDATE_EXCHANGE_RATE_ROLE,
            address(accountant),
            AccountantWithRateProviders.updateExchangeRate.selector,
            true
        );

        // Publicly callable functions
        if (allowPublicDeposits) {
            rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);
            rolesAuthority.setPublicCapability(
                address(teller), TellerWithMultiAssetSupport.depositWithPermit.selector, true
            );
        }

        // Give roles to appropriate contracts
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);
        rolesAuthority.setUserRole(deployer.getAddress(AtomicSolverName), SOLVER_ROLE, true);

        // Setup alternative assets.
        for (uint256 i; i < alternativeAssets.length; i++) {
            AlternativeAsset storage alternativeAsset = alternativeAssets[i];
            if (alternativeAsset.isPeggedToBase) {
                // Rate provider is not needed.
                accountant.setRateProviderData(alternativeAsset.asset, true, address(0));
                teller.addAsset(alternativeAsset.asset);
            } else if (alternativeAsset.rateProvider != address(0)) {
                // Rate provider is provided.
                accountant.setRateProviderData(alternativeAsset.asset, false, alternativeAsset.rateProvider);
                teller.addAsset(alternativeAsset.asset);
            } else {
                // We need a generic rate provider.
                creationCode = type(GenericRateProvider).creationCode;
                constructorArgs =
                    abi.encode(alternativeAsset.target, alternativeAsset.selector, alternativeAsset.params);
                alternativeAsset.rateProvider =
                    deployer.deployContract(alternativeAsset.genericRateProviderName, creationCode, constructorArgs, 0);

                accountant.setRateProviderData(alternativeAsset.asset, false, alternativeAsset.rateProvider);
                teller.addAsset(alternativeAsset.asset);
            }
        }

        // Setup share lock period.
        teller.setShareLockPeriod(shareLockPeriod);

        // Set all RolesAuthorities.
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);

        // Renounce ownership
        boringVault.transferOwnership(address(0));
        manager.transferOwnership(address(0));
        accountant.transferOwnership(address(0));
        teller.transferOwnership(address(0));

        // Setup roles.
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);

        // Give development address straetgist and owner roles, and transfer ownership if needed.
        rolesAuthority.setUserRole(developmentAddress, STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(developmentAddress, OWNER_ROLE, true);
        if (owner != developmentAddress) rolesAuthority.transferOwnership(developmentAddress);

        // Save deployment details.
        string memory filePath = string.concat("./deployments/", deploymentFileName);

        if (vm.exists(filePath)) {
            // Need to delete it
            vm.removeFile(filePath);
        }
        string memory finalJson;
        string memory coreOutput;
        string memory assetConfigurationOutput;
        string memory accountantConfigurationOutput;
        string memory depositConfigurationOutput;
        {
            string memory coreContracts = "core contracts key";
            vm.serializeAddress(coreContracts, "RolesAuthority", address(rolesAuthority));
            vm.serializeAddress(coreContracts, "Lens", address(lens));
            vm.serializeAddress(coreContracts, "BoringVault", address(boringVault));
            vm.serializeAddress(coreContracts, "ManagerWithMerkleVerification", address(manager));
            vm.serializeAddress(coreContracts, "AccountantWithRateProviders", address(accountant));
            vm.serializeAddress(coreContracts, "TellerWithMultiAssetSupport", address(teller));
            coreOutput = vm.serializeAddress(coreContracts, "DecoderAndSanitizer", rawDataDecoderAndSanitizer);
        }

        {
            string memory assetConfiguration = "asset configuration key";
            for (uint256 i; i < alternativeAssets.length; i++) {
                AlternativeAsset memory alternativeAsset = alternativeAssets[i];
                string memory assetKey = "asset key";
                vm.serializeBool(assetKey, "depositable", true);
                vm.serializeBool(assetKey, "withdrawable", true);
                vm.serializeBool(assetKey, "isPeggedToBase", alternativeAsset.isPeggedToBase);
                string memory assetOutput = vm.serializeAddress(assetKey, "rateProvider", alternativeAsset.rateProvider);
                assetConfigurationOutput =
                    vm.serializeString(assetConfiguration, alternativeAsset.asset.symbol(), assetOutput);
            }
        }

        {
            string memory accountantConfiguration = "accountant key";
            vm.serializeAddress(accountantConfiguration, "PayoutAddress", accountantParameters.payoutAddress);
            vm.serializeUint(
                accountantConfiguration,
                "AllowedExchangeRateChangeUpper",
                accountantParameters.allowedExchangeRateChangeUpper
            );
            vm.serializeUint(
                accountantConfiguration,
                "AllowedExchangeRateChangeLower",
                accountantParameters.allowedExchangeRateChangeLower
            );
            vm.serializeUint(
                accountantConfiguration, "MinimumUpateDelayInSeconds", accountantParameters.minimumUpateDelayInSeconds
            );
            vm.serializeUint(accountantConfiguration, "ManagementFee", accountantParameters.managementFee);
            vm.serializeUint(accountantConfiguration, "StartingExchangeRate", accountantParameters.startingExchangeRate);
            accountantConfigurationOutput =
                vm.serializeAddress(accountantConfiguration, "Base", address(accountantParameters.base));
        }

        {
            string memory depositConfiguration = "deposit configuration key";
            vm.serializeBool(depositConfiguration, "AllowPublicDeposits", allowPublicDeposits);
            depositConfigurationOutput = vm.serializeUint(depositConfiguration, "ShareLockPeriod", shareLockPeriod);
        }

        vm.serializeString(finalJson, "depositConfiguration", depositConfigurationOutput);
        vm.serializeString(finalJson, "core", coreOutput);
        vm.serializeString(finalJson, "accountantConfiguration", accountantConfigurationOutput);
        finalJson = vm.serializeString(finalJson, "assetConfiguration", assetConfigurationOutput);

        vm.writeJson(finalJson, filePath);
    }
}
