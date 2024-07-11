pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {ChainValues} from "test/resources/ChainValues.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "forge-std/Base.sol";

contract MerkleTreeHelper is CommonBase, ChainValues {
    string public sourceChain;
    address public _boringVault;
    address public _rawDataDecoderAndSanitizer;
    address public _managerAddress;
    address public _accountantAddress;
    uint256 leafIndex = type(uint256).max;

    function setSourceChainName(string memory _chain) internal {
        sourceChain = _chain;
    }

    // ========================================= StandardBridge =========================================

    error StandardBridge__LocalAndRemoteTokensLengthMismatch();

    function _addStandardBridgeLeafs(
        ManageLeaf[] memory leafs,
        string memory destination,
        address destinationCrossDomainMessenger,
        address sourceResolvedDelegate,
        address sourceStandardBridge,
        address sourcePortal,
        ERC20[] memory localTokens,
        ERC20[] memory remoteTokens
    ) internal virtual {
        if (localTokens.length != remoteTokens.length) {
            revert StandardBridge__LocalAndRemoteTokensLengthMismatch();
        }
        // Approvals
        for (uint256 i; i < localTokens.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(localTokens[i]),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve StandardBridge to spend ", localTokens[i].symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = sourceStandardBridge;
        }

        // ERC20 bridge leafs.
        for (uint256 i; i < localTokens.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                sourceStandardBridge,
                false,
                "bridgeERC20To(address,address,address,uint256,uint32,bytes)",
                new address[](3),
                string.concat("Bridge ", localTokens[i].symbol(), " from ", sourceChain, " to ", destination),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(localTokens[i]);
            leafs[leafIndex].argumentAddresses[1] = address(remoteTokens[i]);
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        }

        // Bridge ETH.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            sourceStandardBridge,
            true,
            "bridgeETHTo(address,uint32,bytes)",
            new address[](1),
            string.concat("Bridge ETH from ", sourceChain, " to ", destination),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // If we are generating leafs for some L2 back to mainnet, these leafs are not needed.
        if (keccak256(abi.encode(destination)) != keccak256(abi.encode(mainnet))) {
            // Prove withdrawal transaction.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                sourcePortal,
                false,
                "proveWithdrawalTransaction((uint256,address,address,uint256,uint256,bytes),uint256,(bytes32,bytes32,bytes32,bytes32),bytes[])",
                new address[](2),
                string.concat("Prove withdrawal transaction from ", destination, " to ", sourceChain),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = destinationCrossDomainMessenger;
            leafs[leafIndex].argumentAddresses[1] = sourceResolvedDelegate;

            // Finalize withdrawal transaction.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                sourcePortal,
                false,
                "finalizeWithdrawalTransaction((uint256,address,address,uint256,uint256,bytes))",
                new address[](2),
                string.concat("Finalize withdrawal transaction from ", destination, " to ", sourceChain),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = destinationCrossDomainMessenger;
            leafs[leafIndex].argumentAddresses[1] = sourceResolvedDelegate;
        }
    }

    // ========================================= JSON FUNCTIONS =========================================
    function _generateLeafs(
        string memory filePath,
        ManageLeaf[] memory leafs,
        bytes32 manageRoot,
        bytes32[][] memory manageTree
    ) internal {
        _boringVault = getAddress(sourceChain, "boringVault");

        if (vm.exists(filePath)) {
            // Need to delete it
            vm.removeFile(filePath);
        }
        vm.writeLine(filePath, "{ \"metadata\": ");
        string[] memory composition = new string[](5);
        composition[0] = "Bytes20(DECODER_AND_SANITIZER_ADDRESS)";
        composition[1] = "Bytes20(TARGET_ADDRESS)";
        composition[2] = "Bytes1(CAN_SEND_VALUE)";
        composition[3] = "Bytes4(TARGET_FUNCTION_SELECTOR)";
        composition[4] = "Bytes{N*20}(ADDRESS_ARGUMENT_0,...,ADDRESS_ARGUMENT_N)";
        string memory metadata = "ManageRoot";
        {
            // Determine how many leafs are used.
            uint256 usedLeafCount;
            for (uint256 i; i < leafs.length; ++i) {
                if (leafs[i].target != address(0)) {
                    usedLeafCount++;
                }
            }
            vm.serializeUint(metadata, "LeafCount", usedLeafCount);
        }
        vm.serializeUint(metadata, "TreeCapacity", leafs.length);
        vm.serializeString(metadata, "DigestComposition", composition);
        vm.serializeAddress(metadata, "BoringVaultAddress", _boringVault);
        vm.serializeAddress(metadata, "DecoderAndSanitizerAddress", _rawDataDecoderAndSanitizer);
        vm.serializeAddress(metadata, "ManagerAddress", _managerAddress);
        vm.serializeAddress(metadata, "AccountantAddress", _accountantAddress);
        string memory finalMetadata = vm.serializeBytes32(metadata, "ManageRoot", manageRoot);

        vm.writeLine(filePath, finalMetadata);
        vm.writeLine(filePath, ",");
        vm.writeLine(filePath, "\"leafs\": [");

        for (uint256 i; i < leafs.length; ++i) {
            string memory leaf = "leaf";
            vm.serializeAddress(leaf, "TargetAddress", leafs[i].target);
            vm.serializeAddress(leaf, "DecoderAndSanitizerAddress", leafs[i].decoderAndSanitizer);
            vm.serializeBool(leaf, "CanSendValue", leafs[i].canSendValue);
            vm.serializeString(leaf, "FunctionSignature", leafs[i].signature);
            bytes4 sel = bytes4(keccak256(abi.encodePacked(leafs[i].signature)));
            string memory selector = Strings.toHexString(uint32(sel), 4);
            vm.serializeString(leaf, "FunctionSelector", selector);
            bytes memory packedData;
            for (uint256 j; j < leafs[i].argumentAddresses.length; ++j) {
                packedData = abi.encodePacked(packedData, leafs[i].argumentAddresses[j]);
            }
            vm.serializeBytes(leaf, "PackedArgumentAddresses", packedData);
            vm.serializeAddress(leaf, "AddressArguments", leafs[i].argumentAddresses);
            bytes32 digest = keccak256(
                abi.encodePacked(leafs[i].decoderAndSanitizer, leafs[i].target, leafs[i].canSendValue, sel, packedData)
            );
            vm.serializeBytes32(leaf, "LeafDigest", digest);

            string memory finalJson = vm.serializeString(leaf, "Description", leafs[i].description);

            // vm.writeJson(finalJson, filePath);
            vm.writeLine(filePath, finalJson);
            if (i != leafs.length - 1) {
                vm.writeLine(filePath, ",");
            }
        }
        vm.writeLine(filePath, "],");

        string memory merkleTreeName = "MerkleTree";
        string[][] memory merkleTree = new string[][](manageTree.length);
        for (uint256 k; k < manageTree.length; ++k) {
            merkleTree[k] = new string[](manageTree[k].length);
        }

        for (uint256 i; i < manageTree.length; ++i) {
            for (uint256 j; j < manageTree[i].length; ++j) {
                merkleTree[i][j] = vm.toString(manageTree[i][j]);
            }
        }

        string memory finalMerkleTree;
        for (uint256 i; i < merkleTree.length; ++i) {
            string memory layer = Strings.toString(merkleTree.length - (i + 1));
            finalMerkleTree = vm.serializeString(merkleTreeName, layer, merkleTree[i]);
        }
        vm.writeLine(filePath, "\"MerkleTree\": ");
        vm.writeLine(filePath, finalMerkleTree);
        vm.writeLine(filePath, "}");
    }

    // ========================================= HELPER FUNCTIONS =========================================

    struct ManageLeaf {
        address target;
        bool canSendValue;
        string signature;
        address[] argumentAddresses;
        string description;
        address decoderAndSanitizer;
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

    function _generateMerkleTree(ManageLeaf[] memory manageLeafs) internal pure returns (bytes32[][] memory tree) {
        uint256 leafsLength = manageLeafs.length;
        bytes32[][] memory leafs = new bytes32[][](1);
        leafs[0] = new bytes32[](leafsLength);
        for (uint256 i; i < leafsLength; ++i) {
            bytes4 selector = bytes4(keccak256(abi.encodePacked(manageLeafs[i].signature)));
            bytes memory rawDigest = abi.encodePacked(
                manageLeafs[i].decoderAndSanitizer, manageLeafs[i].target, manageLeafs[i].canSendValue, selector
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

    function _getPoolAddressFromPoolId(bytes32 poolId) internal pure returns (address) {
        return address(uint160(uint256(poolId >> 96)));
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
                getAddress(sourceChain, "rawDataDecoderAndSanitizer"),
                manageLeafs[i].target,
                manageLeafs[i].canSendValue,
                selector
            );
            uint256 argumentAddressesLength = manageLeafs[i].argumentAddresses.length;
            for (uint256 j; j < argumentAddressesLength; ++j) {
                rawDigest = abi.encodePacked(rawDigest, manageLeafs[i].argumentAddresses[j]);
            }
            bytes32 leaf = keccak256(rawDigest);
            proofs[i] = _generateProof(leaf, tree);
        }
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
                } else if (j == tree[i].length - 1) {
                    // We have reached the end of the layer and have not found the leaf.
                    revert("Leaf not found in tree");
                }
            }
        }
    }
}

interface IMB {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function idToMarketParams(bytes32 id) external view returns (MarketParams memory);
}

interface PendleMarket {
    function readTokens() external view returns (address, address, address);
}

interface PendleSy {
    function getTokensIn() external view returns (address[] memory);
    function getTokensOut() external view returns (address[] memory);
    function assetInfo() external view returns (uint8, ERC20, uint8);
}

interface UniswapV3Pool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
}

interface CurvePool {
    function coins(uint256 i) external view returns (address);
}

interface BalancerVault {
    function getPoolTokens(bytes32) external view returns (ERC20[] memory, uint256[] memory, uint256);
}
