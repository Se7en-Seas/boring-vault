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

    address public boringVault = 0xf8203A33027607D2C82dFd67b46986096257dFA5;
    address public managerAddress = 0x3770E6021d7b2617Ba86E89EF210Cc00A7c9Af95;
    address public accountantAddress = 0xBA4397B2B1780097eD1B483E3C0717E0Ed4fAAa5;
    address public rawDataDecoderAndSanitizer = 0xD9023495256B23D7b4FA32A5Fd724140F179F51b;
    address public drone = 0x80aA0E6c933316464D66A4CFd2A4F1C04677da73;
    address public zircuitDrone = 0xFdC94b15819cc12a010c65A713563B65cDc060E4;

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

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // ========================== Linea Bridge ==========================
        ERC20[] memory localTokens = new ERC20[](1);
        localTokens[0] = getERC20(sourceChain, "DAI");
        _addLineaNativeBridgeLeafs(leafs, "linea", localTokens);

        // ========================== Scroll Bridge ==========================
        _addScrollNativeBridgeLeafs(leafs, "scroll", localTokens);

        // ========================== Mantle Bridge ==========================
        localTokens = new ERC20[](1);
        localTokens[0] = getERC20("mainnet", "METH");
        ERC20[] memory remoteTokens = new ERC20[](1);
        remoteTokens[0] = getERC20("mantle", "METH");
        _addStandardBridgeLeafs(
            leafs,
            "mantle",
            getAddress("mantle", "crossDomainMessenger"),
            getAddress(sourceChain, "mantleResolvedDelegate"),
            getAddress(sourceChain, "mantleStandardBridge"),
            getAddress(sourceChain, "mantlePortal"),
            localTokens,
            remoteTokens
        );

        // ========================== Zircuit Bridge ==========================
        _addStandardBridgeLeafs(
            leafs,
            "zircuit",
            getAddress("zircuit", "crossDomainMessenger"),
            getAddress(sourceChain, "zircuitResolvedDelegate"),
            getAddress(sourceChain, "zircuitStandardBridge"),
            getAddress(sourceChain, "zircuitPortal"),
            localTokens,
            remoteTokens
        );

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "WEETH"),
            getAddress(sourceChain, "EtherFiOFTAdapter"),
            layerZeroLineaEndpointId
        );
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "WEETH"),
            getAddress(sourceChain, "EtherFiOFTAdapter"),
            layerZeroScrollEndpointId
        );

        // ========================== Drone Linea Bridge ==========================
        uint256 startIndex = leafIndex + 1;
        _addLineaNativeBridgeLeafs(leafs, "linea", localTokens);

        _createDroneLeafs(leafs, drone, startIndex, leafIndex + 1);

        // ========================== Drone Transfers ==========================
        _addLeafsForDroneTransfers(leafs, drone, localTokens);

        string memory filePath = "./leafs/Mainnet/BridgingTestStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
