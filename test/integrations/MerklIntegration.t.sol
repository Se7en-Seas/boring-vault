// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {
    EtherFiLiquidEthDecoderAndSanitizer,
    MerklDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/EtherFiLiquidEthDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract MerklIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 20327151;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new EtherFiLiquidEthDecoderAndSanitizer(address(boringVault), address(0)));

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);

        // Setup roles authority.
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

        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            MANGER_INTERNAL_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector, true
        );
        rolesAuthority.setRoleCapability(
            BORING_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.flashLoan.selector, true
        );
        rolesAuthority.setRoleCapability(
            BALANCER_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.receiveFlashLoan.selector, true
        );

        // Grant roles
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        rolesAuthority.setUserRole(getAddress(sourceChain, "vault"), BALANCER_VAULT_ROLE, true);

        // Allow the boring vault to receive ETH.
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);
    }

    function testToggleWhitelistedClaiming() external {
        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        address operator = address(4444);
        _addMerklLeafs(leafs, getAddress(sourceChain, "merklDistributor"), operator, new ERC20[](0));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "merklDistributor");

        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature("toggleOnlyOperatorCanClaim(address)", boringVault);
        uint256[] memory values = new uint256[](1);
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        MerklDistributor distributor = MerklDistributor(getAddress(sourceChain, "merklDistributor"));

        assertEq(
            distributor.onlyOperatorCanClaim(address(boringVault)), 0, "Only operator can claim should be set to false"
        );

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertEq(
            distributor.onlyOperatorCanClaim(address(boringVault)), 1, "Only operator can claim should be set to true"
        );
    }

    function testToggleOperatorClaiming() external {
        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        address operator = address(4444);
        _addMerklLeafs(leafs, getAddress(sourceChain, "merklDistributor"), operator, new ERC20[](0));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "merklDistributor");

        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature("toggleOperator(address,address)", boringVault, operator);
        uint256[] memory values = new uint256[](1);
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        MerklDistributor distributor = MerklDistributor(getAddress(sourceChain, "merklDistributor"));

        assertEq(distributor.operators(address(boringVault), operator), 0, "Operator should be set to false");

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertEq(distributor.operators(address(boringVault), operator), 1, "Operator should be set to true");
    }

    function testClaiming() external {
        address user = 0x8A2eFBd7958dE5c6491A3D7Eba20fFf3773374Bc;

        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        {
            address operator = address(4444);
            ERC20[] memory tokensToClaim = new ERC20[](1);
            tokensToClaim[0] = getERC20(sourceChain, "UNI");
            // We set the boring vault address to be the user so the proper leaf is created.
            setAddress(true, sourceChain, "boringVault", user);
            _addMerklLeafs(leafs, getAddress(sourceChain, "merklDistributor"), operator, tokensToClaim);
        }

        MerklDistributor distributor = MerklDistributor(getAddress(sourceChain, "merklDistributor"));

        // Sppof user address so that they allow the BoringVault to claim.
        vm.prank(user);
        distributor.toggleOperator(user, address(boringVault));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[2];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "merklDistributor");

        bytes[] memory targetData = new bytes[](1);
        {
            address[] memory users = new address[](1);
            users[0] = user;
            address[] memory tokens = new address[](1);
            tokens[0] = getAddress(sourceChain, "UNI");
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = 239109993700000000000;
            bytes32[][] memory proofs = new bytes32[][](1);
            proofs[0] = new bytes32[](14);
            proofs[0][0] = 0x04db4e676ae8fd1aec95f2fca296d5f681cef0530051020791832b030cc61aed;
            proofs[0][1] = 0xa4ca9ea059766b51f61746506b035075ea3f61cf8fce523021ff0f3287effc1f;
            proofs[0][2] = 0xcd24abf63aae07b0f1904f438073adf037f797ed341b388ca631cd6582917422;
            proofs[0][3] = 0x4b8bb8079a5df919dd8ad073a922fd865e296aafeb72dbe943869062ccc38763;
            proofs[0][4] = 0x69176f672dcf56bc214ecae1358927691a9995f1110c6b874b65154e7825f839;
            proofs[0][5] = 0x54dbbc2527049c7c2f6d36289006885cb4a1045ddc535ff76e503f3ac92fbf25;
            proofs[0][6] = 0xc4b80a642e6502722b68d2eb9eaab5db9c8a59544024be006b40c7ea79f316d9;
            proofs[0][7] = 0xd64b8bda6a5a5a633750d4a42ddc3a814019eef1a963f5493628150acaa5010d;
            proofs[0][8] = 0x1e5119d0ffc2d35e04e075d11dcbd2a16c060340da9b7c16c5dec3dc4692d515;
            proofs[0][9] = 0x6cc004c9a3e3673ef4824339f05b1772dea79f870c8e1cd9b64132026383c1a3;
            proofs[0][10] = 0x84f2371a8887d3d2031e13ed21b6c475a9b5c8159af5ce30b12740f632f61544;
            proofs[0][11] = 0x2da3c4be46e42d0575b3aaeb0fa313b677ffd9652c03b2d37c31e1d30f2230ac;
            proofs[0][12] = 0xbbde0977f0179c7e71e9c6174df03b466e84b441168f54c1bcbdaf8f811243ef;
            proofs[0][13] = 0x2c040362f80a7db1a53dd6b2244ff60437ab9cbc3cdfb40ef5882d9758762440;
            targetData[0] = abi.encodeWithSignature(
                "claim(address[],address[],uint256[],bytes32[][])", users, tokens, amounts, proofs
            );
        }
        uint256[] memory values = new uint256[](1);
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        uint256 balanceDelta = getERC20(sourceChain, "UNI").balanceOf(user);
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        balanceDelta = getERC20(sourceChain, "UNI").balanceOf(user) - balanceDelta;

        assertGt(balanceDelta, 0, "User should have received UNI from claim");
    }

    function testClaimingReverts() external {
        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        {
            address operator = address(4444);
            ERC20[] memory tokensToClaim = new ERC20[](1);
            tokensToClaim[0] = getERC20(sourceChain, "UNI");
            // We set the boring vault address to be the user so the proper leaf is created.
            _addMerklLeafs(leafs, getAddress(sourceChain, "merklDistributor"), operator, tokensToClaim);
        }

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[2];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "merklDistributor");

        bytes[] memory targetData = new bytes[](1);
        {
            address[] memory users = new address[](1);
            address[] memory tokens = new address[](2);
            uint256[] memory amounts = new uint256[](1);
            bytes32[][] memory proofs = new bytes32[][](1);
            targetData[0] = abi.encodeWithSignature(
                "claim(address[],address[],uint256[],bytes32[][])", users, tokens, amounts, proofs
            );
        }
        uint256[] memory values = new uint256[](1);
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(MerklDecoderAndSanitizer.MerklDecoderAndSanitizer__InputLengthMismatch.selector)
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        {
            address[] memory users = new address[](1);
            address[] memory tokens = new address[](1);
            uint256[] memory amounts = new uint256[](2);
            bytes32[][] memory proofs = new bytes32[][](1);
            targetData[0] = abi.encodeWithSignature(
                "claim(address[],address[],uint256[],bytes32[][])", users, tokens, amounts, proofs
            );
        }

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(MerklDecoderAndSanitizer.MerklDecoderAndSanitizer__InputLengthMismatch.selector)
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        {
            address[] memory users = new address[](1);
            address[] memory tokens = new address[](1);
            uint256[] memory amounts = new uint256[](1);
            bytes32[][] memory proofs = new bytes32[][](2);
            targetData[0] = abi.encodeWithSignature(
                "claim(address[],address[],uint256[],bytes32[][])", users, tokens, amounts, proofs
            );
        }

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(MerklDecoderAndSanitizer.MerklDecoderAndSanitizer__InputLengthMismatch.selector)
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        {
            address[] memory users = new address[](2);
            address[] memory tokens = new address[](1);
            uint256[] memory amounts = new uint256[](1);
            bytes32[][] memory proofs = new bytes32[][](1);
            targetData[0] = abi.encodeWithSignature(
                "claim(address[],address[],uint256[],bytes32[][])", users, tokens, amounts, proofs
            );
        }

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(MerklDecoderAndSanitizer.MerklDecoderAndSanitizer__InputLengthMismatch.selector)
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

interface MerklDistributor {
    function onlyOperatorCanClaim(address user) external view returns (uint256);
    function operators(address user, address operator) external view returns (uint256);
    function toggleOperator(address user, address operator) external;
}
