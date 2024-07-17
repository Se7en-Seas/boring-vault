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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateBridgingTestMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */
contract CreateBridgingTestMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xaA6D4Fb1FF961f8E52334f433974d40484e8be8F;
    address public managerAddress = 0x744d1f71a6d064204b4c59Cf2BDCF9De9C6c3430;
    address public accountantAddress = 0x99c836937305693A5518819ED457B0d3dfE99785;
    address public rawDataDecoderAndSanitizer = 0x2001b6Ac051612cCf2C05e93B2335d5677b6B86f;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        leafIndex = type(uint256).max;

        ManageLeaf[] memory leafs = new ManageLeaf[](16);

        // ========================== Native Bridge ==========================
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", 0xaA6D4Fb1FF961f8E52334f433974d40484e8be8F);
        setAddress(false, mainnet, "managerAddress", 0x744d1f71a6d064204b4c59Cf2BDCF9De9C6c3430);
        setAddress(false, mainnet, "accountantAddress", 0x99c836937305693A5518819ED457B0d3dfE99785);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", 0x2001b6Ac051612cCf2C05e93B2335d5677b6B86f);
        ERC20[] memory nativeBridgeTokens = new ERC20[](1);
        nativeBridgeTokens[0] = getERC20(sourceChain, "WETH");
        _addArbitrumNativeBridgeLeafs(leafs, nativeBridgeTokens);

        string memory filePath = "./leafs/BridgingTestStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}