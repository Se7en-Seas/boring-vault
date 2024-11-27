// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ITBPositionDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ITB/ITBPositionDecoderAndSanitizer.sol";
import {EtherFiLiquidUsdDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidUsdDecoderAndSanitizer.sol";
import {PancakeSwapV3FullDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/PancakeSwapV3FullDecoderAndSanitizer.sol";
import {AerodromeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/AerodromeDecoderAndSanitizer.sol";
import {EtherFiLiquidEthDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidEthDecoderAndSanitizer.sol";
import {OnlyKarakDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/OnlyKarakDecoderAndSanitizer.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {PointFarmingDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/PointFarmingDecoderAndSanitizer.sol";
import {LombardBtcDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LombardBtcDecoderAndSanitizer.sol";

import {BoringDrone} from "src/base/Drones/BoringDrone.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/Test.sol";

/**
 *  source .env && forge script script/DeployDecoderAndSanitizer.s.sol:DeployDecoderAndSanitizerScript --with-gas-price 30000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployDecoderAndSanitizerScript is Script, Test, ContractNames, MainnetAddresses {
    uint256 public privateKey;
    Deployer public deployer = Deployer(deployerAddress);

    address boringVault = 0x5401b8620E5FB570064CA9114fd1e135fd77D57c;

    function setUp() external {
        //privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("base");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        console.log(privateKey);

        creationCode = type(AerodromeDecoderAndSanitizer).creationCode;
        address aerodromeNonFungiblePositionManager = 0x827922686190790b37229fd06084350E74485b72;
        constructorArgs = abi.encode(boringVault, aerodromeNonFungiblePositionManager);
        deployer.deployContract(LombardBtcAerodromeDecoderAndSanitizerName, creationCode, constructorArgs, 0);

        // creationCode = type(OnlyKarakDecoderAndSanitizer).creationCode;
        // constructorArgs = abi.encode(boringVault);
        // deployer.deployContract(EtherFiLiquidEthDecoderAndSanitizerName, creationCode, constructorArgs, 0);

        // creationCode = type(PancakeSwapV3FullDecoderAndSanitizer).creationCode;
        // constructorArgs = abi.encode(boringVault, pancakeSwapV3NonFungiblePositionManager, pancakeSwapV3MasterChefV3);
        // deployer.deployContract(LombardPancakeSwapDecoderAndSanitizerName, creationCode, constructorArgs, 0);

        //creationCode = type(ITBPositionDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(eEigen);
        //deployer.deployContract(
        //    "ITB Eigen Position Manager Decoder and Sanitizer V0.1", creationCode, constructorArgs, 0
        //);
        // creationCode = type(ITBPositionDecoderAndSanitizer).creationCode;
        // constructorArgs = abi.encode(liquidUsd);
        // deployer.deployContract(ItbPositionDecoderAndSanitizerName, creationCode, constructorArgs, 0);

        //creationCode = type(EtherFiLiquidUsdDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(liquidUsd, uniswapV3NonFungiblePositionManager);
        //deployer.deployContract(EtherFiLiquidUsdDecoderAndSanitizerName, creationCode, constructorArgs, 0);

        creationCode = type(LombardBtcDecoderAndSanitizer).creationCode;
        address baseUniswapV3NonFungiblePositionManager = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
        constructorArgs = abi.encode(boringVault, baseUniswapV3NonFungiblePositionManager);
        deployer.deployContract(LombardBtcDecoderAndSanitizerName, creationCode, constructorArgs, 0);

        // new LombardBtcDecoderAndSanitizer(boringVault, baseUniswapV3NonFungiblePositionManager);

        vm.stopBroadcast();
    }
}
