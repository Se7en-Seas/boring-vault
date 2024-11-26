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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateLoopBTCMerkleRoot.s.sol:CreateLoopBtcMerkleRootScript --rpc-url $MAINNET_RPC_URL
 */
contract CreateLoopBtcMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xFE0C961A49E1aEe2AE2d842fE40157365C6d978f;
    address public managerAddress = 0xaE4b4cfBB7A0B90e9455761ed6D93d6Dc1759710;
    address public accountantAddress = 0xf1ecf4802C2b5Cf9c830A4AF297842Daa6D0f986;
    address public rawDataDecoderAndSanitizer = address(69); 

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

        ManageLeaf[] memory leafs = new ManageLeaf[](16);

        // ========================== Aera ==========================
        ERC20[] memory depositTokens = new ERC20[](3); 
        depositTokens[0] = ERC20(getAddress(sourceChain, "WBTC"));
        depositTokens[1] = ERC20(getAddress(sourceChain, "LBTC")); 
        depositTokens[2] = ERC20(getAddress(sourceChain, "cbBTC"));
        _addAeraLeafs(leafs, getAddress(sourceChain, "aeraLoopBTCVault"), depositTokens);  

        //_verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/LoopBTCStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
