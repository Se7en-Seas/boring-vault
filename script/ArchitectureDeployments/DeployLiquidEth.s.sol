// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {DeployArcticArchitecture, ERC20, Deployer} from "script/ArchitectureDeployments/DeployArcticArchitecture.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";

// Import Decoder and Sanitizer to deploy.
import {EtherFiLiquidEthDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidEthDecoderAndSanitizer.sol";

/**
 *  source .env && forge script script/DeployLiquidEth.s.sol:DeployLiquidEthScript --with-gas-price 30000000000 --slow --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployLiquidEthScript is DeployArcticArchitecture {
    using AddressToBytes32Lib for address;

    uint256 public privateKey;

    // Deployment parameters
    string public boringVaultName = "Ether.Fi Liquid ETH Vault";
    string public boringVaultSymbol = "liquidETH";
    uint8 public boringVaultDecimals = 18;
    address public owner = dev0Address;

    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        // Define names to determine where contracts are deployed.
        names.rolesAuthority = EtherFiLiquidEthRolesAuthorityName;
        names.lens = ArcticArchitectureLensName;
        names.boringVault = EtherFiLiquidEthName;
        names.manager = EtherFiLiquidEthManagerName;
        names.accountant = EtherFiLiquidEthAccountantName;
        names.teller = EtherFiLiquidEthTellerName;
        names.rawDataDecoderAndSanitizer = EtherFiLiquidEthDecoderAndSanitizerName;

        // Define Accountant Parameters.
        accountantParameters.payoutAddress = liquidPayoutAddress;
        accountantParameters.base = WETH;
        // Decimals are in terms of `base`.
        accountantParameters.startingExchangeRate = 1e18;
        //  4 decimals
        accountantParameters.managementFee = 0.02e4;
        accountantParameters.allowedExchangeRateChangeLower = 0.995e4;
        accountantParameters.allowedExchangeRateChangeUpper = 1.005e4;
        // Minimum time(in seconds) to pass between updated without triggering a pause.
        accountantParameters.minimumUpateDelayInSeconds = 1 days / 4;

        // Define Decoder and Sanitizer deployment details.
        bytes memory creationCode = type(EtherFiLiquidEthDecoderAndSanitizer).creationCode;
        bytes memory constructorArgs =
            abi.encode(deployer.getAddress(names.boringVault), uniswapV3NonFungiblePositionManager);

        // Setup alternative assets.
        alternativeAssets.push(
            AlternativeAsset({
                asset: EETH,
                isPeggedToBase: true,
                rateProvider: address(0),
                genericRateProviderName: "",
                target: address(0),
                selector: bytes4(0),
                params: [bytes32(0), 0, 0, 0, 0, 0, 0, 0]
            })
        );
        alternativeAssets.push(
            AlternativeAsset({
                asset: WEETH,
                isPeggedToBase: false,
                rateProvider: address(WEETH),
                genericRateProviderName: "",
                target: address(0),
                selector: bytes4(0),
                params: [bytes32(0), 0, 0, 0, 0, 0, 0, 0]
            })
        );
        bytes4 selector = bytes4(keccak256(abi.encodePacked("getValue(address,uint256,address)")));
        uint256 amount = 1e18;
        alternativeAssets.push(
            AlternativeAsset({
                asset: WSTETH,
                isPeggedToBase: false,
                rateProvider: address(0),
                genericRateProviderName: WstETHRateProviderName,
                target: liquidV1PriceRouter,
                selector: selector,
                params: [address(WSTETH).toBytes32(), bytes32(amount), address(WETH).toBytes32(), 0, 0, 0, 0, 0]
            })
        );

        bool allowPublicDeposits = true;
        uint64 shareLockPeriod = 1 days;

        vm.startBroadcast(privateKey);

        _deploy(
            "LiquidEthDeployment.json",
            owner,
            boringVaultName,
            boringVaultSymbol,
            boringVaultDecimals,
            creationCode,
            constructorArgs,
            allowPublicDeposits,
            shareLockPeriod,
            dev1Address
        );

        vm.stopBroadcast();
    }
}
