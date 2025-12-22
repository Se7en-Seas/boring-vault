// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateLiquidUsualMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */
contract CreateLiquidUsualMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    struct AaveAssets {
        ERC20[] supplyAssets;
        ERC20[] claimAssets;
        ERC20[] borrowAssets;
    }

    struct UniswapV3Tokens {
        address[] token0;
        address[] token1;
    }

    struct SwapAssets {
        address[] assets;
        SwapKind[] kinds;
    }

    struct CollateralConfig {
        ERC20[] collateralAssets;
        ERC20[] feeAssets;
        ERC20[] claimTokens;
    }

    address public boringVault = 0xeDa663610638E6557c27e2f4e973D3393e844E70;
    address public rawDataDecoderAndSanitizer = 0xA8633d10B828f80383D57a63914Fd23D6F71B157;
    address public managerAddress = 0x5F2Ecb56Ed33c86219840A2F89316285A1D9ee0F;
    address public accountantAddress = 0x1D4F0F05e50312d3E7B65659Ef7d06aa74651e0C;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateLiquidUsualStrategistMerkleRoot();
    }

    function generateLiquidUsualStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](512);

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](4);
        supplyAssets[0] = getERC20(sourceChain, "USDC");
        supplyAssets[1] = getERC20(sourceChain, "USDT");
        supplyAssets[2] = getERC20(sourceChain, "DAI");
        supplyAssets[3] = getERC20(sourceChain, "sDAI");
        ERC20[] memory claimAssets = new ERC20[](4);
        claimAssets[0] = getERC20(sourceChain, "USDC");
        claimAssets[1] = getERC20(sourceChain, "USDT");
        claimAssets[2] = getERC20(sourceChain, "DAI");
        claimAssets[3] = getERC20(sourceChain, "sDAI");
        ERC20[] memory borrowAssets = new ERC20[](3);
        borrowAssets[0] = getERC20(sourceChain, "USDC");
        borrowAssets[1] = getERC20(sourceChain, "USDT");
        borrowAssets[2] = getERC20(sourceChain, "DAI");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets, claimAssets);

        // ========================== MakerDAO ==========================
        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sDAI")));

        // ========================== MetaMorpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "usualBoostedUSDC")));

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
         * USD0/USDC  86.00 LLTV market 0xb48bb53f0f2690c71e8813f2dc7ed6fca9ac4b0ace3faa37b4a8e5ece38fa1a2
         * USD0USD0++/USDC   86.00 LLTV market 0x864c9b82eb066ae2c038ba763dfc0221001e62fc40925530056349633eb0a259
         */
        _addMorphoBlueSupplyLeafs(leafs, 0xb48bb53f0f2690c71e8813f2dc7ed6fca9ac4b0ace3faa37b4a8e5ece38fa1a2);
        _addMorphoBlueSupplyLeafs(leafs, 0x864c9b82eb066ae2c038ba763dfc0221001e62fc40925530056349633eb0a259);

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleUSD0PlusMarketOctober"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleUSD0PlusMarketOctober"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USD0Plus_market_03_26_2025"), true);

        // ========================== UniswapV3 ==========================
        _addUniswapV3LeafsWithStruct(leafs);

        // ========================== Fee Claiming ==========================
        _addFeeClaimingLeafsWithStruct(leafs);

        // ========================== Fluid fToken ==========================
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fUSDC"));
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fUSDT"));

        // ========================== Compound V3 ==========================
        _addCompoundV3LeafsWithStruct(leafs);

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
        _add1InchSwappingLeafsWithStruct(leafs);

        // ========================== 1inch Uniswap V3 ==========================
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "GEAR_USDT_30"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "DAI_USDC_01"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "DAI_USDC_05"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "USDC_USDT_01"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "USDC_USDT_05"));

        // ========================== Curve ==========================
        _addCurveLeafs(
            leafs,
            getAddress(sourceChain, "USD0_USD0++_CurvePool"),
            2,
            getAddress(sourceChain, "USD0_USD0++_CurveGauge")
        );

        // ========================== Usual ==========================
        _addUsualMoneyLeafs(leafs);

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/LiquidUsualStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function _addAaveV3LeafsWithStruct(ManageLeaf[] memory leafs) internal {
        AaveAssets memory aaveAssets = AaveAssets({
            supplyAssets: new ERC20[](4),
            claimAssets: new ERC20[](4),
            borrowAssets: new ERC20[](3)
        });

        aaveAssets.supplyAssets[0] = getERC20(sourceChain, "USDC");
        aaveAssets.supplyAssets[1] = getERC20(sourceChain, "USDT");
        aaveAssets.supplyAssets[2] = getERC20(sourceChain, "DAI");
        aaveAssets.supplyAssets[3] = getERC20(sourceChain, "sDAI");

        aaveAssets.claimAssets[0] = getERC20(sourceChain, "USDC");
        aaveAssets.claimAssets[1] = getERC20(sourceChain, "USDT");
        aaveAssets.claimAssets[2] = getERC20(sourceChain, "DAI");
        aaveAssets.claimAssets[3] = getERC20(sourceChain, "sDAI");

        aaveAssets.borrowAssets[0] = getERC20(sourceChain, "USDC");
        aaveAssets.borrowAssets[1] = getERC20(sourceChain, "USDT");
        aaveAssets.borrowAssets[2] = getERC20(sourceChain, "DAI");

        _addAaveV3Leafs(leafs, aaveAssets.supplyAssets, aaveAssets.borrowAssets, aaveAssets.claimAssets);
    }

    function _addUniswapV3LeafsWithStruct(ManageLeaf[] memory leafs) internal {
        UniswapV3Tokens memory tokens = UniswapV3Tokens({
            token0: new address[](10),
            token1: new address[](10)
        });

        tokens.token0[0] = getAddress(sourceChain, "USDC");
        tokens.token0[1] = getAddress(sourceChain, "USDC");
        tokens.token0[2] = getAddress(sourceChain, "USDC");
        tokens.token0[3] = getAddress(sourceChain, "USDC");
        tokens.token0[4] = getAddress(sourceChain, "USDT");
        tokens.token0[5] = getAddress(sourceChain, "USDT");
        tokens.token0[6] = getAddress(sourceChain, "USDT");
        tokens.token0[7] = getAddress(sourceChain, "DAI");
        tokens.token0[8] = getAddress(sourceChain, "DAI");
        tokens.token0[9] = getAddress(sourceChain, "USD0");

        tokens.token1[0] = getAddress(sourceChain, "USDT");
        tokens.token1[1] = getAddress(sourceChain, "DAI");
        tokens.token1[2] = getAddress(sourceChain, "USD0");
        tokens.token1[3] = getAddress(sourceChain, "USD0_plus");
        tokens.token1[4] = getAddress(sourceChain, "DAI");
        tokens.token1[5] = getAddress(sourceChain, "USD0");
        tokens.token1[6] = getAddress(sourceChain, "USD0_plus");
        tokens.token1[7] = getAddress(sourceChain, "USD0");
        tokens.token1[8] = getAddress(sourceChain, "USD0_plus");
        tokens.token1[9] = getAddress(sourceChain, "USD0_plus");

        _addUniswapV3Leafs(leafs, tokens.token0, tokens.token1);
    }

    function _addFeeClaimingLeafsWithStruct(ManageLeaf[] memory leafs) internal {
        CollateralConfig memory config = CollateralConfig({
            collateralAssets: new ERC20[](0),
            feeAssets: new ERC20[](5),
            claimTokens: new ERC20[](0)
        });

        config.feeAssets[0] = getERC20(sourceChain, "USDC");
        config.feeAssets[1] = getERC20(sourceChain, "DAI");
        config.feeAssets[2] = getERC20(sourceChain, "USDT");
        config.feeAssets[3] = getERC20(sourceChain, "USD0");
        config.feeAssets[4] = getERC20(sourceChain, "USD0_plus");

        _addLeafsForFeeClaiming(leafs, config.feeAssets);
    }

    function _addCompoundV3LeafsWithStruct(ManageLeaf[] memory leafs) internal {
        CollateralConfig memory config = CollateralConfig({
            collateralAssets: new ERC20[](0),
            feeAssets: new ERC20[](0),
            claimTokens: new ERC20[](0)
        });

        _addCompoundV3Leafs(
            leafs, config.collateralAssets, getAddress(sourceChain, "cUSDCV3"), getAddress(sourceChain, "cometRewards")
        );
        _addCompoundV3Leafs(
            leafs, config.collateralAssets, getAddress(sourceChain, "cUSDTV3"), getAddress(sourceChain, "cometRewards")
        );
    }

    function _add1InchSwappingLeafsWithStruct(ManageLeaf[] memory leafs) internal {
        SwapAssets memory swapAssets = SwapAssets({
            assets: new address[](13),
            kinds: new SwapKind[](13)
        });

        swapAssets.assets[0] = getAddress(sourceChain, "USDC");
        swapAssets.kinds[0] = SwapKind.BuyAndSell;
        swapAssets.assets[1] = getAddress(sourceChain, "USDT");
        swapAssets.kinds[1] = SwapKind.BuyAndSell;
        swapAssets.assets[2] = getAddress(sourceChain, "DAI");
        swapAssets.kinds[2] = SwapKind.BuyAndSell;
        swapAssets.assets[3] = getAddress(sourceChain, "USD0");
        swapAssets.kinds[3] = SwapKind.BuyAndSell;
        swapAssets.assets[4] = getAddress(sourceChain, "USD0_plus");
        swapAssets.kinds[4] = SwapKind.BuyAndSell;
        swapAssets.assets[5] = getAddress(sourceChain, "GEAR");
        swapAssets.kinds[5] = SwapKind.Sell;
        swapAssets.assets[6] = getAddress(sourceChain, "CRV");
        swapAssets.kinds[6] = SwapKind.Sell;
        swapAssets.assets[7] = getAddress(sourceChain, "CVX");
        swapAssets.kinds[7] = SwapKind.Sell;
        swapAssets.assets[8] = getAddress(sourceChain, "AURA");
        swapAssets.kinds[8] = SwapKind.Sell;
        swapAssets.assets[9] = getAddress(sourceChain, "BAL");
        swapAssets.kinds[9] = SwapKind.Sell;
        swapAssets.assets[10] = getAddress(sourceChain, "INST");
        swapAssets.kinds[10] = SwapKind.Sell;
        swapAssets.assets[11] = getAddress(sourceChain, "RSR");
        swapAssets.kinds[11] = SwapKind.Sell;
        swapAssets.assets[12] = getAddress(sourceChain, "PENDLE");
        swapAssets.kinds[12] = SwapKind.Sell;

        _addLeafsFor1InchGeneralSwapping(leafs, swapAssets.assets, swapAssets.kinds);
    }
}
