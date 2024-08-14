// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SymbioticUManager, DefaultCollateral} from "src/micro-managers/SymbioticUManager.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

/**
 *  source .env && forge script script/DeploySymbioticUManager.s.sol:DeploySymbioticUManagerScript --with-gas-price 10000000000 --slow --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 */
contract DeploySymbioticUManagerScript is MerkleTreeHelper, ContractNames {
    using FixedPointMathLib for uint256;

    uint256 public privateKey;

    address public managerAddress = 0x382d0106F308864D5462332D9D3bB54a60384B70;
    address public rawDataDecoderAndSanitizer = 0xa2Da7A948254692d7B261bBd27b3Cd1E2C7B033c;
    BoringVault public boringVault = BoringVault(payable(0x657e8C867D8B37dCC18fA4Caead9C45EB088C642));
    ManagerWithMerkleVerification public manager =
        ManagerWithMerkleVerification(0x382d0106F308864D5462332D9D3bB54a60384B70);
    address public accountantAddress = 0x1b293DC39F94157fA0D1D36d7e0090C8B8B8c13F;
    RolesAuthority public rolesAuthority;
    SymbioticUManager public symbioticUManager;

    Deployer public deployer;

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
        sourceChain = "mainnet";
        deployer = Deployer(getAddress(sourceChain, "deployerAddress"));

        rolesAuthority = RolesAuthority(deployer.getAddress(SevenSeasRolesAuthorityName));

        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", address(boringVault));
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        // ManageLeaf[] memory leafs = new ManageLeaf[](16);
        // _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "wstETHDefaultCollateral"));
        // _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "cbETHDefaultCollateral"));
        // _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "wBETHDefaultCollateral"));
        // _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "rETHDefaultCollateral"));
        // _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "mETHDefaultCollateral"));
        // _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "swETHDefaultCollateral"));
        // _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "sfrxETHDefaultCollateral"));
        // _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "ETHxDefaultCollateral"));

        // string memory filePath = "./leafs/SuperSymbioticSniperLeafs.json";

        // bytes32[][] memory merkleTree = _generateMerkleTree(leafs);

        // _generateLeafs(filePath, leafs, merkleTree[merkleTree.length - 1][0], merkleTree);

        vm.startBroadcast(privateKey);

        symbioticUManager = new SymbioticUManager(
            getAddress(sourceChain, "dev0Address"), rolesAuthority, address(manager), address(boringVault)
        );

        // symbioticUManager.updateMerkleTree(merkleTree, false);

        // symbioticUManager.setConfiguration(
        //     DefaultCollateral(getAddress(sourceChain, "wstETHDefaultCollateral")), 1e18, rawDataDecoderAndSanitizer
        // );
        // symbioticUManager.setConfiguration(
        //     DefaultCollateral(getAddress(sourceChain, "cbETHDefaultCollateral")), 1e18, rawDataDecoderAndSanitizer
        // );
        // symbioticUManager.setConfiguration(
        //     DefaultCollateral(getAddress(sourceChain, "wBETHDefaultCollateral")), 1e18, rawDataDecoderAndSanitizer
        // );
        // symbioticUManager.setConfiguration(
        //     DefaultCollateral(getAddress(sourceChain, "rETHDefaultCollateral")), 1e18, rawDataDecoderAndSanitizer
        // );
        // symbioticUManager.setConfiguration(
        //     DefaultCollateral(getAddress(sourceChain, "mETHDefaultCollateral")), 1e18, rawDataDecoderAndSanitizer
        // );
        // symbioticUManager.setConfiguration(
        //     DefaultCollateral(getAddress(sourceChain, "swETHDefaultCollateral")), 1e18, rawDataDecoderAndSanitizer
        // );
        // symbioticUManager.setConfiguration(
        //     DefaultCollateral(getAddress(sourceChain, "sfrxETHDefaultCollateral")), 1e18, rawDataDecoderAndSanitizer
        // );
        // symbioticUManager.setConfiguration(
        //     DefaultCollateral(getAddress(sourceChain, "ETHxDefaultCollateral")), 1e18, rawDataDecoderAndSanitizer
        // );

        // rolesAuthority.setRoleCapability(
        //     STRATEGIST_MULTISIG_ROLE, address(symbioticUManager), SymbioticUManager.updateMerkleTree.selector, true
        // );
        // rolesAuthority.setRoleCapability(
        //     STRATEGIST_MULTISIG_ROLE, address(symbioticUManager), SymbioticUManager.setConfiguration.selector, true
        // );
        // rolesAuthority.setRoleCapability(
        //     SNIPER_ROLE, address(symbioticUManager), SymbioticUManager.assemble.selector, true
        // );
        // rolesAuthority.setRoleCapability(
        //     SNIPER_ROLE, address(symbioticUManager), SymbioticUManager.fullAssemble.selector, true
        // );

        // rolesAuthority.transferOwnership(getAddress(sourceChain, "dev1Address"));
        // symbioticUManager.transferOwnership(getAddress(sourceChain, "dev1Address"));

        /// Note need to give strategist role to symbioticUManager
        /// Note need to set merkle root in the manager

        vm.stopBroadcast();
    }
}
