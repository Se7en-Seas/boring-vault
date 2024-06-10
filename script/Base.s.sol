// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19 <=0.9.0;

import { ICreateX } from "./../src/interfaces/ICreateX.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { Script, stdJson } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

abstract contract BaseScript is Script {
    using stdJson for string;
    using Strings for uint256;

    /// Custom base params
    ICreateX constant CREATEX = ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);
    address constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    string defaultConfigPath = "./deployment-config/DeploymentConfig.json";
    string config = vm.readFile(defaultConfigPath);
    address protocolAdmin = config.readAddress(".protocolAdmin");

    /// @dev Included to enable compilation of the script without a $MNEMONIC environment variable.
    string internal constant TEST_MNEMONIC = "test test test test test test test test test test test junk";

    /// @dev Needed for the deterministic deployments.
    bytes32 internal constant ZERO_SALT = bytes32(0);

    /// @dev The address of the transaction broadcaster.
    address internal broadcaster;

    /// @dev Used to derive the broadcaster's address if $ETH_FROM is not defined.
    string internal mnemonic;

    bool internal deployCreate2;

    /// @dev Initializes the transaction broadcaster like this:
    ///
    /// - If $ETH_FROM is defined, use it.
    /// - Otherwise, derive the broadcaster address from $MNEMONIC.
    /// - If $MNEMONIC is not defined, default to a test mnemonic.
    ///
    /// The use case for $ETH_FROM is to specify the broadcaster key and its address via the command line.
    constructor() {
        deployCreate2 = vm.envOr({ name: "CREATE2", defaultValue: true });
        address from = vm.envOr({ name: "ETH_FROM", defaultValue: address(0) });
        if (from != address(0)) {
            broadcaster = from;
        } else {
            mnemonic = vm.envOr({ name: "MNEMONIC", defaultValue: TEST_MNEMONIC });
            (broadcaster,) = deriveRememberKey({ mnemonic: mnemonic, index: 0 });
        }

        console2.log("broadcaster", broadcaster);
    }

    modifier broadcast() {
        vm.startBroadcast(broadcaster);
        _;
        vm.stopBroadcast();
    }

    modifier broadcastFrom(address from) {
        vm.startBroadcast(from);
        _;
        vm.stopBroadcast();
    }
}
