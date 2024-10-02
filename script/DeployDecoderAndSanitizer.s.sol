// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ITBPositionDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ITB/ITBPositionDecoderAndSanitizer.sol";
import {EtherFiLiquidUsdDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidUsdDecoderAndSanitizer.sol";
import {PancakeSwapV3FullDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/PancakeSwapV3FullDecoderAndSanitizer.sol";
import {AerodromeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/AerodromeDecoderAndSanitizer.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {PointFarmingDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/PointFarmingDecoderAndSanitizer.sol";

import {BoringDrone} from "src/base/Drones/BoringDrone.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployDecoderAndSanitizer.s.sol:DeployDecoderAndSanitizerScript --with-gas-price 30000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployDecoderAndSanitizerScript is Script, ContractNames, MainnetAddresses {
    uint256 public privateKey;
    Deployer public deployer = Deployer(deployerAddress);

    address boringVault = 0xf8203A33027607D2C82dFd67b46986096257dFA5;

    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        // creationCode = type(AerodromeDecoderAndSanitizer).creationCode;
        // constructorArgs =
        //     abi.encode(0xf0bb20865277aBd641a307eCe5Ee04E79073416C, 0x416b433906b1B72FA758e166e239c43d68dC6F29);
        // deployer.deployContract(EtherFiLiquidEthAerodromeDecoderAndSanitizerName, creationCode, constructorArgs, 0);

        // creationCode = type(BoringDrone).creationCode;
        // constructorArgs = abi.encode(0xf8203A33027607D2C82dFd67b46986096257dFA5, 0);
        // deployer.deployContract("btv-drone V0.1-0", creationCode, constructorArgs, 0);

        // creationCode = type(PancakeSwapV3FullDecoderAndSanitizer).creationCode;
        // constructorArgs = abi.encode(boringVault, pancakeSwapV3NonFungiblePositionManager, pancakeSwapV3MasterChefV3);
        // deployer.deployContract(EtherFiElixirUsdPancakeSwapDecoderAndSanitizerName, creationCode, constructorArgs, 0);

        creationCode = type(PointFarmingDecoderAndSanitizer).creationCode;
        constructorArgs = abi.encode(boringVault);
        deployer.deployContract(BridgingTestVaultEthDecoderAndSanitizerName, creationCode, constructorArgs, 0);

        vm.stopBroadcast();
    }
}
