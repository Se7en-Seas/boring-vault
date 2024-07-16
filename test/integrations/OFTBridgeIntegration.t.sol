// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {
    BridgingDecoderAndSanitizer,
    OFTDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/BridgingDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract OFTBridgeIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;
    using AddressToBytes32Lib for address;

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
        setSourceChainName(mainnet);
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 20227663;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new BridgingDecoderAndSanitizer(address(boringVault)));

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

    function testBridgingToBaseERC20() external {
        deal(getAddress(sourceChain, "WEETH"), address(boringVault), 101e18);
        deal(getAddress(sourceChain, "boringVault"), 101e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "WEETH"), getAddress(sourceChain, "EtherFiOFTAdapter"), layerZeroBaseEndpointId
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "WEETH");
        targets[1] = getAddress(sourceChain, "EtherFiOFTAdapter");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "EtherFiOFTAdapter"), type(uint256).max
        );
        DecoderCustomTypes.SendParam memory param;
        param.dstEid = layerZeroBaseEndpointId;
        param.to = address(boringVault).toBytes32();
        param.amountLD = 100e18;
        param.minAmountLD = 99e18;
        param.extraOptions = hex"0003";
        param.composeMsg = hex"";
        param.oftCmd = hex"";

        DecoderCustomTypes.MessagingFee memory fee;
        fee.nativeFee = 0.0006e18;
        fee.lzTokenFee = 0;

        targetData[1] = abi.encodeWithSignature(
            "send((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),(uint256,uint256),address)",
            param,
            fee,
            boringVault
        );
        uint256[] memory values = new uint256[](2);
        values[1] = fee.nativeFee;
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testBridgingToBaseERC20Reverts() external {
        deal(getAddress(sourceChain, "WEETH"), address(boringVault), 101e18);
        deal(getAddress(sourceChain, "boringVault"), 101e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "WEETH"), getAddress(sourceChain, "EtherFiOFTAdapter"), layerZeroBaseEndpointId
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "WEETH");
        targets[1] = getAddress(sourceChain, "EtherFiOFTAdapter");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "EtherFiOFTAdapter"), type(uint256).max
        );
        DecoderCustomTypes.SendParam memory param;
        param.dstEid = layerZeroBaseEndpointId;
        param.to = address(boringVault).toBytes32();
        param.amountLD = 100e18;
        param.minAmountLD = 99e18;
        param.extraOptions = hex"0003";
        param.composeMsg = hex"00";
        param.oftCmd = hex"";

        DecoderCustomTypes.MessagingFee memory fee;
        fee.nativeFee = 0.0006e18;
        fee.lzTokenFee = 0;

        targetData[1] = abi.encodeWithSignature(
            "send((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),(uint256,uint256),address)",
            param,
            fee,
            boringVault
        );
        uint256[] memory values = new uint256[](2);
        values[1] = fee.nativeFee;
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        vm.expectRevert(
            bytes(abi.encodeWithSelector(OFTDecoderAndSanitizer.OFTDecoderAndSanitizer__NonZeroMessage.selector))
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        param.composeMsg = hex"";
        param.oftCmd = hex"00";

        targetData[1] = abi.encodeWithSignature(
            "send((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),(uint256,uint256),address)",
            param,
            fee,
            boringVault
        );

        vm.expectRevert(
            bytes(abi.encodeWithSelector(OFTDecoderAndSanitizer.OFTDecoderAndSanitizer__NonZeroOFTCommand.selector))
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        param.oftCmd = hex"";
        targetData[1] = abi.encodeWithSignature(
            "send((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),(uint256,uint256),address)",
            param,
            fee,
            boringVault
        );

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
