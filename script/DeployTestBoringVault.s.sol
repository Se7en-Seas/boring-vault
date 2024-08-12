// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {EtherFiLiquidDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/EtherFiLiquidDecoderAndSanitizer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployTestBoringVault.s.sol:DeployTestBoringVaultScript --with-gas-price 30000000000 --slow --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployTestBoringVaultScript is Script {
    uint256 public privateKey;

    ManagerWithMerkleVerification public manager;
    BoringVault public boring_vault;
    RolesAuthority public rolesAuthority;
    address public rawDataDecoderAndSanitizer;
    TellerWithMultiAssetSupport public teller;
    AccountantWithRateProviders public accountant;
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address public managerAddress = 0xeeF7b7205CAF2Bcd71437D9acDE3874C3388c138;
    address public owner = 0x552acA1343A6383aF32ce1B7c7B1b47959F7ad90;
    address public balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    function setUp() external {
        privateKey = vm.envUint("PRIVATE_KEY");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        vm.startBroadcast(privateKey);

        boring_vault = new BoringVault(owner, "Test Boring Vault", "BV", 18);

        manager = new ManagerWithMerkleVerification(owner, address(boring_vault), balancerVault);

        accountant = new AccountantWithRateProviders(
            owner, address(boring_vault), owner, 1e18, address(WETH), 1.001e4, 0.999e4, 1, 0, 0
        );
        teller = new TellerWithMultiAssetSupport(owner, address(boring_vault), address(accountant), WETH);

        rawDataDecoderAndSanitizer = address(
            new EtherFiLiquidDecoderAndSanitizer(address(boring_vault), 0xC36442b4a4522E871399CD717aBDD847Ab11FE88)
        );
        // rolesAuthority = new RolesAuthority(owner, Authority(address(0)));

        vm.stopBroadcast();
    }
}
