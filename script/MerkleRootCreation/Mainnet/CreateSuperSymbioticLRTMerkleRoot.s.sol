// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateSuperSymbioticLRTMerkleRoot.s.sol:CreateSuperSymbioticLRTMerkleRootScript --rpc-url $MAINNET_RPC_URL
 */
contract CreateSuperSymbioticLRTMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x917ceE801a67f933F2e6b33fC0cD1ED2d5909D88;
    address public managerAddress = 0xA24dD7B978Fbe36125cC4817192f7b8AA18d213c;
    address public accountantAddress = 0xbe16605B22a7faCEf247363312121670DFe5afBE;
    address public rawDataDecoderAndSanitizer = 0xdaEfE2146908BAd73A1C45f75eB2B8E46935c781;
    address public stakingDecoderAndSanitizer = 0x8940DCA8e4e55C228B5060979f225e95E9249421;

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
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        leafIndex = type(uint256).max;
        _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "wstETHDefaultCollateral"));
        _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "cbETHDefaultCollateral"));
        _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "wBETHDefaultCollateral"));
        _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "rETHDefaultCollateral"));
        _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "mETHDefaultCollateral"));
        _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "swETHDefaultCollateral"));
        _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "sfrxETHDefaultCollateral"));
        _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "ETHxDefaultCollateral"));
        // _addSymbioticApproveAndDepositLeaf(leafs, uniETHDefaultCollateral);

        string memory filePath = "./leafs/SuperSymbioticSniperLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](512);

        // ========================== Symbiotic ==========================
        address[] memory defaultCollaterals = new address[](8);
        defaultCollaterals[0] = getAddress(sourceChain, "wstETHDefaultCollateral");
        defaultCollaterals[1] = getAddress(sourceChain, "cbETHDefaultCollateral");
        defaultCollaterals[2] = getAddress(sourceChain, "wBETHDefaultCollateral");
        defaultCollaterals[3] = getAddress(sourceChain, "rETHDefaultCollateral");
        defaultCollaterals[4] = getAddress(sourceChain, "mETHDefaultCollateral");
        defaultCollaterals[5] = getAddress(sourceChain, "swETHDefaultCollateral");
        defaultCollaterals[6] = getAddress(sourceChain, "sfrxETHDefaultCollateral");
        defaultCollaterals[7] = getAddress(sourceChain, "ETHxDefaultCollateral");
        // defaultCollaterals[8] = uniETHDefaultCollateral;
        _addSymbioticLeafs(leafs, defaultCollaterals);

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](5);
        supplyAssets[0] = getERC20(sourceChain, "WETH");
        supplyAssets[1] = getERC20(sourceChain, "WEETH");
        supplyAssets[2] = getERC20(sourceChain, "WSTETH");
        supplyAssets[3] = getERC20(sourceChain, "RETH");
        supplyAssets[4] = getERC20(sourceChain, "cbETH");
        ERC20[] memory borrowAssets = new ERC20[](5);
        borrowAssets[0] = getERC20(sourceChain, "WETH");
        borrowAssets[1] = getERC20(sourceChain, "WEETH");
        borrowAssets[2] = getERC20(sourceChain, "WSTETH");
        borrowAssets[3] = getERC20(sourceChain, "RETH");
        borrowAssets[4] = getERC20(sourceChain, "cbETH");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== Lido ==========================
        _addLidoLeafs(leafs);

        // ========================== EtherFi ==========================
        _addEtherFiLeafs(leafs);

        // ========================== Native ==========================
        _addNativeLeafs(leafs);

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](55);
        token0[0] = getAddress(sourceChain, "WETH");
        token0[1] = getAddress(sourceChain, "WETH");
        token0[2] = getAddress(sourceChain, "WETH");
        token0[3] = getAddress(sourceChain, "WETH");
        token0[4] = getAddress(sourceChain, "WETH");
        token0[5] = getAddress(sourceChain, "WETH");
        token0[6] = getAddress(sourceChain, "WETH");
        token0[7] = getAddress(sourceChain, "WETH");
        token0[8] = getAddress(sourceChain, "WETH");
        token0[9] = getAddress(sourceChain, "WETH");
        token0[10] = getAddress(sourceChain, "WEETH");
        token0[11] = getAddress(sourceChain, "WEETH");
        token0[12] = getAddress(sourceChain, "WEETH");
        token0[13] = getAddress(sourceChain, "WEETH");
        token0[14] = getAddress(sourceChain, "WEETH");
        token0[15] = getAddress(sourceChain, "WEETH");
        token0[16] = getAddress(sourceChain, "WEETH");
        token0[17] = getAddress(sourceChain, "WEETH");
        token0[18] = getAddress(sourceChain, "WEETH");
        token0[19] = getAddress(sourceChain, "WSTETH");
        token0[20] = getAddress(sourceChain, "WSTETH");
        token0[21] = getAddress(sourceChain, "WSTETH");
        token0[22] = getAddress(sourceChain, "WSTETH");
        token0[23] = getAddress(sourceChain, "WSTETH");
        token0[24] = getAddress(sourceChain, "WSTETH");
        token0[25] = getAddress(sourceChain, "WSTETH");
        token0[26] = getAddress(sourceChain, "WSTETH");
        token0[27] = getAddress(sourceChain, "RETH");
        token0[28] = getAddress(sourceChain, "RETH");
        token0[29] = getAddress(sourceChain, "RETH");
        token0[30] = getAddress(sourceChain, "RETH");
        token0[31] = getAddress(sourceChain, "RETH");
        token0[32] = getAddress(sourceChain, "RETH");
        token0[33] = getAddress(sourceChain, "RETH");
        token0[34] = getAddress(sourceChain, "cbETH");
        token0[35] = getAddress(sourceChain, "cbETH");
        token0[36] = getAddress(sourceChain, "cbETH");
        token0[37] = getAddress(sourceChain, "cbETH");
        token0[38] = getAddress(sourceChain, "cbETH");
        token0[39] = getAddress(sourceChain, "cbETH");
        token0[40] = getAddress(sourceChain, "WBETH");
        token0[41] = getAddress(sourceChain, "WBETH");
        token0[42] = getAddress(sourceChain, "WBETH");
        token0[43] = getAddress(sourceChain, "WBETH");
        token0[44] = getAddress(sourceChain, "WBETH");
        token0[45] = getAddress(sourceChain, "METH");
        token0[46] = getAddress(sourceChain, "METH");
        token0[47] = getAddress(sourceChain, "METH");
        token0[48] = getAddress(sourceChain, "METH");
        token0[49] = getAddress(sourceChain, "SWETH");
        token0[50] = getAddress(sourceChain, "SWETH");
        token0[51] = getAddress(sourceChain, "SWETH");
        token0[52] = getAddress(sourceChain, "ETHX");
        token0[53] = getAddress(sourceChain, "ETHX");
        token0[54] = getAddress(sourceChain, "UNIETH");

        address[] memory token1 = new address[](55);
        token1[0] = getAddress(sourceChain, "WEETH");
        token1[1] = getAddress(sourceChain, "WSTETH");
        token1[2] = getAddress(sourceChain, "RETH");
        token1[3] = getAddress(sourceChain, "cbETH");
        token1[4] = getAddress(sourceChain, "WBETH");
        token1[5] = getAddress(sourceChain, "METH");
        token1[6] = getAddress(sourceChain, "SWETH");
        token1[7] = getAddress(sourceChain, "ETHX");
        token1[8] = getAddress(sourceChain, "UNIETH");
        token1[9] = getAddress(sourceChain, "SFRXETH");
        token1[10] = getAddress(sourceChain, "WSTETH");
        token1[11] = getAddress(sourceChain, "RETH");
        token1[12] = getAddress(sourceChain, "cbETH");
        token1[13] = getAddress(sourceChain, "WBETH");
        token1[14] = getAddress(sourceChain, "METH");
        token1[15] = getAddress(sourceChain, "SWETH");
        token1[16] = getAddress(sourceChain, "ETHX");
        token1[17] = getAddress(sourceChain, "UNIETH");
        token1[18] = getAddress(sourceChain, "SFRXETH");
        token1[19] = getAddress(sourceChain, "RETH");
        token1[20] = getAddress(sourceChain, "cbETH");
        token1[21] = getAddress(sourceChain, "WBETH");
        token1[22] = getAddress(sourceChain, "METH");
        token1[23] = getAddress(sourceChain, "SWETH");
        token1[24] = getAddress(sourceChain, "ETHX");
        token1[25] = getAddress(sourceChain, "UNIETH");
        token1[26] = getAddress(sourceChain, "SFRXETH");
        token1[27] = getAddress(sourceChain, "cbETH");
        token1[28] = getAddress(sourceChain, "WBETH");
        token1[29] = getAddress(sourceChain, "METH");
        token1[30] = getAddress(sourceChain, "SWETH");
        token1[31] = getAddress(sourceChain, "ETHX");
        token1[32] = getAddress(sourceChain, "UNIETH");
        token1[33] = getAddress(sourceChain, "SFRXETH");
        token1[34] = getAddress(sourceChain, "WBETH");
        token1[35] = getAddress(sourceChain, "METH");
        token1[36] = getAddress(sourceChain, "SWETH");
        token1[37] = getAddress(sourceChain, "ETHX");
        token1[38] = getAddress(sourceChain, "UNIETH");
        token1[39] = getAddress(sourceChain, "SFRXETH");
        token1[40] = getAddress(sourceChain, "METH");
        token1[41] = getAddress(sourceChain, "SWETH");
        token1[42] = getAddress(sourceChain, "ETHX");
        token1[43] = getAddress(sourceChain, "UNIETH");
        token1[44] = getAddress(sourceChain, "SFRXETH");
        token1[45] = getAddress(sourceChain, "SWETH");
        token1[46] = getAddress(sourceChain, "ETHX");
        token1[47] = getAddress(sourceChain, "UNIETH");
        token1[48] = getAddress(sourceChain, "SFRXETH");
        token1[49] = getAddress(sourceChain, "ETHX");
        token1[50] = getAddress(sourceChain, "UNIETH");
        token1[51] = getAddress(sourceChain, "SFRXETH");
        token1[52] = getAddress(sourceChain, "UNIETH");
        token1[53] = getAddress(sourceChain, "SFRXETH");
        token1[54] = getAddress(sourceChain, "SFRXETH");

        _addUniswapV3Leafs(leafs, token0, token1);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](12);
        SwapKind[] memory kind = new SwapKind[](12);
        assets[0] = getAddress(sourceChain, "WETH");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "WEETH");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "WSTETH");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "RETH");
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = getAddress(sourceChain, "cbETH");
        kind[4] = SwapKind.BuyAndSell;
        assets[5] = getAddress(sourceChain, "WBETH");
        kind[5] = SwapKind.BuyAndSell;
        assets[6] = getAddress(sourceChain, "METH");
        kind[6] = SwapKind.BuyAndSell;
        assets[7] = getAddress(sourceChain, "SWETH");
        kind[7] = SwapKind.BuyAndSell;
        assets[8] = getAddress(sourceChain, "ETHX");
        kind[8] = SwapKind.BuyAndSell;
        assets[9] = getAddress(sourceChain, "UNIETH");
        kind[9] = SwapKind.BuyAndSell;
        assets[10] = getAddress(sourceChain, "SFRXETH");
        kind[10] = SwapKind.BuyAndSell;
        assets[11] = getAddress(sourceChain, "INST");
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
        _addSwellSimpleStakingLeafs(
            leafs, getAddress(sourceChain, "WEETH"), getAddress(sourceChain, "swellSimpleStaking")
        );
        _addSwellSimpleStakingLeafs(
            leafs, getAddress(sourceChain, "WSTETH"), getAddress(sourceChain, "swellSimpleStaking")
        );
        _addSwellSimpleStakingLeafs(
            leafs, getAddress(sourceChain, "SFRXETH"), getAddress(sourceChain, "swellSimpleStaking")
        );
        _addSwellSimpleStakingLeafs(
            leafs, getAddress(sourceChain, "SWETH"), getAddress(sourceChain, "swellSimpleStaking")
        );

        // ========================== Zircuit ==========================
        _addZircuitLeafs(leafs, getAddress(sourceChain, "WEETH"), getAddress(sourceChain, "zircuitSimpleStaking"));
        _addZircuitLeafs(leafs, getAddress(sourceChain, "WSTETH"), getAddress(sourceChain, "zircuitSimpleStaking"));
        _addZircuitLeafs(leafs, getAddress(sourceChain, "SWETH"), getAddress(sourceChain, "zircuitSimpleStaking"));
        _addZircuitLeafs(leafs, getAddress(sourceChain, "METH"), getAddress(sourceChain, "zircuitSimpleStaking"));

        // ========================== Fluid fToken ==========================
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fWETH"));
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fWSTETH"));

        // ========================== FrxEth ==========================
        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "SFRXETH")));

        // ========================== Staking ==========================
        setAddress(true, mainnet, "rawDataDecoderAndSanitizer", stakingDecoderAndSanitizer);

        _addNativeLeafs(leafs);
        _addEtherFiLeafs(leafs);
        _addLidoLeafs(leafs);
        _addSwellStakingLeafs(leafs);
        _addMantleStakingLeafs(leafs);

        string memory filePath = "./leafs/SuperSymbioticStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
