// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {
    DeployArcticArchitectureManagementOnly,
    ERC20,
    Deployer
} from "script/ArchitectureDeployments/DeployArcticArchitectureManagementOnly.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {BoringDrone} from "src/base/Drones/BoringDrone.sol";

// Import Decoder and Sanitizer to deploy.
import {PointFarmingDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/PointFarmingDecoderAndSanitizer.sol";

/**
 *  source .env && forge script script/ArchitectureDeployments/Linea/DeploySkyFallVault.s.sol:DeploySkyFallVaultScript --evm-version london --broadcast --etherscan-api-key $LINEASCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeploySkyFallVaultScript is DeployArcticArchitectureManagementOnly, MerkleTreeHelper {
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
        vm.createSelectFork("linea");
        setSourceChainName(linea);

        owner = getAddress(sourceChain, "dev0Address");
        testAddress = getAddress(sourceChain, "dev1Address");
        WETH = getERC20(sourceChain, "WETH");
        balancerVault = address(0);
        deployerAddress = getAddress(sourceChain, "boringDeployerContract");
        uniswapV3NonFungiblePositionManager = address(0);
        liquidPayoutAddress = getAddress(sourceChain, "liquidPayoutAddress");

        droneCount = 1;
    }

    function run() external {
        // Configure the deployment.
        configureDeployment.deployContracts = true;
        configureDeployment.setupRoles = true;
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
        names.boringVault = SkyFallVaultName;
        names.manager = SkyFallVaultManagerName;
        names.rawDataDecoderAndSanitizer = SkyFallVaultDecoderAndSanitizerName;
        names.droneBaseName = SkyFallVaultDroneName;

        // Define Decoder and Sanitizer deployment details.
        bytes memory creationCode = type(PointFarmingDecoderAndSanitizer).creationCode;
        bytes memory constructorArgs = abi.encode(deployer.getAddress(names.boringVault));

        vm.startBroadcast(privateKey);

        _deploy(
            "Linea/SkyFallDeployment.json",
            owner,
            boringVaultName,
            boringVaultSymbol,
            boringVaultDecimals,
            creationCode,
            constructorArgs,
            testAddress
        );

        vm.stopBroadcast();
    }
}
