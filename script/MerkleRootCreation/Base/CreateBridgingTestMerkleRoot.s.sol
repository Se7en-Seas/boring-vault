// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Base/CreateBridgingTestMerkleRoot.s.sol --rpc-url $BASE_RPC_URL
 */
contract CreateBridgingTestMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xaA6D4Fb1FF961f8E52334f433974d40484e8be8F;
    address public managerAddress = 0x744d1f71a6d064204b4c59Cf2BDCF9De9C6c3430;
    address public accountantAddress = 0x99c836937305693A5518819ED457B0d3dfE99785;
    address public rawDataDecoderAndSanitizer = 0xD5678900d413591513216E386332Db21c1bEc131;

    address public aerodromeDecoderAndSanitizer = 0x5b2c3622a9CbEF64107c40bd213B39f3C0437D9c;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(base);
        setAddress(false, base, "boringVault", boringVault);
        setAddress(false, base, "managerAddress", managerAddress);
        setAddress(false, base, "accountantAddress", accountantAddress);
        setAddress(false, base, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](3);
        supplyAssets[0] = getERC20(sourceChain, "WETH");
        supplyAssets[1] = getERC20(sourceChain, "WSTETH");
        supplyAssets[2] = getERC20(sourceChain, "WEETH");
        ERC20[] memory borrowAssets = new ERC20[](3);
        borrowAssets[0] = getERC20(sourceChain, "WETH");
        borrowAssets[1] = getERC20(sourceChain, "WSTETH");
        borrowAssets[2] = getERC20(sourceChain, "WEETH");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== Native ==========================
        /**
         * wrap, unwrap
         */
        _addNativeLeafs(leafs);

        // ========================== Standard Bridge ==========================
        ERC20[] memory localTokens = new ERC20[](2);
        localTokens[0] = getERC20(sourceChain, "WETH");
        localTokens[1] = getERC20(sourceChain, "WSTETH");
        ERC20[] memory remoteTokens = new ERC20[](2);
        remoteTokens[0] = getERC20(mainnet, "WETH");
        remoteTokens[1] = getERC20(mainnet, "WSTETH");
        _addStandardBridgeLeafs(
            leafs,
            mainnet,
            address(0),
            address(0),
            getAddress(sourceChain, "standardBridge"),
            address(0),
            localTokens,
            remoteTokens
        );

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "WEETH"), getAddress(sourceChain, "WEETH"), layerZeroMainnetEndpointId
        );
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "WEETH"), getAddress(sourceChain, "WEETH"), layerZeroOptimismEndpointId
        );

        // ========================== 1inch ==========================
        address[] memory assets = new address[](6);
        SwapKind[] memory kind = new SwapKind[](6);
        assets[0] = getAddress(sourceChain, "WETH");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "WEETH");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "WSTETH");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "RETH");
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = getAddress(sourceChain, "BSDETH");
        kind[4] = SwapKind.BuyAndSell;
        assets[5] = getAddress(sourceChain, "AERO");
        kind[5] = SwapKind.Sell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Aerodrome ==========================
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", aerodromeDecoderAndSanitizer);
        address[] memory token0 = new address[](3);
        token0[0] = getAddress(sourceChain, "WETH");
        token0[1] = getAddress(sourceChain, "WETH");
        token0[2] = getAddress(sourceChain, "WETH");
        address[] memory token1 = new address[](3);
        token1[0] = getAddress(sourceChain, "WSTETH");
        token1[1] = getAddress(sourceChain, "CBETH");
        token1[2] = getAddress(sourceChain, "BSDETH");
        address[] memory gauges = new address[](3);
        gauges[0] = getAddress(sourceChain, "aerodrome_Weth_Wsteth_v3_1_gauge");
        gauges[1] = getAddress(sourceChain, "aerodrome_Cbeth_Weth_v3_1_gauge");
        gauges[2] = getAddress(sourceChain, "aerodrome_Weth_Bsdeth_v3_1_gauge");
        _addVelodromeV3Leafs(
            leafs, token0, token1, getAddress(sourceChain, "aerodromeNonFungiblePositionManager"), gauges
        );

        string memory filePath = "./leafs/Base/BridgingTestStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
