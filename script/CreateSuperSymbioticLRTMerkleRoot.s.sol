// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {BaseMerkleRootGenerator} from "resources/BaseMerkleRootGenerator.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";

/**
 *  source .env && forge script script/CreateSuperSymbioticLRTMerkleRoot.s.sol:CreateSuperSymbioticLRTMerkleRootScript --rpc-url $MAINNET_RPC_URL
 */
contract CreateSuperSymbioticLRTMerkleRootScript is BaseMerkleRootGenerator {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x917ceE801a67f933F2e6b33fC0cD1ED2d5909D88;
    address public managerAddress = 0xA24dD7B978Fbe36125cC4817192f7b8AA18d213c;
    address public accountantAddress = 0xbe16605B22a7faCEf247363312121670DFe5afBE;
    address public rawDataDecoderAndSanitizer = 0xdaEfE2146908BAd73A1C45f75eB2B8E46935c781;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
        // generateSniperMerkleRoot();
    }

    function generateSniperMerkleRoot() public {
        updateAddresses(boringVault, rawDataDecoderAndSanitizer, managerAddress, accountantAddress);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        leafIndex = type(uint256).max;
        _addSymbioticApproveAndDepositLeaf(leafs, wstETHDefaultCollateral);
        _addSymbioticApproveAndDepositLeaf(leafs, cbETHDefaultCollateral);
        _addSymbioticApproveAndDepositLeaf(leafs, wBETHDefaultCollateral);
        _addSymbioticApproveAndDepositLeaf(leafs, rETHDefaultCollateral);
        _addSymbioticApproveAndDepositLeaf(leafs, mETHDefaultCollateral);
        _addSymbioticApproveAndDepositLeaf(leafs, swETHDefaultCollateral);
        _addSymbioticApproveAndDepositLeaf(leafs, sfrxETHDefaultCollateral);
        _addSymbioticApproveAndDepositLeaf(leafs, ETHxDefaultCollateral);
        // _addSymbioticApproveAndDepositLeaf(leafs, uniETHDefaultCollateral);

        string memory filePath = "./leafs/SuperSymbioticSniperLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function generateAdminStrategistMerkleRoot() public {
        updateAddresses(boringVault, rawDataDecoderAndSanitizer, managerAddress, accountantAddress);

        ManageLeaf[] memory leafs = new ManageLeaf[](512);

        // ========================== Symbiotic ==========================
        address[] memory defaultCollaterals = new address[](8);
        defaultCollaterals[0] = wstETHDefaultCollateral;
        defaultCollaterals[1] = cbETHDefaultCollateral;
        defaultCollaterals[2] = wBETHDefaultCollateral;
        defaultCollaterals[3] = rETHDefaultCollateral;
        defaultCollaterals[4] = mETHDefaultCollateral;
        defaultCollaterals[5] = swETHDefaultCollateral;
        defaultCollaterals[6] = sfrxETHDefaultCollateral;
        defaultCollaterals[7] = ETHxDefaultCollateral;
        // defaultCollaterals[8] = uniETHDefaultCollateral;
        _addSymbioticLeafs(leafs, defaultCollaterals);

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](5);
        supplyAssets[0] = WETH;
        supplyAssets[1] = WEETH;
        supplyAssets[2] = WSTETH;
        supplyAssets[3] = RETH;
        supplyAssets[4] = cbETH;
        ERC20[] memory borrowAssets = new ERC20[](5);
        borrowAssets[0] = WETH;
        borrowAssets[1] = WEETH;
        borrowAssets[2] = WSTETH;
        borrowAssets[3] = RETH;
        borrowAssets[4] = cbETH;
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== Lido ==========================
        _addLidoLeafs(leafs);

        // ========================== EtherFi ==========================
        _addEtherFiLeafs(leafs);

        // ========================== Native ==========================
        _addNativeLeafs(leafs);

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](55);
        token0[0] = address(WETH);
        token0[1] = address(WETH);
        token0[2] = address(WETH);
        token0[3] = address(WETH);
        token0[4] = address(WETH);
        token0[5] = address(WETH);
        token0[6] = address(WETH);
        token0[7] = address(WETH);
        token0[8] = address(WETH);
        token0[9] = address(WETH);
        token0[10] = address(WEETH);
        token0[11] = address(WEETH);
        token0[12] = address(WEETH);
        token0[13] = address(WEETH);
        token0[14] = address(WEETH);
        token0[15] = address(WEETH);
        token0[16] = address(WEETH);
        token0[17] = address(WEETH);
        token0[18] = address(WEETH);
        token0[19] = address(WSTETH);
        token0[20] = address(WSTETH);
        token0[21] = address(WSTETH);
        token0[22] = address(WSTETH);
        token0[23] = address(WSTETH);
        token0[24] = address(WSTETH);
        token0[25] = address(WSTETH);
        token0[26] = address(WSTETH);
        token0[27] = address(RETH);
        token0[28] = address(RETH);
        token0[29] = address(RETH);
        token0[30] = address(RETH);
        token0[31] = address(RETH);
        token0[32] = address(RETH);
        token0[33] = address(RETH);
        token0[34] = address(cbETH);
        token0[35] = address(cbETH);
        token0[36] = address(cbETH);
        token0[37] = address(cbETH);
        token0[38] = address(cbETH);
        token0[39] = address(cbETH);
        token0[40] = address(WBETH);
        token0[41] = address(WBETH);
        token0[42] = address(WBETH);
        token0[43] = address(WBETH);
        token0[44] = address(WBETH);
        token0[45] = address(METH);
        token0[46] = address(METH);
        token0[47] = address(METH);
        token0[48] = address(METH);
        token0[49] = address(SWETH);
        token0[50] = address(SWETH);
        token0[51] = address(SWETH);
        token0[52] = address(ETHX);
        token0[53] = address(ETHX);
        token0[54] = address(UNIETH);

        address[] memory token1 = new address[](55);
        token1[0] = address(WEETH);
        token1[1] = address(WSTETH);
        token1[2] = address(RETH);
        token1[3] = address(cbETH);
        token1[4] = address(WBETH);
        token1[5] = address(METH);
        token1[6] = address(SWETH);
        token1[7] = address(ETHX);
        token1[8] = address(UNIETH);
        token1[9] = address(SFRXETH);
        token1[10] = address(WSTETH);
        token1[11] = address(RETH);
        token1[12] = address(cbETH);
        token1[13] = address(WBETH);
        token1[14] = address(METH);
        token1[15] = address(SWETH);
        token1[16] = address(ETHX);
        token1[17] = address(UNIETH);
        token1[18] = address(SFRXETH);
        token1[19] = address(RETH);
        token1[20] = address(cbETH);
        token1[21] = address(WBETH);
        token1[22] = address(METH);
        token1[23] = address(SWETH);
        token1[24] = address(ETHX);
        token1[25] = address(UNIETH);
        token1[26] = address(SFRXETH);
        token1[27] = address(cbETH);
        token1[28] = address(WBETH);
        token1[29] = address(METH);
        token1[30] = address(SWETH);
        token1[31] = address(ETHX);
        token1[32] = address(UNIETH);
        token1[33] = address(SFRXETH);
        token1[34] = address(WBETH);
        token1[35] = address(METH);
        token1[36] = address(SWETH);
        token1[37] = address(ETHX);
        token1[38] = address(UNIETH);
        token1[39] = address(SFRXETH);
        token1[40] = address(METH);
        token1[41] = address(SWETH);
        token1[42] = address(ETHX);
        token1[43] = address(UNIETH);
        token1[44] = address(SFRXETH);
        token1[45] = address(SWETH);
        token1[46] = address(ETHX);
        token1[47] = address(UNIETH);
        token1[48] = address(SFRXETH);
        token1[49] = address(ETHX);
        token1[50] = address(UNIETH);
        token1[51] = address(SFRXETH);
        token1[52] = address(UNIETH);
        token1[53] = address(SFRXETH);
        token1[54] = address(SFRXETH);

        _addUniswapV3Leafs(leafs, token0, token1);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](12);
        SwapKind[] memory kind = new SwapKind[](12);
        assets[0] = address(WETH);
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = address(WEETH);
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = address(WSTETH);
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = address(RETH);
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = address(cbETH);
        kind[4] = SwapKind.BuyAndSell;
        assets[5] = address(WBETH);
        kind[5] = SwapKind.BuyAndSell;
        assets[6] = address(METH);
        kind[6] = SwapKind.BuyAndSell;
        assets[7] = address(SWETH);
        kind[7] = SwapKind.BuyAndSell;
        assets[8] = address(ETHX);
        kind[8] = SwapKind.BuyAndSell;
        assets[9] = address(UNIETH);
        kind[9] = SwapKind.BuyAndSell;
        assets[10] = address(SFRXETH);
        kind[10] = SwapKind.BuyAndSell;
        assets[11] = address(INST);
        kind[11] = SwapKind.Sell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // _addLeafsFor1InchUniswapV3Swapping(leafs, wstETH_wETH_01);
        // _addLeafsFor1InchUniswapV3Swapping(leafs, rETH_wETH_01);
        // _addLeafsFor1InchUniswapV3Swapping(leafs, rETH_wETH_05);
        // _addLeafsFor1InchUniswapV3Swapping(leafs, wstETH_rETH_05);
        // _addLeafsFor1InchUniswapV3Swapping(leafs, PENDLE_wETH_30);
        // _addLeafsFor1InchUniswapV3Swapping(leafs, wETH_weETH_05);
        // _addLeafsFor1InchUniswapV3Swapping(leafs, GEAR_wETH_100);

        // ========================== Swell ==========================
        _addSwellLeafs(leafs, address(WEETH), swellSimpleStaking);
        _addSwellLeafs(leafs, address(WSTETH), swellSimpleStaking);
        _addSwellLeafs(leafs, address(SFRXETH), swellSimpleStaking);
        _addSwellLeafs(leafs, address(SWETH), swellSimpleStaking);

        // ========================== Zircuit ==========================
        _addZircuitLeafs(leafs, address(WEETH), zircuitSimpleStaking);
        _addZircuitLeafs(leafs, address(WSTETH), zircuitSimpleStaking);
        _addZircuitLeafs(leafs, address(SWETH), zircuitSimpleStaking);
        _addZircuitLeafs(leafs, address(METH), zircuitSimpleStaking);

        // ========================== Fluid fToken ==========================
        _addFluidFTokenLeafs(leafs, fWETH);
        _addFluidFTokenLeafs(leafs, fWSTETH);

        // ========================== FrxEth ==========================
        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(address(SFRXETH)));

        string memory filePath = "./leafs/SuperSymbioticStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
