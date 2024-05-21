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

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployBoringVaultArctic.s.sol:DeployBoringVaultArcticScript --with-gas-price 30000000000 --slow --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployBoringVaultArcticScript is Script, ContractNames, MainnetAddresses {
    uint256 public privateKey;

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
    EtherFiLiquid1 public etherFiLiquid1 = EtherFiLiquid1(0xeA1A6307D9b18F8d1cbf1c3Dd6aad8416C06a221);
    CellarMigrationAdaptor public migrationAdaptor;
    GenericRateProvider public ptEethRateProvider;
    GenericRateProvider public ytEethRateProvider;
    GenericRateProvider public lpEethRateProvider;
    GenericRateProvider public ptZeethRateProvider;
    GenericRateProvider public ytZeethRateProvider;
    GenericRateProvider public lpZeethRateProvider;
    GenericRateProvider public auraRETHWeETHBptRateProvider;
    GenericRateProvider public wstethRateProvider;
    // Deployment parameters
    string public boringVaultName = "Ether.Fi Liquid ETH";
    string public boringVaultSymbol = "liquidETH";
    uint8 public boringVaultDecimals = 18;
    address public owner = dev1Address;

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

    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast();
        // vm.startBroadcast(privateKey);

        // creationCode = type(RolesAuthority).creationCode;
        // constructorArgs = abi.encode(owner, Authority(address(0)));
        rolesAuthority = RolesAuthority(deployer.getAddress(EtherFiLiquidEthRolesAuthorityName));

        // creationCode = type(ArcticArchitectureLens).creationCode;
        // lens = ArcticArchitectureLens(deployer.deployContract(ArcticArchitectureLensName, creationCode, hex"", 0));

        creationCode = type(BoringVault).creationCode;
        constructorArgs = abi.encode(owner, boringVaultName, boringVaultSymbol, boringVaultDecimals);
        boringVault =
            BoringVault(payable(deployer.deployContract(EtherFiLiquidEthName, creationCode, constructorArgs, 0)));

        creationCode = type(ManagerWithMerkleVerification).creationCode;
        constructorArgs = abi.encode(owner, address(boringVault), balancerVault);
        manager = ManagerWithMerkleVerification(
            deployer.deployContract(EtherFiLiquidEthManagerName, creationCode, constructorArgs, 0)
        );

        // Set the exchange rate to match the current vaults share price. Use the larger of the two preview functions.
        uint256 exchangeRate0 = etherFiLiquid1.previewMint(1e18);
        uint256 exchangeRate1 = etherFiLiquid1.previewRedeem(1e18);
        uint256 exchangeRate = exchangeRate0 > exchangeRate1 ? exchangeRate0 : exchangeRate1;
        creationCode = type(AccountantWithRateProviders).creationCode;
        constructorArgs = abi.encode(
            owner,
            address(boringVault),
            liquidPayoutAddress,
            exchangeRate,
            address(WETH),
            1.005e4,
            0.995e4,
            1 days / 4,
            0.02e4
        );
        accountant = AccountantWithRateProviders(
            deployer.deployContract(EtherFiLiquidEthAccountantName, creationCode, constructorArgs, 0)
        );

        creationCode = type(TellerWithMultiAssetSupport).creationCode;
        constructorArgs = abi.encode(owner, address(boringVault), address(accountant), WETH);
        teller = TellerWithMultiAssetSupport(
            payable(deployer.deployContract(EtherFiLiquidEthTellerName, creationCode, constructorArgs, 0))
        );

        // creationCode = type(EtherFiLiquidEthDecoderAndSanitizer).creationCode;
        // constructorArgs = abi.encode(address(boringVault), uniswapV3NonFungiblePositionManager);
        rawDataDecoderAndSanitizer = deployer.getAddress(EtherFiLiquidEthDecoderAndSanitizerName);

        creationCode = type(CellarMigrationAdaptor).creationCode;
        constructorArgs = abi.encode(address(boringVault), address(accountant), address(teller));
        migrationAdaptor = CellarMigrationAdaptor(
            deployer.deployContract(CellarMigrationAdaptorName, creationCode, constructorArgs, 0)
        );

        // Deploy Generic Rate Providers.
        bytes4 selector = bytes4(keccak256(abi.encodePacked("getValue(address,uint256,address)")));
        uint256 amount = 1e18;
        bytes32 base = 0x000000000000000000000000c69Ad9baB1dEE23F4605a82b3354F8E40d1E5966; // pendleEethPt
        bytes32 quote = 0x000000000000000000000000C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // wETH

        creationCode = type(GenericRateProvider).creationCode;
        constructorArgs = abi.encode(liquidV1PriceRouter, selector, base, bytes32(amount), quote, 0, 0, 0, 0, 0);
        ptEethRateProvider = GenericRateProvider(deployer.getAddress(PendlePTweETHRateProviderName));

        base = 0x000000000000000000000000fb35Fd0095dD1096b1Ca49AD44d8C5812A201677; // pendleEethYt
        constructorArgs = abi.encode(liquidV1PriceRouter, selector, base, bytes32(amount), quote, 0, 0, 0, 0, 0);
        ytEethRateProvider = GenericRateProvider(deployer.getAddress(PendleYTweETHRateProviderName));

        base = 0x000000000000000000000000F32e58F92e60f4b0A37A69b95d642A471365EAe8; // pendleEethLp
        constructorArgs = abi.encode(liquidV1PriceRouter, selector, base, bytes32(amount), quote, 0, 0, 0, 0, 0);
        lpEethRateProvider = GenericRateProvider(deployer.getAddress(PendleLPweETHRateProviderName));

        base = 0x0000000000000000000000004AE5411F3863CdB640309e84CEDf4B08B8b33FfF; // pendleZeethPt
        constructorArgs = abi.encode(liquidV1PriceRouter, selector, base, bytes32(amount), quote, 0, 0, 0, 0, 0);
        ptZeethRateProvider = GenericRateProvider(deployer.getAddress(PendleZircuitPTweETHRateProviderName));

        base = 0x0000000000000000000000007C2D26182adeEf96976035986cF56474feC03bDa; // pendleZeethYt
        constructorArgs = abi.encode(liquidV1PriceRouter, selector, base, bytes32(amount), quote, 0, 0, 0, 0, 0);
        ytZeethRateProvider = GenericRateProvider(deployer.getAddress(PendleZircuitYTweETHRateProviderName));

        base = 0x000000000000000000000000e26D7f9409581f606242300fbFE63f56789F2169; // pendleZeethLp
        constructorArgs = abi.encode(liquidV1PriceRouter, selector, base, bytes32(amount), quote, 0, 0, 0, 0, 0);
        lpZeethRateProvider = GenericRateProvider(deployer.getAddress(PendleZircuitLPweETHRateProviderName));

        auraRETHWeETHBptRateProvider = GenericRateProvider(deployer.getAddress(AuraRETHWeETHBptRateProviderName));
        wstethRateProvider = GenericRateProvider(deployer.getAddress(WstETHRateProviderName));

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
        // rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);
        // rolesAuthority.setPublicCapability(
        //     address(teller), TellerWithMultiAssetSupport.depositWithPermit.selector, true
        // );

        // Give roles to appropriate contracts
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);
        rolesAuthority.setUserRole(deployer.getAddress(AtomicSolverName), SOLVER_ROLE, true);
        // Give Liquid V1 the solver role so it can use bulk withdraw and deposit.
        rolesAuthority.setUserRole(address(etherFiLiquid1), SOLVER_ROLE, true);

        // Setup rate providers.
        accountant.setRateProviderData(WETH, true, address(0));
        accountant.setRateProviderData(EETH, true, address(0));
        accountant.setRateProviderData(WEETH, false, address(WEETH));
        accountant.setRateProviderData(ERC20(pendleEethPt), false, address(ptEethRateProvider));
        accountant.setRateProviderData(ERC20(pendleEethYt), false, address(ytEethRateProvider));
        accountant.setRateProviderData(ERC20(pendleWeETHMarket), false, address(lpEethRateProvider));
        accountant.setRateProviderData(ERC20(pendleZircuitEethPt), false, address(ptZeethRateProvider));
        accountant.setRateProviderData(ERC20(pendleZircuitEethYt), false, address(ytZeethRateProvider));
        accountant.setRateProviderData(ERC20(pendleZircuitWeETHMarket), false, address(lpZeethRateProvider));
        accountant.setRateProviderData(rETH_weETH, false, address(auraRETHWeETHBptRateProvider));
        accountant.setRateProviderData(WSTETH, false, address(wstethRateProvider));

        // Setup Teller deposit assets.
        teller.addAsset(WETH);
        teller.addAsset(EETH);
        teller.addAsset(WEETH);
        teller.addAsset(ERC20(pendleEethPt));
        teller.addAsset(ERC20(pendleEethYt));
        teller.addAsset(ERC20(pendleWeETHMarket));
        teller.addAsset(ERC20(pendleZircuitEethPt));
        teller.addAsset(ERC20(pendleZircuitEethYt));
        teller.addAsset(ERC20(pendleZircuitWeETHMarket));
        teller.addAsset(rETH_weETH);
        teller.addAsset(WSTETH);

        // Setup share lock period.
        teller.setShareLockPeriod(1 days);

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
        rolesAuthority.setUserRole(dev1Address, STRATEGIST_ROLE, true);

        // rolesAuthority.transferOwnership(dev1Address);

        vm.stopBroadcast();
    }
}
