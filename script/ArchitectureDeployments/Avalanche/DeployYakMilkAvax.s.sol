// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DeployArcticArchitecture, ERC20, Deployer} from "script/ArchitectureDeployments/DeployArcticArchitecture.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {AvalancheAddresses} from "test/resources/AvalancheAddresses.sol";

// Import Decoder and Sanitizer to deploy.
import {EtherFiLiquidEthDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidEthDecoderAndSanitizer.sol";

/**
 *  source .env && forge script script/ArchitectureDeployments/Avalanche/DeployYakMilkAvax.s.sol:DeployYakMilkAvaxScript --with-gas-price 25000000000 --broadcast --etherscan-api-key $SNOWTRACE_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployYakMilkAvaxScript is DeployArcticArchitecture, AvalancheAddresses {
    using AddressToBytes32Lib for address;

    uint256 public privateKey;

    // Deployment parameters
    string public boringVaultName = "Yak Milk AVAX";
    string public boringVaultSymbol = "AVAXMILK";
    uint8 public boringVaultDecimals = 18;
    address public owner = dev0Address;

    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("avalanche");
    }

    function run() external {
        // Configure the deployment.
        configureDeployment.deployContracts = true;
        configureDeployment.setupRoles = true;
        configureDeployment.setupDepositAssets = true;
        configureDeployment.setupWithdrawAssets = true;
        configureDeployment.finishSetup = true;
        configureDeployment.setupTestUser = true;
        configureDeployment.saveDeploymentDetails = true;
        configureDeployment.deployerAddress = deployerAddress;
        configureDeployment.balancerVault = balancerVault;
        configureDeployment.WETH = address(WAVAX);

        // Save deployer.
        deployer = Deployer(configureDeployment.deployerAddress);

        // Define names to determine where contracts are deployed.
        names.rolesAuthority = YakMilkAvaxVaultRolesAuthorityName;
        names.lens = ArcticArchitectureLensName;
        names.boringVault = YakMilkAvaxVaultName;
        names.manager = YakMilkAvaxVaultManagerName;
        names.accountant = YakMilkAvaxVaultAccountantName;
        names.teller = YakMilkAvaxVaultTellerName;
        names.rawDataDecoderAndSanitizer = YakMilkAvaxVaultDecoderAndSanitizerName;
        names.delayedWithdrawer = YakMilkAvaxVaultDelayedWithdrawer;

        // Define Accountant Parameters.
        accountantParameters.payoutAddress = liquidPayoutAddress;
        accountantParameters.base = WAVAX;
        // Decimals are in terms of `base`.
        accountantParameters.startingExchangeRate = 1e18;
        //  4 decimals
        accountantParameters.managementFee = 0.02e4;
        accountantParameters.performanceFee = 0;
        accountantParameters.allowedExchangeRateChangeLower = 0.995e4;
        accountantParameters.allowedExchangeRateChangeUpper = 1.005e4;
        // Minimum time(in seconds) to pass between updated without triggering a pause.
        accountantParameters.minimumUpateDelayInSeconds = 1 days / 4;

        // Define Decoder and Sanitizer deployment details.
        bytes memory creationCode = type(EtherFiLiquidEthDecoderAndSanitizer).creationCode;
        bytes memory constructorArgs =
            abi.encode(deployer.getAddress(names.boringVault), uniswapV3NonFungiblePositionManager);

        // Setup extra deposit assets.
        // none

        // Setup withdraw assets.
        // none

        bool allowPublicDeposits = true;
        bool allowPublicWithdraws = true;
        uint64 shareLockPeriod = 1 days;
        address delayedWithdrawFeeAddress = liquidPayoutAddress;

        vm.startBroadcast(privateKey);

        _deploy(
            "YakMilkAvaxDeployment.json",
            owner,
            boringVaultName,
            boringVaultSymbol,
            boringVaultDecimals,
            creationCode,
            constructorArgs,
            delayedWithdrawFeeAddress,
            allowPublicDeposits,
            allowPublicWithdraws,
            shareLockPeriod,
            dev1Address
        );

        vm.stopBroadcast();
    }
}
