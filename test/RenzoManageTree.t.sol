// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {ILiquidityPool} from "src/interfaces/IStaking.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {RenzoLiquidDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/RenzoLiquidDecoderAndSanitizer.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";
import "@forge-std/StdJson.sol";

contract RenzoManageTreeTest is Test, MainnetAddresses {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;
    using Address for address;
    using stdJson for string;

    uint8 public constant ADMIN_ROLE = 1;
    uint8 public constant MINTER_ROLE = 7;
    uint8 public constant BURNER_ROLE = 8;

    BoringVault public boringVault;
    ManagerWithMerkleVerification public manager;
    TellerWithMultiAssetSupport public teller;
    AccountantWithRateProviders public accountant;
    address public rawDataDecoderAndSanitizer;
    address public payout_address = vm.addr(7777777);
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    ERC20 internal constant NATIVE_ERC20 = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    RolesAuthority public rolesAuthority;
    uint256 treeCapacity;
    uint256 leafCount;

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19582913;
        _startFork(rpcKey, blockNumber);

        // Load the json.
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/leafs/AdminStrategistLeafs.json");
        string memory json = vm.readFile(path);

        // Grab global addresses from the json.
        boringVault = BoringVault(abi.decode(json.parseRaw(".metadata.BoringVaultAddress"), (address)));

        manager = ManagerWithMerkleVerification(abi.decode(json.parseRaw(".metadata.ManagerAddress"), (address)));

        accountant = AccountantWithRateProviders(abi.decode(json.parseRaw(".metadata.AccountantAddress"), (address)));

        rawDataDecoderAndSanitizer = abi.decode(json.parseRaw(".metadata.DecoderAndSanitizerAddress"), (address));
    }

    // function testRenzoManageTree() external {
    //     (ManageLeaf[] memory manageLeafs, bytes32[][] memory manageTree) = _loadManageLeafsAndManageTreeFromJson();

    //     for (uint256 i; i < leafCount; ++i) {
    //         bytes memory gibberish =
    //             hex"EeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeEEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeEEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeEEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeEEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeEEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeEEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeEEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeEEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeEEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeEEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeEEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeEEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeEEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeEEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeEEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeEEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeEEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeEEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeEEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
    //         bytes memory data = abi.encodeWithSignature(manageLeafs[i].signature, gibberish);

    //         (bool success, bytes memory returndata) = rawDataDecoderAndSanitizer.staticcall(data);

    //         if (!success) {
    //             console.log("return data length: ", returndata.length);
    //         }
    //     }
    // }

    // ========================================= HELPER FUNCTIONS =========================================

    function _loadManageLeafsAndManageTreeFromJson()
        internal
        returns (ManageLeaf[] memory manageLeafs, bytes32[][] memory manageTree)
    {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/leafs/AdminStrategistLeafs.json");
        string memory json = vm.readFile(path);
        // Grab leafs from the json.
        treeCapacity = abi.decode(json.parseRaw(".metadata.TreeCapacity"), (uint256));
        manageLeafs = new ManageLeaf[](treeCapacity);
        leafCount = abi.decode(json.parseRaw(".metadata.LeafCount"), (uint256));
        for (uint256 i; i < leafCount; ++i) {
            string memory baseJsonQuery = string.concat(".leafs[", vm.toString(i), "]");
            address target = abi.decode(json.parseRaw(string.concat(baseJsonQuery, ".TargetAddress")), (address));
            bool canSendValue = abi.decode(json.parseRaw(string.concat(baseJsonQuery, ".CanSendValue")), (bool));
            string memory signature =
                abi.decode(json.parseRaw(string.concat(baseJsonQuery, ".FunctionSignature")), (string));
            address[] memory argumentAddresses =
                abi.decode(json.parseRaw(string.concat(baseJsonQuery, ".AddressArguments")), (address[]));
            manageLeafs[i] = ManageLeaf(target, canSendValue, signature, argumentAddresses);
        }

        manageTree = _generateMerkleTree(manageLeafs);

        bytes32 jsonRoot = abi.decode(json.parseRaw(".metadata.ManageRoot"), (bytes32));

        assertEq(jsonRoot, manageTree[manageTree.length - 1][0], "json root and derived root mismatch");
    }

    struct ManageLeaf {
        address target;
        bool canSendValue;
        string signature;
        address[] argumentAddresses;
    }

    bool doNothing = true;

    function flashLoan(address, address[] calldata tokens, uint256[] calldata amounts, bytes memory userData)
        external
    {
        if (doNothing) {
            return;
        } else {
            // Edit userData.
            userData = hex"DEAD01";
            manager.receiveFlashLoan(tokens, amounts, amounts, userData);
        }
    }

    bool iDidSomething = false;

    // Call this function approve, so that we can use the standard decoder.
    function approve(ERC20 token, uint256 amount) external {
        token.safeTransferFrom(msg.sender, address(this), amount);
        token.safeTransfer(msg.sender, amount);
        iDidSomething = true;
    }

    function _generateProof(bytes32 leaf, bytes32[][] memory tree) internal pure returns (bytes32[] memory proof) {
        // The length of each proof is the height of the tree - 1.
        uint256 tree_length = tree.length;
        proof = new bytes32[](tree_length - 1);

        // Build the proof
        for (uint256 i; i < tree_length - 1; ++i) {
            // For each layer we need to find the leaf.
            for (uint256 j; j < tree[i].length; ++j) {
                if (leaf == tree[i][j]) {
                    // We have found the leaf, so now figure out if the proof needs the next leaf or the previous one.
                    proof[i] = j % 2 == 0 ? tree[i][j + 1] : tree[i][j - 1];
                    leaf = _hashPair(leaf, proof[i]);
                    break;
                }
            }
        }
    }

    function _getProofsUsingTree(ManageLeaf[] memory manageLeafs, bytes32[][] memory tree)
        internal
        view
        returns (bytes32[][] memory proofs)
    {
        proofs = new bytes32[][](manageLeafs.length);
        for (uint256 i; i < manageLeafs.length; ++i) {
            // Generate manage proof.
            bytes4 selector = bytes4(keccak256(abi.encodePacked(manageLeafs[i].signature)));
            bytes memory rawDigest = abi.encodePacked(
                rawDataDecoderAndSanitizer, manageLeafs[i].target, manageLeafs[i].canSendValue, selector
            );
            uint256 argumentAddressesLength = manageLeafs[i].argumentAddresses.length;
            for (uint256 j; j < argumentAddressesLength; ++j) {
                rawDigest = abi.encodePacked(rawDigest, manageLeafs[i].argumentAddresses[j]);
            }
            bytes32 leaf = keccak256(rawDigest);
            proofs[i] = _generateProof(leaf, tree);
        }
    }

    function _buildTrees(bytes32[][] memory merkleTreeIn) internal pure returns (bytes32[][] memory merkleTreeOut) {
        // We are adding another row to the merkle tree, so make merkleTreeOut be 1 longer.
        uint256 merkleTreeIn_length = merkleTreeIn.length;
        merkleTreeOut = new bytes32[][](merkleTreeIn_length + 1);
        uint256 layer_length;
        // Iterate through merkleTreeIn to copy over data.
        for (uint256 i; i < merkleTreeIn_length; ++i) {
            layer_length = merkleTreeIn[i].length;
            merkleTreeOut[i] = new bytes32[](layer_length);
            for (uint256 j; j < layer_length; ++j) {
                merkleTreeOut[i][j] = merkleTreeIn[i][j];
            }
        }

        uint256 next_layer_length;
        if (layer_length % 2 != 0) {
            next_layer_length = (layer_length + 1) / 2;
        } else {
            next_layer_length = layer_length / 2;
        }
        merkleTreeOut[merkleTreeIn_length] = new bytes32[](next_layer_length);
        uint256 count;
        for (uint256 i; i < layer_length; i += 2) {
            merkleTreeOut[merkleTreeIn_length][count] =
                _hashPair(merkleTreeIn[merkleTreeIn_length - 1][i], merkleTreeIn[merkleTreeIn_length - 1][i + 1]);
            count++;
        }

        if (next_layer_length > 1) {
            // We need to process the next layer of leaves.
            merkleTreeOut = _buildTrees(merkleTreeOut);
        }
    }

    function _generateMerkleTree(ManageLeaf[] memory manageLeafs) internal view returns (bytes32[][] memory tree) {
        uint256 leafsLength = manageLeafs.length;
        bytes32[][] memory leafs = new bytes32[][](1);
        leafs[0] = new bytes32[](leafsLength);
        for (uint256 i; i < leafsLength; ++i) {
            bytes4 selector = bytes4(keccak256(abi.encodePacked(manageLeafs[i].signature)));
            bytes memory rawDigest = abi.encodePacked(
                rawDataDecoderAndSanitizer, manageLeafs[i].target, manageLeafs[i].canSendValue, selector
            );
            uint256 argumentAddressesLength = manageLeafs[i].argumentAddresses.length;
            for (uint256 j; j < argumentAddressesLength; ++j) {
                rawDigest = abi.encodePacked(rawDigest, manageLeafs[i].argumentAddresses[j]);
            }
            leafs[0][i] = keccak256(rawDigest);
        }
        tree = _buildTrees(leafs);
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
