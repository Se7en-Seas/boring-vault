// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {BaseMerkleRootGenerator} from "resources/BaseMerkleRootGenerator.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";

/**
 *  source .env && forge script script/CreateSuperSymbioticLRTMerkleRoot.s.sol:CreateSuperSymbioticLRTMerkleRootScript --rpc-url $MAINNET_RPC_URL
 */
contract CreateSuperSymbioticLRTMerkleRootScript is BaseMerkleRootGenerator {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x917ceE801a67f933F2e6b33fC0cD1ED2d5909D88;
    address public managerAddress = 0xA24dD7B978Fbe36125cC4817192f7b8AA18d213c;
    address public accountantAddress = 0xbe16605B22a7faCEf247363312121670DFe5afBE;
    address public rawDataDecoderAndSanitizer = 0x95e00919CDFC598dAE87944b5b4D1eCC7B943266;

    RolesAuthority public rolesAuthority = RolesAuthority(0xec8CE1a4eD2611c02A42B5B66dd968CdB20a20B9);

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        // generateAdminStrategistMerkleRoot();
        generateSniperMerkleRoot();
    }

    function generateSniperMerkleRoot() public {
        updateAddresses(boringVault, rawDataDecoderAndSanitizer, managerAddress, accountantAddress);

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        _addSymbioticApproveAndDepositLeaf(leafs, wstETHDefaultCollateral);
        _addSymbioticApproveAndDepositLeaf(leafs, cbETHDefaultCollateral);
        _addSymbioticApproveAndDepositLeaf(leafs, wBETHDefaultCollateral);
        _addSymbioticApproveAndDepositLeaf(leafs, rETHDefaultCollateral);
        _addSymbioticApproveAndDepositLeaf(leafs, mETHDefaultCollateral);
        _addSymbioticApproveAndDepositLeaf(leafs, swETHDefaultCollateral);
        _addSymbioticApproveAndDepositLeaf(leafs, sfrxETHDefaultCollateral);
        _addSymbioticApproveAndDepositLeaf(leafs, ETHxDefaultCollateral);
        _addSymbioticApproveAndDepositLeaf(leafs, uniETHDefaultCollateral);

        string memory filePath = "./leafs/SuperSymbioticSniperLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function generateAdminStrategistMerkleRoot() public {
        updateAddresses(boringVault, rawDataDecoderAndSanitizer, managerAddress, accountantAddress);

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        address[] memory defaultCollaterals = new address[](9);
        defaultCollaterals[0] = wstETHDefaultCollateral;
        defaultCollaterals[1] = cbETHDefaultCollateral;
        defaultCollaterals[2] = wBETHDefaultCollateral;
        defaultCollaterals[3] = rETHDefaultCollateral;
        defaultCollaterals[4] = mETHDefaultCollateral;
        defaultCollaterals[5] = swETHDefaultCollateral;
        defaultCollaterals[6] = sfrxETHDefaultCollateral;
        defaultCollaterals[7] = ETHxDefaultCollateral;
        defaultCollaterals[8] = uniETHDefaultCollateral;
        _addSymbioticLeafs(leafs, defaultCollaterals);

        string memory filePath = "./leafs/SuperSymbioticStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
