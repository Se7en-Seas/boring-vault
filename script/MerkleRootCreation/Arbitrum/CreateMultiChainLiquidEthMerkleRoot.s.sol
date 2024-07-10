// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {
    BaseMerkleRootGenerator, MainnetAddresses
} from "script/MerkleRootCreation/Arbitrum/BaseMerkleRootGenerator.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Arbitrum/CreateMultiChainLiquidEthMerkleRoot.s.sol:CreateMultiChainLiquidEthMerkleRootScript --rpc-url $ARBITRUM_RPC_URL
 */
contract CreateMultiChainLiquidEthMerkleRootScript is BaseMerkleRootGenerator {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xaA6D4Fb1FF961f8E52334f433974d40484e8be8F;
    address public rawDataDecoderAndSanitizer = 0xD5678900d413591513216E386332Db21c1bEc131;
    address public managerAddress = 0x744d1f71a6d064204b4c59Cf2BDCF9De9C6c3430;
    address public accountantAddress = 0x99c836937305693A5518819ED457B0d3dfE99785;

    // address public itbDecoderAndSanitizer = 0xEEb53299Cb894968109dfa420D69f0C97c835211;
    // address public itbReserveProtocolPositionManager = 0x778aC5d0EE062502fADaa2d300a51dE0869f7995;

    MainnetAddresses public mainnetAddresses;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateMultiChainLiquidEthStrategistMerkleRoot();
    }

    function generateMultiChainLiquidEthStrategistMerkleRoot() public {
        mainnetAddresses = new MainnetAddresses();
        updateAddresses(boringVault, rawDataDecoderAndSanitizer, managerAddress, accountantAddress);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

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

        // ========================== Native ==========================
        /**
         * wrap, unwrap
         */
        _addNativeLeafs(leafs);

        // ========================== Gearbox ==========================
        _addGearboxLeafs(leafs, ERC4626(dWETHV3), sdWETHV3);

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, pendleWeETHMarketSeptember);

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
        ERC20[] memory feeAssets = new ERC20[](2);
        feeAssets[0] = WETH;
        feeAssets[1] = WEETH;
        _addLeafsForFeeClaiming(leafs, feeAssets);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](12);
        SwapKind[] memory kind = new SwapKind[](12);
        assets[0] = address(WETH);
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = address(WEETH);
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = address(WSTETH);
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = address(RETH);
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = address(ARB);
        kind[4] = SwapKind.Sell;
        assets[5] = address(CRV);
        kind[5] = SwapKind.Sell;
        assets[6] = address(AURA);
        kind[6] = SwapKind.Sell;
        assets[7] = address(BAL);
        kind[7] = SwapKind.Sell;
        assets[8] = address(PENDLE);
        kind[8] = SwapKind.Sell;
        assets[9] = address(SFRXETH);
        kind[9] = SwapKind.BuyAndSell;
        assets[10] = address(RSR);
        kind[10] = SwapKind.Sell;
        assets[11] = address(LINK);
        kind[11] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        _addLeafsFor1InchUniswapV3Swapping(leafs, wstETH_wETH_01);
        _addLeafsFor1InchUniswapV3Swapping(leafs, wstETH_wETH_05);
        _addLeafsFor1InchUniswapV3Swapping(leafs, PENDLE_wETH_30);
        _addLeafsFor1InchUniswapV3Swapping(leafs, wETH_weETH_30);
        _addLeafsFor1InchUniswapV3Swapping(leafs, wETH_weETH_05);
        _addLeafsFor1InchUniswapV3Swapping(leafs, wETH_weETH_01);

        // ========================== Flashloans ==========================
        _addBalancerFlashloanLeafs(leafs, address(WETH));
        _addBalancerFlashloanLeafs(leafs, address(WEETH));

        // ========================== Native Bridge Leafs ==========================
        ERC20[] memory bridgeAssets = new ERC20[](3);
        bridgeAssets[0] = mainnetAddresses.WETH();
        bridgeAssets[1] = mainnetAddresses.WEETH();
        bridgeAssets[2] = mainnetAddresses.WSTETH();
        _addArbitrumNativeBridgeLeafs(leafs, bridgeAssets);

        // ========================== CCIP Bridge Leafs ==========================
        ERC20[] memory ccipBridgeAssets = new ERC20[](1);
        ccipBridgeAssets[0] = WETH;
        ERC20[] memory ccipBridgeFeeAssets = new ERC20[](2);
        ccipBridgeFeeAssets[0] = WETH;
        ccipBridgeFeeAssets[1] = LINK;
        _addCcipBridgeLeafs(leafs, mainnetChainSelector, ccipBridgeAssets, ccipBridgeFeeAssets);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/ArbitrumMultiChainLiquidEthStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    // function _addLeafsForITBPositionManager(
    //     ManageLeaf[] memory leafs,
    //     address itbPositionManager,
    //     ERC20[] memory tokensUsed,
    //     string memory itbContractName
    // ) internal {
    //     // acceptOwnership
    //     leafIndex++;
    //     leafs[leafIndex] = ManageLeaf(
    //         itbPositionManager,
    //         false,
    //         "acceptOwnership()",
    //         new address[](0),
    //         string.concat("Accept ownership of the ", itbContractName, " contract"),
    //         itbDecoderAndSanitizer
    //     );
    //     for (uint256 i; i < tokensUsed.length; ++i) {
    //         // Transfer
    //         leafIndex++;
    //         leafs[leafIndex] = ManageLeaf(
    //             address(tokensUsed[i]),
    //             false,
    //             "transfer(address,uint256)",
    //             new address[](1),
    //             string.concat("Transfer ", tokensUsed[i].symbol(), " to the ", itbContractName, " contract"),
    //             itbDecoderAndSanitizer
    //         );
    //         leafs[leafIndex].argumentAddresses[0] = itbPositionManager;
    //         // Withdraw
    //         leafIndex++;
    //         leafs[leafIndex] = ManageLeaf(
    //             itbPositionManager,
    //             false,
    //             "withdraw(address,uint256)",
    //             new address[](1),
    //             string.concat("Withdraw ", tokensUsed[i].symbol(), " from the ", itbContractName, " contract"),
    //             itbDecoderAndSanitizer
    //         );
    //         leafs[leafIndex].argumentAddresses[0] = address(tokensUsed[i]);
    //         // WithdrawAll
    //         leafIndex++;
    //         leafs[leafIndex] = ManageLeaf(
    //             itbPositionManager,
    //             false,
    //             "withdrawAll(address)",
    //             new address[](1),
    //             string.concat("Withdraw all ", tokensUsed[i].symbol(), " from the ", itbContractName, " contract"),
    //             itbDecoderAndSanitizer
    //         );
    //         leafs[leafIndex].argumentAddresses[0] = address(tokensUsed[i]);
    //     }
    // }

    // function _addLeafsForItbReserve(
    //     ManageLeaf[] memory leafs,
    //     address itbPositionManager,
    //     ERC20[] memory tokensUsed,
    //     string memory itbContractName
    // ) internal {
    //     _addLeafsForITBPositionManager(leafs, itbPositionManager, tokensUsed, itbContractName);

    //     // mint
    //     leafIndex++;
    //     leafs[leafIndex] = ManageLeaf(
    //         itbPositionManager,
    //         false,
    //         "mint(uint256)",
    //         new address[](0),
    //         string.concat("Mint ", itbContractName),
    //         itbDecoderAndSanitizer
    //     );

    //     // redeem
    //     leafIndex++;
    //     leafs[leafIndex] = ManageLeaf(
    //         itbPositionManager,
    //         false,
    //         "redeem(uint256,uint256[])",
    //         new address[](0),
    //         string.concat("Redeem ", itbContractName),
    //         itbDecoderAndSanitizer
    //     );

    //     // redeemCustom
    //     leafIndex++;
    //     leafs[leafIndex] = ManageLeaf(
    //         itbPositionManager,
    //         false,
    //         "redeemCustom(uint256,uint48[],uint192[],address[],uint256[])",
    //         new address[](tokensUsed.length),
    //         string.concat("Redeem custom ", itbContractName),
    //         itbDecoderAndSanitizer
    //     );
    //     for (uint256 i; i < tokensUsed.length; ++i) {
    //         leafs[leafIndex].argumentAddresses[i] = address(tokensUsed[i]);
    //     }

    //     // assemble
    //     leafIndex++;
    //     leafs[leafIndex] = ManageLeaf(
    //         itbPositionManager,
    //         false,
    //         "assemble(uint256,uint256)",
    //         new address[](0),
    //         string.concat("Assemble ", itbContractName),
    //         itbDecoderAndSanitizer
    //     );

    //     // disassemble
    //     leafIndex++;
    //     leafs[leafIndex] = ManageLeaf(
    //         itbPositionManager,
    //         false,
    //         "disassemble(uint256,uint256[])",
    //         new address[](0),
    //         string.concat("Disassemble ", itbContractName),
    //         itbDecoderAndSanitizer
    //     );

    //     // fullDisassemble
    //     leafIndex++;
    //     leafs[leafIndex] = ManageLeaf(
    //         itbPositionManager,
    //         false,
    //         "fullDisassemble(uint256[])",
    //         new address[](0),
    //         string.concat("Full disassemble ", itbContractName),
    //         itbDecoderAndSanitizer
    //     );
    // }
}
