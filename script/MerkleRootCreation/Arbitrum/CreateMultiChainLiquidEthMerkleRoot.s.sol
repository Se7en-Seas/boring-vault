// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Arbitrum/CreateMultiChainLiquidEthMerkleRoot.s.sol:CreateMultiChainLiquidEthMerkleRootScript --rpc-url $ARBITRUM_RPC_URL
 */
contract CreateMultiChainLiquidEthMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C;
    address public rawDataDecoderAndSanitizer = 0xdCbC0DeF063C497aA25Eb52eB29aa96C90be0F79;
    address public camelotFullDecoderAndSanitizer = 0xe315ADA67dB9Fd97523620194ccdd727102830c7;
    address public managerAddress = 0x227975088C28DBBb4b421c6d96781a53578f19a8;
    address public accountantAddress = 0x0d05D94a5F1E76C18fbeB7A13d17C8a314088198;

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
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarketSeptember"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_weETH_market_12_25_24"), true);

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
        address[] memory assets = new address[](17);
        SwapKind[] memory kind = new SwapKind[](17);
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
        assets[15] = getAddress(sourceChain, "GRAIL");
        kind[15] = SwapKind.Sell;
        assets[16] = getAddress(sourceChain, "UNI");
        kind[16] = SwapKind.Sell;
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
        bridgeAssets[0] = getERC20(mainnet, "WETH");
        bridgeAssets[1] = getERC20(mainnet, "WEETH");
        bridgeAssets[2] = getERC20(mainnet, "WSTETH");
        bridgeAssets[3] = getERC20(mainnet, "RETH");
        bridgeAssets[4] = getERC20(mainnet, "CBETH");
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
            ERC20[] memory tokensToClaim = new ERC20[](3);
            tokensToClaim[0] = getERC20(sourceChain, "UNI");
            tokensToClaim[1] = getERC20(sourceChain, "ARB");
            tokensToClaim[2] = getERC20(sourceChain, "GRAIL");
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

        // ========================== Camelot ==========================
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", camelotFullDecoderAndSanitizer);
        token0 = new address[](3);
        token0[0] = getAddress(sourceChain, "WETH");
        token0[1] = getAddress(sourceChain, "WETH");
        token0[2] = getAddress(sourceChain, "WETH");
        token1 = new address[](3);
        token1[0] = getAddress(sourceChain, "WEETH");
        token1[1] = getAddress(sourceChain, "WSTETH");
        token1[2] = getAddress(sourceChain, "RSETH");
        _addCamelotV3Leafs(leafs, token0, token1);

        // iTb
        _addLeafsForItbGearbox(
            leafs,
            itbGearboxProtocolPositionManager,
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "dWETHV3"),
            getAddress(sourceChain, "sdWETHV3"),
            "ITB wETH Gearbox"
        );

        // ========================== Reclamation ==========================
        {
            address reclamationDecoder = 0xd7335170816912F9D06e23d23479589ed63b3c33;
            address target = 0xad5dB17b44506785931dbc49c8857482c3b4F622;
            _addReclamationLeafs(leafs, target, reclamationDecoder);
        }

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
