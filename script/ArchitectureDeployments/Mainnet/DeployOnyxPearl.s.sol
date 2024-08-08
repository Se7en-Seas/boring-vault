// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {DeployArcticArchitecture, ERC20, Deployer} from "script/ArchitectureDeployments/DeployArcticArchitecture.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {ChainValues} from "test/resources/ChainValues.sol";

// Import Decoder and Sanitizer to deploy.
import {EtherFiLiquidEthDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidEthDecoderAndSanitizer.sol";

/**
 *  source .env && forge script script/ArchitectureDeployments/Mainnet/DeployOnyxPearl.s.sol:DeployOnyxPearlScript --with-gas-price 10000000000 --slow --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployOnyxPearlScript is DeployArcticArchitecture, ChainValues {
    using AddressToBytes32Lib for address;

    uint256 public privateKey;

    // Deployment parameters
    string public boringVaultName = "Onyx Pearl";
    string public boringVaultSymbol = "OP";
    uint8 public boringVaultDecimals = 18;
    string internal sourceChain = mainnet;
    address public owner;

    function setUp() external {
        privateKey = vm.envUint("ONYX_PEARL_DEPLOYER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        owner = 0x4bf96e802e02e2a14DbB36347cC49bfa8A2706Ae;
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
        // TODO make a seven seas deployer
        deployer = Deployer(configureDeployment.deployerAddress);

        // Define names to determine where contracts are deployed.
        names.rolesAuthority = OnyxPearlRolesAuthorityName;
        names.lens = ArcticArchitectureLensName;
        names.boringVault = OnyxPearlName;
        names.manager = OnyxPearlManagerName;
        names.accountant = OnyxPearlAccountantName;
        names.teller = OnyxPearlTellerName;
        names.rawDataDecoderAndSanitizer = OnyxPearlDecoderAndSanitizerName;
        names.delayedWithdrawer = OnyxPearlDelayedWithdrawer;

        // Define Accountant Parameters.
        accountantParameters.payoutAddress = getAddress(sourceChain, "liquidPayoutAddress");
        accountantParameters.base = getERC20(sourceChain, "WETH");
        // Decimals are in terms of `base`.
        accountantParameters.startingExchangeRate = 1e18;
        //  4 decimals
        accountantParameters.managementFee = 0;
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

        bool allowPublicDeposits = false;
        bool allowPublicWithdraws = false;
        uint64 shareLockPeriod = 1 days;
        address delayedWithdrawFeeAddress = getAddress(sourceChain, "liquidPayoutAddress");

        vm.startBroadcast(privateKey);

        _deploy(
            "OnyxPearlDeployment.json",
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
            getAddress(sourceChain, "dev1Address") // TODO need a new address
        );

        vm.stopBroadcast();
    }
}
