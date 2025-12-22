// SPDX-License-Identifier: UNLICENSED
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
        ERC20[] bridgeAssets;
        ERC20[] ccipBridgeAssets;
        ERC20[] ccipBridgeFeeAssets;
    }

    struct CollateralConfig {
        ERC20[] collateralAssets;
        ERC20[] feeAssets;
        ERC20[] claimTokens;
    }

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
        _addAaveV3LeafsWithStruct(leafs);

        // ========================== Native ==========================
        /**
         * wrap, unwrap
         */
        _addNativeLeafs(leafs);

        // ========================== Gearbox ==========================
        _addGearboxLeafs(leafs, ERC4626(getAddress(sourceChain, "dWETHV3")), getAddress(sourceChain, "sdWETHV3"));

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarketSeptember"), false);

        // ========================== UniswapV3 ==========================
        _addUniswapV3LeafsWithStruct(leafs);

        // ========================== Fee Claiming ==========================
        _addFeeClaimingLeafsWithStruct(leafs);

        // ========================== 1inch ==========================
        _add1InchSwappingLeafsWithStruct(leafs);

        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "wstETH_wETH_01"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "wstETH_wETH_05"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "PENDLE_wETH_30"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "wETH_weETH_30"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "wETH_weETH_05"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "wETH_weETH_01"));

        // ========================== Flashloans ==========================
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WETH"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WEETH"));

        // ========================== Bridge Leafs ==========================
        _addBridgeLeafsWithStruct(leafs);

        // ========================== Fluid fToken ==========================
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fWETH"));
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fWSTETH"));

        // ========================== Vault Craft ==========================
        _addVaultCraftLeafs(
            leafs, ERC4626(getAddress(sourceChain, "compoundV3Weth")), getAddress(sourceChain, "compoundV3WethGauge")
        );

        // ========================== Compound V3 ==========================
        _addCompoundV3LeafsWithStruct(leafs);

        // ========================== Merkl ==========================
        _addMerklLeafsWithStruct(leafs);

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

    function _addUniswapV3LeafsWithStruct(ManageLeaf[] memory leafs) internal {
        UniswapV3Tokens memory tokens = UniswapV3Tokens({
            token0: new address[](10),
            token1: new address[](10)
        });

        tokens.token0[0] = getAddress(sourceChain, "WETH");
        tokens.token0[1] = getAddress(sourceChain, "WETH");
        tokens.token0[2] = getAddress(sourceChain, "WETH");
        tokens.token0[3] = getAddress(sourceChain, "WEETH");
        tokens.token0[4] = getAddress(sourceChain, "WEETH");
        tokens.token0[5] = getAddress(sourceChain, "WSTETH");
        tokens.token0[6] = getAddress(sourceChain, "WETH");
        tokens.token0[7] = getAddress(sourceChain, "WETH");
        tokens.token0[8] = getAddress(sourceChain, "WETH");
        tokens.token0[9] = getAddress(sourceChain, "WETH");

        tokens.token1[0] = getAddress(sourceChain, "WEETH");
        tokens.token1[1] = getAddress(sourceChain, "WSTETH");
        tokens.token1[2] = getAddress(sourceChain, "RETH");
        tokens.token1[3] = getAddress(sourceChain, "WSTETH");
        tokens.token1[4] = getAddress(sourceChain, "RETH");
        tokens.token1[5] = getAddress(sourceChain, "RETH");
        tokens.token1[6] = getAddress(sourceChain, "SFRXETH");
        tokens.token1[7] = getAddress(sourceChain, "CBETH");
        tokens.token1[8] = getAddress(sourceChain, "OSETH");
        tokens.token1[9] = getAddress(sourceChain, "RSETH");

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
            assets: new address[](15),
            kinds: new SwapKind[](15)
        });

        swapAssets.assets[0] = getAddress(sourceChain, "WETH");
        swapAssets.kinds[0] = SwapKind.BuyAndSell;
        swapAssets.assets[1] = getAddress(sourceChain, "WEETH");
        swapAssets.kinds[1] = SwapKind.BuyAndSell;
        swapAssets.assets[2] = getAddress(sourceChain, "WSTETH");
        swapAssets.kinds[2] = SwapKind.BuyAndSell;
        swapAssets.assets[3] = getAddress(sourceChain, "RETH");
        swapAssets.kinds[3] = SwapKind.BuyAndSell;
        swapAssets.assets[4] = getAddress(sourceChain, "ARB");
        swapAssets.kinds[4] = SwapKind.Sell;
        swapAssets.assets[5] = getAddress(sourceChain, "CRV");
        swapAssets.kinds[5] = SwapKind.Sell;
        swapAssets.assets[6] = getAddress(sourceChain, "AURA");
        swapAssets.kinds[6] = SwapKind.Sell;
        swapAssets.assets[7] = getAddress(sourceChain, "BAL");
        swapAssets.kinds[7] = SwapKind.Sell;
        swapAssets.assets[8] = getAddress(sourceChain, "PENDLE");
        swapAssets.kinds[8] = SwapKind.Sell;
        swapAssets.assets[9] = getAddress(sourceChain, "SFRXETH");
        swapAssets.kinds[9] = SwapKind.BuyAndSell;
        swapAssets.assets[10] = getAddress(sourceChain, "RSR");
        swapAssets.kinds[10] = SwapKind.Sell;
        swapAssets.assets[11] = getAddress(sourceChain, "LINK");
        swapAssets.kinds[11] = SwapKind.BuyAndSell;
        swapAssets.assets[12] = getAddress(sourceChain, "CBETH");
        swapAssets.kinds[12] = SwapKind.BuyAndSell;
        swapAssets.assets[13] = getAddress(sourceChain, "OSETH");
        swapAssets.kinds[13] = SwapKind.BuyAndSell;
        swapAssets.assets[14] = getAddress(sourceChain, "RSETH");
        swapAssets.kinds[14] = SwapKind.BuyAndSell;

        _addLeafsFor1InchGeneralSwapping(leafs, swapAssets.assets, swapAssets.kinds);
    }

    function _addBridgeLeafsWithStruct(ManageLeaf[] memory leafs) internal {
        BridgeAssets memory bridgeAssets = BridgeAssets({
            bridgeAssets: new ERC20[](5),
            ccipBridgeAssets: new ERC20[](1),
            ccipBridgeFeeAssets: new ERC20[](2)
        });

        bridgeAssets.bridgeAssets[0] = getERC20(sourceChain, "WETH");
        bridgeAssets.bridgeAssets[1] = getERC20(sourceChain, "WEETH");
        bridgeAssets.bridgeAssets[2] = getERC20(sourceChain, "WSTETH");
        bridgeAssets.bridgeAssets[3] = getERC20(sourceChain, "RETH");
        bridgeAssets.bridgeAssets[4] = getERC20(sourceChain, "CBETH");

        bridgeAssets.ccipBridgeAssets[0] = getERC20(sourceChain, "WETH");

        bridgeAssets.ccipBridgeFeeAssets[0] = getERC20(sourceChain, "WETH");
        bridgeAssets.ccipBridgeFeeAssets[1] = getERC20(sourceChain, "LINK");

        _addArbitrumNativeBridgeLeafs(leafs, bridgeAssets.bridgeAssets);
        _addCcipBridgeLeafs(leafs, ccipMainnetChainSelector, bridgeAssets.ccipBridgeAssets, bridgeAssets.ccipBridgeFeeAssets);
    }

    function _addCompoundV3LeafsWithStruct(ManageLeaf[] memory leafs) internal {
        CollateralConfig memory config = CollateralConfig({
            collateralAssets: new ERC20[](3),
            feeAssets: new ERC20[](0),
            claimTokens: new ERC20[](0)
        });

        config.collateralAssets[0] = getERC20(sourceChain, "WSTETH");
        config.collateralAssets[1] = getERC20(sourceChain, "RETH");
        config.collateralAssets[2] = getERC20(sourceChain, "WEETH");

        _addCompoundV3Leafs(
            leafs, config.collateralAssets, getAddress(sourceChain, "cWETHV3"), getAddress(sourceChain, "cometRewards")
        );
    }

    function _addMerklLeafsWithStruct(ManageLeaf[] memory leafs) internal {
        CollateralConfig memory config = CollateralConfig({
            collateralAssets: new ERC20[](0),
            feeAssets: new ERC20[](0),
            claimTokens: new ERC20[](2)
        });

        config.claimTokens[0] = getERC20(sourceChain, "UNI");
        config.claimTokens[1] = getERC20(sourceChain, "ARB");

        _addMerklLeafs(
            leafs,
            getAddress(sourceChain, "merklDistributor"),
            getAddress(sourceChain, "dev1Address"),
            config.claimTokens
        );
    }
}
