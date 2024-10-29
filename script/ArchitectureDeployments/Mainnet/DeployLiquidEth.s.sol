// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DeployArcticArchitecture, ERC20, Deployer} from "script/ArchitectureDeployments/DeployArcticArchitecture.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {ChainValues} from "test/resources/ChainValues.sol";

// Import Decoder and Sanitizer to deploy.
import {EtherFiLiquidEthDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidEthDecoderAndSanitizer.sol";

/**
 *  source .env && forge script script/ArchitectureDeployments/Mainnet/DeployLiquidEth.s.sol:DeployLiquidEthScript --with-gas-price 10000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployLiquidEthScript is DeployArcticArchitecture, ChainValues {
    using AddressToBytes32Lib for address;

    uint256 public privateKey;

    // Deployment parameters
    string public boringVaultName = "Ether.Fi Liquid ETH Vault";
    string public boringVaultSymbol = "liquidETH";
    uint8 public boringVaultDecimals = 18;
    string internal sourceChain = mainnet;
    address public owner;

    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        owner = getAddress(sourceChain, "dev0Address");
        // Configure the deployment.
        configureDeployment.deployContracts = true;
        configureDeployment.setupRoles = false;
        configureDeployment.setupDepositAssets = false;
        configureDeployment.setupWithdrawAssets = false;
        configureDeployment.finishSetup = false;
        configureDeployment.setupTestUser = false;
        configureDeployment.saveDeploymentDetails = true;
        configureDeployment.deployerAddress = getAddress(sourceChain, "deployerAddress");
        configureDeployment.balancerVault = getAddress(sourceChain, "balancerVault");
        configureDeployment.WETH = getAddress(sourceChain, "WETH");

        // Save deployer.
        deployer = Deployer(configureDeployment.deployerAddress);

        // Define names to determine where contracts are deployed.
        names.rolesAuthority = EtherFiLiquidEthRolesAuthorityName;
        names.lens = ArcticArchitectureLensName;
        names.boringVault = EtherFiLiquidEthName;
        names.manager = EtherFiLiquidEthManagerName;
        names.accountant = EtherFiLiquidEthAccountantName;
        names.teller = EtherFiLiquidEthTellerName;
        names.rawDataDecoderAndSanitizer = EtherFiLiquidEthDecoderAndSanitizerName;
        names.delayedWithdrawer = EtherFiLiquidEthDelayedWithdrawer;

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
                asset: getERC20(sourceChain, "EETH"),
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
                asset: getERC20(sourceChain, "WEETH"),
                isPeggedToBase: false,
                rateProvider: getAddress(sourceChain, "WEETH"),
                genericRateProviderName: "",
                target: address(0),
                selector: bytes4(0),
                params: [bytes32(0), 0, 0, 0, 0, 0, 0, 0]
            })
        );
        // bytes4 selector = bytes4(keccak256(abi.encodePacked("getValue(address,uint256,address)")));
        // uint256 amount = 1e18;
        // depositAssets.push(
        //     DepositAsset({
        //         asset: WSTETH,
        //         isPeggedToBase: false,
        //         rateProvider: address(0),
        //         genericRateProviderName: WstETHRateProviderName,
        //         target: liquidV1PriceRouter,
        //         selector: selector,
        //         params: [address(WSTETH).toBytes32(), bytes32(amount), address(WETH).toBytes32(), 0, 0, 0, 0, 0]
        //     })
        // );

        // Setup withdraw assets.
        withdrawAssets.push(
            WithdrawAsset({
                asset: getERC20(sourceChain, "WETH"),
                withdrawDelay: 3 days,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );

        withdrawAssets.push(
            WithdrawAsset({
                asset: getERC20(sourceChain, "EETH"),
                withdrawDelay: 3 days,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );

        withdrawAssets.push(
            WithdrawAsset({
                asset: getERC20(sourceChain, "WEETH"),
                withdrawDelay: 3 days,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );

        bool allowPublicDeposits = false;
        bool allowPublicWithdraws = false;
        uint64 shareLockPeriod = 1 days;
        address delayedWithdrawFeeAddress = getAddress(sourceChain, "liquidPayoutAddress");

        vm.startBroadcast(privateKey);

        _deploy(
            "LiquidEthDeployment.json",
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
