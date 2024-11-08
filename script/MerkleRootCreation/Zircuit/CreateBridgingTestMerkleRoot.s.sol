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
 *  source .env && forge script script/MerkleRootCreation/Zircuit/CreateBridgingTestMerkleRoot.s.sol --rpc-url $ZIRCUIT_RPC_URL
 */
contract CreateBridgingTestMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xf8203A33027607D2C82dFd67b46986096257dFA5;
    address public managerAddress = 0x3770E6021d7b2617Ba86E89EF210Cc00A7c9Af95;
    address public accountantAddress = 0xBA4397B2B1780097eD1B483E3C0717E0Ed4fAAa5;
    address public rawDataDecoderAndSanitizer = 0x16D377CE4c95F7737Ef4B45F81301A988F62b61a;
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
        setSourceChainName(zircuit);
        setAddress(false, zircuit, "boringVault", boringVault);
        setAddress(false, zircuit, "managerAddress", managerAddress);
        setAddress(false, zircuit, "accountantAddress", accountantAddress);
        setAddress(false, zircuit, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](4);

        // ========================== Standard Bridge ==========================
        ERC20[] memory localTokens = new ERC20[](1);
        localTokens[0] = getERC20("zircuit", "METH");
        ERC20[] memory remoteTokens = new ERC20[](1);
        remoteTokens[0] = getERC20("mainnet", "METH");
        _addStandardBridgeLeafs(
            leafs,
            "mainnet",
            address(0),
            address(0),
            getAddress("zircuit", "standardBridge"),
            address(0),
            localTokens,
            remoteTokens
        );

        string memory filePath = "./leafs/Zircuit/BridgingTestStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
