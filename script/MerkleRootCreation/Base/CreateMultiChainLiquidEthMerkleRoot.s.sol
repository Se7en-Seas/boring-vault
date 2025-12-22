// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Base/CreateMultiChainLiquidEthMerkleRoot.s.sol:CreateMultiChainLiquidEthMerkleRootScript --rpc-url $BASE_RPC_URL
 */
contract CreateMultiChainLiquidEthMerkleRootScript is Script, MerkleTreeHelper {
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

    struct BridgeAssets {
        ERC20[] localTokens;
        ERC20[] remoteTokens;
    }

    struct CollateralConfig {
        ERC20[] collateralAssets;
        ERC20[] feeAssets;
        ERC20[] claimTokens;
    }

    struct AerodromeTokens {
        address[] token0;
        address[] token1;
        address[] gauges;
    }

    address public boringVault = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C;
    address public rawDataDecoderAndSanitizer = 0x568a4E08909aab6995979dB24B3cdaE00244CeB4;
    address public managerAddress = 0x227975088C28DBBb4b421c6d96781a53578f19a8;
    address public accountantAddress = 0x0d05D94a5F1E76C18fbeB7A13d17C8a314088198;
    address public weEthFullDecoderAndSanitizer = 0x34Daed44420e3750608Eb992f092aDcA4A8C73b6;

    address public aerodromeDecoderAndSanitizer = 0x0cD9e50616efdc3a5598e4483e212fe127E08f3C;

    address public itbDecoderAndSanitizer = 0xEEb53299Cb894968109dfa420D69f0C97c835211;
    address public itbGearboxProtocolPositionManager = 0xad5dB17b44506785931dbc49c8857482c3b4F622;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateMultiChainLiquidEthStrategistMerkleRoot();
    }

    function generateMultiChainLiquidEthStrategistMerkleRoot() public {
        setSourceChainName(base);
        setAddress(false, base, "boringVault", boringVault);
        setAddress(false, base, "managerAddress", managerAddress);
        setAddress(false, base, "accountantAddress", accountantAddress);
        setAddress(false, base, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== Aave V3 ==========================
        _addAaveV3LeafsWithStruct(leafs);

        // ========================== Native ==========================
        /**
         * wrap, unwrap
         */
        _addNativeLeafs(leafs);

        // ========================== MorphoBlue ==========================
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "weETH_wETH_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "wstETH_wETH_945"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "cbETH_wETH_965"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "cbETH_wETH_945"));

        // ========================== UniswapV3 ==========================
        _addUniswapV3LeafsWithStruct(leafs);

        // ========================== Fee Claiming ==========================
        _addFeeClaimingLeafsWithStruct(leafs);

        // ========================== 1inch ==========================
        _add1InchSwappingLeafsWithStruct(leafs);

        // ========================== Compound V3 ==========================
        _addCompoundV3LeafsWithStruct(leafs);

        // ========================== Fluid fToken ==========================
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fWETH"));
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fWSTETH"));

        // ========================== Flashloans ==========================
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WETH"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WEETH"));

        // ========================== Standard Bridge ==========================
        _addStandardBridgeLeafsWithStruct(leafs);

        // ========================== Merkl ==========================
        _addMerklLeafsWithStruct(leafs);

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "WEETH"), getAddress(sourceChain, "WEETH"), layerZeroMainnetEndpointId
        );
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "WEETH"), getAddress(sourceChain, "WEETH"), layerZeroOptimismEndpointId
        );

        // ========================== Aerodrome ==========================
        _addAerodromeLeafsWithStruct(leafs);

        // ========================== WeETH ==========================
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", weEthFullDecoderAndSanitizer);

        _addWeETHLeafs(
            leafs,
            getAddress(sourceChain, "ETH"), //tokenIn
            getAddress(sourceChain, "boringVault") //referral
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/BaseMultiChainLiquidEthStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function _addAaveV3LeafsWithStruct(ManageLeaf[] memory leafs) internal {
        AaveAssets memory aaveAssets = AaveAssets({
            supplyAssets: new ERC20[](4),
            claimAssets: new ERC20[](4),
            borrowAssets: new ERC20[](4)
        });

        aaveAssets.supplyAssets[0] = getERC20(sourceChain, "WETH");
        aaveAssets.supplyAssets[1] = getERC20(sourceChain, "WEETH");
        aaveAssets.supplyAssets[2] = getERC20(sourceChain, "WSTETH");
        aaveAssets.supplyAssets[3] = getERC20(sourceChain, "CBETH");

        aaveAssets.claimAssets[0] = getERC20(sourceChain, "WETH");
        aaveAssets.claimAssets[1] = getERC20(sourceChain, "WEETH");
        aaveAssets.claimAssets[2] = getERC20(sourceChain, "WSTETH");
        aaveAssets.claimAssets[3] = getERC20(sourceChain, "CBETH");

        aaveAssets.borrowAssets[0] = getERC20(sourceChain, "WETH");
        aaveAssets.borrowAssets[1] = getERC20(sourceChain, "WEETH");
        aaveAssets.borrowAssets[2] = getERC20(sourceChain, "WSTETH");
        aaveAssets.borrowAssets[3] = getERC20(sourceChain, "CBETH");

        _addAaveV3Leafs(leafs, aaveAssets.supplyAssets, aaveAssets.borrowAssets, aaveAssets.claimAssets);
    }

    function _addUniswapV3LeafsWithStruct(ManageLeaf[] memory leafs) internal {
        UniswapV3Tokens memory tokens = UniswapV3Tokens({
            token0: new address[](3),
            token1: new address[](3)
        });

        tokens.token0[0] = getAddress(sourceChain, "WETH");
        tokens.token0[1] = getAddress(sourceChain, "WETH");
        tokens.token0[2] = getAddress(sourceChain, "WETH");

        tokens.token1[0] = getAddress(sourceChain, "WEETH");
        tokens.token1[1] = getAddress(sourceChain, "WSTETH");
        tokens.token1[2] = getAddress(sourceChain, "CBETH");

        _addUniswapV3Leafs(leafs, tokens.token0, tokens.token1);
    }

    function _addFeeClaimingLeafsWithStruct(ManageLeaf[] memory leafs) internal {
        CollateralConfig memory config = CollateralConfig({
            collateralAssets: new ERC20[](0),
            feeAssets: new ERC20[](2),
            claimTokens: new ERC20[](0)
        });

        config.feeAssets[0] = getERC20(sourceChain, "WETH");
        config.feeAssets[1] = getERC20(sourceChain, "WEETH");

        _addLeafsForFeeClaiming(leafs, config.feeAssets);
    }

    function _add1InchSwappingLeafsWithStruct(ManageLeaf[] memory leafs) internal {
        SwapAssets memory swapAssets = SwapAssets({
            assets: new address[](11),
            kinds: new SwapKind[](11)
        });

        swapAssets.assets[0] = getAddress(sourceChain, "WETH");
        swapAssets.kinds[0] = SwapKind.BuyAndSell;
        swapAssets.assets[1] = getAddress(sourceChain, "WEETH");
        swapAssets.kinds[1] = SwapKind.BuyAndSell;
        swapAssets.assets[2] = getAddress(sourceChain, "WSTETH");
        swapAssets.kinds[2] = SwapKind.BuyAndSell;
        swapAssets.assets[3] = getAddress(sourceChain, "CBETH");
        swapAssets.kinds[3] = SwapKind.BuyAndSell;
        swapAssets.assets[4] = getAddress(sourceChain, "CRV");
        swapAssets.kinds[4] = SwapKind.Sell;
        swapAssets.assets[5] = getAddress(sourceChain, "AURA");
        swapAssets.kinds[5] = SwapKind.Sell;
        swapAssets.assets[6] = getAddress(sourceChain, "BAL");
        swapAssets.kinds[6] = SwapKind.Sell;
        swapAssets.assets[7] = getAddress(sourceChain, "RETH");
        swapAssets.kinds[7] = SwapKind.BuyAndSell;
        swapAssets.assets[8] = getAddress(sourceChain, "BSDETH");
        swapAssets.kinds[8] = SwapKind.BuyAndSell;
        swapAssets.assets[9] = getAddress(sourceChain, "AERO");
        swapAssets.kinds[9] = SwapKind.Sell;
        swapAssets.assets[10] = getAddress(sourceChain, "SFRXETH");
        swapAssets.kinds[10] = SwapKind.BuyAndSell;

        _addLeafsFor1InchGeneralSwapping(leafs, swapAssets.assets, swapAssets.kinds);
    }

    function _addCompoundV3LeafsWithStruct(ManageLeaf[] memory leafs) internal {
        CollateralConfig memory config = CollateralConfig({
            collateralAssets: new ERC20[](1),
            feeAssets: new ERC20[](0),
            claimTokens: new ERC20[](0)
        });

        config.collateralAssets[0] = getERC20(sourceChain, "CBETH");

        _addCompoundV3Leafs(
            leafs, config.collateralAssets, getAddress(sourceChain, "cWETHV3"), getAddress(sourceChain, "cometRewards")
        );
    }

    function _addStandardBridgeLeafsWithStruct(ManageLeaf[] memory leafs) internal {
        BridgeAssets memory bridgeAssets = BridgeAssets({
            localTokens: new ERC20[](2),
            remoteTokens: new ERC20[](2)
        });

        bridgeAssets.localTokens[0] = getERC20(sourceChain, "RETH");
        bridgeAssets.localTokens[1] = getERC20(sourceChain, "CBETH");

        bridgeAssets.remoteTokens[0] = getERC20(mainnet, "RETH");
        bridgeAssets.remoteTokens[1] = getERC20(mainnet, "CBETH");

        _addStandardBridgeLeafs(
            leafs,
            mainnet,
            address(0),
            address(0),
            getAddress(sourceChain, "standardBridge"),
            address(0),
            bridgeAssets.localTokens,
            bridgeAssets.remoteTokens
        );
    }

    function _addMerklLeafsWithStruct(ManageLeaf[] memory leafs) internal {
        CollateralConfig memory config = CollateralConfig({
            collateralAssets: new ERC20[](0),
            feeAssets: new ERC20[](0),
            claimTokens: new ERC20[](1)
        });

        config.claimTokens[0] = getERC20(sourceChain, "UNI");

        _addMerklLeafs(
            leafs, getAddress(sourceChain, "merklDistributor"), getAddress(sourceChain, "dev1Address"), config.claimTokens
        );
    }

    function _addAerodromeLeafsWithStruct(ManageLeaf[] memory leafs) internal {
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", aerodromeDecoderAndSanitizer);

        // First set: V3 Leafs
        AerodromeTokens memory v3Tokens = AerodromeTokens({
            token0: new address[](3),
            token1: new address[](3),
            gauges: new address[](3)
        });

        v3Tokens.token0[0] = getAddress(sourceChain, "WETH");
        v3Tokens.token0[1] = getAddress(sourceChain, "WETH");
        v3Tokens.token0[2] = getAddress(sourceChain, "WETH");

        v3Tokens.token1[0] = getAddress(sourceChain, "WSTETH");
        v3Tokens.token1[1] = getAddress(sourceChain, "CBETH");
        v3Tokens.token1[2] = getAddress(sourceChain, "BSDETH");

        v3Tokens.gauges[0] = getAddress(sourceChain, "aerodrome_Weth_Wsteth_v3_1_gauge");
        v3Tokens.gauges[1] = getAddress(sourceChain, "aerodrome_Cbeth_Weth_v3_1_gauge");
        v3Tokens.gauges[2] = getAddress(sourceChain, "aerodrome_Weth_Bsdeth_v3_1_gauge");

        _addVelodromeV3Leafs(
            leafs, v3Tokens.token0, v3Tokens.token1, getAddress(sourceChain, "aerodromeNonFungiblePositionManager"), v3Tokens.gauges
        );

        // Second set: V2 Leafs
        AerodromeTokens memory v2Tokens = AerodromeTokens({
            token0: new address[](4),
            token1: new address[](4),
            gauges: new address[](4)
        });

        v2Tokens.token0[0] = getAddress(sourceChain, "WETH");
        v2Tokens.token0[1] = getAddress(sourceChain, "WEETH");
        v2Tokens.token0[2] = getAddress(sourceChain, "WETH");
        v2Tokens.token0[3] = getAddress(sourceChain, "SFRXETH");

        v2Tokens.token1[0] = getAddress(sourceChain, "WSTETH");
        v2Tokens.token1[1] = getAddress(sourceChain, "WETH");
        v2Tokens.token1[2] = getAddress(sourceChain, "RETH");
        v2Tokens.token1[3] = getAddress(sourceChain, "WSTETH");

        v2Tokens.gauges[0] = getAddress(sourceChain, "aerodrome_Weth_Wsteth_v2_30_gauge");
        v2Tokens.gauges[1] = getAddress(sourceChain, "aerodrome_Weth_Weeth_v2_30_gauge");
        v2Tokens.gauges[2] = getAddress(sourceChain, "aerodrome_Weth_Reth_v2_05_gauge");
        v2Tokens.gauges[3] = getAddress(sourceChain, "aerodrome_Sfrxeth_Wsteth_v2_30_gauge");

        _addVelodromeV2Leafs(leafs, v2Tokens.token0, v2Tokens.token1, getAddress(sourceChain, "aerodromeRouter"), v2Tokens.gauges);
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
