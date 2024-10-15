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
 *  source .env && forge script script/MerkleRootCreation/Arbitrum/CreateStakedETHFIMerkleRoot.s.sol --rpc-url $ARBITRUM_RPC_URL
 */
contract CreateStakedETHFIMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x86B5780b606940Eb59A062aA85a07959518c0161;
    address public managerAddress = 0xb623FaF559b414A1C7EF2d15f3260CA0Fd239431;
    address public accountantAddress = 0x05A1552c5e18F5A0BB9571b5F2D6a4765ebdA32b;
    address public rawDataDecoderAndSanitizer = 0xb8bb22226d385Cf504f30176683FC395cB928633;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(arbitrum);
        setAddress(false, arbitrum, "boringVault", boringVault);
        setAddress(false, arbitrum, "managerAddress", managerAddress);
        setAddress(false, arbitrum, "accountantAddress", accountantAddress);
        setAddress(false, arbitrum, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        // ========================== Karak ==========================
        _addKarakLeafs(leafs, getAddress(sourceChain, "vaultSupervisor"), getAddress(sourceChain, "kETHFI"));

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Arbitrum/StakedETHFIStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
