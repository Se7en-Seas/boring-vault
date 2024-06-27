// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {ChainlinkCCIPTeller} from "src/base/Roles/CrossChain/Bridges/CCIP/ChainlinkCCIPTeller.sol";
import {OptimismAddresses} from "test/resources/OptimismAddresses.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {BoringVault, Auth} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithRateProviders, IRateProvider} from "src/base/Roles/AccountantWithRateProviders.sol";
import {ContractNames} from "resources/ContractNames.sol";

import "forge-std/Script.sol";

/**
 *  source .env && forge script script/ArchitectureDeployments/Optimism/DeployTestCCIPTeller.s.sol:DeployTestCCIPTellerScript --with-gas-price 70000000 --evm-version london --slow --broadcast --etherscan-api-key $OPTIMISMSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployTestCCIPTellerScript is Script, OptimismAddresses, ContractNames {
    uint256 public privateKey;

    Deployer public deployer = Deployer(deployerAddress);
    RolesAuthority public rolesAuthority;
    BoringVault public boringVault;
    AccountantWithRateProviders public accountant;
    ChainlinkCCIPTeller public teller;

    uint64 public constant OPTIMISM_SELECTOR = 3734403246176062136;
    uint64 public constant ARBITRUM_SELECTOR = 4949039107694359620;

    uint8 public constant MINTER_ROLE = 2;
    uint8 public constant BURNER_ROLE = 3;

    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("optimism");
        rolesAuthority = RolesAuthority(deployer.getAddress(BridgingTestVaultEthRolesAuthorityName));
        boringVault = BoringVault(payable(deployer.getAddress(BridgingTestVaultEthName)));
        accountant = AccountantWithRateProviders(deployer.getAddress(BridgingTestVaultEthAccountantName));
        teller = ChainlinkCCIPTeller(deployer.getAddress(TestCCIPTellerName));
    }

    function run() external {
        vm.startBroadcast(privateKey);

        bytes memory creationCode = type(ChainlinkCCIPTeller).creationCode;
        bytes memory constructorArgs =
            abi.encode(dev0Address, address(boringVault), address(accountant), WETH, ccipRouter);

        teller = ChainlinkCCIPTeller(deployer.deployContract(TestCCIPTellerName, creationCode, constructorArgs, 0));

        teller.addChain(ARBITRUM_SELECTOR, true, true, address(teller), 100_000);

        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);
        vm.stopBroadcast();
    }
}
