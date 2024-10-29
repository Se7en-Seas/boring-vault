// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateLombardMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */
contract CreateLombardMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x5401b8620E5FB570064CA9114fd1e135fd77D57c;
    address public rawDataDecoderAndSanitizer = 0x1060E9391dfdba7F1F24D142eFE71544F590d33F;
    address public managerAddress = 0xcf38e37872748E3b66741A42560672A6cef75e9B;
    address public accountantAddress = 0x28634D0c5edC67CF2450E74deA49B90a4FF93dCE;

    address public pancakeSwapDataDecoderAndSanitizer = 0xac226f3e2677d79c0688A9f6f05B9B4eBBeDdebD;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateLombardStrategistMerkleRoot();
    }

    function generateLombardStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        leafIndex = type(uint256).max;

        ManageLeaf[] memory leafs = new ManageLeaf[](512);

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](1);
        supplyAssets[0] = getERC20(sourceChain, "WBTC");
        ERC20[] memory borrowAssets = new ERC20[](1);
        borrowAssets[0] = getERC20(sourceChain, "WBTC");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== SparkLend ==========================
        /**
         * lend USDC, USDT, DAI, sDAI
         * borrow wETH, wstETH
         */
        borrowAssets = new ERC20[](1);
        borrowAssets[0] = getERC20(sourceChain, "WBTC");
        _addSparkLendLeafs(leafs, supplyAssets, borrowAssets);

        // ========================== Gearbox ==========================
        _addGearboxLeafs(leafs, ERC4626(getAddress(sourceChain, "dWBTCV3")), getAddress(sourceChain, "sdWBTCV3"));

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](5);
        token0[0] = getAddress(sourceChain, "WBTC");
        token0[1] = getAddress(sourceChain, "WBTC");
        token0[2] = getAddress(sourceChain, "WBTC");
        token0[3] = getAddress(sourceChain, "WBTC");
        token0[4] = getAddress(sourceChain, "eBTC");

        address[] memory token1 = new address[](5);
        token1[0] = getAddress(sourceChain, "LBTC");
        token1[1] = getAddress(sourceChain, "cbBTC");
        token1[2] = getAddress(sourceChain, "eBTC");
        token1[3] = getAddress(sourceChain, "LBTC");
        token1[4] = getAddress(sourceChain, "LBTC");

        _addUniswapV3Leafs(leafs, token0, token1);

        // ========================== Fee Claiming ==========================
        /**
         * Claim fees in USDC, DAI, USDT and USDE
         */
        ERC20[] memory feeAssets = new ERC20[](3);
        feeAssets[0] = getERC20(sourceChain, "WBTC");
        feeAssets[1] = getERC20(sourceChain, "LBTC");
        feeAssets[2] = getERC20(sourceChain, "cbBTC");
        _addLeafsForFeeClaiming(leafs, feeAssets);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](11);
        SwapKind[] memory kind = new SwapKind[](11);
        assets[0] = getAddress(sourceChain, "WBTC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "LBTC");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "GEAR");
        kind[2] = SwapKind.Sell;
        assets[3] = getAddress(sourceChain, "CRV");
        kind[3] = SwapKind.Sell;
        assets[4] = getAddress(sourceChain, "CVX");
        kind[4] = SwapKind.Sell;
        assets[5] = getAddress(sourceChain, "AURA");
        kind[5] = SwapKind.Sell;
        assets[6] = getAddress(sourceChain, "BAL");
        kind[6] = SwapKind.Sell;
        assets[7] = getAddress(sourceChain, "PENDLE");
        kind[7] = SwapKind.Sell;
        assets[8] = getAddress(sourceChain, "INST");
        kind[8] = SwapKind.Sell;
        assets[9] = getAddress(sourceChain, "RSR");
        kind[9] = SwapKind.Sell;
        assets[10] = getAddress(sourceChain, "cbBTC");
        kind[10] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Flashloans ==========================
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WBTC"));

        // ========================== Curve ==========================
        _addCurveLeafs(leafs, getAddress(sourceChain, "lBTC_wBTC_Curve_Pool"), 2, address(0));
        _addCurveLeafs(
            leafs,
            getAddress(sourceChain, "eBTC_LBTC_WBTC_Curve_Pool"),
            3,
            getAddress(sourceChain, "eBTC_LBTC_WBTC_Curve_Gauge")
        );
        _addLeafsForCurveSwapping3Pool(leafs, getAddress(sourceChain, "eBTC_LBTC_WBTC_Curve_Pool"));

        // ========================== Convex ==========================
        // _addConvexLeafs(leafs, getERC20(sourceChain, "lBTC_wBTC_Curve_Pool"), CONVEX_REWARDS_CONTRACT);

        // ========================== BoringVaults ==========================
        {
            ERC20[] memory tellerAssets = new ERC20[](3);
            tellerAssets[0] = getERC20(sourceChain, "WBTC");
            tellerAssets[1] = getERC20(sourceChain, "LBTC");
            tellerAssets[2] = getERC20(sourceChain, "cbBTC");
            address eBTCTeller = 0xe19a43B1b8af6CeE71749Af2332627338B3242D1;
            _addTellerLeafs(leafs, eBTCTeller, tellerAssets);

            address newEBTCTeller = 0x458797A320e6313c980C2bC7D270466A6288A8bB;
            _addTellerLeafs(leafs, newEBTCTeller, tellerAssets);
        }

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_eBTC_market_12_26_24"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_LBTC_corn_market_12_26_24"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_LBTC_market_03_26_25"), true);

        // ========================== MorphoBlue ==========================
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "LBTC_WBTC_945"));

        // ========================== MetaMorpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "Re7WBTC")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletWBTCcore")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "MCwBTC")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "Re7cbBTC")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletCbBTCcore")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "MCcbBTC")));

        // ========================== Gearbox ==========================
        _addGearboxLeafs(leafs, ERC4626(getAddress(sourceChain, "dWBTCV3")), getAddress(sourceChain, "sdWBTCV3"));

        // ========================== PancakeSwapV3 ==========================
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", pancakeSwapDataDecoderAndSanitizer);

        token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "WBTC");

        token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "LBTC");

        _addPancakeSwapV3Leafs(leafs, token0, token1);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Mainnet/LombardStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
