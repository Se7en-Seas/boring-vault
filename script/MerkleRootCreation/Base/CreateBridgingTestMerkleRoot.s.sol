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

    struct AaveAssets {
        ERC20[] supplyAssets;
        ERC20[] claimAssets;
        ERC20[] borrowAssets;
    }

    struct SwapAssets {
        address[] assets;
        SwapKind[] kinds;
    }

    struct BridgeAssets {
        ERC20[] localTokens;
        ERC20[] remoteTokens;
    }

    struct AerodromeTokens {
        address[] token0;
        address[] token1;
        address[] gauges;
    }

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
        _addAaveV3LeafsWithStruct(leafs);

        // ========================== Native ==========================
        /**
         * wrap, unwrap
         */
        _addNativeLeafs(leafs);

        // ========================== Standard Bridge ==========================
        _addStandardBridgeLeafsWithStruct(leafs);

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "WEETH"), getAddress(sourceChain, "WEETH"), layerZeroMainnetEndpointId
        );
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "WEETH"), getAddress(sourceChain, "WEETH"), layerZeroOptimismEndpointId
        );

        // ========================== 1inch ==========================
        _add1InchSwappingLeafsWithStruct(leafs);

        // ========================== Aerodrome ==========================
        _addAerodromeLeafsWithStruct(leafs);

        string memory filePath = "./leafs/Base/BridgingTestStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function _addAaveV3LeafsWithStruct(ManageLeaf[] memory leafs) internal {
        AaveAssets memory aaveAssets = AaveAssets({
            supplyAssets: new ERC20[](3),
            claimAssets: new ERC20[](3),
            borrowAssets: new ERC20[](3)
        });

        aaveAssets.supplyAssets[0] = getERC20(sourceChain, "WETH");
        aaveAssets.supplyAssets[1] = getERC20(sourceChain, "WSTETH");
        aaveAssets.supplyAssets[2] = getERC20(sourceChain, "WEETH");

        aaveAssets.claimAssets[0] = getERC20(sourceChain, "WETH");
        aaveAssets.claimAssets[1] = getERC20(sourceChain, "WSTETH");
        aaveAssets.claimAssets[2] = getERC20(sourceChain, "WEETH");

        aaveAssets.borrowAssets[0] = getERC20(sourceChain, "WETH");
        aaveAssets.borrowAssets[1] = getERC20(sourceChain, "WSTETH");
        aaveAssets.borrowAssets[2] = getERC20(sourceChain, "WEETH");

        _addAaveV3Leafs(leafs, aaveAssets.supplyAssets, aaveAssets.borrowAssets, aaveAssets.claimAssets);
    }

    function _addStandardBridgeLeafsWithStruct(ManageLeaf[] memory leafs) internal {
        BridgeAssets memory bridgeAssets = BridgeAssets({
            localTokens: new ERC20[](2),
            remoteTokens: new ERC20[](2)
        });

        bridgeAssets.localTokens[0] = getERC20(sourceChain, "WETH");
        bridgeAssets.localTokens[1] = getERC20(sourceChain, "WSTETH");

        bridgeAssets.remoteTokens[0] = getERC20(mainnet, "WETH");
        bridgeAssets.remoteTokens[1] = getERC20(mainnet, "WSTETH");

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

    function _add1InchSwappingLeafsWithStruct(ManageLeaf[] memory leafs) internal {
        SwapAssets memory swapAssets = SwapAssets({
            assets: new address[](6),
            kinds: new SwapKind[](6)
        });

        swapAssets.assets[0] = getAddress(sourceChain, "WETH");
        swapAssets.kinds[0] = SwapKind.BuyAndSell;
        swapAssets.assets[1] = getAddress(sourceChain, "WEETH");
        swapAssets.kinds[1] = SwapKind.BuyAndSell;
        swapAssets.assets[2] = getAddress(sourceChain, "WSTETH");
        swapAssets.kinds[2] = SwapKind.BuyAndSell;
        swapAssets.assets[3] = getAddress(sourceChain, "RETH");
        swapAssets.kinds[3] = SwapKind.BuyAndSell;
        swapAssets.assets[4] = getAddress(sourceChain, "BSDETH");
        swapAssets.kinds[4] = SwapKind.BuyAndSell;
        swapAssets.assets[5] = getAddress(sourceChain, "AERO");
        swapAssets.kinds[5] = SwapKind.Sell;

        _addLeafsFor1InchGeneralSwapping(leafs, swapAssets.assets, swapAssets.kinds);
    }

    function _addAerodromeLeafsWithStruct(ManageLeaf[] memory leafs) internal {
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", aerodromeDecoderAndSanitizer);

        AerodromeTokens memory aerodromeTokens = AerodromeTokens({
            token0: new address[](3),
            token1: new address[](3),
            gauges: new address[](3)
        });

        aerodromeTokens.token0[0] = getAddress(sourceChain, "WETH");
        aerodromeTokens.token0[1] = getAddress(sourceChain, "WETH");
        aerodromeTokens.token0[2] = getAddress(sourceChain, "WETH");

        aerodromeTokens.token1[0] = getAddress(sourceChain, "WSTETH");
        aerodromeTokens.token1[1] = getAddress(sourceChain, "CBETH");
        aerodromeTokens.token1[2] = getAddress(sourceChain, "BSDETH");

        aerodromeTokens.gauges[0] = getAddress(sourceChain, "aerodrome_Weth_Wsteth_v3_1_gauge");
        aerodromeTokens.gauges[1] = getAddress(sourceChain, "aerodrome_Cbeth_Weth_v3_1_gauge");
        aerodromeTokens.gauges[2] = getAddress(sourceChain, "aerodrome_Weth_Bsdeth_v3_1_gauge");

        _addVelodromeV3Leafs(
            leafs, aerodromeTokens.token0, aerodromeTokens.token1, getAddress(sourceChain, "aerodromeNonFungiblePositionManager"), aerodromeTokens.gauges
        );
    }
}
