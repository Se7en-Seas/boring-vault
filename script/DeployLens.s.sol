// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {ArcticArchitectureLens} from "src/helper/ArcticArchitectureLens.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployLens.s.sol:DeployLensScript --with-gas-price 30000000000 --slow --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployLensScript is Script {
    uint256 public privateKey;

    function setUp() external {
        privateKey = vm.envUint("PRIVATE_KEY");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        vm.startBroadcast(privateKey);

        new ArcticArchitectureLens();

        vm.stopBroadcast();
    }
}
