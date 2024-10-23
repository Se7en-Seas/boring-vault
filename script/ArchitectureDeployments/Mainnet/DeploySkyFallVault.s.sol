// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DeployArcticArchitecture, ERC20, Deployer} from "script/ArchitectureDeployments/DeployArcticArchitecture.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {BoringDrone} from "src/base/Drones/BoringDrone.sol";

// Import Decoder and Sanitizer to deploy.
import {PointFarmingDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/PointFarmingDecoderAndSanitizer.sol";

/**
 *  source .env && forge script script/ArchitectureDeployments/Mainnet/DeploySkyFallVault.s.sol:DeploySkyFallVaultScript --with-gas-price 8000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeploySkyFallVaultScript is DeployArcticArchitecture, MerkleTreeHelper {
    using AddressToBytes32Lib for address;

    uint256 public privateKey;

    // Deployment parameters
    string public boringVaultName = "Ether.Fi Liquid SkyFall";
    string public boringVaultSymbol = "liquidSkyFall";
    uint8 public boringVaultDecimals = 18;

    address internal owner;
    address internal testAddress;
    ERC20 internal WETH;
    address internal balancerVault;
    address internal deployerAddress;
    address internal uniswapV3NonFungiblePositionManager;
    address internal liquidPayoutAddress;

    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("mainnet");
        setSourceChainName(mainnet);

        owner = getAddress(sourceChain, "dev0Address");
        testAddress = getAddress(sourceChain, "dev1Address");
        WETH = getERC20(sourceChain, "WETH");
        balancerVault = getAddress(sourceChain, "balancerVault");
        deployerAddress = getAddress(sourceChain, "boringDeployerContract");
        uniswapV3NonFungiblePositionManager = getAddress(sourceChain, "uniswapV3NonFungiblePositionManager");
        liquidPayoutAddress = getAddress(sourceChain, "liquidPayoutAddress");

        droneCount = 1;
    }

    function run() external {
        // Configure the deployment.
        configureDeployment.deployContracts = false;
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
        names.rolesAuthority = SkyFallVaultRolesAuthorityName;
        names.lens = ArcticArchitectureLensName;
        names.boringVault = SkyFallVaultName;
        names.manager = SkyFallVaultManagerName;
        names.accountant = SkyFallVaultAccountantName;
        names.teller = SkyFallVaultTellerName;
        names.rawDataDecoderAndSanitizer = SkyFallVaultDecoderAndSanitizerName;
        names.delayedWithdrawer = SkyFallVaultDelayedWithdrawer;
        names.droneBaseName = SkyFallVaultDroneName;

        // Define Accountant Parameters.
        accountantParameters.payoutAddress = liquidPayoutAddress;
        accountantParameters.base = WETH;
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
        bytes memory creationCode = type(PointFarmingDecoderAndSanitizer).creationCode;
        bytes memory constructorArgs = abi.encode(deployer.getAddress(names.boringVault));

        // Setup extra deposit assets.
        // none

        bool allowPublicDeposits = true;
        bool allowPublicWithdraws = false;
        uint64 shareLockPeriod = 0;
        address delayedWithdrawFeeAddress = liquidPayoutAddress;

        vm.startBroadcast(privateKey);

        _deploy(
            "Mainnet/SkyFallVaultDeployment.json",
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
            testAddress
        );

        vm.stopBroadcast();
    }
}
