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
import {ContractNames} from "resources/ContractNames.sol";
import {GenericRateProvider} from "src/helper/GenericRateProvider.sol";
import {DelayedWithdraw} from "src/base/Roles/DelayedWithdraw.sol";

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
        string delayedWithdrawer;
    }

    ArchitectureNames public names;

    struct AccountantParameters {
        address payoutAddress;
        uint16 allowedExchangeRateChangeUpper;
        uint16 allowedExchangeRateChangeLower;
        uint24 minimumUpateDelayInSeconds;
        uint16 managementFee;
        uint16 performanceFee;
        uint96 startingExchangeRate;
        ERC20 base;
    }

    AccountantParameters public accountantParameters;

    struct DepositAsset {
        ERC20 asset;
        bool isPeggedToBase;
        address rateProvider;
        string genericRateProviderName;
        address target;
        bytes4 selector;
        bytes32[8] params;
    }

    DepositAsset[] public depositAssets;

    struct WithdrawAsset {
        ERC20 asset;
        uint32 withdrawDelay;
        uint32 completionWindow;
        uint16 withdrawFee;
        uint16 maxLoss;
    }

    WithdrawAsset[] public withdrawAssets;

    // Contracts to deploy
    Deployer public deployer = Deployer(deployerAddress);
    ArcticArchitectureLens public lens;
    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    RolesAuthority public rolesAuthority;
    address public rawDataDecoderAndSanitizer;
    TellerWithMultiAssetSupport public teller;
    AccountantWithRateProviders public accountant;
    DelayedWithdraw public delayedWithdrawer;

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

    string finalJson;
    string coreOutput;
    string depositAssetConfigurationOutput;
    string withdrawAssetConfigurationOutput;
    string accountantConfigurationOutput;
    string depositConfigurationOutput;

    function _getAddressIfDeployed(string memory name) internal view returns (address) {
        address deployedAt = deployer.getAddress(name);
        uint256 size;
        assembly {
            size := extcodesize(deployedAt)
        }
        return size > 0 ? deployedAt : address(0);
    }

    function _deploy(
        string memory deploymentFileName,
        address owner,
        string memory boringVaultName,
        string memory boringVaultSymbol,
        uint8 boringVaultDecimals,
        bytes memory decoderAndSanitizerCreationCode,
        bytes memory decoderAndSanitizerConstructorArgs,
        address delayedWithdrawFeeAddress,
        bool allowPublicDeposits,
        bool allowPublicWithdraws,
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
                accountantParameters.managementFee,
                accountantParameters.performanceFee
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

        deployedAddress = _getAddressIfDeployed(names.delayedWithdrawer);
        if (deployedAddress == address(0)) {
            creationCode = type(DelayedWithdraw).creationCode;
            constructorArgs = abi.encode(owner, address(boringVault), address(accountant), delayedWithdrawFeeAddress);
            delayedWithdrawer =
                DelayedWithdraw(deployer.deployContract(names.delayedWithdrawer, creationCode, constructorArgs, 0));
        } else {
            delayedWithdrawer = DelayedWithdraw(deployedAddress);
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
        rolesAuthority.setRoleCapability(OWNER_ROLE, address(delayedWithdrawer), Auth.setAuthority.selector, true);
        rolesAuthority.setRoleCapability(OWNER_ROLE, address(delayedWithdrawer), Auth.transferOwnership.selector, true);
        rolesAuthority.setRoleCapability(
            OWNER_ROLE, address(delayedWithdrawer), DelayedWithdraw.changeWithdrawFee.selector, true
        );
        rolesAuthority.setRoleCapability(
            OWNER_ROLE, address(delayedWithdrawer), DelayedWithdraw.setupWithdrawAsset.selector, true
        );
        rolesAuthority.setRoleCapability(
            OWNER_ROLE, address(delayedWithdrawer), DelayedWithdraw.changeMaxLoss.selector, true
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
        rolesAuthority.setRoleCapability(
            MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.pause.selector, true
        );
        rolesAuthority.setRoleCapability(
            MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.unpause.selector, true
        );
        rolesAuthority.setRoleCapability(
            MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.stopWithdrawalsInAsset.selector, true
        );
        rolesAuthority.setRoleCapability(
            MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.changeWithdrawDelay.selector, true
        );
        rolesAuthority.setRoleCapability(
            MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.changeCompletionWindow.selector, true
        );
        rolesAuthority.setRoleCapability(
            MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.cancelUserWithdraw.selector, true
        );
        rolesAuthority.setRoleCapability(
            MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.completeUserWithdraw.selector, true
        );

        // STRATEGIST_MULTISIG_ROLE
        rolesAuthority.setRoleCapability(
            STRATEGIST_MULTISIG_ROLE, address(teller), TellerWithMultiAssetSupport.refundDeposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            STRATEGIST_MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.completeUserWithdraw.selector, true
        );
        rolesAuthority.setRoleCapability(
            STRATEGIST_MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.cancelUserWithdraw.selector, true
        );
        rolesAuthority.setRoleCapability(
            STRATEGIST_MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.setFeeAddress.selector, true
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
        if (allowPublicWithdraws) {
            rolesAuthority.setPublicCapability(
                address(delayedWithdrawer), DelayedWithdraw.setAllowThirdPartyToComplete.selector, true
            );
            rolesAuthority.setPublicCapability(
                address(delayedWithdrawer), DelayedWithdraw.requestWithdraw.selector, true
            );
            rolesAuthority.setPublicCapability(
                address(delayedWithdrawer), DelayedWithdraw.cancelWithdraw.selector, true
            );
            rolesAuthority.setPublicCapability(
                address(delayedWithdrawer), DelayedWithdraw.completeWithdraw.selector, true
            );
        }

        // Setup deposit asset.
        teller.addAsset(accountantParameters.base);

        // Setup extra deposit assets.
        for (uint256 i; i < depositAssets.length; i++) {
            DepositAsset storage depositAsset = depositAssets[i];
            if (depositAsset.isPeggedToBase) {
                // Rate provider is not needed.
                accountant.setRateProviderData(depositAsset.asset, true, address(0));
                teller.addAsset(depositAsset.asset);
            } else if (depositAsset.rateProvider != address(0)) {
                // Rate provider is provided.
                accountant.setRateProviderData(depositAsset.asset, false, depositAsset.rateProvider);
                teller.addAsset(depositAsset.asset);
            } else {
                // We need a generic rate provider.
                creationCode = type(GenericRateProvider).creationCode;
                constructorArgs = abi.encode(depositAsset.target, depositAsset.selector, depositAsset.params);
                depositAsset.rateProvider =
                    deployer.deployContract(depositAsset.genericRateProviderName, creationCode, constructorArgs, 0);

                accountant.setRateProviderData(depositAsset.asset, false, depositAsset.rateProvider);
                teller.addAsset(depositAsset.asset);
            }
        }

        // Setup withdraw assets.
        for (uint256 i; i < withdrawAssets.length; i++) {
            WithdrawAsset memory withdrawAsset = withdrawAssets[i];
            delayedWithdrawer.setupWithdrawAsset(
                withdrawAsset.asset,
                withdrawAsset.withdrawDelay,
                withdrawAsset.completionWindow,
                withdrawAsset.withdrawFee,
                withdrawAsset.maxLoss
            );
        }

        // Setup share lock period.
        teller.setShareLockPeriod(shareLockPeriod);

        // Set all RolesAuthorities.
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);
        delayedWithdrawer.setAuthority(rolesAuthority);

        // Renounce ownership
        boringVault.transferOwnership(address(0));
        manager.transferOwnership(address(0));
        accountant.transferOwnership(address(0));
        teller.transferOwnership(address(0));
        delayedWithdrawer.transferOwnership(address(0));

        // Setup roles.
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(delayedWithdrawer), BURNER_ROLE, true);

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

        {
            string memory coreContracts = "core contracts key";
            vm.serializeAddress(coreContracts, "RolesAuthority", address(rolesAuthority));
            vm.serializeAddress(coreContracts, "Lens", address(lens));
            vm.serializeAddress(coreContracts, "BoringVault", address(boringVault));
            vm.serializeAddress(coreContracts, "ManagerWithMerkleVerification", address(manager));
            vm.serializeAddress(coreContracts, "AccountantWithRateProviders", address(accountant));
            vm.serializeAddress(coreContracts, "TellerWithMultiAssetSupport", address(teller));
            vm.serializeAddress(coreContracts, "DecoderAndSanitizer", rawDataDecoderAndSanitizer);
            coreOutput = vm.serializeAddress(coreContracts, "DelayedWithdraw", address(delayedWithdrawer));
        }

        {
            string memory depositAssetConfiguration = "deposit asset configuration key";
            // Add the base asset.
            string memory assetKey = "asset key 0";
            vm.serializeBool(assetKey, "isPeggedToBase", true);
            string memory assetOutput = vm.serializeAddress(assetKey, "rateProvider", address(0));
            depositAssetConfigurationOutput =
                vm.serializeString(depositAssetConfiguration, accountantParameters.base.symbol(), assetOutput);
            for (uint256 i; i < depositAssets.length; i++) {
                DepositAsset memory depositAsset = depositAssets[i];
                assetKey = "asset key";
                vm.serializeBool(assetKey, "isPeggedToBase", depositAsset.isPeggedToBase);
                assetOutput = vm.serializeAddress(assetKey, "rateProvider", depositAsset.rateProvider);
                depositAssetConfigurationOutput =
                    vm.serializeString(depositAssetConfiguration, depositAsset.asset.symbol(), assetOutput);
            }
        }

        {
            string memory withdrawAssetConfiguration = "withdraw asset configuration key";
            for (uint256 i; i < withdrawAssets.length; i++) {
                WithdrawAsset memory withdrawAsset = withdrawAssets[i];
                string memory assetKey = "asset key 1";
                vm.serializeUint(assetKey, "WithdrawDelay", withdrawAsset.withdrawDelay);
                vm.serializeUint(assetKey, "CompletionWindow", withdrawAsset.completionWindow);
                vm.serializeUint(assetKey, "WithdrawFee", withdrawAsset.withdrawFee);
                string memory assetOutput = vm.serializeUint(assetKey, "MaxLoss", withdrawAsset.maxLoss);
                withdrawAssetConfigurationOutput =
                    vm.serializeString(withdrawAssetConfiguration, withdrawAsset.asset.symbol(), assetOutput);
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
            vm.serializeBool(depositConfiguration, "AllowPublicWithdraws", allowPublicWithdraws);
            depositConfigurationOutput = vm.serializeUint(depositConfiguration, "ShareLockPeriod", shareLockPeriod);
        }

        vm.serializeString(finalJson, "depositConfiguration", depositConfigurationOutput);
        vm.serializeString(finalJson, "core", coreOutput);
        vm.serializeString(finalJson, "accountantConfiguration", accountantConfigurationOutput);
        vm.serializeString(finalJson, "WithdrawAssets", withdrawAssetConfigurationOutput);
        finalJson = vm.serializeString(finalJson, "DepositAssets", depositAssetConfigurationOutput);

        vm.writeJson(finalJson, filePath);
    }
}
