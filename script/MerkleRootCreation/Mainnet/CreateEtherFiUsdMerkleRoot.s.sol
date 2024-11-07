// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateEtherFiUsdMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */
contract CreateEtherFiUsdMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x939778D83b46B456224A33Fb59630B11DEC56663;
    address public rawDataDecoderAndSanitizer = 0xA26fefB4a509D6345e279499ED9bcd4ce3e7fFc2;
    address public managerAddress = 0xDFC5b0d2eC65864Dc773F681E3D52c765dc083ac;
    address public accountantAddress = 0xEB440B36f61Bf62E0C54C622944545f159C3B790;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateLiquidUsdStrategistMerkleRoot();
    }

    function generateLiquidUsdStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

        // ========================== Ethena ==========================
        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "SUSDE")));
        _addEthenaSUSDeWithdrawLeafs(leafs);

        // ========================== UniswapV3 ==========================
        /**
         * Full position management for USDC, USDT, DAI, USDe, sUSDe.
         */
        address[] memory token0 = new address[](10);
        token0[0] = getAddress(sourceChain, "USDC");
        token0[1] = getAddress(sourceChain, "USDC");
        token0[2] = getAddress(sourceChain, "USDC");
        token0[3] = getAddress(sourceChain, "USDC");
        token0[4] = getAddress(sourceChain, "USDT");
        token0[5] = getAddress(sourceChain, "USDT");
        token0[6] = getAddress(sourceChain, "USDT");
        token0[7] = getAddress(sourceChain, "DAI");
        token0[8] = getAddress(sourceChain, "DAI");
        token0[9] = getAddress(sourceChain, "USDE");

        address[] memory token1 = new address[](10);
        token1[0] = getAddress(sourceChain, "USDT");
        token1[1] = getAddress(sourceChain, "DAI");
        token1[2] = getAddress(sourceChain, "USDE");
        token1[3] = getAddress(sourceChain, "SUSDE");
        token1[4] = getAddress(sourceChain, "DAI");
        token1[5] = getAddress(sourceChain, "USDE");
        token1[6] = getAddress(sourceChain, "SUSDE");
        token1[7] = getAddress(sourceChain, "USDE");
        token1[8] = getAddress(sourceChain, "SUSDE");
        token1[9] = getAddress(sourceChain, "SUSDE");

        _addUniswapV3Leafs(leafs, token0, token1);

        // ========================== Fee Claiming ==========================
        /**
         * Claim fees in USDC, DAI, USDT and USDE
         */
        ERC20[] memory feeAssets = new ERC20[](4);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        feeAssets[1] = getERC20(sourceChain, "DAI");
        feeAssets[2] = getERC20(sourceChain, "USDT");
        feeAssets[3] = getERC20(sourceChain, "USDE");
        _addLeafsForFeeClaiming(leafs, feeAssets);

        // ========================== 1inch ==========================
        /**
         * USDC <-> USDT,
         * USDC <-> DAI,
         * USDT <-> DAI,
         * USDC <-> USDE,
         * USDT <-> USDE,
         * DAI <-> USDE,
         * sUSDE <-> USDE
         */
        address[] memory assets = new address[](5);
        SwapKind[] memory kind = new SwapKind[](5);
        assets[0] = getAddress(sourceChain, "USDC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "USDT");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "DAI");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "USDE");
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = getAddress(sourceChain, "SUSDE");
        kind[4] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "USDe_USDT_01"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "USDe_USDC_01"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "USDe_DAI_01"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "sUSDe_USDT_05"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "DAI_USDC_01"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "DAI_USDC_05"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "USDC_USDT_01"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "USDC_USDT_05"));
        // ========================== Eigen Layer ==========================
        // TODO USDeStrategy is still wrong.
        // _addLeafsForEigenLayerLST(
        //     leafs,
        //     getAddress(sourceChain, "USDE"),
        //     getAddress(sourceChain, "USDeStrategy"),
        //     getAddress(sourceChain, "strategyManager"),
        //     getAddress(sourceChain, "delegationManager"),
        //     getAddress(sourceChain, "testOperator")
        // );

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Mainnet/EtherFiUsdStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
