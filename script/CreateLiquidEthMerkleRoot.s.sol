// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {BaseMerkleRootGenerator} from "resources/BaseMerkleRootGenerator.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";

/**
 *  source .env && forge script script/CreateLiquidEthMerkleRoot.s.sol:CreateLiquidEthMerkleRootScript --rpc-url $MAINNET_RPC_URL
 */
contract CreateLiquidEthMerkleRootScript is BaseMerkleRootGenerator {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x66BC9023f618C447e52c31dAF591d1943529D9e7;
    address public rawDataDecoderAndSanitizer = 0x0c9fd99d67DF2AB4722640eC4A5b495371bc81d2;
    address public managerAddress = 0x2f33E96790EF4A8b98E0F207CAB1e5972Be6989A;
    address public accountantAddress = 0x3365AD279cD33508A837EBC23c61C0Ca0ac9950B;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateLiquidEthStrategistMerkleRoot();
    }

    function generateLiquidEthStrategistMerkleRoot() public {
        updateAddresses(boringVault, rawDataDecoderAndSanitizer, managerAddress, accountantAddress);

        ManageLeaf[] memory leafs = new ManageLeaf[](512);

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](4);
        supplyAssets[0] = WETH;
        supplyAssets[1] = WEETH;
        supplyAssets[2] = WSTETH;
        supplyAssets[3] = RETH;
        ERC20[] memory borrowAssets = new ERC20[](4);
        borrowAssets[0] = WETH;
        borrowAssets[1] = WEETH;
        borrowAssets[2] = WSTETH;
        borrowAssets[3] = RETH;
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== SparkLend ==========================
        /**
         * lend USDC, USDT, DAI, sDAI
         * borrow wETH, wstETH
         */
        borrowAssets = new ERC20[](3);
        borrowAssets[0] = WETH;
        borrowAssets[1] = WSTETH;
        borrowAssets[2] = RETH;
        _addSparkLendLeafs(leafs, supplyAssets, borrowAssets);

        // ========================== Lido ==========================
        _addLidoLeafs(leafs);

        // ========================== EtherFi ==========================
        /**
         * stake, unstake, wrap, unwrap
         */
        _addEtherFiLeafs(leafs);

        // ========================== Native ==========================
        /**
         * wrap, unwrap
         */
        _addNativeLeafs(leafs);

        // ========================== Gearbox ==========================
        _addGearboxLeafs(leafs, ERC4626(dWETHV3), sdWETHV3);

        // ========================== MorphoBlue ==========================
        /**
         * weETH/wETH  86.00 LLTV market 0x698fe98247a40c5771537b5786b2f3f9d78eb487b4ce4d75533cd0e94d88a115
         */
        _addMorphoBlueSupplyLeafs(leafs, 0x698fe98247a40c5771537b5786b2f3f9d78eb487b4ce4d75533cd0e94d88a115);

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, pendleWeETHMarket);
        _addPendleMarketLeafs(leafs, pendleZircuitWeETHMarket);
        _addPendleMarketLeafs(leafs, pendleWeETHMarketNew);

        // ========================== UniswapV3 ==========================
        /**
         * Full position management for USDC, USDT, DAI, USDe, sUSDe.
         */
        address[] memory token0 = new address[](6);
        token0[0] = address(WETH);
        token0[1] = address(WETH);
        token0[2] = address(WETH);
        token0[3] = address(WEETH);
        token0[4] = address(WEETH);
        token0[5] = address(WSTETH);

        address[] memory token1 = new address[](6);
        token1[0] = address(WEETH);
        token1[1] = address(WSTETH);
        token1[2] = address(RETH);
        token1[3] = address(WSTETH);
        token1[4] = address(RETH);
        token1[5] = address(RETH);

        _addUniswapV3Leafs(leafs, token0, token1);

        // ========================== Fee Claiming ==========================
        /**
         * Claim fees in USDC, DAI, USDT and USDE
         */
        ERC20[] memory feeAssets = new ERC20[](3);
        feeAssets[0] = WETH;
        feeAssets[1] = WEETH;
        feeAssets[2] = EETH;
        _addLeafsForFeeClaiming(leafs, feeAssets);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](10);
        SwapKind[] memory kind = new SwapKind[](10);
        assets[0] = address(WETH);
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = address(WEETH);
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = address(WSTETH);
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = address(RETH);
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = address(GEAR);
        kind[4] = SwapKind.Sell;
        assets[5] = address(CRV);
        kind[5] = SwapKind.Sell;
        assets[6] = address(CVX);
        kind[6] = SwapKind.Sell;
        assets[7] = address(AURA);
        kind[7] = SwapKind.Sell;
        assets[8] = address(BAL);
        kind[8] = SwapKind.Sell;
        assets[9] = address(PENDLE);
        kind[9] = SwapKind.Sell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        _addLeafsFor1InchUniswapV3Swapping(leafs, wstETH_wETH_01);
        _addLeafsFor1InchUniswapV3Swapping(leafs, rETH_wETH_01);
        _addLeafsFor1InchUniswapV3Swapping(leafs, rETH_wETH_05);
        _addLeafsFor1InchUniswapV3Swapping(leafs, wstETH_rETH_05);
        _addLeafsFor1InchUniswapV3Swapping(leafs, PENDLE_wETH_30);
        _addLeafsFor1InchUniswapV3Swapping(leafs, wETH_weETH_05);
        _addLeafsFor1InchUniswapV3Swapping(leafs, GEAR_wETH_100);

        // ========================== Curve Swapping ==========================
        _addLeafsForCurveSwapping(leafs, weETH_wETH_Pool);
        _addLeafsForCurveSwapping(leafs, weETH_wETH_NG_Pool);

        // ========================== Swell ==========================
        _addSwellLeafs(leafs, address(WEETH), swellSimpleStaking);
        _addSwellLeafs(leafs, address(EETH), swellSimpleStaking);
        _addSwellLeafs(leafs, address(WSTETH), swellSimpleStaking);
        _addSwellLeafs(leafs, pendleEethPt, swellSimpleStaking);
        _addSwellLeafs(leafs, pendleEethPtNew, swellSimpleStaking);
        _addSwellLeafs(leafs, pendleZircuitEethPt, swellSimpleStaking);

        // ========================== Zircuit ==========================
        _addZircuitLeafs(leafs, address(WEETH), zircuitSimpleStaking);
        _addZircuitLeafs(leafs, address(WSTETH), zircuitSimpleStaking);

        // ========================== Balancer ==========================
        _addBalancerLeafs(leafs, rETH_weETH_id, rETH_weETH_gauge);

        // ========================== Aura ==========================
        _addAuraLeafs(leafs, aura_reth_weeth);

        // ========================== Flashloans ==========================
        _addBalancerFlashloanLeafs(leafs, address(WETH));
        _addBalancerFlashloanLeafs(leafs, address(WEETH));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/LiquidEthStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
