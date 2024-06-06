// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {DeployArcticArchitecture, ERC20, Deployer} from "script/ArchitectureDeployments/DeployArcticArchitecture.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";

// Import Decoder and Sanitizer to deploy.
import {EtherFiLiquidUsdDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidUsdDecoderAndSanitizer.sol";

/**
 *  source .env && forge script script/ArchitectureDeployments/DeployLiquidUsd.s.sol:DeployLiquidUsdScript --with-gas-price 10000000000 --slow --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployLiquidUsdScript is DeployArcticArchitecture, MainnetAddresses {
    using AddressToBytes32Lib for address;

    uint256 public privateKey;

    // Deployment parameters
    string public boringVaultName = "Ether.Fi Liquid USD";
    string public boringVaultSymbol = "liquidUSD";
    uint8 public boringVaultDecimals = 6;
    address public owner = dev0Address;

    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        // Configure the deployment.
        configureDeployment.deployContracts = true;
        configureDeployment.setupRoles = false;
        configureDeployment.setupDepositAssets = false;
        configureDeployment.setupWithdrawAssets = true;
        configureDeployment.finishSetup = false;
        configureDeployment.setupTestUser = false;
        configureDeployment.saveDeploymentDetails = true;
        configureDeployment.deployerAddress = deployerAddress;
        configureDeployment.balancerVault = balancerVault;
        configureDeployment.WETH = address(WETH);

        // Define names to determine where contracts are deployed.
        names.rolesAuthority = EtherFiLiquidUsdRolesAuthorityName;
        names.lens = ArcticArchitectureLensName;
        names.boringVault = EtherFiLiquidUsdName;
        names.manager = EtherFiLiquidUsdManagerName;
        names.accountant = EtherFiLiquidUsdAccountantName;
        names.teller = EtherFiLiquidUsdTellerName;
        names.rawDataDecoderAndSanitizer = EtherFiLiquidUsdDecoderAndSanitizerName;
        names.delayedWithdrawer = EtherFiLiquidUsdDelayedWithdrawer;

        // Define Accountant Parameters.
        accountantParameters.payoutAddress = liquidPayoutAddress;
        accountantParameters.base = USDC;
        // Decimals are in terms of `base`.
        accountantParameters.startingExchangeRate = 1e6;
        //  4 decimals
        accountantParameters.managementFee = 0.02e4;
        accountantParameters.performanceFee = 0;
        accountantParameters.allowedExchangeRateChangeLower = 0.995e4;
        accountantParameters.allowedExchangeRateChangeUpper = 1.005e4;
        // Minimum time(in seconds) to pass between updated without triggering a pause.
        accountantParameters.minimumUpateDelayInSeconds = 1 days / 4;

        // Define Decoder and Sanitizer deployment details.
        bytes memory creationCode = type(EtherFiLiquidUsdDecoderAndSanitizer).creationCode;
        bytes memory constructorArgs =
            abi.encode(deployer.getAddress(names.boringVault), uniswapV3NonFungiblePositionManager);

        // Setup extra deposit assets.
        // none to setup

        // Setup withdraw assets.
        withdrawAssets.push(
            WithdrawAsset({
                asset: USDC,
                withdrawDelay: 3 days,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );

        withdrawAssets.push(
            WithdrawAsset({
                asset: USDT,
                withdrawDelay: 3 days,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );

        withdrawAssets.push(
            WithdrawAsset({asset: DAI, withdrawDelay: 3 days, completionWindow: 7 days, withdrawFee: 0, maxLoss: 0.01e4})
        );

        withdrawAssets.push(
            WithdrawAsset({
                asset: USDE,
                withdrawDelay: 7 days,
                completionWindow: 14 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );

        bool allowPublicDeposits = false;
        bool allowPublicWithdraws = true;
        uint64 shareLockPeriod = 1 days;
        address delayedWithdrawFeeAddress = liquidPayoutAddress;

        // vm.startBroadcast();
        vm.startBroadcast(privateKey);

        _deploy(
            "LiquidUsdDeployment.json",
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
