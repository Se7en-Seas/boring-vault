// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {DeployArcticArchitecture, ERC20, Deployer} from "script/ArchitectureDeployments/DeployArcticArchitecture.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";

// Import Decoder and Sanitizer to deploy.
import {EtherFiLiquidBtcDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidBtcDecoderAndSanitizer.sol";

/**
 *  source .env && forge script script/ArchitectureDeployments/DeployLiquidBtc.s.sol:DeployLiquidBtcScript --with-gas-price 30000000000 --slow --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployLiquidBtcScript is DeployArcticArchitecture {
    using AddressToBytes32Lib for address;

    uint256 public privateKey;

    // Deployment parameters
    string public boringVaultName = "Ether.Fi Liquid BTC Vault";
    string public boringVaultSymbol = "liquidBtc";
    uint8 public boringVaultDecimals = 8;
    address public owner = dev0Address;

    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        // Define names to determine where contracts are deployed.
        names.rolesAuthority = EtherFiLiquidBtcRolesAuthorityName;
        names.lens = ArcticArchitectureLensName;
        names.boringVault = EtherFiLiquidBtcName;
        names.manager = EtherFiLiquidBtcManagerName;
        names.accountant = EtherFiLiquidBtcAccountantName;
        names.teller = EtherFiLiquidBtcTellerName;
        names.rawDataDecoderAndSanitizer = EtherFiLiquidBtcDecoderAndSanitizerName;

        // Define Accountant Parameters.
        accountantParameters.payoutAddress = liquidPayoutAddress;
        accountantParameters.base = WBTC;
        // Decimals are in terms of `base`.
        accountantParameters.startingExchangeRate = 1e8;
        //  4 decimals
        accountantParameters.managementFee = 0.02e4;
        accountantParameters.allowedExchangeRateChangeLower = 0.995e4;
        accountantParameters.allowedExchangeRateChangeUpper = 1.005e4;
        // Minimum time(in seconds) to pass between updated without triggering a pause.
        accountantParameters.minimumUpateDelayInSeconds = 1 days / 4;

        // Define Decoder and Sanitizer deployment details.
        bytes memory creationCode = type(EtherFiLiquidBtcDecoderAndSanitizer).creationCode;
        bytes memory constructorArgs =
            abi.encode(deployer.getAddress(names.boringVault), uniswapV3NonFungiblePositionManager);

        // Setup alternative assets.
        // none

        bool allowPublicDeposits = true;
        uint64 shareLockPeriod = 1 days;

        vm.startBroadcast(privateKey);

        _deploy(
            "LiquidBtcDeployment.json",
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
