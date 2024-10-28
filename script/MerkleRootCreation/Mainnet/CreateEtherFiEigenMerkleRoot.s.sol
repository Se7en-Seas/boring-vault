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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateEtherFiEigenMerkleRoot.s.sol:CreateEtherFiEigenMerkleRootScript --rpc-url $MAINNET_RPC_URL
 */
contract CreateEtherFiEigenMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xE77076518A813616315EaAba6cA8e595E845EeE9;
    address public managerAddress = 0x354ade0382EEC1BF0a444339ABc82931457C2c0e;
    address public accountantAddress = 0x075e60550C6f77f430B284E76aF699bC31651f75;
    address public rawDataDecoderAndSanitizer = 0x0De55435028D904e1af8Ec58C2f86DF2c4d32f2a;
    address public itbDecoderAndSanitizer = 0xBF76C48401f7f690f46F0C481Ee9f193D0c43062;

    address public itbEigenPositionManager = 0xb814C334748dc8D12145b009020e2783624c0775;

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

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        // ========================== Eigen ==========================
        _addLeafsForEigenLayerLST(
            leafs,
            getAddress(sourceChain, "EIGEN"),
            getAddress(sourceChain, "eigenStrategy"),
            getAddress(sourceChain, "strategyManager"),
            getAddress(sourceChain, "delegationManager"),
            getAddress(sourceChain, "eEigenOperator")
        );

        // ========================== ITB Eigen ==========================
        _addLeafsForITBEigenLayerPositionManager(
            leafs, itbEigenPositionManager, getERC20(sourceChain, "EIGEN"), getAddress(sourceChain, "strategyManager")
        );

        // ========================== Reclamation ==========================
        {
            address reclamationDecoder = 0xd7335170816912F9D06e23d23479589ed63b3c33;
            address target = 0xb814C334748dc8D12145b009020e2783624c0775;
            _addReclamationLeafs(leafs, target, reclamationDecoder);
        }

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/eEigenStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    // ========================================= ITB EigenLayer =========================================

    function _addLeafsForITBEigenLayerPositionManager(
        ManageLeaf[] memory leafs,
        address positionManager,
        ERC20 underlying,
        address strategyManager
    ) internal {
        // acceptOwnership
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "acceptOwnership()",
            new address[](0),
            string.concat("Accept ownership of the ITB Contract: ", vm.toString(positionManager)),
            itbDecoderAndSanitizer
        );
        // Transfer all tokens to the ITB contract.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(underlying),
            false,
            "transfer(address,uint256)",
            new address[](1),
            string.concat("Transfer ", underlying.symbol(), " to ITB Contract: ", vm.toString(positionManager)),
            itbDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = positionManager;
        // Approval Strategy Manager to spend all tokens.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "approveToken(address,address,uint256)",
            new address[](2),
            string.concat("Approve Strategy Manager to spend ", underlying.symbol()),
            itbDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = address(underlying);
        leafs[leafIndex].argumentAddresses[1] = strategyManager;
        // Withdraw all tokens
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "withdraw(address,uint256)",
            new address[](1),
            string.concat("Withdraw ", underlying.symbol(), " from ITB Contract: ", vm.toString(positionManager)),
            itbDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = address(underlying);

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "withdrawAll(address)",
            new address[](1),
            string.concat(
                "Withdraw all ", underlying.symbol(), " from the ITB Contract: ", vm.toString(positionManager)
            ),
            itbDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = address(underlying);

        // Delegate
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] =
            ManageLeaf(positionManager, false, "delegate()", new address[](0), "Delegate", itbDecoderAndSanitizer);

        // Undelegate
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] =
            ManageLeaf(positionManager, false, "undelegate()", new address[](0), "Undelegate", itbDecoderAndSanitizer);

        // delegateWithSignature
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "delegateWithSignature(bytes,uint256,bytes32)",
            new address[](0),
            "Delegate With Signature",
            itbDecoderAndSanitizer
        );

        // Deposit
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager, false, "deposit(uint256,uint256)", new address[](0), "Deposit", itbDecoderAndSanitizer
        );

        // Start Withdrawal
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "startWithdrawal(uint256)",
            new address[](0),
            "Start Withdrawal",
            itbDecoderAndSanitizer
        );

        // Complete Withdrawal
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "completeWithdrawal(uint256,uint256)",
            new address[](0),
            "Complete Withdrawal",
            itbDecoderAndSanitizer
        );

        // Complete Next Withdrawal
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "completeNextWithdrawal(uint256)",
            new address[](0),
            "Complete Next Withdrawal",
            itbDecoderAndSanitizer
        );

        // Complete Next Withdrawals
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "completeNextWithdrawals(uint256)",
            new address[](0),
            "Complete Next Withdrawals",
            itbDecoderAndSanitizer
        );

        // Override Withdrawal Indexes
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "overrideWithdrawalIndexes(uint256,uint256)",
            new address[](0),
            "Override Withdrawal Indexes",
            itbDecoderAndSanitizer
        );

        // Assemble
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager, false, "assemble(uint256)", new address[](0), "Assemble", itbDecoderAndSanitizer
        );

        // Disassemble
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "disassemble(uint256,uint256)",
            new address[](0),
            "Disassemble",
            itbDecoderAndSanitizer
        );

        // Full Disassemble
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "fullDisassemble(uint256)",
            new address[](0),
            "Full Disassemble",
            itbDecoderAndSanitizer
        );
    }
}
