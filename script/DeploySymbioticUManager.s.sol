// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {BaseMerkleRootGenerator} from "resources/BaseMerkleRootGenerator.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SymbioticUManager, DefaultCollateral} from "src/micro-managers/SymbioticUManager.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {Deployer} from "src/helper/Deployer.sol";

/**
 *  source .env && forge script script/DeploySymbioticUManager.s.sol:DeploySymbioticUManagerScript --with-gas-price 10000000000 --slow --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 */
contract DeploySymbioticUManagerScript is BaseMerkleRootGenerator, ContractNames {
    using FixedPointMathLib for uint256;

    uint256 public privateKey;

    address public managerAddress = 0xcFF411d5C54FE0583A984beE1eF43a4776854B9A;
    address public rawDataDecoderAndSanitizer = 0xdaEfE2146908BAd73A1C45f75eB2B8E46935c781;
    BoringVault public boringVault = BoringVault(payable(0x08c6F91e2B681FaF5e17227F2a44C307b3C1364C));
    ManagerWithMerkleVerification public manager =
        ManagerWithMerkleVerification(0xcFF411d5C54FE0583A984beE1eF43a4776854B9A);
    address public accountantAddress = 0xc315D6e14DDCDC7407784e2Caf815d131Bc1D3E7;
    RolesAuthority public rolesAuthority;
    SymbioticUManager public symbioticUManager;

    Deployer public deployer = Deployer(deployerAddress);

    uint8 public constant STRATEGIST_MULTISIG_ROLE = 10;
    uint8 public constant SNIPER_ROLE = 88;

    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("mainnet");
    }

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateSniperMerkleRoot();
    }

    function generateSniperMerkleRoot() public {
        rolesAuthority = RolesAuthority(deployer.getAddress(SevenSeasRolesAuthorityName));
        updateAddresses(address(boringVault), rawDataDecoderAndSanitizer, managerAddress, accountantAddress);

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        leafIndex = type(uint256).max;
        _addSymbioticApproveAndDepositLeaf(leafs, sUSDeDefaultCollateral);

        string memory filePath = "./leafs/LiquidUsdSniperLeafs.json";

        bytes32[][] memory merkleTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, merkleTree[merkleTree.length - 1][0], merkleTree);

        vm.startBroadcast(privateKey);

        symbioticUManager = new SymbioticUManager(dev0Address, rolesAuthority, address(manager), address(boringVault));

        symbioticUManager.updateMerkleTree(merkleTree, false);

        symbioticUManager.setConfiguration(DefaultCollateral(sUSDeDefaultCollateral), 1e18, rawDataDecoderAndSanitizer);

        // rolesAuthority.setRoleCapability(
        //     STRATEGIST_MULTISIG_ROLE, address(symbioticUManager), SymbioticUManager.updateMerkleTree.selector, true
        // );
        // rolesAuthority.setRoleCapability(
        //     STRATEGIST_MULTISIG_ROLE, address(symbioticUManager), SymbioticUManager.setConfiguration.selector, true
        // );

        symbioticUManager.transferOwnership(dev1Address);

        /// Note need to give strategist role to symbioticUManager
        /// Note need to set merkle root in the manager

        vm.stopBroadcast();
    }
}
