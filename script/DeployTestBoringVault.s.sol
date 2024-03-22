// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {EtherFiLiquidDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/EtherFiLiquidDecoderAndSanitizer.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployTestBoringVault.s.sol:DeployTestBoringVaultScript --evm-version london --with-gas-price 100000000 --slow --broadcast --etherscan-api-key $ARBISCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployTestBoringVaultScript is Script {
    uint256 public privateKey;

    ManagerWithMerkleVerification public manager;
    BoringVault public boring_vault;
    address public rawDataDecoderAndSanitizer;

    address public managerAddress = 0xeeF7b7205CAF2Bcd71437D9acDE3874C3388c138;
    address public owner = 0x552acA1343A6383aF32ce1B7c7B1b47959F7ad90;
    address public balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    function setUp() external {
        privateKey = vm.envUint("PRIVATE_KEY");
        vm.createSelectFork("arbitrum");
    }

    function run() external {
        vm.startBroadcast(privateKey);

        boring_vault = new BoringVault(owner, "Test Boring Vault", "BV", 18);

        manager = new ManagerWithMerkleVerification(owner, managerAddress, owner, address(boring_vault), balancerVault);

        rawDataDecoderAndSanitizer = address(
            new EtherFiLiquidDecoderAndSanitizer(address(boring_vault), 0xC36442b4a4522E871399CD717aBDD847Ab11FE88)
        );

        boring_vault.grantRole(boring_vault.MANAGER_ROLE(), address(manager));
        boring_vault.grantRole(boring_vault.MINTER_ROLE(), managerAddress);
        boring_vault.grantRole(boring_vault.BURNER_ROLE(), managerAddress);
        manager.grantRole(manager.ADMIN_ROLE(), managerAddress);

        vm.stopBroadcast();
    }
}
