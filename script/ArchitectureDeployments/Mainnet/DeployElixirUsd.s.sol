// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DeployArcticArchitecture, ERC20, Deployer} from "script/ArchitectureDeployments/DeployArcticArchitecture.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";

// Import Decoder and Sanitizer to deploy.
import {EtherFiLiquidUsdDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidUsdDecoderAndSanitizer.sol";

/**
 *  source .env && forge script script/ArchitectureDeployments/Mainnet/DeployElixirUsd.s.sol:DeployElixirUsdScript --with-gas-price 1000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployElixirUsdScript is DeployArcticArchitecture, MainnetAddresses {
    using AddressToBytes32Lib for address;

    uint256 public privateKey;

    // Deployment parameters
    string public boringVaultName = "Ether.Fi Liquid Elixir";
    string public boringVaultSymbol = "liquidElixir";
    uint8 public boringVaultDecimals = 18;
    address public owner = dev1Address;

    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("mainnet");
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
        configureDeployment.WETH = address(WETH);

        // Save deployer.
        deployer = Deployer(configureDeployment.deployerAddress);

        // Define names to determine where contracts are deployed.
        names.rolesAuthority = EtherFiElixirUsdRolesAuthorityName;
        names.lens = ArcticArchitectureLensName;
        names.boringVault = EtherFiElixirUsdName;
        names.manager = EtherFiElixirUsdManagerName;
        names.accountant = EtherFiElixirUsdAccountantName;
        names.teller = EtherFiElixirUsdTellerName;
        names.rawDataDecoderAndSanitizer = EtherFiElixirUsdDecoderAndSanitizerName;
        names.delayedWithdrawer = EtherFiElixirUsdDelayedWithdrawer;

        // Define Accountant Parameters.
        accountantParameters.payoutAddress = liquidPayoutAddress;
        accountantParameters.base = deUSD;
        // Decimals are in terms of `base`.
        accountantParameters.startingExchangeRate = 1e18;
        //  4 decimals
        accountantParameters.platformFee = 0.02e4;
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
        depositAssets.push(
            DepositAsset({
                asset: USDC,
                isPeggedToBase: true,
                rateProvider: address(0),
                genericRateProviderName: "",
                target: address(0),
                selector: bytes4(0),
                params: [bytes32(0), 0, 0, 0, 0, 0, 0, 0]
            })
        );
        depositAssets.push(
            DepositAsset({
                asset: USDT,
                isPeggedToBase: true,
                rateProvider: address(0),
                genericRateProviderName: "",
                target: address(0),
                selector: bytes4(0),
                params: [bytes32(0), 0, 0, 0, 0, 0, 0, 0]
            })
        );
        depositAssets.push(
            DepositAsset({
                asset: DAI,
                isPeggedToBase: true,
                rateProvider: address(0),
                genericRateProviderName: "",
                target: address(0),
                selector: bytes4(0),
                params: [bytes32(0), 0, 0, 0, 0, 0, 0, 0]
            })
        );
        depositAssets.push(
            DepositAsset({
                asset: sdeUSD,
                isPeggedToBase: false,
                rateProvider: address(0),
                genericRateProviderName: sdeUSDRateProviderName,
                target: address(sdeUSD),
                selector: bytes4(keccak256(abi.encodePacked("previewRedeem(uint256)"))),
                params: [bytes32(uint256(1e18)), 0, 0, 0, 0, 0, 0, 0]
            })
        );
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
                asset: deUSD,
                withdrawDelay: 3 days,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );

        withdrawAssets.push(
            WithdrawAsset({
                asset: sdeUSD,
                withdrawDelay: 3 days,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );

        bool allowPublicDeposits = true;
        bool allowPublicWithdraws = false;
        uint64 shareLockPeriod = 1 days;
        address delayedWithdrawFeeAddress = liquidPayoutAddress;

        // vm.startBroadcast();
        vm.startBroadcast(privateKey);

        _deploy(
            "ElixirUsdDeployment.json",
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
