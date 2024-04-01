// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault, Auth} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {RenzoLiquidDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/RenzoLiquidDecoderAndSanitizer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {ArcticArchitectureLens} from "src/helper/ArcticArchitectureLens.sol";
import {DexAggregatorUManager} from "src/micro-managers/DexAggregatorUManager.sol";
import {DexSwapperUManager} from "src/micro-managers/DexSwapperUManager.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployBoringVaultArctic.s.sol:DeployBoringVaultArcticScript --with-gas-price 30000000000 --slow --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployBoringVaultArcticScript is Script {
    uint256 public privateKey;

    // Contracts to deploy
    Deployer public deployer;
    ArcticArchitectureLens public lens;
    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    RolesAuthority public rolesAuthority;
    address public rawDataDecoderAndSanitizer;
    TellerWithMultiAssetSupport public teller;
    AccountantWithRateProviders public accountant;
    DexAggregatorUManager public dexAggregatorUManager;
    DexSwapperUManager public dexSwapperUManager;

    // Deployment parameters
    string public boringVaultName = "Test Boring Vault";
    string public boringVaultSymbol = "BV";
    uint8 public boringVaultDecimals = 18;
    address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public uniswapV3NonFungiblePositionManager = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address public owner = 0x552acA1343A6383aF32ce1B7c7B1b47959F7ad90;
    address public balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address public oneInchAggregatorV5 = 0x1111111254EEB25477B68fb85Ed929f73A960582;
    address public uniswapV3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public priceRouter; // TODO

    // Roles
    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant MINTER_ROLE = 2;
    uint8 public constant BURNER_ROLE = 3;
    uint8 public constant MANAGER_INTERNAL_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;
    uint8 public constant SOLVER_ROLE = 12;
    uint8 public constant OWNER_ROLE = 8;
    uint8 public constant MULTISIG_ROLE = 9;
    uint8 public constant STRATEGIST_MULTISIG_ROLE = 10;
    uint8 public constant STRATEGIST_ROLE = 7;
    uint8 public constant MICRO_MANAGER_ROLE = 13;
    uint8 public constant UPDATE_EXCHANGE_RATE_ROLE = 11;

    function setUp() external {
        privateKey = vm.envUint("PRIVATE_KEY");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        vm.startBroadcast(privateKey);

        // TODO change all deployments to use the Deployer
        rolesAuthority = new RolesAuthority(owner, Authority(address(0)));
        deployer = new Deployer(owner, rolesAuthority);
        lens = new ArcticArchitectureLens();

        boringVault = new BoringVault(owner, boringVaultName, boringVaultSymbol, boringVaultDecimals);

        manager = new ManagerWithMerkleVerification(owner, address(boringVault), balancerVault);

        accountant = new AccountantWithRateProviders(
            owner, address(boringVault), owner, 1e18, address(WETH), 1.001e4, 0.999e4, 1, 0
        );

        teller = new TellerWithMultiAssetSupport(owner, address(boringVault), address(accountant), WETH);

        rawDataDecoderAndSanitizer =
            address(new RenzoLiquidDecoderAndSanitizer(address(boringVault), uniswapV3NonFungiblePositionManager));

        dexAggregatorUManager =
            new DexAggregatorUManager(owner, address(manager), address(boringVault), oneInchAggregatorV5, priceRouter);
        dexSwapperUManager =
            new DexSwapperUManager(owner, address(manager), address(boringVault), uniswapV3Router, priceRouter);

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
        // BORING_VAULT_ROLE
        rolesAuthority.setRoleCapability(
            BORING_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.flashLoan.selector, true
        );
        // BALANCER_VAULT_ROLE
        rolesAuthority.setRoleCapability(
            BALANCER_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.receiveFlashLoan.selector, true
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
        rolesAuthority.setRoleCapability(OWNER_ROLE, address(dexAggregatorUManager), Auth.setAuthority.selector, true);
        rolesAuthority.setRoleCapability(
            OWNER_ROLE, address(dexAggregatorUManager), Auth.transferOwnership.selector, true
        );
        rolesAuthority.setRoleCapability(OWNER_ROLE, address(dexSwapperUManager), Auth.setAuthority.selector, true);
        rolesAuthority.setRoleCapability(OWNER_ROLE, address(dexSwapperUManager), Auth.transferOwnership.selector, true);
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
            MULTISIG_ROLE, address(dexAggregatorUManager), DexAggregatorUManager.setAllowedSlippage.selector, true
        );
        rolesAuthority.setRoleCapability(
            MULTISIG_ROLE, address(dexSwapperUManager), DexSwapperUManager.setAllowedSlippage.selector, true
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
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE, address(dexAggregatorUManager), DexAggregatorUManager.swapWith1Inch.selector, true
        );
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE, address(dexAggregatorUManager), DexAggregatorUManager.revokeTokenApproval.selector, true
        );
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE, address(dexSwapperUManager), DexSwapperUManager.swapWithUniswapV3.selector, true
        );
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE, address(dexSwapperUManager), DexSwapperUManager.revokeTokenApproval.selector, true
        );
        // MICRO_MANAGER_ROLE
        rolesAuthority.setRoleCapability(
            MICRO_MANAGER_ROLE,
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
        // Publically callable functions
        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);
        rolesAuthority.setPublicCapability(
            address(teller), TellerWithMultiAssetSupport.depositWithPermit.selector, true
        );

        // Give roles to appropriate contracts

        // Setup rate providers

        vm.stopBroadcast();
    }
}
