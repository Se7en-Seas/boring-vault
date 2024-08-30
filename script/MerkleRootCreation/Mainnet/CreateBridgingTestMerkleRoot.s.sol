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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateBridgingTestMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */
contract CreateBridgingTestMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xaA6D4Fb1FF961f8E52334f433974d40484e8be8F;
    address public managerAddress = 0x744d1f71a6d064204b4c59Cf2BDCF9De9C6c3430;
    address public accountantAddress = 0x99c836937305693A5518819ED457B0d3dfE99785;
    address public rawDataDecoderAndSanitizer = 0x28edfc0bffdF1f9C986923729b88B5F40f2B92D9;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== Native Bridge ==========================
        ERC20[] memory nativeBridgeTokens = new ERC20[](2);
        nativeBridgeTokens[0] = getERC20(sourceChain, "WETH");
        nativeBridgeTokens[1] = getERC20(sourceChain, "WSTETH");
        _addArbitrumNativeBridgeLeafs(leafs, nativeBridgeTokens);

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
            optimism,
            getAddress(optimism, "crossDomainMessenger"),
            getAddress(sourceChain, "optimismResolvedDelegate"),
            getAddress(sourceChain, "optimismStandardBridge"),
            getAddress(sourceChain, "optimismPortal"),
            localTokens,
            remoteTokens
        );

        _addStandardBridgeLeafs(
            leafs,
            base,
            getAddress(base, "crossDomainMessenger"),
            getAddress(sourceChain, "baseResolvedDelegate"),
            getAddress(sourceChain, "baseStandardBridge"),
            getAddress(sourceChain, "basePortal"),
            localTokens,
            remoteTokens
        );

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "WEETH"),
            getAddress(sourceChain, "EtherFiOFTAdapter"),
            layerZeroOptimismEndpointId
        );
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "WEETH"), getAddress(sourceChain, "EtherFiOFTAdapter"), layerZeroBaseEndpointId
        );

        // ========================== Pendle ==========================
        // update to use Liquid ETHs Decoder and Sanitizer.
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", 0xdCbC0DeF063C497aA25Eb52eB29aa96C90be0F79);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarket"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleZircuitWeETHMarket"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarketSeptember"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarketDecember"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleKarakWeETHMarketSeptember"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleZircuitWeETHMarketAugust"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarketJuly"), true);

        string memory filePath = "./leafs/Mainnet/BridgingTestStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
