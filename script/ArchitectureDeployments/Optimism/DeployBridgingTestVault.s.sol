// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DeployArcticArchitecture, ERC20, Deployer} from "script/ArchitectureDeployments/DeployArcticArchitecture.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {ChainValues} from "test/resources/ChainValues.sol";

// Import Decoder and Sanitizer to deploy.
import {EtherFiLiquidEthDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidEthDecoderAndSanitizer.sol";

/**
 *  source .env && forge script script/ArchitectureDeployments/Optimism/DeployBridgingTestVault.s.sol:DeployBridgingTestVaultScript --with-gas-price 70000000 --evm-version london --broadcast --etherscan-api-key $OPTIMISMSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployBridgingTestVaultScript is DeployArcticArchitecture, ChainValues {
    using AddressToBytes32Lib for address;

    uint256 public privateKey;

    // Deployment parameters
    string public boringVaultName = "Bridging Test Vault";
    string public boringVaultSymbol = "BTEV";
    uint8 public boringVaultDecimals = 18;
    string internal sourceChain = optimism;
    address public owner;

    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork(sourceChain);
    }

    function run() external {
        owner = getAddress(sourceChain, "dev0Address");
        // Configure the deployment.
        configureDeployment.deployContracts = true;
        configureDeployment.setupRoles = true;
        configureDeployment.setupDepositAssets = true;
        configureDeployment.setupWithdrawAssets = true;
        configureDeployment.finishSetup = true;
        configureDeployment.setupTestUser = true;
        configureDeployment.saveDeploymentDetails = true;
        configureDeployment.deployerAddress = getAddress(sourceChain, "deployerAddress");
        configureDeployment.balancerVault = getAddress(sourceChain, "balancerVault");
        configureDeployment.WETH = getAddress(sourceChain, "WETH");

        // Save deployer.
        deployer = Deployer(configureDeployment.deployerAddress);

        // Define names to determine where contracts are deployed.
        names.rolesAuthority = BridgingTestVaultEthRolesAuthorityName;
        names.lens = ArcticArchitectureLensName;
        names.boringVault = BridgingTestVaultEthName;
        names.manager = BridgingTestVaultEthManagerName;
        names.accountant = BridgingTestVaultEthAccountantName;
        names.teller = BridgingTestVaultEthTellerName;
        names.rawDataDecoderAndSanitizer = BridgingTestVaultEthDecoderAndSanitizerName;
        names.delayedWithdrawer = BridgingTestVaultEthDelayedWithdrawer;

        // Define Accountant Parameters.
        accountantParameters.payoutAddress = getAddress(sourceChain, "liquidPayoutAddress");
        accountantParameters.base = getERC20(sourceChain, "WETH");
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
        bytes memory constructorArgs = abi.encode(
            deployer.getAddress(names.boringVault), getAddress(sourceChain, "uniswapV3NonFungiblePositionManager")
        );

        // Setup extra deposit assets.
        depositAssets.push(
            DepositAsset({
                asset: getERC20(sourceChain, "WEETH"),
                isPeggedToBase: false,
                rateProvider: address(0),
                genericRateProviderName: "",
                target: getAddress(sourceChain, "weETH_ETH_ExchangeRate"),
                selector: bytes4(keccak256(abi.encodePacked("latestAnswer()"))),
                params: [bytes32(0), 0, 0, 0, 0, 0, 0, 0]
            })
        );

        // Setup withdraw assets.
        withdrawAssets.push(
            WithdrawAsset({
                asset: getERC20(sourceChain, "WETH"),
                withdrawDelay: 60,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );

        withdrawAssets.push(
            WithdrawAsset({
                asset: getERC20(sourceChain, "WEETH"),
                withdrawDelay: 60,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );

        bool allowPublicDeposits = true;
        bool allowPublicWithdraws = true;
        uint64 shareLockPeriod = 0;
        address delayedWithdrawFeeAddress = getAddress(sourceChain, "liquidPayoutAddress");

        vm.startBroadcast(privateKey);

        _deploy(
            "OptimismBridgingTestVaultDeployment.json",
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
            getAddress(sourceChain, "dev1Address")
        );

        vm.stopBroadcast();
    }
}
