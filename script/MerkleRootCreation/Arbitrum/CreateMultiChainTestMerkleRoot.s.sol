// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Arbitrum/CreateMultiChainTestMerkleRoot.s.sol:CreateMultiChainTestMerkleRootScript --rpc-url $ARBITRUM_RPC_URL
 */
contract CreateMultiChainTestMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xaA6D4Fb1FF961f8E52334f433974d40484e8be8F;
    address public rawDataDecoderAndSanitizer = 0x28edfc0bffdF1f9C986923729b88B5F40f2B92D9;
    address public managerAddress = 0x744d1f71a6d064204b4c59Cf2BDCF9De9C6c3430;
    address public accountantAddress = 0x99c836937305693A5518819ED457B0d3dfE99785;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateMultiChainTestStrategistMerkleRoot();
    }

    function generateMultiChainTestStrategistMerkleRoot() public {
        setSourceChainName(arbitrum);
        setAddress(false, arbitrum, "boringVault", boringVault);
        setAddress(false, arbitrum, "managerAddress", managerAddress);
        setAddress(false, arbitrum, "accountantAddress", accountantAddress);
        setAddress(false, arbitrum, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](512);

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](4);
        supplyAssets[0] = getERC20(sourceChain, "WETH");
        supplyAssets[1] = getERC20(sourceChain, "WEETH");
        supplyAssets[2] = getERC20(sourceChain, "WSTETH");
        supplyAssets[3] = getERC20(sourceChain, "RETH");
        ERC20[] memory borrowAssets = new ERC20[](4);
        borrowAssets[0] = getERC20(sourceChain, "WETH");
        borrowAssets[1] = getERC20(sourceChain, "WEETH");
        borrowAssets[2] = getERC20(sourceChain, "WSTETH");
        borrowAssets[3] = getERC20(sourceChain, "RETH");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== Native ==========================
        /**
         * wrap, unwrap
         */
        _addNativeLeafs(leafs);

        // ========================== Gearbox ==========================
        _addGearboxLeafs(leafs, ERC4626(getAddress(sourceChain, "dWETHV3")), getAddress(sourceChain, "sdWETHV3"));

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarketSeptember"));

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](10);
        token0[0] = getAddress(sourceChain, "WETH");
        token0[1] = getAddress(sourceChain, "WETH");
        token0[2] = getAddress(sourceChain, "WETH");
        token0[3] = getAddress(sourceChain, "WEETH");
        token0[4] = getAddress(sourceChain, "WEETH");
        token0[5] = getAddress(sourceChain, "WSTETH");
        token0[6] = getAddress(sourceChain, "WETH");
        token0[7] = getAddress(sourceChain, "WETH");
        token0[8] = getAddress(sourceChain, "WETH");
        token0[9] = getAddress(sourceChain, "WETH");

        address[] memory token1 = new address[](10);
        token1[0] = getAddress(sourceChain, "WEETH");
        token1[1] = getAddress(sourceChain, "WSTETH");
        token1[2] = getAddress(sourceChain, "RETH");
        token1[3] = getAddress(sourceChain, "WSTETH");
        token1[4] = getAddress(sourceChain, "RETH");
        token1[5] = getAddress(sourceChain, "RETH");
        token1[6] = getAddress(sourceChain, "SFRXETH");
        token1[7] = getAddress(sourceChain, "CBETH");
        token1[8] = getAddress(sourceChain, "OSETH");
        token1[9] = getAddress(sourceChain, "RSETH");

        _addUniswapV3Leafs(leafs, token0, token1);

        // ========================== Fee Claiming ==========================
        /**
         * Claim fees in USDC, DAI, USDT and USDE
         */
        ERC20[] memory feeAssets = new ERC20[](2);
        feeAssets[0] = getERC20(sourceChain, "WETH");
        feeAssets[1] = getERC20(sourceChain, "WEETH");
        _addLeafsForFeeClaiming(leafs, feeAssets);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](15);
        SwapKind[] memory kind = new SwapKind[](15);
        assets[0] = getAddress(sourceChain, "WETH");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "WEETH");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "WSTETH");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "RETH");
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = getAddress(sourceChain, "ARB");
        kind[4] = SwapKind.Sell;
        assets[5] = getAddress(sourceChain, "CRV");
        kind[5] = SwapKind.Sell;
        assets[6] = getAddress(sourceChain, "AURA");
        kind[6] = SwapKind.Sell;
        assets[7] = getAddress(sourceChain, "BAL");
        kind[7] = SwapKind.Sell;
        assets[8] = getAddress(sourceChain, "PENDLE");
        kind[8] = SwapKind.Sell;
        assets[9] = getAddress(sourceChain, "SFRXETH");
        kind[9] = SwapKind.BuyAndSell;
        assets[10] = getAddress(sourceChain, "RSR");
        kind[10] = SwapKind.Sell;
        assets[11] = getAddress(sourceChain, "LINK");
        kind[11] = SwapKind.BuyAndSell;
        assets[12] = getAddress(sourceChain, "CBETH");
        kind[12] = SwapKind.BuyAndSell;
        assets[13] = getAddress(sourceChain, "OSETH");
        kind[13] = SwapKind.BuyAndSell;
        assets[14] = getAddress(sourceChain, "RSETH");
        kind[14] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "wstETH_wETH_01"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "wstETH_wETH_05"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "PENDLE_wETH_30"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "wETH_weETH_30"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "wETH_weETH_05"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "wETH_weETH_01"));

        // ========================== Flashloans ==========================
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WETH"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WEETH"));

        // ========================== Native Bridge Leafs ==========================
        ERC20[] memory bridgeAssets = new ERC20[](5);
        bridgeAssets[0] = getERC20(sourceChain, "WETH");
        bridgeAssets[1] = getERC20(sourceChain, "WEETH");
        bridgeAssets[2] = getERC20(sourceChain, "WSTETH");
        bridgeAssets[3] = getERC20(sourceChain, "RETH");
        bridgeAssets[4] = getERC20(sourceChain, "CBETH");
        _addArbitrumNativeBridgeLeafs(leafs, bridgeAssets);

        // ========================== CCIP Bridge Leafs ==========================
        ERC20[] memory ccipBridgeAssets = new ERC20[](1);
        ccipBridgeAssets[0] = getERC20(sourceChain, "WETH");
        ERC20[] memory ccipBridgeFeeAssets = new ERC20[](2);
        ccipBridgeFeeAssets[0] = getERC20(sourceChain, "WETH");
        ccipBridgeFeeAssets[1] = getERC20(sourceChain, "LINK");
        _addCcipBridgeLeafs(leafs, ccipMainnetChainSelector, ccipBridgeAssets, ccipBridgeFeeAssets);

        // ========================== Fluid fToken ==========================
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fWETH"));
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fWSTETH"));

        // ========================== Vault Craft ==========================
        _addVaultCraftLeafs(
            leafs, ERC4626(getAddress(sourceChain, "compoundV3Weth")), getAddress(sourceChain, "compoundV3WethGauge")
        );

        // ========================== Compound V3 ==========================
        ERC20[] memory collateralAssets = new ERC20[](3);
        collateralAssets[0] = getERC20(sourceChain, "WSTETH");
        collateralAssets[1] = getERC20(sourceChain, "RETH");
        collateralAssets[2] = getERC20(sourceChain, "WEETH");
        _addCompoundV3Leafs(
            leafs, collateralAssets, getAddress(sourceChain, "cWETHV3"), getAddress(sourceChain, "cometRewards")
        );

        // ========================== Merkl ==========================
        {
            ERC20[] memory tokensToClaim = new ERC20[](2);
            tokensToClaim[0] = getERC20(sourceChain, "UNI");
            tokensToClaim[1] = getERC20(sourceChain, "ARB");
            _addMerklLeafs(
                leafs,
                getAddress(sourceChain, "merklDistributor"),
                getAddress(sourceChain, "dev1Address"),
                tokensToClaim
            );
        }

        // ========================== Balancer ==========================
        _addBalancerLeafs(leafs, getBytes32(sourceChain, "rsETH_wETH_Id"), getAddress(sourceChain, "rsETH_wETH_Gauge"));
        _addBalancerLeafs(
            leafs, getBytes32(sourceChain, "wstETH_sfrxETH_Id"), getAddress(sourceChain, "wstETH_sfrxETH_Gauge")
        );
        _addBalancerLeafs(
            leafs, getBytes32(sourceChain, "wstETH_wETH_Gyro_Id"), getAddress(sourceChain, "wstETH_wETH_Gyro_Gauge")
        );
        _addBalancerLeafs(
            leafs, getBytes32(sourceChain, "weETH_wstETH_Gyro_Id"), getAddress(sourceChain, "weETH_wstETH_Gyro_Gauge")
        );
        _addBalancerLeafs(leafs, getBytes32(sourceChain, "osETH_wETH_Id"), getAddress(sourceChain, "osETH_wETH_Gauge"));

        // ========================== Aura ==========================
        _addAuraLeafs(leafs, getAddress(sourceChain, "aura_rsETH_wETH"));
        _addAuraLeafs(leafs, getAddress(sourceChain, "aura_wstETH_sfrxETH"));
        _addAuraLeafs(leafs, getAddress(sourceChain, "aura_wstETH_wETH_Gyro"));
        _addAuraLeafs(leafs, getAddress(sourceChain, "aura_weETH_wstETH_Gyro"));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/ArbitrumMultiChainTestStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
