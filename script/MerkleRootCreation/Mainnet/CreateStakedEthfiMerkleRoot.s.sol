// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateStakedEthfiMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */
contract CreateStakedEthfiMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x86B5780b606940Eb59A062aA85a07959518c0161;
    address public managerAddress = 0xb623FaF559b414A1C7EF2d15f3260CA0Fd239431;
    address public accountantAddress = 0x05A1552c5e18F5A0BB9571b5F2D6a4765ebdA32b;
    address public rawDataDecoderAndSanitizer = 0xcfa57ea1b1E138cf89050253CcF5d0836566C06D;

    address public itbDecoderAndSanitizer = 0xcfa57ea1b1E138cf89050253CcF5d0836566C06D;

    address public itbKETHFIPositionManager = 0xCF413A1989e33C8Ef59fbA79935d93205C9BE4c7;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateKarakVaultStrategistMerkleRoot();
    }

    function generateKarakVaultStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", itbDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);

        // ========================== ITB Karak Position Managers ==========================
        _addLeafsForITBKarakPositionManager(
            leafs,
            itbDecoderAndSanitizer,
            itbKETHFIPositionManager,
            getAddress(sourceChain, "kETHFI"),
            getAddress(sourceChain, "vaultSupervisor")
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/StakedETHFIStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
