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

    address public boringVault = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C;
    address public rawDataDecoderAndSanitizer = 0x0C8B49b06544fA8B5c85755267498E407433edBB;
    address public managerAddress = 0x227975088C28DBBb4b421c6d96781a53578f19a8;
    address public accountantAddress = 0x0d05D94a5F1E76C18fbeB7A13d17C8a314088198;

    address public itbDecoderAndSanitizer = 0xEEb53299Cb894968109dfa420D69f0C97c835211;
    address public itbGearboxProtocolPositionManager = 0xad5dB17b44506785931dbc49c8857482c3b4F622;

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

        // ========================== Fluid fToken ==========================
        _addFluidFTokenLeafs(leafs, fWETH);
        _addFluidFTokenLeafs(leafs, fWSTETH);

        // iTb
        _addLeafsForItbGearbox(
            leafs, itbGearboxProtocolPositionManager, WETH, ERC20(dWETHV3), sdWETHV3, "ITB wETH Gearbox"
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/ArbitrumMultiChainLiquidEthStrategistLeafs.json";

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
            itbGearboxProtocolPositionManager,
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
            itbGearboxProtocolPositionManager,
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
            itbGearboxProtocolPositionManager,
            false,
            "deposit(uint256,uint256)",
            new address[](0),
            string.concat("Deposit ", underlying.symbol(), " into Gearbox ", diesal.symbol(), " contract"),
            itbDecoderAndSanitizer
        );

        // Withdraw
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbGearboxProtocolPositionManager,
            false,
            "withdrawSupply(uint256,uint256)",
            new address[](0),
            string.concat("Withdraw ", underlying.symbol(), " from Gearbox ", diesal.symbol(), " contract"),
            itbDecoderAndSanitizer
        );

        // Stake
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbGearboxProtocolPositionManager,
            false,
            "stake(uint256)",
            new address[](0),
            string.concat("Stake ", diesal.symbol(), " into Gearbox s", diesal.symbol(), " contract"),
            itbDecoderAndSanitizer
        );

        // Unstake
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbGearboxProtocolPositionManager,
            false,
            "unstake(uint256)",
            new address[](0),
            string.concat("Unstake ", diesal.symbol(), " from Gearbox s", diesal.symbol(), " contract"),
            itbDecoderAndSanitizer
        );
    }
}
