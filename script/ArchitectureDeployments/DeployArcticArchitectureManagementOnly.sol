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
import {BoringDrone} from "src/base/Drones/BoringDrone.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployBoringVaultArctic.s.sol:DeployBoringVaultArcticScript --with-gas-price 30000000000 --slow --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployArcticArchitectureManagementOnly is Script, ContractNames {
    struct ConfigureDeployment {
        bool deployContracts;
        bool setupRoles;
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
        string boringVault;
        string manager;
        string rawDataDecoderAndSanitizer;
        string droneBaseName;
    }

    ArchitectureNames public names;

    // Contracts to deploy
    Deployer public deployer;
    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    RolesAuthority public rolesAuthority;
    address public rawDataDecoderAndSanitizer;

    // Roles
    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant MANAGER_INTERNAL_ROLE = 4;
    uint8 public constant OWNER_ROLE = 8;
    uint8 public constant MULTISIG_ROLE = 9;
    uint8 public constant STRATEGIST_ROLE = 7;

    uint8 public droneCount;
    address[] public droneAddresses;

    bytes public boringCreationCode;

    string finalJson;
    string coreOutput;
    string droneOutput;

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

            deployedAddress = _getAddressIfDeployed(names.boringVault);
            if (deployedAddress == address(0)) {
                creationCode = boringCreationCode.length == 0 ? type(BoringVault).creationCode : boringCreationCode;
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

            for (uint256 i; i < droneCount; ++i) {
                string memory droneName = string.concat(names.droneBaseName, "-", vm.toString(i));
                deployedAddress = _getAddressIfDeployed(droneName);
                if (deployedAddress == address(0)) {
                    creationCode = type(BoringDrone).creationCode;
                    constructorArgs = abi.encode(address(boringVault), 0);
                    droneAddresses.push(deployer.deployContract(droneName, creationCode, constructorArgs, 0));
                } else {
                    droneAddresses.push(deployedAddress);
                }
            }
        } else {
            rolesAuthority = RolesAuthority(_getAddressIfDeployed(names.rolesAuthority));
            boringVault = BoringVault(payable(_getAddressIfDeployed(names.boringVault)));
            manager = ManagerWithMerkleVerification(_getAddressIfDeployed(names.manager));
            rawDataDecoderAndSanitizer = _getAddressIfDeployed(names.rawDataDecoderAndSanitizer);
            for (uint256 i; i < droneCount; ++i) {
                string memory droneName = string.concat(names.droneBaseName, "-", vm.toString(i));
                address deployedAddress = _getAddressIfDeployed(droneName);
                droneAddresses.push(deployedAddress);
            }
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
            // MULTISIG_ROLE
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
        }

        if (configureDeployment.finishSetup) {
            // Set all RolesAuthorities.
            if (boringVault.authority() != rolesAuthority) boringVault.setAuthority(rolesAuthority);
            if (manager.authority() != rolesAuthority) manager.setAuthority(rolesAuthority);

            // Renounce ownership
            if (boringVault.owner() != address(0)) boringVault.transferOwnership(address(0));
            if (manager.owner() != address(0)) manager.transferOwnership(address(0));

            // Setup roles.
            if (!rolesAuthority.doesUserHaveRole(address(manager), MANAGER_ROLE)) {
                rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
            }
            if (!rolesAuthority.doesUserHaveRole(address(manager), MANAGER_INTERNAL_ROLE)) {
                rolesAuthority.setUserRole(address(manager), MANAGER_INTERNAL_ROLE, true);
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
                vm.serializeAddress(coreContracts, "BoringVault", address(boringVault));
                vm.serializeAddress(coreContracts, "ManagerWithMerkleVerification", address(manager));
                coreOutput = vm.serializeAddress(coreContracts, "DecoderAndSanitizer", rawDataDecoderAndSanitizer);
            }

            {
                string memory drones = "drone key";
                for (uint256 i; i < droneAddresses.length; i++) {
                    droneOutput =
                        vm.serializeAddress(drones, string.concat("drone-", vm.toString(i)), droneAddresses[i]);
                }
            }

            vm.serializeString(finalJson, "core", coreOutput);
            finalJson = vm.serializeString(finalJson, "Drones", droneOutput);

            vm.writeJson(finalJson, filePath);
        }
    }
}
