// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

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
import {AccountantWithRateProviders, IRateProvider} from "src/base/Roles/AccountantWithRateProviders.sol";
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
contract DeployArcticArchitecture is Script, ContractNames {
    struct ConfigureDeployment {
        bool deployContracts;
        bool setupRoles;
        bool setupDepositAssets;
        bool setupWithdrawAssets;
        bool finishSetup;
        bool setupTestUser;
        bool saveDeploymentDetails;
        address deployerAddress;
        address balancerVault;
        address WETH;
    }

    ConfigureDeployment public configureDeployment;

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
    Deployer public deployer;
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
        if (configureDeployment.deployContracts) {
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
                constructorArgs = abi.encode(owner, address(boringVault), configureDeployment.balancerVault);
                manager = ManagerWithMerkleVerification(
                    deployer.deployContract(names.manager, creationCode, constructorArgs, 0)
                );
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
                accountant = AccountantWithRateProviders(
                    deployer.deployContract(names.accountant, creationCode, constructorArgs, 0)
                );
            } else {
                accountant = AccountantWithRateProviders(deployedAddress);
            }

            deployedAddress = _getAddressIfDeployed(names.teller);
            if (deployedAddress == address(0)) {
                creationCode = type(TellerWithMultiAssetSupport).creationCode;
                constructorArgs = abi.encode(owner, address(boringVault), address(accountant), configureDeployment.WETH);
                teller = TellerWithMultiAssetSupport(
                    payable(deployer.deployContract(names.teller, creationCode, constructorArgs, 0))
                );
            } else {
                teller = TellerWithMultiAssetSupport(payable(deployedAddress));
            }

            deployedAddress = _getAddressIfDeployed(names.rawDataDecoderAndSanitizer);
            if (deployedAddress == address(0)) {
                rawDataDecoderAndSanitizer = deployer.deployContract(
                    names.rawDataDecoderAndSanitizer,
                    decoderAndSanitizerCreationCode,
                    decoderAndSanitizerConstructorArgs,
                    0
                );
            } else {
                rawDataDecoderAndSanitizer = deployedAddress;
            }

            deployedAddress = _getAddressIfDeployed(names.delayedWithdrawer);
            if (deployedAddress == address(0)) {
                creationCode = type(DelayedWithdraw).creationCode;
                constructorArgs =
                    abi.encode(owner, address(boringVault), address(accountant), delayedWithdrawFeeAddress);
                delayedWithdrawer =
                    DelayedWithdraw(deployer.deployContract(names.delayedWithdrawer, creationCode, constructorArgs, 0));
            } else {
                delayedWithdrawer = DelayedWithdraw(deployedAddress);
            }
        } else {
            rolesAuthority = RolesAuthority(_getAddressIfDeployed(names.rolesAuthority));
            lens = ArcticArchitectureLens(_getAddressIfDeployed(names.lens));
            boringVault = BoringVault(payable(_getAddressIfDeployed(names.boringVault)));
            manager = ManagerWithMerkleVerification(_getAddressIfDeployed(names.manager));
            accountant = AccountantWithRateProviders(_getAddressIfDeployed(names.accountant));
            teller = TellerWithMultiAssetSupport(payable(_getAddressIfDeployed(names.teller)));
            rawDataDecoderAndSanitizer = _getAddressIfDeployed(names.rawDataDecoderAndSanitizer);
            delayedWithdrawer = DelayedWithdraw(_getAddressIfDeployed(names.delayedWithdrawer));
        }

        if (configureDeployment.setupRoles) {
            // Setup roles.
            // MANAGER_ROLE
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    MANAGER_ROLE, address(boringVault), bytes4(abi.encodeWithSignature("manage(address,bytes,uint256)"))
                )
            ) {
                rolesAuthority.setRoleCapability(
                    MANAGER_ROLE,
                    address(boringVault),
                    bytes4(abi.encodeWithSignature("manage(address,bytes,uint256)")),
                    true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    MANAGER_ROLE,
                    address(boringVault),
                    bytes4(abi.encodeWithSignature("manage(address[],bytes[],uint256[])"))
                )
            ) {
                rolesAuthority.setRoleCapability(
                    MANAGER_ROLE,
                    address(boringVault),
                    bytes4(abi.encodeWithSignature("manage(address[],bytes[],uint256[])")),
                    true
                );
            }
            // MINTER_ROLE
            if (!rolesAuthority.doesRoleHaveCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector)) {
                rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
            }
            // BURNER_ROLE
            if (!rolesAuthority.doesRoleHaveCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector)) {
                rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);
            }
            // MANAGER_INTERNAL_ROLE
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    MANAGER_INTERNAL_ROLE,
                    address(manager),
                    ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    MANAGER_INTERNAL_ROLE,
                    address(manager),
                    ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
                    true
                );
            }
            // SOLVER_ROLE
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    SOLVER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkDeposit.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    SOLVER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkDeposit.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    SOLVER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    SOLVER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
                );
            }
            // OWNER_ROLE
            if (!rolesAuthority.doesRoleHaveCapability(OWNER_ROLE, address(boringVault), Auth.setAuthority.selector)) {
                rolesAuthority.setRoleCapability(OWNER_ROLE, address(boringVault), Auth.setAuthority.selector, true);
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(OWNER_ROLE, address(boringVault), Auth.transferOwnership.selector)
            ) {
                rolesAuthority.setRoleCapability(
                    OWNER_ROLE, address(boringVault), Auth.transferOwnership.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    OWNER_ROLE, address(boringVault), BoringVault.setBeforeTransferHook.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    OWNER_ROLE, address(boringVault), BoringVault.setBeforeTransferHook.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    OWNER_ROLE, address(accountant), AccountantWithRateProviders.resetHighwaterMark.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    OWNER_ROLE, address(accountant), AccountantWithRateProviders.resetHighwaterMark.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    OWNER_ROLE, address(accountant), AccountantWithRateProviders.updatePerformanceFee.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    OWNER_ROLE, address(accountant), AccountantWithRateProviders.updatePerformanceFee.selector, true
                );
            }
            if (!rolesAuthority.doesRoleHaveCapability(OWNER_ROLE, address(accountant), Auth.setAuthority.selector)) {
                rolesAuthority.setRoleCapability(OWNER_ROLE, address(accountant), Auth.setAuthority.selector, true);
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(OWNER_ROLE, address(accountant), Auth.transferOwnership.selector)
            ) {
                rolesAuthority.setRoleCapability(OWNER_ROLE, address(accountant), Auth.transferOwnership.selector, true);
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    OWNER_ROLE, address(accountant), AccountantWithRateProviders.updateDelay.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    OWNER_ROLE, address(accountant), AccountantWithRateProviders.updateDelay.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    OWNER_ROLE, address(accountant), AccountantWithRateProviders.updateUpper.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    OWNER_ROLE, address(accountant), AccountantWithRateProviders.updateUpper.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    OWNER_ROLE, address(accountant), AccountantWithRateProviders.updateLower.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    OWNER_ROLE, address(accountant), AccountantWithRateProviders.updateLower.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    OWNER_ROLE, address(accountant), AccountantWithRateProviders.updateManagementFee.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    OWNER_ROLE, address(accountant), AccountantWithRateProviders.updateManagementFee.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    OWNER_ROLE, address(accountant), AccountantWithRateProviders.updatePayoutAddress.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    OWNER_ROLE, address(accountant), AccountantWithRateProviders.updatePayoutAddress.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    OWNER_ROLE, address(accountant), AccountantWithRateProviders.setRateProviderData.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    OWNER_ROLE, address(accountant), AccountantWithRateProviders.setRateProviderData.selector, true
                );
            }
            if (!rolesAuthority.doesRoleHaveCapability(OWNER_ROLE, address(manager), Auth.setAuthority.selector)) {
                rolesAuthority.setRoleCapability(OWNER_ROLE, address(manager), Auth.setAuthority.selector, true);
            }
            if (!rolesAuthority.doesRoleHaveCapability(OWNER_ROLE, address(manager), Auth.transferOwnership.selector)) {
                rolesAuthority.setRoleCapability(OWNER_ROLE, address(manager), Auth.transferOwnership.selector, true);
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    OWNER_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    OWNER_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector, true
                );
            }
            if (!rolesAuthority.doesRoleHaveCapability(OWNER_ROLE, address(teller), Auth.setAuthority.selector)) {
                rolesAuthority.setRoleCapability(OWNER_ROLE, address(teller), Auth.setAuthority.selector, true);
            }
            if (!rolesAuthority.doesRoleHaveCapability(OWNER_ROLE, address(teller), Auth.transferOwnership.selector)) {
                rolesAuthority.setRoleCapability(OWNER_ROLE, address(teller), Auth.transferOwnership.selector, true);
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    OWNER_ROLE, address(teller), TellerWithMultiAssetSupport.addAsset.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    OWNER_ROLE, address(teller), TellerWithMultiAssetSupport.addAsset.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    OWNER_ROLE, address(teller), TellerWithMultiAssetSupport.removeAsset.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    OWNER_ROLE, address(teller), TellerWithMultiAssetSupport.removeAsset.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    OWNER_ROLE, address(teller), TellerWithMultiAssetSupport.setShareLockPeriod.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    OWNER_ROLE, address(teller), TellerWithMultiAssetSupport.setShareLockPeriod.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    OWNER_ROLE, address(delayedWithdrawer), Auth.setAuthority.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    OWNER_ROLE, address(delayedWithdrawer), Auth.setAuthority.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    OWNER_ROLE, address(delayedWithdrawer), Auth.transferOwnership.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    OWNER_ROLE, address(delayedWithdrawer), Auth.transferOwnership.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    OWNER_ROLE, address(delayedWithdrawer), DelayedWithdraw.changeWithdrawFee.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    OWNER_ROLE, address(delayedWithdrawer), DelayedWithdraw.changeWithdrawFee.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    OWNER_ROLE, address(delayedWithdrawer), DelayedWithdraw.setupWithdrawAsset.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    OWNER_ROLE, address(delayedWithdrawer), DelayedWithdraw.setupWithdrawAsset.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    OWNER_ROLE, address(delayedWithdrawer), DelayedWithdraw.changeMaxLoss.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    OWNER_ROLE, address(delayedWithdrawer), DelayedWithdraw.changeMaxLoss.selector, true
                );
            }
            // MULTISIG_ROLE
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    MULTISIG_ROLE, address(accountant), AccountantWithRateProviders.pause.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    MULTISIG_ROLE, address(accountant), AccountantWithRateProviders.pause.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    MULTISIG_ROLE, address(accountant), AccountantWithRateProviders.unpause.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    MULTISIG_ROLE, address(accountant), AccountantWithRateProviders.unpause.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    MULTISIG_ROLE, address(teller), TellerWithMultiAssetSupport.pause.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    MULTISIG_ROLE, address(teller), TellerWithMultiAssetSupport.pause.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    MULTISIG_ROLE, address(teller), TellerWithMultiAssetSupport.unpause.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    MULTISIG_ROLE, address(teller), TellerWithMultiAssetSupport.unpause.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    MULTISIG_ROLE, address(manager), ManagerWithMerkleVerification.pause.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    MULTISIG_ROLE, address(manager), ManagerWithMerkleVerification.pause.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    MULTISIG_ROLE, address(manager), ManagerWithMerkleVerification.unpause.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    MULTISIG_ROLE, address(manager), ManagerWithMerkleVerification.unpause.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.pause.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.pause.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.unpause.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.unpause.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.stopWithdrawalsInAsset.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.stopWithdrawalsInAsset.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.changeWithdrawDelay.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.changeWithdrawDelay.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.changeCompletionWindow.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.changeCompletionWindow.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.cancelUserWithdraw.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.cancelUserWithdraw.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.completeUserWithdraw.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.completeUserWithdraw.selector, true
                );
            }

            // STRATEGIST_MULTISIG_ROLE
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    STRATEGIST_MULTISIG_ROLE, address(teller), TellerWithMultiAssetSupport.refundDeposit.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    STRATEGIST_MULTISIG_ROLE, address(teller), TellerWithMultiAssetSupport.refundDeposit.selector, true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    STRATEGIST_MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.completeUserWithdraw.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    STRATEGIST_MULTISIG_ROLE,
                    address(delayedWithdrawer),
                    DelayedWithdraw.completeUserWithdraw.selector,
                    true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    STRATEGIST_MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.cancelUserWithdraw.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    STRATEGIST_MULTISIG_ROLE,
                    address(delayedWithdrawer),
                    DelayedWithdraw.cancelUserWithdraw.selector,
                    true
                );
            }
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    STRATEGIST_MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.setFeeAddress.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    STRATEGIST_MULTISIG_ROLE, address(delayedWithdrawer), DelayedWithdraw.setFeeAddress.selector, true
                );
            }
            // STRATEGIST_ROLE
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    STRATEGIST_ROLE,
                    address(manager),
                    ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    STRATEGIST_ROLE,
                    address(manager),
                    ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
                    true
                );
            }
            // UPDATE_EXCHANGE_RATE_ROLE
            if (
                !rolesAuthority.doesRoleHaveCapability(
                    UPDATE_EXCHANGE_RATE_ROLE,
                    address(accountant),
                    AccountantWithRateProviders.updateExchangeRate.selector
                )
            ) {
                rolesAuthority.setRoleCapability(
                    UPDATE_EXCHANGE_RATE_ROLE,
                    address(accountant),
                    AccountantWithRateProviders.updateExchangeRate.selector,
                    true
                );
            }

            // Publicly callable functions
            if (allowPublicDeposits) {
                if (!rolesAuthority.isCapabilityPublic(address(teller), TellerWithMultiAssetSupport.deposit.selector)) {
                    rolesAuthority.setPublicCapability(
                        address(teller), TellerWithMultiAssetSupport.deposit.selector, true
                    );
                }
                if (
                    !rolesAuthority.isCapabilityPublic(
                        address(teller), TellerWithMultiAssetSupport.depositWithPermit.selector
                    )
                ) {
                    rolesAuthority.setPublicCapability(
                        address(teller), TellerWithMultiAssetSupport.depositWithPermit.selector, true
                    );
                }
            }
            if (allowPublicWithdraws) {
                if (
                    !rolesAuthority.isCapabilityPublic(
                        address(delayedWithdrawer), DelayedWithdraw.setAllowThirdPartyToComplete.selector
                    )
                ) {
                    rolesAuthority.setPublicCapability(
                        address(delayedWithdrawer), DelayedWithdraw.setAllowThirdPartyToComplete.selector, true
                    );
                }
                if (
                    !rolesAuthority.isCapabilityPublic(
                        address(delayedWithdrawer), DelayedWithdraw.requestWithdraw.selector
                    )
                ) {
                    rolesAuthority.setPublicCapability(
                        address(delayedWithdrawer), DelayedWithdraw.requestWithdraw.selector, true
                    );
                }
                if (
                    !rolesAuthority.isCapabilityPublic(
                        address(delayedWithdrawer), DelayedWithdraw.cancelWithdraw.selector
                    )
                ) {
                    rolesAuthority.setPublicCapability(
                        address(delayedWithdrawer), DelayedWithdraw.cancelWithdraw.selector, true
                    );
                }
                if (
                    !rolesAuthority.isCapabilityPublic(
                        address(delayedWithdrawer), DelayedWithdraw.completeWithdraw.selector
                    )
                ) {
                    rolesAuthority.setPublicCapability(
                        address(delayedWithdrawer), DelayedWithdraw.completeWithdraw.selector, true
                    );
                }
            }
        }

        if (configureDeployment.setupDepositAssets) {
            // Setup deposit asset.
            if (!teller.isSupported(accountantParameters.base)) teller.addAsset(accountantParameters.base);

            // Setup extra deposit assets.
            for (uint256 i; i < depositAssets.length; i++) {
                DepositAsset storage depositAsset = depositAssets[i];
                (bool isPeggedToBase, IRateProvider rateProvider) = accountant.rateProviderData(depositAssets[i].asset);
                if (isPeggedToBase || address(rateProvider) != address(0)) {
                    depositAsset.rateProvider = address(rateProvider);
                    continue;
                }
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
                    address deployedAddress = _getAddressIfDeployed(depositAsset.genericRateProviderName);
                    if (deployedAddress == address(0)) {
                        depositAsset.rateProvider = deployer.deployContract(
                            depositAsset.genericRateProviderName, creationCode, constructorArgs, 0
                        );
                    } else {
                        depositAsset.rateProvider = deployedAddress;
                    }

                    accountant.setRateProviderData(depositAsset.asset, false, depositAsset.rateProvider);
                    teller.addAsset(depositAsset.asset);
                }
            }
        }

        if (configureDeployment.setupWithdrawAssets) {
            // Setup withdraw assets.
            for (uint256 i; i < withdrawAssets.length; i++) {
                (bool allowWithdraws,,,,,) = delayedWithdrawer.withdrawAssets(withdrawAssets[i].asset);
                if (allowWithdraws) continue;
                WithdrawAsset memory withdrawAsset = withdrawAssets[i];
                delayedWithdrawer.setupWithdrawAsset(
                    withdrawAsset.asset,
                    withdrawAsset.withdrawDelay,
                    withdrawAsset.completionWindow,
                    withdrawAsset.withdrawFee,
                    withdrawAsset.maxLoss
                );
            }
        }

        if (configureDeployment.finishSetup) {
            // Setup share lock period.
            if (teller.shareLockPeriod() != shareLockPeriod) teller.setShareLockPeriod(shareLockPeriod);
            if (address(boringVault.hook()) != address(teller)) boringVault.setBeforeTransferHook(address(teller));

            // Set all RolesAuthorities.
            if (boringVault.authority() != rolesAuthority) boringVault.setAuthority(rolesAuthority);
            if (manager.authority() != rolesAuthority) manager.setAuthority(rolesAuthority);
            if (accountant.authority() != rolesAuthority) accountant.setAuthority(rolesAuthority);
            if (teller.authority() != rolesAuthority) teller.setAuthority(rolesAuthority);
            if (delayedWithdrawer.authority() != rolesAuthority) delayedWithdrawer.setAuthority(rolesAuthority);

            // Renounce ownership
            if (boringVault.owner() != address(0)) boringVault.transferOwnership(address(0));
            if (manager.owner() != address(0)) manager.transferOwnership(address(0));
            if (accountant.owner() != address(0)) accountant.transferOwnership(address(0));
            if (teller.owner() != address(0)) teller.transferOwnership(address(0));
            if (delayedWithdrawer.owner() != address(0)) delayedWithdrawer.transferOwnership(address(0));

            // Setup roles.
            if (!rolesAuthority.doesUserHaveRole(address(manager), MANAGER_ROLE)) {
                rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
            }
            if (!rolesAuthority.doesUserHaveRole(address(manager), MANAGER_INTERNAL_ROLE)) {
                rolesAuthority.setUserRole(address(manager), MANAGER_INTERNAL_ROLE, true);
            }
            if (!rolesAuthority.doesUserHaveRole(address(teller), MINTER_ROLE)) {
                rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
            }
            if (!rolesAuthority.doesUserHaveRole(address(delayedWithdrawer), BURNER_ROLE)) {
                rolesAuthority.setUserRole(address(delayedWithdrawer), BURNER_ROLE, true);
            }
        }

        if (configureDeployment.setupTestUser) {
            // Give development address straetgist and owner roles, and transfer ownership if needed.
            if (!rolesAuthority.doesUserHaveRole(developmentAddress, STRATEGIST_ROLE)) {
                rolesAuthority.setUserRole(developmentAddress, STRATEGIST_ROLE, true);
            }
            if (!rolesAuthority.doesUserHaveRole(developmentAddress, OWNER_ROLE)) {
                rolesAuthority.setUserRole(developmentAddress, OWNER_ROLE, true);
            }
            if (owner != developmentAddress) rolesAuthority.transferOwnership(developmentAddress);
        }

        if (configureDeployment.saveDeploymentDetails) {
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
                    accountantConfiguration,
                    "MinimumUpateDelayInSeconds",
                    accountantParameters.minimumUpateDelayInSeconds
                );
                vm.serializeUint(accountantConfiguration, "ManagementFee", accountantParameters.managementFee);
                vm.serializeUint(
                    accountantConfiguration, "StartingExchangeRate", accountantParameters.startingExchangeRate
                );
                vm.serializeAddress(accountantConfiguration, "BaseAddress", address(accountantParameters.base));
                accountantConfigurationOutput =
                    vm.serializeString(accountantConfiguration, "Base", accountantParameters.base.symbol());
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
}
