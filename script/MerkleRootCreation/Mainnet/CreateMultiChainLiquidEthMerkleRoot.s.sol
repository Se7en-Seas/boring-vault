// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateMultiChainLiquidEthMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */
contract CreateMultiChainLiquidEthMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C;
    address public rawDataDecoderAndSanitizer = 0x6175ab325B51bFDd27ab306e4D6A5850AFbd7764;
    address public managerAddress = 0x227975088C28DBBb4b421c6d96781a53578f19a8;
    address public accountantAddress = 0x0d05D94a5F1E76C18fbeB7A13d17C8a314088198;
    address public pancakeSwapDataDecoderAndSanitizer = 0x4dE66AA174b99481dAAe12F2Cdd5D76Dc14Eb3BC;
    address public itbDecoderAndSanitizer = 0xEEb53299Cb894968109dfa420D69f0C97c835211;
    address public itbReserveProtocolPositionManager = 0x778aC5d0EE062502fADaa2d300a51dE0869f7995;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateLiquidEthStrategistMerkleRoot();
    }

    function generateLiquidEthStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](1024);

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

        // ========================== SparkLend ==========================
        borrowAssets = new ERC20[](3);
        borrowAssets[0] = getERC20(sourceChain, "WETH");
        borrowAssets[1] = getERC20(sourceChain, "WSTETH");
        borrowAssets[2] = getERC20(sourceChain, "RETH");
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
        _addGearboxLeafs(leafs, ERC4626(getAddress(sourceChain, "dWETHV3")), getAddress(sourceChain, "sdWETHV3"));

        // ========================== MorphoBlue ==========================
        /**
         * weETH/wETH  86.00 LLTV market 0x698fe98247a40c5771537b5786b2f3f9d78eb487b4ce4d75533cd0e94d88a115
         */
        _addMorphoBlueSupplyLeafs(leafs, 0x698fe98247a40c5771537b5786b2f3f9d78eb487b4ce4d75533cd0e94d88a115);

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarket"));
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleZircuitWeETHMarket"));
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarketSeptember"));
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarketDecember"));
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleKarakWeETHMarketSeptember"));
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleZircuitWeETHMarketAugust"));
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarketJuly"));

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](8);
        token0[0] = getAddress(sourceChain, "WETH");
        token0[1] = getAddress(sourceChain, "WETH");
        token0[2] = getAddress(sourceChain, "WETH");
        token0[3] = getAddress(sourceChain, "WEETH");
        token0[4] = getAddress(sourceChain, "WEETH");
        token0[5] = getAddress(sourceChain, "WSTETH");
        token0[6] = getAddress(sourceChain, "WETH");
        token0[7] = getAddress(sourceChain, "WETH");

        address[] memory token1 = new address[](8);
        token1[0] = getAddress(sourceChain, "WEETH");
        token1[1] = getAddress(sourceChain, "WSTETH");
        token1[2] = getAddress(sourceChain, "RETH");
        token1[3] = getAddress(sourceChain, "WSTETH");
        token1[4] = getAddress(sourceChain, "RETH");
        token1[5] = getAddress(sourceChain, "RETH");
        token1[6] = getAddress(sourceChain, "SFRXETH");
        token1[7] = getAddress(sourceChain, "CBETH");

        _addUniswapV3Leafs(leafs, token0, token1);

        // ========================== Fee Claiming ==========================
        /**
         * Claim fees in USDC, DAI, USDT and USDE
         */
        ERC20[] memory feeAssets = new ERC20[](3);
        feeAssets[0] = getERC20(sourceChain, "WETH");
        feeAssets[1] = getERC20(sourceChain, "WEETH");
        feeAssets[2] = getERC20(sourceChain, "EETH");
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
        assets[4] = getAddress(sourceChain, "GEAR");
        kind[4] = SwapKind.Sell;
        assets[5] = getAddress(sourceChain, "CRV");
        kind[5] = SwapKind.Sell;
        assets[6] = getAddress(sourceChain, "CVX");
        kind[6] = SwapKind.Sell;
        assets[7] = getAddress(sourceChain, "AURA");
        kind[7] = SwapKind.Sell;
        assets[8] = getAddress(sourceChain, "BAL");
        kind[8] = SwapKind.Sell;
        assets[9] = getAddress(sourceChain, "PENDLE");
        kind[9] = SwapKind.Sell;
        assets[10] = getAddress(sourceChain, "SFRXETH");
        kind[10] = SwapKind.BuyAndSell;
        assets[11] = getAddress(sourceChain, "INST");
        kind[11] = SwapKind.Sell;
        assets[12] = getAddress(sourceChain, "RSR");
        kind[12] = SwapKind.Sell;
        assets[13] = getAddress(sourceChain, "CBETH");
        kind[13] = SwapKind.BuyAndSell;
        assets[14] = getAddress(sourceChain, "RSETH");
        kind[14] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "wstETH_wETH_01"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "rETH_wETH_01"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "rETH_wETH_05"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "wstETH_rETH_05"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "PENDLE_wETH_30"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "wETH_weETH_05"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "GEAR_wETH_100"));

        // ========================== Curve Swapping ==========================
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "weETH_wETH_Pool"));
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "weETH_wETH_NG_Pool"));

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
            leafs, getAddress(sourceChain, "pendleEethPt"), getAddress(sourceChain, "swellSimpleStaking")
        );
        _addSwellSimpleStakingLeafs(
            leafs, getAddress(sourceChain, "pendleEethPtDecember"), getAddress(sourceChain, "swellSimpleStaking")
        );
        _addSwellSimpleStakingLeafs(
            leafs, getAddress(sourceChain, "pendleEethPtSeptember"), getAddress(sourceChain, "swellSimpleStaking")
        );
        _addSwellSimpleStakingLeafs(
            leafs, getAddress(sourceChain, "pendleZircuitEethPt"), getAddress(sourceChain, "swellSimpleStaking")
        );

        // ========================== Zircuit ==========================
        _addZircuitLeafs(leafs, getAddress(sourceChain, "WEETH"), getAddress(sourceChain, "zircuitSimpleStaking"));
        _addZircuitLeafs(leafs, getAddress(sourceChain, "WSTETH"), getAddress(sourceChain, "zircuitSimpleStaking"));

        // ========================== Balancer ==========================
        _addBalancerLeafs(leafs, getBytes32(sourceChain, "rETH_weETH_id"), getAddress(sourceChain, "rETH_weETH_gauge"));
        _addBalancerLeafs(leafs, getBytes32(sourceChain, "rETH_wETH_id"), getAddress(sourceChain, "rETH_wETH_gauge"));
        _addBalancerLeafs(
            leafs, getBytes32(sourceChain, "wstETH_wETH_Id"), getAddress(sourceChain, "wstETH_wETH_Gauge")
        );

        // ========================== Aura ==========================
        _addAuraLeafs(leafs, getAddress(sourceChain, "aura_reth_weeth"));
        _addAuraLeafs(leafs, getAddress(sourceChain, "aura_reth_weth"));
        _addAuraLeafs(leafs, getAddress(sourceChain, "aura_wstETH_wETH"));

        // ========================== Flashloans ==========================
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WETH"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WEETH"));

        // ========================== Fluid fToken ==========================
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fWETH"));
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fWSTETH"));

        // ========================== FrxEth ==========================
        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "SFRXETH")));

        // ========================== Curve ==========================
        _addCurveLeafs(
            leafs, getAddress(sourceChain, "weETH_wETH_ng"), 2, getAddress(sourceChain, "weETH_wETH_ng_gauge")
        );

        // ========================== Convex ==========================
        _addConvexLeafs(
            leafs, getERC20(sourceChain, "weETH_wETH_NG_Pool"), getAddress(sourceChain, "weETH_wETH_NG_Convex_Reward")
        );

        // ========================== ITB Reserve ==========================
        ERC20[] memory tokensUsed = new ERC20[](3);
        tokensUsed[0] = getERC20(sourceChain, "SFRXETH");
        tokensUsed[1] = getERC20(sourceChain, "WSTETH");
        tokensUsed[2] = getERC20(sourceChain, "RETH");
        _addLeafsForItbReserve(
            leafs, itbReserveProtocolPositionManager, tokensUsed, "ETHPlus ITB Reserve Protocol Position Manager"
        );

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
        _addCcipBridgeLeafs(leafs, ccipArbitrumChainSelector, ccipBridgeAssets, ccipBridgeFeeAssets);

        // ========================== Standard Bridge ==========================
        {
            ERC20[] memory localTokens = new ERC20[](2);
            localTokens[0] = getERC20(sourceChain, "RETH");
            localTokens[1] = getERC20(sourceChain, "CBETH");
            ERC20[] memory remoteTokens = new ERC20[](2);
            remoteTokens[0] = getERC20(optimism, "RETH");
            remoteTokens[1] = getERC20(optimism, "CBETH");
            _addStandardBridgeLeafs(
                leafs,
                optimism,
                getAddress(optimism, "crossDomainMessenger"),
                getAddress(sourceChain, "optimismResolvedDelegate"),
                getAddress(sourceChain, "optimismStandardBridge"),
                getAddress(sourceChain, "optimismPortal"),
                localTokens,
                remoteTokens
            );

            remoteTokens[0] = getERC20(base, "RETH");
            remoteTokens[1] = getERC20(base, "CBETH");

            _addStandardBridgeLeafs(
                leafs,
                base,
                getAddress(base, "crossDomainMessenger"),
                getAddress(sourceChain, "baseResolvedDelegate"),
                getAddress(sourceChain, "baseStandardBridge"),
                getAddress(sourceChain, "basePortal"),
                localTokens,
                remoteTokens
            );
        }

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "WEETH"),
            getAddress(sourceChain, "EtherFiOFTAdapter"),
            layerZeroOptimismEndpointId
        );
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "WEETH"), getAddress(sourceChain, "EtherFiOFTAdapter"), layerZeroBaseEndpointId
        );

        // ========================== Merkl ==========================
        {
            ERC20[] memory tokensToClaim = new ERC20[](1);
            tokensToClaim[0] = getERC20(sourceChain, "UNI");
            _addMerklLeafs(
                leafs,
                getAddress(sourceChain, "merklDistributor"),
                getAddress(sourceChain, "dev1Address"),
                tokensToClaim
            );
        }

        // ========================== PancakeSwapV3 ==========================
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", pancakeSwapDataDecoderAndSanitizer);

        token0 = new address[](8);
        token0[0] = getAddress(sourceChain, "WETH");
        token0[1] = getAddress(sourceChain, "WETH");
        token0[2] = getAddress(sourceChain, "WETH");
        token0[3] = getAddress(sourceChain, "WEETH");
        token0[4] = getAddress(sourceChain, "WEETH");
        token0[5] = getAddress(sourceChain, "WSTETH");
        token0[6] = getAddress(sourceChain, "WETH");
        token0[7] = getAddress(sourceChain, "WETH");

        token1 = new address[](8);
        token1[0] = getAddress(sourceChain, "WEETH");
        token1[1] = getAddress(sourceChain, "WSTETH");
        token1[2] = getAddress(sourceChain, "RETH");
        token1[3] = getAddress(sourceChain, "WSTETH");
        token1[4] = getAddress(sourceChain, "RETH");
        token1[5] = getAddress(sourceChain, "RETH");
        token1[6] = getAddress(sourceChain, "SFRXETH");
        token1[7] = getAddress(sourceChain, "CBETH");

        _addPancakeSwapV3Leafs(leafs, token0, token1);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/MainnetMultiChainLiquidEthStrategistLeafs.json";

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
            string.concat("Accept ownership of the ", itbContractName, " contract"),
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

    function _addLeafsForItbReserve(
        ManageLeaf[] memory leafs,
        address itbPositionManager,
        ERC20[] memory tokensUsed,
        string memory itbContractName
    ) internal {
        _addLeafsForITBPositionManager(leafs, itbPositionManager, tokensUsed, itbContractName);

        // mint
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "mint(uint256)",
            new address[](0),
            string.concat("Mint ", itbContractName),
            itbDecoderAndSanitizer
        );

        // redeem
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "redeem(uint256,uint256[])",
            new address[](0),
            string.concat("Redeem ", itbContractName),
            itbDecoderAndSanitizer
        );

        // redeemCustom
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "redeemCustom(uint256,uint48[],uint192[],address[],uint256[])",
            new address[](tokensUsed.length),
            string.concat("Redeem custom ", itbContractName),
            itbDecoderAndSanitizer
        );
        for (uint256 i; i < tokensUsed.length; ++i) {
            leafs[leafIndex].argumentAddresses[i] = address(tokensUsed[i]);
        }

        // assemble
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "assemble(uint256,uint256)",
            new address[](0),
            string.concat("Assemble ", itbContractName),
            itbDecoderAndSanitizer
        );

        // disassemble
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "disassemble(uint256,uint256[])",
            new address[](0),
            string.concat("Disassemble ", itbContractName),
            itbDecoderAndSanitizer
        );

        // fullDisassemble
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "fullDisassemble(uint256[])",
            new address[](0),
            string.concat("Full disassemble ", itbContractName),
            itbDecoderAndSanitizer
        );
    }
}
