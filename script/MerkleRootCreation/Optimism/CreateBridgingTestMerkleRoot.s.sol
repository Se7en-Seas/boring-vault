// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Optimism/CreateBridgingTestMerkleRoot.s.sol --rpc-url $OPTIMISM_RPC_URL
 */
contract CreateBridgingTestMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xaA6D4Fb1FF961f8E52334f433974d40484e8be8F;
    address public managerAddress = 0x744d1f71a6d064204b4c59Cf2BDCF9De9C6c3430;
    address public accountantAddress = 0x99c836937305693A5518819ED457B0d3dfE99785;
    address public rawDataDecoderAndSanitizer = 0xD5678900d413591513216E386332Db21c1bEc131;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(optimism);
        setAddress(false, optimism, "boringVault", boringVault);
        setAddress(false, optimism, "managerAddress", managerAddress);
        setAddress(false, optimism, "accountantAddress", accountantAddress);
        setAddress(false, optimism, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](3);
        supplyAssets[0] = getERC20(sourceChain, "WETH");
        supplyAssets[1] = getERC20(sourceChain, "WSTETH");
        supplyAssets[2] = getERC20(sourceChain, "RETH");
        ERC20[] memory borrowAssets = new ERC20[](3);
        borrowAssets[0] = getERC20(sourceChain, "WETH");
        borrowAssets[1] = getERC20(sourceChain, "WSTETH");
        borrowAssets[2] = getERC20(sourceChain, "RETH");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== Native ==========================
        /**
         * wrap, unwrap
         */
        _addNativeLeafs(leafs);

        // ========================== Gearbox ==========================
        _addGearboxLeafs(leafs, ERC4626(getAddress(sourceChain, "dWETHV3")), getAddress(sourceChain, "sdWETHV3"));

        // ========================== Standard Bridge ==========================
        ERC20[] memory localTokens = new ERC20[](3);
        localTokens[0] = getERC20(sourceChain, "WETH");
        localTokens[1] = getERC20(sourceChain, "WSTETH");
        localTokens[2] = getERC20(sourceChain, "WEETH");
        ERC20[] memory remoteTokens = new ERC20[](3);
        remoteTokens[0] = getERC20(mainnet, "WETH");
        remoteTokens[1] = getERC20(mainnet, "WSTETH");
        remoteTokens[2] = getERC20(mainnet, "WEETH");
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
            leafs, getERC20(sourceChain, "WEETH_OFT"), getAddress(sourceChain, "WEETH_OFT"), layerZeroMainnetEndpointId
        );
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "WEETH_OFT"), getAddress(sourceChain, "WEETH_OFT"), layerZeroBaseEndpointId
        );

        string memory filePath = "./leafs/Optimism/BridgingTestStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
