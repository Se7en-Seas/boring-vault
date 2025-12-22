// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";
/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateLiquidEthMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */

contract CreateLiquidEthMerkleRootScript is Script, MerkleTreeHelper {
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

    address public boringVault = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C;
    address public rawDataDecoderAndSanitizer = 0xdCbC0DeF063C497aA25Eb52eB29aa96C90be0F79;
    address public pancakeSwapDataDecoderAndSanitizer = 0x4dE66AA174b99481dAAe12F2Cdd5D76Dc14Eb3BC;
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
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        leafIndex = 0;

        ManageLeaf[] memory leafs = new ManageLeaf[](512);

        // ========================== Aave V3 ==========================
        _addAaveV3LeafsWithStruct(leafs);

        // ========================== SparkLend ==========================
        _addSparkLendLeafsWithStruct(leafs);

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
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarket"), false);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleZircuitWeETHMarket"), false);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarketSeptember"), false);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarketDecember"), false);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleKarakWeETHMarketSeptember"), false);
        // _addPendleMarketLeafs(leafs, pendleZircuitWeETHMarketAugust);
        // _addPendleMarketLeafs(leafs, pendleWeETHMarketJuly);

        // ========================== UniswapV3 ==========================
        _addUniswapV3LeafsWithStruct(leafs);

        // ========================== Fee Claiming ==========================
        _addFeeClaimingLeafsWithStruct(leafs);

        // ========================== 1inch ==========================
        _add1InchSwappingLeafsWithStruct(leafs);

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

        // ========================== Aura ==========================
        _addAuraLeafs(leafs, getAddress(sourceChain, "aura_reth_weeth"));
        _addAuraLeafs(leafs, getAddress(sourceChain, "aura_reth_weth"));

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
        _addItbReserveLeafsWithStruct(leafs);

        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleZircuitWeETHMarketAugust"), false);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarketJuly"), false);

        // ========================== PancakeSwapV3 ==========================
        _addPancakeSwapV3LeafsWithStruct(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/LiquidEthStrategistLeafs.json";

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
        aaveAssets.supplyAssets[3] = getERC20(sourceChain, "RETH");

        aaveAssets.claimAssets[0] = getERC20(sourceChain, "WETH");
        aaveAssets.claimAssets[1] = getERC20(sourceChain, "WEETH");
        aaveAssets.claimAssets[2] = getERC20(sourceChain, "WSTETH");
        aaveAssets.claimAssets[3] = getERC20(sourceChain, "RETH");

        aaveAssets.borrowAssets[0] = getERC20(sourceChain, "WETH");
        aaveAssets.borrowAssets[1] = getERC20(sourceChain, "WEETH");
        aaveAssets.borrowAssets[2] = getERC20(sourceChain, "WSTETH");
        aaveAssets.borrowAssets[3] = getERC20(sourceChain, "RETH");

        _addAaveV3Leafs(leafs, aaveAssets.supplyAssets, aaveAssets.borrowAssets, aaveAssets.claimAssets);
    }

    function _addSparkLendLeafsWithStruct(ManageLeaf[] memory leafs) internal {
        AaveAssets memory sparkAssets = AaveAssets({
            supplyAssets: new ERC20[](4),
            claimAssets: new ERC20[](4),
            borrowAssets: new ERC20[](3)
        });

        sparkAssets.supplyAssets[0] = getERC20(sourceChain, "WETH");
        sparkAssets.supplyAssets[1] = getERC20(sourceChain, "WEETH");
        sparkAssets.supplyAssets[2] = getERC20(sourceChain, "WSTETH");
        sparkAssets.supplyAssets[3] = getERC20(sourceChain, "RETH");

        sparkAssets.claimAssets[0] = getERC20(sourceChain, "WETH");
        sparkAssets.claimAssets[1] = getERC20(sourceChain, "WEETH");
        sparkAssets.claimAssets[2] = getERC20(sourceChain, "WSTETH");
        sparkAssets.claimAssets[3] = getERC20(sourceChain, "RETH");

        sparkAssets.borrowAssets[0] = getERC20(sourceChain, "WETH");
        sparkAssets.borrowAssets[1] = getERC20(sourceChain, "WSTETH");
        sparkAssets.borrowAssets[2] = getERC20(sourceChain, "RETH");

        _addSparkLendLeafs(leafs, sparkAssets.supplyAssets, sparkAssets.borrowAssets, sparkAssets.claimAssets);
    }

    function _addUniswapV3LeafsWithStruct(ManageLeaf[] memory leafs) internal {
        UniswapV3Tokens memory tokens = UniswapV3Tokens({
            token0: new address[](7),
            token1: new address[](7)
        });

        tokens.token0[0] = getAddress(sourceChain, "WETH");
        tokens.token0[1] = getAddress(sourceChain, "WETH");
        tokens.token0[2] = getAddress(sourceChain, "WETH");
        tokens.token0[3] = getAddress(sourceChain, "WEETH");
        tokens.token0[4] = getAddress(sourceChain, "WEETH");
        tokens.token0[5] = getAddress(sourceChain, "WSTETH");
        tokens.token0[6] = getAddress(sourceChain, "WETH");

        tokens.token1[0] = getAddress(sourceChain, "WEETH");
        tokens.token1[1] = getAddress(sourceChain, "WSTETH");
        tokens.token1[2] = getAddress(sourceChain, "RETH");
        tokens.token1[3] = getAddress(sourceChain, "WSTETH");
        tokens.token1[4] = getAddress(sourceChain, "RETH");
        tokens.token1[5] = getAddress(sourceChain, "RETH");
        tokens.token1[6] = getAddress(sourceChain, "SFRXETH");

        _addUniswapV3Leafs(leafs, tokens.token0, tokens.token1);
    }

    function _addFeeClaimingLeafsWithStruct(ManageLeaf[] memory leafs) internal {
        CollateralConfig memory config = CollateralConfig({
            collateralAssets: new ERC20[](0),
            feeAssets: new ERC20[](3),
            claimTokens: new ERC20[](0)
        });

        config.feeAssets[0] = getERC20(sourceChain, "WETH");
        config.feeAssets[1] = getERC20(sourceChain, "WEETH");
        config.feeAssets[2] = getERC20(sourceChain, "EETH");

        _addLeafsForFeeClaiming(leafs, config.feeAssets);
    }

    function _add1InchSwappingLeafsWithStruct(ManageLeaf[] memory leafs) internal {
        SwapAssets memory swapAssets = SwapAssets({
            assets: new address[](13),
            kinds: new SwapKind[](13)
        });

        swapAssets.assets[0] = getAddress(sourceChain, "WETH");
        swapAssets.kinds[0] = SwapKind.BuyAndSell;
        swapAssets.assets[1] = getAddress(sourceChain, "WEETH");
        swapAssets.kinds[1] = SwapKind.BuyAndSell;
        swapAssets.assets[2] = getAddress(sourceChain, "WSTETH");
        swapAssets.kinds[2] = SwapKind.BuyAndSell;
        swapAssets.assets[3] = getAddress(sourceChain, "RETH");
        swapAssets.kinds[3] = SwapKind.BuyAndSell;
        swapAssets.assets[4] = getAddress(sourceChain, "GEAR");
        swapAssets.kinds[4] = SwapKind.Sell;
        swapAssets.assets[5] = getAddress(sourceChain, "CRV");
        swapAssets.kinds[5] = SwapKind.Sell;
        swapAssets.assets[6] = getAddress(sourceChain, "CVX");
        swapAssets.kinds[6] = SwapKind.Sell;
        swapAssets.assets[7] = getAddress(sourceChain, "AURA");
        swapAssets.kinds[7] = SwapKind.Sell;
        swapAssets.assets[8] = getAddress(sourceChain, "BAL");
        swapAssets.kinds[8] = SwapKind.Sell;
        swapAssets.assets[9] = getAddress(sourceChain, "PENDLE");
        swapAssets.kinds[9] = SwapKind.Sell;
        swapAssets.assets[10] = getAddress(sourceChain, "SFRXETH");
        swapAssets.kinds[10] = SwapKind.BuyAndSell;
        swapAssets.assets[11] = getAddress(sourceChain, "INST");
        swapAssets.kinds[11] = SwapKind.Sell;
        swapAssets.assets[12] = getAddress(sourceChain, "RSR");
        swapAssets.kinds[12] = SwapKind.Sell;

        _addLeafsFor1InchGeneralSwapping(leafs, swapAssets.assets, swapAssets.kinds);
    }

    function _addItbReserveLeafsWithStruct(ManageLeaf[] memory leafs) internal {
        CollateralConfig memory config = CollateralConfig({
            collateralAssets: new ERC20[](3),
            feeAssets: new ERC20[](0),
            claimTokens: new ERC20[](0)
        });

        config.collateralAssets[0] = getERC20(sourceChain, "SFRXETH");
        config.collateralAssets[1] = getERC20(sourceChain, "WSTETH");
        config.collateralAssets[2] = getERC20(sourceChain, "RETH");

        _addLeafsForItbReserve(
            leafs, itbReserveProtocolPositionManager, config.collateralAssets, "ETHPlus ITB Reserve Protocol Position Manager"
        );
    }

    function _addPancakeSwapV3LeafsWithStruct(ManageLeaf[] memory leafs) internal {
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", pancakeSwapDataDecoderAndSanitizer);

        UniswapV3Tokens memory tokens = UniswapV3Tokens({
            token0: new address[](7),
            token1: new address[](7)
        });

        tokens.token0[0] = getAddress(sourceChain, "WETH");
        tokens.token0[1] = getAddress(sourceChain, "WETH");
        tokens.token0[2] = getAddress(sourceChain, "WETH");
        tokens.token0[3] = getAddress(sourceChain, "WEETH");
        tokens.token0[4] = getAddress(sourceChain, "WEETH");
        tokens.token0[5] = getAddress(sourceChain, "WSTETH");
        tokens.token0[6] = getAddress(sourceChain, "WETH");

        tokens.token1[0] = getAddress(sourceChain, "WEETH");
        tokens.token1[1] = getAddress(sourceChain, "WSTETH");
        tokens.token1[2] = getAddress(sourceChain, "RETH");
        tokens.token1[3] = getAddress(sourceChain, "WSTETH");
        tokens.token1[4] = getAddress(sourceChain, "RETH");
        tokens.token1[5] = getAddress(sourceChain, "RETH");
        tokens.token1[6] = getAddress(sourceChain, "SFRXETH");

        _addPancakeSwapV3Leafs(leafs, tokens.token0, tokens.token1);
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
