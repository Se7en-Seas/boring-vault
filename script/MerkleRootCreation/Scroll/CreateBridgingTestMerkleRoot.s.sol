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
 *  source .env && forge script script/MerkleRootCreation/Scroll/CreateBridgingTestMerkleRoot.s.sol --rpc-url $SCROLL_RPC_URL
 */
contract CreateBridgingTestMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xf8203A33027607D2C82dFd67b46986096257dFA5;
    address public managerAddress = 0x3770E6021d7b2617Ba86E89EF210Cc00A7c9Af95;
    address public accountantAddress = 0xBA4397B2B1780097eD1B483E3C0717E0Ed4fAAa5;
    address public rawDataDecoderAndSanitizer = 0xD9023495256B23D7b4FA32A5Fd724140F179F51b;
    address public drone = 0x80aA0E6c933316464D66A4CFd2A4F1C04677da73;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(scroll);
        setAddress(false, scroll, "boringVault", boringVault);
        setAddress(false, scroll, "managerAddress", managerAddress);
        setAddress(false, scroll, "accountantAddress", accountantAddress);
        setAddress(false, scroll, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);

        // ========================== Scroll Bridge ==========================
        ERC20[] memory localTokens = new ERC20[](1);
        localTokens[0] = getERC20(sourceChain, "DAI");
        _addScrollNativeBridgeLeafs(leafs, "mainnet", localTokens);

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "WEETH"), getAddress(sourceChain, "WEETH"), layerZeroMainnetEndpointId
        );
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "WEETH"), getAddress(sourceChain, "WEETH"), layerZeroScrollEndpointId
        );

        // ========================== Drone Linea Bridge ==========================
        uint256 startIndex = leafIndex + 1;
        _addScrollNativeBridgeLeafs(leafs, "mainnet", localTokens);

        _createDroneLeafs(leafs, drone, startIndex, leafIndex + 1);

        // ========================== Drone Transfers ==========================
        _addLeafsForDroneTransfers(leafs, drone, localTokens);

        string memory filePath = "./leafs/Scroll/BridgingTestStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
