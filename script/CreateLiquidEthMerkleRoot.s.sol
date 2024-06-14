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

    address public boringVault = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C;
    address public rawDataDecoderAndSanitizer = 0x00965B60EFa746d41198aE844725AaB26D14e51b;
    address public managerAddress = 0x227975088C28DBBb4b421c6d96781a53578f19a8;
    address public accountantAddress = 0x0d05D94a5F1E76C18fbeB7A13d17C8a314088198;

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
        _addPendleMarketLeafs(leafs, pendleWeETHMarketSeptember);
        _addPendleMarketLeafs(leafs, pendleWeETHMarketDecember);
        _addPendleMarketLeafs(leafs, pendleKarakWeETHMarketSeptember);

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](7);
        token0[0] = address(WETH);
        token0[1] = address(WETH);
        token0[2] = address(WETH);
        token0[3] = address(WEETH);
        token0[4] = address(WEETH);
        token0[5] = address(WSTETH);
        token0[6] = address(WETH);

        address[] memory token1 = new address[](7);
        token1[0] = address(WEETH);
        token1[1] = address(WSTETH);
        token1[2] = address(RETH);
        token1[3] = address(WSTETH);
        token1[4] = address(RETH);
        token1[5] = address(RETH);
        token1[6] = address(SFRXETH);

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
        address[] memory assets = new address[](13);
        SwapKind[] memory kind = new SwapKind[](13);
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
        assets[10] = address(SFRXETH);
        kind[10] = SwapKind.BuyAndSell;
        assets[11] = address(INST);
        kind[11] = SwapKind.Sell;
        assets[12] = address(RSR);
        kind[12] = SwapKind.Sell;
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
        _addSwellLeafs(leafs, address(WSTETH), swellSimpleStaking);
        _addSwellLeafs(leafs, address(SFRXETH), swellSimpleStaking);
        _addSwellLeafs(leafs, pendleEethPt, swellSimpleStaking);
        _addSwellLeafs(leafs, pendleEethPtDecember, swellSimpleStaking);
        _addSwellLeafs(leafs, pendleEethPtSeptember, swellSimpleStaking);
        _addSwellLeafs(leafs, pendleZircuitEethPt, swellSimpleStaking);

        // ========================== Zircuit ==========================
        _addZircuitLeafs(leafs, address(WEETH), zircuitSimpleStaking);
        _addZircuitLeafs(leafs, address(WSTETH), zircuitSimpleStaking);

        // ========================== Balancer ==========================
        _addBalancerLeafs(leafs, rETH_weETH_id, rETH_weETH_gauge);
        _addBalancerLeafs(leafs, rETH_wETH_id, rETH_wETH_gauge);

        // ========================== Aura ==========================
        _addAuraLeafs(leafs, aura_reth_weeth);
        _addAuraLeafs(leafs, aura_reth_weth);

        // ========================== Flashloans ==========================
        _addBalancerFlashloanLeafs(leafs, address(WETH));
        _addBalancerFlashloanLeafs(leafs, address(WEETH));

        // ========================== Fluid fToken ==========================
        _addFluidFTokenLeafs(leafs, fWETH);
        _addFluidFTokenLeafs(leafs, fWSTETH);

        // ========================== FrxEth ==========================
        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(address(SFRXETH)));

        // ========================== Curve ==========================
        _addCurveLeafs(leafs, weETH_wETH_ng, 2, weETH_wETH_ng_gauge);

        // ========================== Convex ==========================
        _addConvexLeafs(leafs, ERC20(weETH_wETH_NG_Pool), weETH_wETH_NG_Convex_Reward);

        // ========================== ITB Reserve ==========================
        ERC20[] memory tokensUsed = new ERC20[](3);
        tokensUsed[0] = SFRXETH;
        tokensUsed[1] = WSTETH;
        tokensUsed[2] = RETH;
        _addLeafsForItbReserve(
            leafs, itbReserveProtocolPositionManager, tokensUsed, "ETHPlus ITB Reserve Protocol Position Manager"
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/LiquidEthStrategistLeafs.json";

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
