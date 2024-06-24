// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {BoringVault} from "./../../src/base/BoringVault.sol";
import {TellerWithMultiAssetSupport} from "./../../src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithRateProviders} from "./../../src/base/Roles/AccountantWithRateProviders.sol";
import {ManagerWithMerkleVerification} from "./../../src/base/Roles/ManagerWithMerkleVerification.sol";
import {IonPoolDecoderAndSanitizer} from "./../../src/base/DecodersAndSanitizers/IonPoolDecoderAndSanitizer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MainnetAddresses} from "./../resources/MainnetAddresses.sol";
import {IIonPool} from "@ion-protocol/interfaces/IIonPool.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

contract IonPoolSharedSetup is Test, MainnetAddresses {
    using stdStorage for StdStorage;

    IIonPool constant WEETH_IONPOOL = IIonPool(0x0000000000eaEbd95dAfcA37A39fd09745739b78);
    // --- Vault ---
    address immutable VAULT_OWNER = makeAddr("VAULT_OWNER");
    address immutable VAULT_STRATEGIST = makeAddr("VAULT_STRATEGIST");
    // --- Manager ---
    address immutable MANAGER_OWNER = makeAddr("MANAGER_OWNER");
    bytes32[][] manageTree;
    bytes32[][] manageProofs;
    ManageLeaf[] leafs;
    // --- Teller ---
    address immutable TELLER_OWNER = makeAddr("TELLER_OWNER");
    // --- Accountant ---
    address immutable ACCOUNTANT_OWNER = makeAddr("ACCOUNTANT_OWNER");
    address immutable PAYOUT_ADDRESS = makeAddr("PAYOUT_ADDRESS");
    uint96 immutable STARTING_EXCHANGE_RATE = 1e18;
    uint16 immutable ALLOWED_EXCHANGE_RATE_CHANGE_UPPER = 1.005e4;
    uint16 immutable ALLOWED_EXCHANGE_RATE_CHANGE_LOWER = 0.995e4;
    uint32 immutable MINIMUM_UPDATE_DELAY_IN_SECONDS = 3600; // 1 hour
    uint16 immutable MANAGEMENT_FEE = 0.2e4; // maximum 0.2e4
    // --- RolesAuthority ---
    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant TELLER_ROLE = 3;
    // uint8 public constant MANGER_INTERNAL_ROLE = 3;
    // uint8 public constant ADMIN_ROLE = 4;
    // uint8 public constant BORING_VAULT_ROLE = 5;
    // uint8 public constant BALANCER_VAULT_ROLE = 6;

    BoringVault public boringVault;
    TellerWithMultiAssetSupport public teller;
    AccountantWithRateProviders public accountant;
    ManagerWithMerkleVerification public manager;

    IonPoolDecoderAndSanitizer public ionPoolDecoderAndSanitizer;

    RolesAuthority public rolesAuthority;

    address public rawDataDecoderAndSanitizer;

    struct ManageLeaf {
        address target;
        bool canSendValue;
        string signature;
        address[] argumentAddresses;
    }

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 20027194);

        boringVault = new BoringVault(VAULT_OWNER, "Ion Boring Vault", "IBV", 18);

        uint256 startingExchangeRate = 1e18;

        accountant = new AccountantWithRateProviders(
            ACCOUNTANT_OWNER,
            address(boringVault),
            PAYOUT_ADDRESS,
            STARTING_EXCHANGE_RATE,
            address(WETH), // BASE
            ALLOWED_EXCHANGE_RATE_CHANGE_UPPER,
            ALLOWED_EXCHANGE_RATE_CHANGE_LOWER,
            MINIMUM_UPDATE_DELAY_IN_SECONDS,
            MANAGEMENT_FEE
        );

        teller = new TellerWithMultiAssetSupport(
            TELLER_OWNER,
            address(boringVault),
            address(accountant),
            address(WETH) // NOTE NOT THE BASE ASSET, ALWAYS WETH FOR WRAPPER
        );

        manager = new ManagerWithMerkleVerification(MANAGER_OWNER, address(boringVault), balancerVault);

        ionPoolDecoderAndSanitizer = new IonPoolDecoderAndSanitizer(address(boringVault));
        rawDataDecoderAndSanitizer = address(ionPoolDecoderAndSanitizer); // TODO Make this calculated at runtime instead

        // Set the merkle root
        leafs.push(ManageLeaf(address(WSTETH), false, "approve(address,uint256)", new address[](1)));
        leafs[0].argumentAddresses[0] = address(WEETH_IONPOOL);

        leafs.push(ManageLeaf(address(WEETH_IONPOOL), false, "supply(address,uint256,bytes32[])", new address[](1)));
        leafs[1].argumentAddresses[0] = address(boringVault);

        leafs.push(ManageLeaf(address(WEETH_IONPOOL), false, "withdraw(address,uint256)", new address[](1)));
        leafs[2].argumentAddresses[0] = address(boringVault);

        // The leafs have to be even numbers. So we populate an empty `ManageLeaf`
        leafs.push(ManageLeaf(address(0), false, "", new address[](1)));

        manageTree = _generateMerkleTree(leafs);

        // Each array is the proof for each leaf (transaction) in the same tree
        // First element is the proof for the first leaf.
        manageProofs = _getProofsUsingTree(leafs, manageTree);

        bytes32 manageRoot = manageTree[manageTree.length - 1][0];

        vm.prank(MANAGER_OWNER);
        manager.setManageRoot(VAULT_STRATEGIST, manageRoot);

        bytes32[] memory leafBytes32 = _getLeafs(leafs);

        // --- ROLES CONFIGURATION ---
        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));

        // --- Roles ---
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );

        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)"))),
            true
        );

        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])"))),
            true
        );

        rolesAuthority.setRoleCapability(TELLER_ROLE, address(boringVault), BoringVault.enter.selector, true);

        rolesAuthority.setRoleCapability(TELLER_ROLE, address(boringVault), BoringVault.exit.selector, true);

        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);

        // rolesAuthority.setPublicCapability(
        //     address(teller), TellerWithMultiAssetSupport.depositWithPermit.selector, true
        // );
        // --- Assign roles to users ---

        rolesAuthority.setUserRole(VAULT_STRATEGIST, STRATEGIST_ROLE, true);

        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);

        rolesAuthority.setUserRole(address(teller), TELLER_ROLE, true);

        // Single Asset, ETH as base asset
        // Setup rate providers
        vm.prank(ACCOUNTANT_OWNER);
        accountant.setAuthority(rolesAuthority);
        vm.prank(VAULT_OWNER);
        boringVault.setAuthority(rolesAuthority);
        vm.prank(MANAGER_OWNER);
        manager.setAuthority(rolesAuthority);
        vm.prank(TELLER_OWNER);
        teller.setAuthority(rolesAuthority);
    }

    /**
     * Each element in the `manageLeafs` array is a whitelisted transaction
     * type.
     */
    function _generateMerkleTree(ManageLeaf[] memory manageLeafs) internal view returns (bytes32[][] memory tree) {
        uint256 leafsLength = manageLeafs.length; // number of transactions
        // 2D array, array of arrays
        // Why is it a 2d array tho?
        bytes32[][] memory _leafs = new bytes32[][](1);

        // First array in the 2D array has all of the encoded leafs.
        // What about the other arrays in the 2D array?
        // Why is the 2D array always populated for the 0th index?
        _leafs[0] = new bytes32[](leafsLength);
        for (uint256 i; i < leafsLength; ++i) {
            console2.log("--- SETUP LEAF ---");
            bytes4 selector = bytes4(keccak256(abi.encodePacked(manageLeafs[i].signature)));
            bytes memory rawDigest = abi.encodePacked(
                rawDataDecoderAndSanitizer, manageLeafs[i].target, manageLeafs[i].canSendValue, selector
            );
            uint256 argumentAddressesLength = manageLeafs[i].argumentAddresses.length;
            for (uint256 j; j < argumentAddressesLength; ++j) {
                rawDigest = abi.encodePacked(rawDigest, manageLeafs[i].argumentAddresses[j]);
            }

            console2.log("rawDigest");
            console2.logBytes(rawDigest);
            console2.log("leaf hash");
            console2.logBytes32(keccak256(rawDigest));

            _leafs[0][i] = keccak256(rawDigest);
        }
        tree = _buildTrees(_leafs); // are other indicies in the leafs ever accessed?
    }

    function _buildTrees(bytes32[][] memory merkleTreeIn) internal pure returns (bytes32[][] memory merkleTreeOut) {
        // We are adding another row to the merkle tree, so make merkleTreeOut be 1 longer.
        uint256 merkleTreeIn_length = merkleTreeIn.length;
        merkleTreeOut = new bytes32[][](merkleTreeIn_length + 1);
        uint256 layer_length;
        // Iterate through merkleTreeIn to copy over data.
        for (uint256 i; i < merkleTreeIn_length; ++i) {
            layer_length = merkleTreeIn[i].length; // number of leafs
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
            console2.log("i: ", i);
            merkleTreeOut[merkleTreeIn_length][count] =
                _hashPair(merkleTreeIn[merkleTreeIn_length - 1][i], merkleTreeIn[merkleTreeIn_length - 1][i + 1]);
            count++;
        }

        if (next_layer_length > 1) {
            // We need to process the next layer of leaves.
            merkleTreeOut = _buildTrees(merkleTreeOut);
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

    function _getLeafs(ManageLeaf[] memory manageLeafs) internal view returns (bytes32[] memory leafs) {
        leafs = new bytes32[](manageLeafs.length);
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
            leafs[i] = keccak256(rawDigest);
        }
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

    function test_SetUp() public {}
}
