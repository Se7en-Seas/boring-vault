// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateLiquidElixirMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */
contract CreateLiquidElixirMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x352180974C71f84a934953Cf49C4E538a6F9c997;
    address public rawDataDecoderAndSanitizer = 0x0b01C5F5D333f9921240ab08dA92805F41604add;
    address public managerAddress = 0x4D0EF2A55db2439A37507a893b624f89eC7A403c;
    address public accountantAddress = 0xBae19b38Bf727Be64AF0B578c34985c3D612e2Ba;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateLiquidElixirStrategistMerkleRoot();
    }

    function generateLiquidElixirStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

        // ========================== UniswapV3 ==========================
        /**
         * Full position management for USDC, USDT, DAI, USDe, sUSDe.
         */
        address[] memory token0 = new address[](10);
        token0[0] = getAddress(sourceChain, "USDC");
        token0[1] = getAddress(sourceChain, "USDC");
        token0[2] = getAddress(sourceChain, "USDC");
        token0[3] = getAddress(sourceChain, "USDC");
        token0[4] = getAddress(sourceChain, "USDT");
        token0[5] = getAddress(sourceChain, "USDT");
        token0[6] = getAddress(sourceChain, "USDT");
        token0[7] = getAddress(sourceChain, "DAI");
        token0[8] = getAddress(sourceChain, "DAI");
        token0[9] = getAddress(sourceChain, "deUSD");

        address[] memory token1 = new address[](10);
        token1[0] = getAddress(sourceChain, "USDT");
        token1[1] = getAddress(sourceChain, "DAI");
        token1[2] = getAddress(sourceChain, "deUSD");
        token1[3] = getAddress(sourceChain, "sdeUSD");
        token1[4] = getAddress(sourceChain, "DAI");
        token1[5] = getAddress(sourceChain, "deUSD");
        token1[6] = getAddress(sourceChain, "sdeUSD");
        token1[7] = getAddress(sourceChain, "deUSD");
        token1[8] = getAddress(sourceChain, "sdeUSD");
        token1[9] = getAddress(sourceChain, "sdeUSD");

        _addUniswapV3Leafs(leafs, token0, token1);

        // ========================== Fee Claiming ==========================
        /**
         * Claim fees in USDC, DAI, USDT and USDE
         */
        ERC20[] memory feeAssets = new ERC20[](5);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        feeAssets[1] = getERC20(sourceChain, "DAI");
        feeAssets[2] = getERC20(sourceChain, "USDT");
        feeAssets[3] = getERC20(sourceChain, "deUSD");
        feeAssets[4] = getERC20(sourceChain, "sdeUSD");
        _addLeafsForFeeClaiming(leafs, feeAssets);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](7);
        SwapKind[] memory kind = new SwapKind[](7);
        assets[0] = getAddress(sourceChain, "USDC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "USDT");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "DAI");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "deUSD");
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = getAddress(sourceChain, "sdeUSD");
        kind[4] = SwapKind.BuyAndSell;
        assets[5] = getAddress(sourceChain, "CRV");
        kind[5] = SwapKind.Sell;
        assets[6] = getAddress(sourceChain, "BAL");
        kind[6] = SwapKind.Sell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Curve ==========================
        _addCurveLeafs(leafs, getAddress(sourceChain, "deUSD_USDC_Curve_Pool"), 2, address(0));
        _addCurveLeafs(leafs, getAddress(sourceChain, "deUSD_USDT_Curve_Pool"), 2, address(0));
        _addCurveLeafs(leafs, getAddress(sourceChain, "deUSD_DAI_Curve_Pool"), 2, address(0));
        _addCurveLeafs(
            leafs,
            getAddress(sourceChain, "deUSD_FRAX_Curve_Pool"),
            2,
            getAddress(sourceChain, "deUSD_FRAX_Curve_Gauge")
        );

        // ========================== Balancer ==========================
        _addBalancerLeafs(
            leafs, getBytes32(sourceChain, "deUSD_sdeUSD_ECLP_id"), getAddress(sourceChain, "deUSD_sdeUSD_ECLP_Gauge")
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Mainnet/LiquidElixirStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
