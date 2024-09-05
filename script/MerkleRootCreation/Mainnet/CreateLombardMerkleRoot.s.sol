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
    address public rawDataDecoderAndSanitizer = 0x402d89D6c763E8e79b77Ac1424f28cbA80ac9caa;
    address public managerAddress = 0xcf38e37872748E3b66741A42560672A6cef75e9B;
    address public accountantAddress = 0x28634D0c5edC67CF2450E74deA49B90a4FF93dCE;

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

        leafIndex = 0;

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

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
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "WBTC");

        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "LBTC");

        _addUniswapV3Leafs(leafs, token0, token1);

        // ========================== Fee Claiming ==========================
        /**
         * Claim fees in USDC, DAI, USDT and USDE
         */
        ERC20[] memory feeAssets = new ERC20[](2);
        feeAssets[0] = getERC20(sourceChain, "WBTC");
        feeAssets[1] = getERC20(sourceChain, "LBTC");
        _addLeafsForFeeClaiming(leafs, feeAssets);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](10);
        SwapKind[] memory kind = new SwapKind[](10);
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
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Flashloans ==========================
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WBTC"));

        // ========================== Curve ==========================
        _addCurveLeafs(
            leafs, getAddress(sourceChain, "lBTC_wBTC_Curve_Pool"), 2, getAddress(sourceChain, "lBTC_wBTC_Curve_Gauge")
        );

        // ========================== Convex ==========================
        // _addConvexLeafs(leafs, getERC20(sourceChain, "lBTC_wBTC_Curve_Pool"), CONVEX_REWARDS_CONTRACT);

        // ERC20[] memory tellerAssets = new ERC20[](1);
        // tellerAssets[0] = getERC20(sourceChain, "WBTC");
        // _addTellerLeafs(leafs, 0xe19a43B1b8af6CeE71749Af2332627338B3242D1, tellerAssets);

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/LombardStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
