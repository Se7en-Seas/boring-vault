// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {PaymentSplitter} from "src/helper/PaymentSplitter.sol";
import {ContractNames} from "resources/ContractNames.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployPaymentSplitter.s.sol:DeployPaymentSplitterScript --with-gas-price 7000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployPaymentSplitterScript is Script, ContractNames, MainnetAddresses {
    uint256 public privateKey;

    // Contracts to deploy
    Deployer public deployer = Deployer(deployerAddress);
    RolesAuthority public rolesAuthority;
    PaymentSplitter public splitter;
    address public accountDeploying = dev0Address;
    address public owner = dev1Address;

    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        address deployedAddress = _getAddressIfDeployed(PaymentSplitterRolesAuthorityName);
        if (deployedAddress == address(0)) {
            creationCode = type(RolesAuthority).creationCode;
            constructorArgs = abi.encode(owner, Authority(address(0)));
            rolesAuthority = RolesAuthority(
                deployer.deployContract(PaymentSplitterRolesAuthorityName, creationCode, constructorArgs, 0)
            );
        } else {
            rolesAuthority = RolesAuthority(deployedAddress);
        }

        creationCode = type(PaymentSplitter).creationCode;
        PaymentSplitter.SplitInformation[] memory splits = new PaymentSplitter.SplitInformation[](2);
        splits[0] = PaymentSplitter.SplitInformation({to: 0x5f0E7A424d306e9E310be4f5Bb347216e473Ae55, percent: 0.5e4});
        splits[1] = PaymentSplitter.SplitInformation({to: 0xA9962a5BfBea6918E958DeE0647E99fD7863b95A, percent: 0.5e4});
        constructorArgs = abi.encode(accountDeploying, 1e4, splits);
        splitter = PaymentSplitter(deployer.deployContract(PaymentSplitterName, creationCode, constructorArgs, 0));

        splitter.setAuthority(rolesAuthority);
        splitter.transferOwnership(owner);

        vm.stopBroadcast();
    }

    function _getAddressIfDeployed(string memory name) internal view returns (address) {
        address deployedAt = deployer.getAddress(name);
        uint256 size;
        assembly {
            size := extcodesize(deployedAt)
        }
        return size > 0 ? deployedAt : address(0);
    }
}
