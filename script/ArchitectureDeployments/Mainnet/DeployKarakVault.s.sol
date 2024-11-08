// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DeployArcticArchitecture, ERC20, Deployer} from "script/ArchitectureDeployments/DeployArcticArchitecture.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";

// Import Decoder and Sanitizer to deploy.
import {ITBPositionDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ITB/ITBPositionDecoderAndSanitizer.sol";

/**
 *  source .env && forge script script/ArchitectureDeployments/Mainnet/DeployKarakVault.s.sol:DeployKarakVaultScript --with-gas-price 10000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployKarakVaultScript is DeployArcticArchitecture, MainnetAddresses {
    using AddressToBytes32Lib for address;

    uint256 public privateKey;

    // Deployment parameters
    string public boringVaultName = "King Karak LRT";
    string public boringVaultSymbol = "weETHk";
    uint8 public boringVaultDecimals = 18;
    address public owner = dev0Address;

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
        names.rolesAuthority = KarakVaultRolesAuthorityName;
        names.lens = ArcticArchitectureLensName;
        names.boringVault = KarakVaultName;
        names.manager = KarakVaultManagerName;
        names.accountant = KarakVaultAccountantName;
        names.teller = KarakVaultTellerName;
        names.rawDataDecoderAndSanitizer = KarakVaultDecoderAndSanitizerName;
        names.delayedWithdrawer = KarakVaultDelayedWithdrawer;

        // Define Accountant Parameters.
        accountantParameters.payoutAddress = liquidPayoutAddress;
        accountantParameters.base = WETH;
        // Decimals are in terms of `base`.
        accountantParameters.startingExchangeRate = 1e18;
        //  4 decimals
        accountantParameters.platformFee = 0;
        accountantParameters.performanceFee = 0;
        accountantParameters.allowedExchangeRateChangeLower = 0.995e4;
        accountantParameters.allowedExchangeRateChangeUpper = 1.005e4;
        // Minimum time(in seconds) to pass between updated without triggering a pause.
        accountantParameters.minimumUpateDelayInSeconds = 1 days / 4;

        // Define Decoder and Sanitizer deployment details.
        bytes memory creationCode = type(ITBPositionDecoderAndSanitizer).creationCode;
        bytes memory constructorArgs =
            abi.encode(deployer.getAddress(names.boringVault), uniswapV3NonFungiblePositionManager);

        // Setup extra deposit assets.
        uint256 amount = 1e18;
        depositAssets.push(
            DepositAsset({
                asset: EETH,
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
                asset: WEETH,
                isPeggedToBase: false,
                rateProvider: address(WEETH),
                genericRateProviderName: "",
                target: address(0),
                selector: bytes4(0),
                params: [bytes32(0), 0, 0, 0, 0, 0, 0, 0]
            })
        );
        depositAssets.push(
            DepositAsset({
                asset: WSTETH,
                isPeggedToBase: false,
                rateProvider: address(0),
                genericRateProviderName: WSTETHRateProviderName,
                target: address(WSTETH),
                selector: bytes4(keccak256(abi.encodePacked("getStETHByWstETH(uint256)"))),
                params: [bytes32(amount), 0, 0, 0, 0, 0, 0, 0]
            })
        );
        depositAssets.push(
            DepositAsset({
                asset: cbETH,
                isPeggedToBase: false,
                rateProvider: address(0),
                genericRateProviderName: CBETHRateProviderName,
                target: address(cbETH),
                selector: bytes4(keccak256(abi.encodePacked("exchangeRate()"))),
                params: [bytes32(0), 0, 0, 0, 0, 0, 0, 0]
            })
        );
        depositAssets.push(
            DepositAsset({
                asset: WBETH,
                isPeggedToBase: false,
                rateProvider: address(0),
                genericRateProviderName: WBETHRateProviderName,
                target: address(WBETH),
                selector: bytes4(keccak256(abi.encodePacked("exchangeRate()"))),
                params: [bytes32(0), 0, 0, 0, 0, 0, 0, 0]
            })
        );
        depositAssets.push(
            DepositAsset({
                asset: RETH,
                isPeggedToBase: false,
                rateProvider: address(0),
                genericRateProviderName: RETHRateProviderName,
                target: address(RETH),
                selector: bytes4(keccak256(abi.encodePacked("getExchangeRate()"))),
                params: [bytes32(0), 0, 0, 0, 0, 0, 0, 0]
            })
        );
        depositAssets.push(
            DepositAsset({
                asset: METH,
                isPeggedToBase: false,
                rateProvider: address(0),
                genericRateProviderName: METHRateProviderName,
                target: mantleLspStaking,
                selector: bytes4(keccak256(abi.encodePacked("mETHToETH(uint256)"))),
                params: [bytes32(amount), 0, 0, 0, 0, 0, 0, 0]
            })
        );
        depositAssets.push(
            DepositAsset({
                asset: SWETH,
                isPeggedToBase: false,
                rateProvider: address(0),
                genericRateProviderName: SWETHRateProviderName,
                target: address(SWETH),
                selector: bytes4(keccak256(abi.encodePacked("swETHToETHRate()"))),
                params: [bytes32(0), 0, 0, 0, 0, 0, 0, 0]
            })
        );
        depositAssets.push(
            DepositAsset({
                asset: SFRXETH,
                isPeggedToBase: false,
                rateProvider: address(0),
                genericRateProviderName: SFRXETHRateProviderName,
                target: address(SFRXETH),
                selector: bytes4(keccak256(abi.encodePacked("previewRedeem(uint256)"))),
                params: [bytes32(amount), 0, 0, 0, 0, 0, 0, 0]
            })
        );
        depositAssets.push(
            DepositAsset({
                asset: ETHX,
                isPeggedToBase: false,
                rateProvider: ETHX_RATE_PROVIDER,
                genericRateProviderName: "",
                target: address(0),
                selector: bytes4(0),
                params: [bytes32(0), 0, 0, 0, 0, 0, 0, 0]
            })
        );

        // Setup withdraw assets.
        withdrawAssets.push(
            WithdrawAsset({
                asset: WETH,
                withdrawDelay: 3 days,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );

        withdrawAssets.push(
            WithdrawAsset({
                asset: EETH,
                withdrawDelay: 3 days,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );

        withdrawAssets.push(
            WithdrawAsset({
                asset: WEETH,
                withdrawDelay: 3 days,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );

        withdrawAssets.push(
            WithdrawAsset({
                asset: WSTETH,
                withdrawDelay: 3 days,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );
        withdrawAssets.push(
            WithdrawAsset({
                asset: cbETH,
                withdrawDelay: 3 days,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );
        withdrawAssets.push(
            WithdrawAsset({
                asset: WBETH,
                withdrawDelay: 3 days,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );
        withdrawAssets.push(
            WithdrawAsset({
                asset: RETH,
                withdrawDelay: 3 days,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );
        withdrawAssets.push(
            WithdrawAsset({
                asset: METH,
                withdrawDelay: 3 days,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );
        withdrawAssets.push(
            WithdrawAsset({
                asset: SWETH,
                withdrawDelay: 3 days,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );
        withdrawAssets.push(
            WithdrawAsset({
                asset: SFRXETH,
                withdrawDelay: 3 days,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );
        withdrawAssets.push(
            WithdrawAsset({
                asset: ETHX,
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

        vm.startBroadcast(privateKey);

        _deploy(
            "KarakVaultDeployment.json",
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
