// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateLiquidUsdMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */
contract CreateLiquidUsdMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x08c6F91e2B681FaF5e17227F2a44C307b3C1364C;
    address public rawDataDecoderAndSanitizer = 0xB240f07102a907B7B007A36f2ef70EbC9BFf14E8;
    address public pancakeSwapDataDecoderAndSanitizer = 0x47F62174e7A8EF939d8525C9670025d19DeFd821;
    address public managerAddress = 0xcFF411d5C54FE0583A984beE1eF43a4776854B9A;
    address public accountantAddress = 0xc315D6e14DDCDC7407784e2Caf815d131Bc1D3E7;

    address public itbAaveV3Usdc = 0xa6c9A887F5Ae28A70E457178AABDd153859B572b;
    // address public itbAaveV3Dai = address(65);
    address public itbAaveV3Usdt = 0x9c62cB41eACe893E5cc72C0C933E14B299C520A8;
    address public itbGearboxUsdc = 0x9e7f6dC1d0Ec371a1e5d918f1f8f120f1B1DD00c;
    // address public itbGearboxDai = address(65);
    // address public itbGearboxUsdt = address(65);
    address public itbCurveConvex_PyUsdUsdc = 0x5036E6D1019BF07589574446C2b3f57B8FeB895F;
    // address public itbCurve_sDai_sUsde = address(65);
    // address public itbCurveConvex_FraxUsdc = address(65);
    // address public itbCurveConvex_UsdcCrvUsd = address(65);
    address public itbDecoderAndSanitizer = 0x7fA5dbDB1A76d2990Ea0f3c74e520E3fcE94748B;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateLiquidUsdStrategistMerkleRoot();
        // generateMiniLiquidUsdStrategistMerkleRoot();
    }

    function generateMiniLiquidUsdStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](4);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        feeAssets[1] = getERC20(sourceChain, "DAI");
        feeAssets[2] = getERC20(sourceChain, "USDT");
        feeAssets[3] = getERC20(sourceChain, "USDE");
        _addLeafsForFeeClaiming(leafs, feeAssets);

        // ========================== Fluid fToken ==========================
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fUSDC"));
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fUSDT"));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/MiniLiquidUsdStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function generateLiquidUsdStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](1024);

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](6);
        supplyAssets[0] = getERC20(sourceChain, "USDC");
        supplyAssets[1] = getERC20(sourceChain, "USDT");
        supplyAssets[2] = getERC20(sourceChain, "DAI");
        supplyAssets[3] = getERC20(sourceChain, "sDAI");
        supplyAssets[4] = getERC20(sourceChain, "USDE");
        supplyAssets[5] = getERC20(sourceChain, "SUSDE");
        ERC20[] memory borrowAssets = new ERC20[](4);
        borrowAssets[0] = getERC20(sourceChain, "USDC");
        borrowAssets[1] = getERC20(sourceChain, "USDT");
        borrowAssets[2] = getERC20(sourceChain, "DAI");
        borrowAssets[3] = getERC20(sourceChain, "USDE");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== SparkLend ==========================
        supplyAssets = new ERC20[](4);
        supplyAssets[0] = getERC20(sourceChain, "USDC");
        supplyAssets[1] = getERC20(sourceChain, "USDT");
        supplyAssets[2] = getERC20(sourceChain, "DAI");
        supplyAssets[3] = getERC20(sourceChain, "sDAI");
        borrowAssets = new ERC20[](3);
        borrowAssets[0] = getERC20(sourceChain, "USDC");
        borrowAssets[1] = getERC20(sourceChain, "USDT");
        borrowAssets[2] = getERC20(sourceChain, "DAI");
        _addSparkLendLeafs(leafs, supplyAssets, borrowAssets);

        // ========================== MakerDAO ==========================
        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sDAI")));

        // ========================== Gearbox ==========================
        /**
         * USDC, DAI, USDT deposit, withdraw,  dUSDCV3, dDAIV3 dUSDTV3 deposit, withdraw, claim
         */
        _addGearboxLeafs(leafs, ERC4626(getAddress(sourceChain, "dUSDCV3")), getAddress(sourceChain, "sdUSDCV3"));
        _addGearboxLeafs(leafs, ERC4626(getAddress(sourceChain, "dDAIV3")), getAddress(sourceChain, "sdDAIV3"));
        _addGearboxLeafs(leafs, ERC4626(getAddress(sourceChain, "dUSDTV3")), getAddress(sourceChain, "sdUSDTV3"));

        // ========================== MorphoBlue ==========================
        /**
         * Supply, Withdraw DAI, USDT, USDC to/from
         * sUSDe/USDT  91.50 LLTV market 0xdc5333039bcf15f1237133f74d5806675d83d9cf19cfd4cfdd9be674842651bf
         * USDe/USDT   91.50 LLTV market 0xcec858380cba2d9ca710fce3ce864d74c3f620d53826f69d08508902e09be86f
         * USDe/DAI    91.50 LLTV market 0x8e6aeb10c401de3279ac79b4b2ea15fc94b7d9cfc098d6c2a1ff7b2b26d9d02c
         * sUSDe/DAI   91.50 LLTV market 0x1247f1c237eceae0602eab1470a5061a6dd8f734ba88c7cdc5d6109fb0026b28
         * USDe/DAI    94.50 LLTV market 0xdb760246f6859780f6c1b272d47a8f64710777121118e56e0cdb4b8b744a3094
         * USDe/DAI    86.00 LLTV market 0xc581c5f70bd1afa283eed57d1418c6432cbff1d862f94eaf58fdd4e46afbb67f
         * USDe/DAI    77.00 LLTV market 0xfd8493f09eb6203615221378d89f53fcd92ff4f7d62cca87eece9a2fff59e86f
         * wETH/USDC   86.00 LLTV market 0x7dde86a1e94561d9690ec678db673c1a6396365f7d1d65e129c5fff0990ff758
         * wETH/USDC   91.50 LLTV market 0xf9acc677910cc17f650416a22e2a14d5da7ccb9626db18f1bf94efe64f92b372
         * sUSDe/DAI   77.00 LLTV market 0x42dcfb38bb98767afb6e38ccf90d59d0d3f0aa216beb3a234f12850323d17536
         * sUSDe/DAI   86.00 LLTV market 0x39d11026eae1c6ec02aa4c0910778664089cdd97c3fd23f68f7cd05e2e95af48
         * wstETH/USDT 86.00 LLTV market 0xe7e9694b754c4d4f7e21faf7223f6fa71abaeb10296a4c43a54a7977149687d2
         * wstETH/USDC 86.00 LLTV market 0xb323495f7e4148be5643a4ea4a8221eef163e4bccfdedc2a6f4696baacbc86cc
         */
        _addMorphoBlueSupplyLeafs(leafs, 0xdc5333039bcf15f1237133f74d5806675d83d9cf19cfd4cfdd9be674842651bf);
        _addMorphoBlueSupplyLeafs(leafs, 0xcec858380cba2d9ca710fce3ce864d74c3f620d53826f69d08508902e09be86f);
        _addMorphoBlueSupplyLeafs(leafs, 0x8e6aeb10c401de3279ac79b4b2ea15fc94b7d9cfc098d6c2a1ff7b2b26d9d02c);
        _addMorphoBlueSupplyLeafs(leafs, 0x1247f1c237eceae0602eab1470a5061a6dd8f734ba88c7cdc5d6109fb0026b28);
        _addMorphoBlueSupplyLeafs(leafs, 0xdb760246f6859780f6c1b272d47a8f64710777121118e56e0cdb4b8b744a3094);
        _addMorphoBlueSupplyLeafs(leafs, 0xc581c5f70bd1afa283eed57d1418c6432cbff1d862f94eaf58fdd4e46afbb67f);
        _addMorphoBlueSupplyLeafs(leafs, 0xfd8493f09eb6203615221378d89f53fcd92ff4f7d62cca87eece9a2fff59e86f);
        _addMorphoBlueSupplyLeafs(leafs, 0x7dde86a1e94561d9690ec678db673c1a6396365f7d1d65e129c5fff0990ff758);
        _addMorphoBlueSupplyLeafs(leafs, 0xf9acc677910cc17f650416a22e2a14d5da7ccb9626db18f1bf94efe64f92b372);
        _addMorphoBlueSupplyLeafs(leafs, 0x42dcfb38bb98767afb6e38ccf90d59d0d3f0aa216beb3a234f12850323d17536);
        _addMorphoBlueSupplyLeafs(leafs, 0x39d11026eae1c6ec02aa4c0910778664089cdd97c3fd23f68f7cd05e2e95af48);
        _addMorphoBlueSupplyLeafs(leafs, 0xe7e9694b754c4d4f7e21faf7223f6fa71abaeb10296a4c43a54a7977149687d2);
        _addMorphoBlueSupplyLeafs(leafs, 0xb323495f7e4148be5643a4ea4a8221eef163e4bccfdedc2a6f4696baacbc86cc);

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleUSDeMarket"));
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleZircuitUSDeMarket"));
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleSUSDeMarketSeptember"));
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleSUSDeMarketJuly"));
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleKarakUSDeMarket"));
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleKarakSUSDeMarket"));
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleUSDeZircuitMarketAugust"));
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_sUSDe_08_23_24"));
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_sUSDe_12_25_24"));
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USDe_08_23_24"));
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USDe_12_25_24"));

        // ========================== Ethena ==========================
        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "SUSDE")));

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

        // ========================== Fluid fToken ==========================
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fUSDC"));
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fUSDT"));

        // ========================== 1inch ==========================
        /**
         * USDC <-> USDT,
         * USDC <-> DAI,
         * USDT <-> DAI,
         * GHO <-> USDC,
         * GHO <-> USDT,
         * GHO <-> DAI,
         * Swap GEAR -> USDC
         * Swap crvUSD <-> USDC
         * Swap crvUSD <-> USDT
         * Swap crvUSD <-> USDe
         * Swap FRAX <-> USDC
         * Swap FRAX <-> USDT
         * Swap FRAX <-> DAI
         * Swap PYUSD <-> USDC
         * Swap PYUSD <-> FRAX
         * Swap PYUSD <-> crvUSD
         */
        address[] memory assets = new address[](16);
        SwapKind[] memory kind = new SwapKind[](16);
        assets[0] = getAddress(sourceChain, "USDC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "USDT");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "DAI");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "GHO");
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = getAddress(sourceChain, "USDE");
        kind[4] = SwapKind.BuyAndSell;
        assets[5] = getAddress(sourceChain, "CRVUSD");
        kind[5] = SwapKind.BuyAndSell;
        assets[6] = getAddress(sourceChain, "FRAX");
        kind[6] = SwapKind.BuyAndSell;
        assets[7] = getAddress(sourceChain, "PYUSD");
        kind[7] = SwapKind.BuyAndSell;
        assets[8] = getAddress(sourceChain, "GEAR");
        kind[8] = SwapKind.Sell;
        assets[9] = getAddress(sourceChain, "CRV");
        kind[9] = SwapKind.Sell;
        assets[10] = getAddress(sourceChain, "CVX");
        kind[10] = SwapKind.Sell;
        assets[11] = getAddress(sourceChain, "AURA");
        kind[11] = SwapKind.Sell;
        assets[12] = getAddress(sourceChain, "BAL");
        kind[12] = SwapKind.Sell;
        assets[13] = getAddress(sourceChain, "INST");
        kind[13] = SwapKind.Sell;
        assets[14] = getAddress(sourceChain, "RSR");
        kind[14] = SwapKind.Sell;
        assets[15] = getAddress(sourceChain, "PENDLE");
        kind[15] = SwapKind.Sell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "PENDLE_wETH_30"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "USDe_USDT_01"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "USDe_USDC_01"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "USDe_DAI_01"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "sUSDe_USDT_05"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "GEAR_wETH_100"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "GEAR_USDT_30"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "DAI_USDC_01"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "DAI_USDC_05"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "USDC_USDT_01"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "USDC_USDT_05"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "USDC_wETH_05"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "FRAX_USDC_05"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "FRAX_USDC_01"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "FRAX_USDT_05"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "DAI_FRAX_05"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "PYUSD_USDC_01"));

        // ========================== Curve Swapping ==========================
        /**
         * USDe <-> USDC,
         * USDe <-> DAI,
         * sDAI <-> sUSDe,
         */
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "USDe_USDC_Curve_Pool"));
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "USDe_DAI_Curve_Pool"));
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "sDAI_sUSDe_Curve_Pool"));

        // ========================== Ethena Withdraws ==========================
        _addEthenaSUSDeWithdrawLeafs(leafs);

        // ========================== ITB Aave V3 USDC ==========================
        /**
         * acceptOwnership() of itbAaveV3Usdc
         * transfer USDC to itbAaveV3Usdc
         * withdraw USDC from itbAaveV3Usdc
         * withdrawAll USDC from itbAaveV3Usdc
         * deposit USDC to itbAaveV3Usdc
         * withdraw USDC supply from itbAaveV3Usdc
         */
        supplyAssets = new ERC20[](1);
        supplyAssets[0] = getERC20(sourceChain, "USDC");
        _addLeafsForItbAaveV3(leafs, itbAaveV3Usdc, supplyAssets, "ITB Aave V3 USDC");
        // // ========================== ITB Aave V3 DAI ==========================
        // /**
        //  * acceptOwnership() of itbAaveV3Dai
        //  * transfer DAI to itbAaveV3Dai
        //  * withdraw DAI from itbAaveV3Dai
        //  * withdrawAll DAI from itbAaveV3Dai
        //  * deposit DAI to itbAaveV3Dai
        //  * withdraw DAI supply from itbAaveV3Dai
        //  */
        // supplyAssets = new ERC20[](1);
        // supplyAssets[0] = DAI;
        // _addLeafsForItbAaveV3(leafs, itbAaveV3Dai, supplyAssets, "ITB Aave V3 DAI");
        // ========================== ITB Aave V3 USDT ==========================
        /**
         * acceptOwnership() of itbAaveV3Usdt
         * transfer USDT to itbAaveV3Usdt
         * withdraw USDT from itbAaveV3Usdt
         * withdrawAll USDT from itbAaveV3Usdt
         * deposit USDT to itbAaveV3Usdt
         * withdraw USDT supply from itbAaveV3Usdt
         */
        supplyAssets = new ERC20[](1);
        supplyAssets[0] = getERC20(sourceChain, "USDT");
        _addLeafsForItbAaveV3(leafs, itbAaveV3Usdt, supplyAssets, "ITB Aave V3 USDT");

        // ========================== ITB Gearbox USDC ==========================
        /**
         * acceptOwnership() of itbGearboxUsdc
         * transfer USDC to itbGearboxUsdc
         * withdraw USDC from itbGearboxUsdc
         * withdrawAll USDC from itbGearboxUsdc
         * deposit USDC to dUSDCV3
         * withdraw USDC from dUSDCV3
         * stake dUSDCV3 into sdUSDCV3
         * unstake dUSDCV3 from sdUSDCV3
         */
        _addLeafsForItbGearbox(
            leafs,
            itbGearboxUsdc,
            getERC20(sourceChain, "USDC"),
            getERC20(sourceChain, "dUSDCV3"),
            getAddress(sourceChain, "sdUSDCV3"),
            "ITB Gearbox USDC"
        );

        // ========================== ITB Gearbox DAI ==========================
        /**
         * acceptOwnership() of itbGearboxDai
         * transfer DAI to itbGearboxDai
         * withdraw DAI from itbGearboxDai
         * withdrawAll DAI from itbGearboxDai
         * deposit DAI to dDAIV3
         * withdraw DAI from dDAIV3
         * stake dDAIV3 into sdDAIV3
         * unstake dDAIV3 from sdDAIV3
         */
        // _addLeafsForItbGearbox(leafs, itbGearboxDai, DAI, ERC20(dDAIV3), sdDAIV3, "ITB Gearbox DAI");

        // ========================== ITB Gearbox USDT ==========================
        /**
         * acceptOwnership() of itbGearboxUsdt
         * transfer USDT to itbGearboxUsdt
         * withdraw USDT from itbGearboxUsdt
         * withdrawAll USDT from itbGearboxUsdt
         * deposit USDT to dUSDTV3
         * withdraw USDT from dUSDTV3
         * stake dUSDTV3 into sdUSDTV3
         * unstake dUSDTV3 from sdUSDTV3
         */
        // _addLeafsForItbGearbox(leafs, itbGearboxUsdt, USDT, ERC20(dUSDTV3), sdUSDTV3, "ITB Gearbox USDT");

        // ========================== ITB Curve/Convex PYUSD/USDC ==========================
        /**
         * itbCurveConvex_PyUsdUsdc
         * acceptOwnership() of itbCurveConvex_PyUsdUsdc
         * transfer both tokens to the pool
         * withdraw and withdraw all both tokens
         * addLiquidityAllCoinsAndStakeConvex
         * unstakeAndRemoveLiquidityAllCoinsConvex
         */
        {
            // acceptOwnership
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_PyUsdUsdc,
                false,
                "acceptOwnership()",
                new address[](0),
                "Accept ownership of the ITB Curve/Convex PYUSD/USDC contract",
                itbDecoderAndSanitizer
            );
            // Transfer both tokens to the pool
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "PYUSD"),
                false,
                "transfer(address,uint256)",
                new address[](1),
                "Transfer PYUSD to the ITB Curve/Convex PYUSD/USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = itbCurveConvex_PyUsdUsdc;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "USDC"),
                false,
                "transfer(address,uint256)",
                new address[](1),
                "Transfer USDC to the ITB Curve/Convex PYUSD/USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = itbCurveConvex_PyUsdUsdc;
            // Approvals
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_PyUsdUsdc,
                false,
                "approveToken(address,address,uint256)",
                new address[](2),
                "Approve Curve pool to spend PYUSD",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "PYUSD");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "pyUsd_Usdc_Curve_Pool");
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_PyUsdUsdc,
                false,
                "approveToken(address,address,uint256)",
                new address[](2),
                "Approve Curve pool to spend USDC",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "USDC");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "pyUsd_Usdc_Curve_Pool");
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_PyUsdUsdc,
                false,
                "approveToken(address,address,uint256)",
                new address[](2),
                "Approve Convex to spend Curve LP",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pyUsd_Usdc_Curve_Pool");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "convexCurveMainnetBooster");
            // Withdraw both tokens
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_PyUsdUsdc,
                false,
                "withdraw(address,uint256)",
                new address[](1),
                "Withdraw PYUSD from the ITB Curve/Convex PYUSD/USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "PYUSD");
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_PyUsdUsdc,
                false,
                "withdraw(address,uint256)",
                new address[](1),
                "Withdraw USDC from the ITB Curve/Convex PYUSD/USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "USDC");
            // WithdrawAll both tokens
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_PyUsdUsdc,
                false,
                "withdrawAll(address)",
                new address[](1),
                "Withdraw all PYUSD from the ITB Curve/Convex PYUSD/USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "PYUSD");
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_PyUsdUsdc,
                false,
                "withdrawAll(address)",
                new address[](1),
                "Withdraw all USDC from the ITB Curve/Convex PYUSD/USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "USDC");
            // Add liquidity and stake
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_PyUsdUsdc,
                false,
                "addLiquidityAllCoinsAndStakeConvex(address,uint256[],uint256,uint256)",
                new address[](2),
                "Add liquidity to the ITB Curve/Convex PYUSD/USDC contract and stake the convex tokens",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pyUsd_Usdc_Curve_Pool");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "pyUsd_Usdc_Convex_Id");
            // Unstake and remove liquidity
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_PyUsdUsdc,
                false,
                "unstakeAndRemoveLiquidityAllCoinsConvex(address,uint256,uint256,uint256[])",
                new address[](2),
                "Unstake the convex tokens and remove liquidity from the ITB Curve/Convex PYUSD/USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pyUsd_Usdc_Curve_Pool");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "pyUsd_Usdc_Convex_Id");
        }

        // ========================== ITB Curve/Convex FRAX/USDC ==========================
        /**
         * itbCurveConvex_FraxUsdc
         * acceptOwnership() of itbCurveConvex_FraxUsdc
         * transfer both tokens to the pool
         * withdraw and withdraw all both tokens
         * addLiquidityAllCoinsAndStakeConvex
         * unstakeAndRemoveLiquidityAllCoinsConvex
         */
        // {
        //     // acceptOwnership
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurveConvex_FraxUsdc,
        //         false,
        //         "acceptOwnership()",
        //         new address[](0),
        //         "Accept ownership of the ITB Curve/Convex FRAX/USDC contract",
        //         itbDecoderAndSanitizer
        //     );
        //     // Transfer both tokens to the pool
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         address(FRAX),
        //         false,
        //         "transfer(address,uint256)",
        //         new address[](1),
        //         "Transfer FRAX to the ITB Curve/Convex FRAX/USDC contract",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = itbCurveConvex_FraxUsdc;
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         getAddress(sourceChain, "USDC"),
        //         false,
        //         "transfer(address,uint256)",
        //         new address[](1),
        //         "Transfer USDC to the ITB Curve/Convex FRAX/USDC contract",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = itbCurveConvex_FraxUsdc;
        //     // Approvals
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurveConvex_FraxUsdc,
        //         false,
        //         "approveToken(address,address,uint256)",
        //         new address[](2),
        //         "Approve Curve pool to spend FRAX",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = address(FRAX);
        //     leafs[leafIndex].argumentAddresses[1] = frax_Usdc_Curve_Pool;
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurveConvex_FraxUsdc,
        //         false,
        //         "approveToken(address,address,uint256)",
        //         new address[](2),
        //         "Approve Curve pool to spend USDC",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = address(USDC);
        //     leafs[leafIndex].argumentAddresses[1] = frax_Usdc_Curve_Pool;
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurveConvex_FraxUsdc,
        //         false,
        //         "approveToken(address,address,uint256)",
        //         new address[](2),
        //         "Approve Convex to spend Curve LP",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = frax_Usdc_Curve_Pool;
        //     leafs[leafIndex].argumentAddresses[1] = convexCurveMainnetBooster;
        //     // Withdraw both tokens
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurveConvex_FraxUsdc,
        //         false,
        //         "withdraw(address,uint256)",
        //         new address[](1),
        //         "Withdraw FRAX from the ITB Curve/Convex FRAX/USDC contract",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = address(FRAX);
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurveConvex_FraxUsdc,
        //         false,
        //         "withdraw(address,uint256)",
        //         new address[](1),
        //         "Withdraw USDC from the ITB Curve/Convex FRAX/USDC",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = address(USDC);
        //     // WithdrawAll both tokens
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurveConvex_FraxUsdc,
        //         false,
        //         "withdrawAll(address)",
        //         new address[](1),
        //         "Withdraw all FRAX from the ITB Curve/Convex FRAX/USDC contract",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = address(FRAX);
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurveConvex_FraxUsdc,
        //         false,
        //         "withdrawAll(address)",
        //         new address[](1),
        //         "Withdraw all USDC from the ITB Curve/Convex FRAX/USDC contract",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = address(USDC);
        //     // Add liquidity and stake
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurveConvex_FraxUsdc,
        //         false,
        //         "addLiquidityAllCoinsAndStakeConvex(address,uint256[],uint256,uint256)",
        //         new address[](2),
        //         "Add liquidity to the ITB Curve/Convex FRAX/USDC contract and stake the convex tokens",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = frax_Usdc_Curve_Pool;
        //     leafs[leafIndex].argumentAddresses[1] = frax_Usdc_Convex_Id;
        //     // Unstake and remove liquidity
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurveConvex_FraxUsdc,
        //         false,
        //         "unstakeAndRemoveLiquidityAllCoinsConvex(address,uint256,uint256,uint256[])",
        //         new address[](2),
        //         "Unstake the convex tokens and remove liquidity from the ITB Curve/Convex FRAX/USDC contract",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = frax_Usdc_Curve_Pool;
        //     leafs[leafIndex].argumentAddresses[1] = frax_Usdc_Convex_Id;
        // }

        // ========================== ITB Curve/Convex USDC/crvUSD ==========================
        /**
         * itbCurveConvex_UsdcCrvUsd
         * acceptOwnership() of itbCurveConvex_UsdcCrvUsd
         * transfer both tokens to the pool
         * withdraw and withdraw all both tokens
         * addLiquidityAllCoinsAndStakeConvex
         * unstakeAndRemoveLiquidityAllCoinsConvex
         */
        // {
        //     // acceptOwnership
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurveConvex_UsdcCrvUsd,
        //         false,
        //         "acceptOwnership()",
        //         new address[](0),
        //         "Accept ownership of the ITB Curve/Convex USDC/crvUSD contract",
        //         itbDecoderAndSanitizer
        //     );
        //     // Transfer both tokens to the pool
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         address(USDC),
        //         false,
        //         "transfer(address,uint256)",
        //         new address[](1),
        //         "Transfer USDC to the ITB Curve/Convex USDC/crvUSD contract",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = itbCurveConvex_UsdcCrvUsd;
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         address(CRVUSD),
        //         false,
        //         "transfer(address,uint256)",
        //         new address[](1),
        //         "Transfer crvUSD to the ITB Curve/Convex USDC/crvUSD contract",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = itbCurveConvex_UsdcCrvUsd;
        //     // Approvals
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurveConvex_UsdcCrvUsd,
        //         false,
        //         "approveToken(address,address,uint256)",
        //         new address[](2),
        //         "Approve Curve pool to spend USDC",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = address(USDC);
        //     leafs[leafIndex].argumentAddresses[1] = usdc_CrvUsd_Curve_Pool;
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurveConvex_UsdcCrvUsd,
        //         false,
        //         "approveToken(address,address,uint256)",
        //         new address[](2),
        //         "Approve Curve pool to spend crvUSD",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = address(CRVUSD);
        //     leafs[leafIndex].argumentAddresses[1] = usdc_CrvUsd_Curve_Pool;
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurveConvex_UsdcCrvUsd,
        //         false,
        //         "approveToken(address,address,uint256)",
        //         new address[](2),
        //         "Approve Convex to spend Curve LP",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = usdc_CrvUsd_Curve_Pool;
        //     leafs[leafIndex].argumentAddresses[1] = convexCurveMainnetBooster;
        //     // Withdraw both tokens
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurveConvex_UsdcCrvUsd,
        //         false,
        //         "withdraw(address,uint256)",
        //         new address[](1),
        //         "Withdraw USDC from the ITB Curve/Convex USDC/crvUSD contract",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = address(USDC);
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurveConvex_UsdcCrvUsd,
        //         false,
        //         "withdraw(address,uint256)",
        //         new address[](1),
        //         "Withdraw crvUSD from the ITB Curve/Convex USDC/crvUSD contract",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = address(CRVUSD);
        //     // WithdrawAll both tokens
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurveConvex_UsdcCrvUsd,
        //         false,
        //         "withdrawAll(address)",
        //         new address[](1),
        //         "Withdraw all USDC from the ITB Curve/Convex USDC/crvUSD contract",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = address(USDC);
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurveConvex_UsdcCrvUsd,
        //         false,
        //         "withdrawAll(address)",
        //         new address[](1),
        //         "Withdraw all crvUSD from the ITB Curve/Convex USDC/crvUSD contract",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = address(CRVUSD);
        //     // Add liquidity and stake
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurveConvex_UsdcCrvUsd,
        //         false,
        //         "addLiquidityAllCoinsAndStakeConvex(address,uint256[],uint256,uint256)",
        //         new address[](2),
        //         "Add liquidity to the ITB Curve/Convex USDC/crvUSD contract and stake the convex tokens",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = usdc_CrvUsd_Curve_Pool;
        //     leafs[leafIndex].argumentAddresses[1] = usdc_CrvUsd_Convex_Id;
        //     // Unstake and remove liquidity
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurveConvex_UsdcCrvUsd,
        //         false,
        //         "unstakeAndRemoveLiquidityAllCoinsConvex(address,uint256,uint256,uint256[])",
        //         new address[](2),
        //         "Unstake the convex tokens and remove liquidity from the ITB Curve/Convex USDC/crvUSD contract",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = usdc_CrvUsd_Curve_Pool;
        //     leafs[leafIndex].argumentAddresses[1] = usdc_CrvUsd_Convex_Id;
        // }

        // ========================== ITB Curve sDAI/sUSDe ==========================
        /**
         * acceptOwnership() of itbCurve_sDai_sUsde
         * transfer both tokens to the pool
         * withdraw and withdraw all both tokens
         * addLiquidityAllCoinsAndStake
         * unstakeAndRemoveLiquidityAllCoins
         */
        // {
        //     // acceptOwnership
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurve_sDai_sUsde,
        //         false,
        //         "acceptOwnership()",
        //         new address[](0),
        //         "Accept ownership of the ITB Curve sDAI/sUSDe contract",
        //         itbDecoderAndSanitizer
        //     );
        //     // Transfer both tokens to the pool
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         address(sDAI),
        //         false,
        //         "transfer(address,uint256)",
        //         new address[](1),
        //         "Transfer sDAI to the ITB Curve sDAI/sUSDe contract",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = itbCurve_sDai_sUsde;
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         address(SUSDE),
        //         false,
        //         "transfer(address,uint256)",
        //         new address[](1),
        //         "Transfer sUSDe to the ITB Curve sDAI/sUSDe contract",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = itbCurve_sDai_sUsde;
        //     // Approvals
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurve_sDai_sUsde,
        //         false,
        //         "approveToken(address,address,uint256)",
        //         new address[](2),
        //         "Approve Curve pool to spend sDAI",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = address(sDAI);
        //     leafs[leafIndex].argumentAddresses[1] = sDai_sUsde_Curve_Pool;
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurve_sDai_sUsde,
        //         false,
        //         "approveToken(address,address,uint256)",
        //         new address[](2),
        //         "Approve Curve pool to spend sUSDe",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = address(SUSDE);
        //     leafs[leafIndex].argumentAddresses[1] = sDai_sUsde_Curve_Pool;
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurve_sDai_sUsde,
        //         false,
        //         "approveToken(address,address,uint256)",
        //         new address[](2),
        //         "Approve Curve gauge to spend Curve LP",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = sDai_sUsde_Curve_Pool;
        //     leafs[leafIndex].argumentAddresses[1] = sDai_sUsde_Curve_Gauge;
        //     // Withdraw both tokens
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurve_sDai_sUsde,
        //         false,
        //         "withdraw(address,uint256)",
        //         new address[](1),
        //         "Withdraw sDAI from the ITB Curve sDAI/sUSDe contract",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = address(sDAI);
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurve_sDai_sUsde,
        //         false,
        //         "withdraw(address,uint256)",
        //         new address[](1),
        //         "Withdraw sUSDe from the ITB Curve sDAI/sUSDe contract",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = address(SUSDE);
        //     // WithdrawAll both tokens
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurve_sDai_sUsde,
        //         false,
        //         "withdrawAll(address)",
        //         new address[](1),
        //         "Withdraw all sDAI from the ITB Curve sDAI/sUSDe contract",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = address(sDAI);
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurve_sDai_sUsde,
        //         false,
        //         "withdrawAll(address)",
        //         new address[](1),
        //         "Withdraw all sUSDe from the ITB Curve sDAI/sUSDe contract",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = address(SUSDE);
        //     // Add liquidity and stake
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurve_sDai_sUsde,
        //         false,
        //         "addLiquidityAllCoinsAndStake(address,uint256[],address,uint256)",
        //         new address[](2),
        //         "Add liquidity and stake to the ITB Curve sDAI/sUSDe contract",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = sDai_sUsde_Curve_Pool;
        //     leafs[leafIndex].argumentAddresses[1] = sDai_sUsde_Curve_Gauge;
        //     // Unstake and remove liquidity
        //     leafIndex++;
        //     leafs[leafIndex] = ManageLeaf(
        //         itbCurve_sDai_sUsde,
        //         false,
        //         "unstakeAndRemoveLiquidityAllCoins(address,uint256,address,uint256[])",
        //         new address[](2),
        //         "Unstake and remove liquidity from the ITB Curve sDAI/sUSDe contract",
        //         itbDecoderAndSanitizer
        //     );
        //     leafs[leafIndex].argumentAddresses[0] = sDai_sUsde_Curve_Pool;
        //     leafs[leafIndex].argumentAddresses[1] = sDai_sUsde_Curve_Gauge;
        // }

        // ========================== SYMBIOTIC ==========================
        address[] memory defaultCollaterals = new address[](1);
        defaultCollaterals[0] = getAddress(sourceChain, "sUSDeDefaultCollateral");
        _addSymbioticLeafs(leafs, defaultCollaterals);

        // ========================== PancakeSwapV3 ==========================
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", pancakeSwapDataDecoderAndSanitizer);

        /**
         * Full position management for USDC, USDT, DAI, USDe, sUSDe.
         */
        token0 = new address[](10);
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

        token1 = new address[](10);
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

        _addPancakeSwapV3Leafs(leafs, token0, token1);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/LiquidUsdStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function _addLeafsForITBPositionManager(
        ManageLeaf[] memory leafs,
        address itbPositionManager,
        ERC20[] memory tokensUsed,
        string memory itbContractName
    ) internal {
        // acceptOwnership
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "acceptOwnership()",
            new address[](0),
            "Accept ownership of the ITB Aave V3 USDC contract",
            itbDecoderAndSanitizer
        );
        for (uint256 i; i < tokensUsed.length; ++i) {
            // Transfer
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(tokensUsed[i]),
                false,
                "transfer(address,uint256)",
                new address[](1),
                string.concat("Transfer ", tokensUsed[i].symbol(), " to the ", itbContractName, " contract"),
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = itbPositionManager;
            // Withdraw
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbPositionManager,
                false,
                "withdraw(address,uint256)",
                new address[](1),
                string.concat("Withdraw ", tokensUsed[i].symbol(), " from the ", itbContractName, " contract"),
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(tokensUsed[i]);
            // WithdrawAll
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbPositionManager,
                false,
                "withdrawAll(address)",
                new address[](1),
                string.concat("Withdraw all ", tokensUsed[i].symbol(), " from the ", itbContractName, " contract"),
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(tokensUsed[i]);
        }
    }

    function _addLeafsForItbAaveV3(
        ManageLeaf[] memory leafs,
        address itbPositionManager,
        ERC20[] memory tokensUsed,
        string memory itbContractName
    ) internal {
        _addLeafsForITBPositionManager(leafs, itbPositionManager, tokensUsed, itbContractName);
        for (uint256 i; i < tokensUsed.length; ++i) {
            // Deposit
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbPositionManager,
                false,
                "deposit(address,uint256)",
                new address[](1),
                string.concat("Deposit ", tokensUsed[i].symbol(), " to the ", itbContractName, " contract"),
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(tokensUsed[i]);
            // Withdraw Supply
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbPositionManager,
                false,
                "withdrawSupply(address,uint256)",
                new address[](1),
                string.concat("Withdraw ", tokensUsed[i].symbol(), " supply from the ", itbContractName, " contract"),
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(tokensUsed[i]);
        }
    }

    function _addLeafsForItbGearbox(
        ManageLeaf[] memory leafs,
        address itbPositionManager,
        ERC20 underlying,
        ERC20 diesal,
        address diesalStaking,
        string memory itbContractName
    ) internal {
        ERC20[] memory tokensUsed = new ERC20[](2);
        tokensUsed[0] = underlying;
        tokensUsed[1] = diesal;
        _addLeafsForITBPositionManager(leafs, itbPositionManager, tokensUsed, itbContractName);

        // Approvals
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbGearboxUsdc,
            false,
            "approveToken(address,address,uint256)",
            new address[](2),
            string.concat("Approve Gearbox ", diesal.symbol(), " to spend ", underlying.symbol()),
            itbDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = address(underlying);
        leafs[leafIndex].argumentAddresses[1] = address(diesal);
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbGearboxUsdc,
            false,
            "approveToken(address,address,uint256)",
            new address[](2),
            string.concat("Approve Gearbox s", diesal.symbol(), " to spend ", diesal.symbol()),
            itbDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = address(diesal);
        leafs[leafIndex].argumentAddresses[1] = address(diesalStaking);

        // Deposit
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbGearboxUsdc,
            false,
            "deposit(uint256,uint256)",
            new address[](0),
            string.concat("Deposit ", underlying.symbol(), " into Gearbox ", diesal.symbol(), " contract"),
            itbDecoderAndSanitizer
        );

        // Withdraw
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbGearboxUsdc,
            false,
            "withdrawSupply(uint256,uint256)",
            new address[](0),
            string.concat("Withdraw ", underlying.symbol(), " from Gearbox ", diesal.symbol(), " contract"),
            itbDecoderAndSanitizer
        );

        // Stake
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbGearboxUsdc,
            false,
            "stake(uint256)",
            new address[](0),
            string.concat("Stake ", diesal.symbol(), " into Gearbox s", diesal.symbol(), " contract"),
            itbDecoderAndSanitizer
        );

        // Unstake
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbGearboxUsdc,
            false,
            "unstake(uint256)",
            new address[](0),
            string.concat("Unstake ", diesal.symbol(), " from Gearbox s", diesal.symbol(), " contract"),
            itbDecoderAndSanitizer
        );
    }
}
