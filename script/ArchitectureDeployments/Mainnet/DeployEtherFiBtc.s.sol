// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DeployArcticArchitecture, ERC20, Deployer} from "script/ArchitectureDeployments/DeployArcticArchitecture.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";

// Import Decoder and Sanitizer to deploy.
import {EtherFiBtcDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/EtherFiBtcDecoderAndSanitizer.sol";

/**
 *  source .env && forge script script/ArchitectureDeployments/Mainnet/DeployEtherFiBtc.s.sol:DeployEtherFiBtcScript --with-gas-price 10000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployEtherFiBtcScript is DeployArcticArchitecture, MainnetAddresses {
    using AddressToBytes32Lib for address;

    uint256 public privateKey;

    // Deployment parameters
    string public boringVaultName = "ether.fi BTC";
    string public boringVaultSymbol = "eBTC";
    uint8 public boringVaultDecimals = 8;
    address public owner = dev1Address;

    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        // Configure the deployment.
        configureDeployment.deployContracts = false;
        configureDeployment.setupRoles = false;
        configureDeployment.setupDepositAssets = true;
        configureDeployment.setupWithdrawAssets = true;
        configureDeployment.finishSetup = false;
        configureDeployment.setupTestUser = false;
        configureDeployment.saveDeploymentDetails = true;
        configureDeployment.deployerAddress = deployerAddress;
        configureDeployment.balancerVault = balancerVault;
        configureDeployment.WETH = address(WETH);

        // Save deployer.
        deployer = Deployer(configureDeployment.deployerAddress);

        // Define names to determine where contracts are deployed.
        names.rolesAuthority = EtherFiBtcRolesAuthorityName;
        names.lens = ArcticArchitectureLensName;
        names.boringVault = EtherFiBtcName;
        names.manager = EtherFiBtcManagerName;
        names.accountant = EtherFiBtcAccountantName;
        names.teller = EtherFiBtcTellerName;
        names.rawDataDecoderAndSanitizer = EtherFiBtcDecoderAndSanitizerName;
        names.delayedWithdrawer = EtherFiBtcDelayedWithdrawer;

        // Define Accountant Parameters.
        accountantParameters.payoutAddress = liquidPayoutAddress;
        accountantParameters.base = WBTC;
        // Decimals are in terms of `base`.
        accountantParameters.startingExchangeRate = 1e8;
        //  4 decimals
        accountantParameters.managementFee = 0.02e4;
        accountantParameters.performanceFee = 0;
        accountantParameters.allowedExchangeRateChangeLower = 0.995e4;
        accountantParameters.allowedExchangeRateChangeUpper = 1.005e4;
        // Minimum time(in seconds) to pass between updated without triggering a pause.
        accountantParameters.minimumUpateDelayInSeconds = 1 days / 4;

        // Define Decoder and Sanitizer deployment details.
        bytes memory creationCode = type(EtherFiBtcDecoderAndSanitizer).creationCode;
        bytes memory constructorArgs =
            abi.encode(deployer.getAddress(names.boringVault), uniswapV3NonFungiblePositionManager);

        // Setup extra deposit assets.
        depositAssets.push(
            DepositAsset({
                asset: TBTC,
                isPeggedToBase: true,
                rateProvider: address(0),
                genericRateProviderName: "",
                target: address(0),
                selector: bytes4(0),
                params: [bytes32(0), 0, 0, 0, 0, 0, 0, 0]
            })
        );

        // Setup withdraw assets.
        withdrawAssets.push(
            WithdrawAsset({
                asset: WBTC,
                withdrawDelay: 3 days,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );
        withdrawAssets.push(
            WithdrawAsset({
                asset: TBTC,
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

        vm.startBroadcast();

        _deploy(
            "EtherFiBtcDeployment.json",
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
