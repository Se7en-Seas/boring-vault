// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {
    BridgingDecoderAndSanitizer,
    CCIPDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/BridgingDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract CCIPBridgeIntegrationTest is Test, MerkleTreeHelper {
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

    function testBridgingToArbitrumERC20() external {
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 101e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        ERC20[] memory bridgeAssets = new ERC20[](1);
        bridgeAssets[0] = getERC20(sourceChain, "WETH");
        ERC20[] memory feeTokens = new ERC20[](1);
        feeTokens[0] = getERC20(sourceChain, "WETH");
        _addCcipBridgeLeafs(leafs, ccipArbitrumChainSelector, bridgeAssets, feeTokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "ccipRouter");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "ccipRouter"), type(uint256).max
        );
        DecoderCustomTypes.EVM2AnyMessage memory message;
        message.receiver = abi.encode(address(boringVault));
        message.data = "";
        message.tokenAmounts = new DecoderCustomTypes.EVMTokenAmount[](1);
        message.tokenAmounts[0].token = getAddress(sourceChain, "WETH");
        message.tokenAmounts[0].amount = 100e18;
        message.feeToken = getAddress(sourceChain, "WETH");
        message.extraArgs = abi.encode(bytes4(0x97a657c9), 0);

        targetData[1] = abi.encodeWithSignature(
            "ccipSend(uint64,(bytes,bytes,(address,uint256)[],address,bytes))", ccipArbitrumChainSelector, message
        );
        uint256[] memory values = new uint256[](2);
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testBridgingToArbitrumERC20Reverts() external {
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 101e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        ERC20[] memory bridgeAssets = new ERC20[](1);
        bridgeAssets[0] = getERC20(sourceChain, "WETH");
        ERC20[] memory feeTokens = new ERC20[](1);
        feeTokens[0] = getERC20(sourceChain, "WETH");
        _addCcipBridgeLeafs(leafs, ccipArbitrumChainSelector, bridgeAssets, feeTokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "ccipRouter");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "ccipRouter"), type(uint256).max
        );
        DecoderCustomTypes.EVM2AnyMessage memory message;
        message.receiver = abi.encode(address(boringVault));
        message.data = "01";
        message.tokenAmounts = new DecoderCustomTypes.EVMTokenAmount[](1);
        message.tokenAmounts[0].token = getAddress(sourceChain, "WETH");
        message.tokenAmounts[0].amount = 100e18;
        message.feeToken = getAddress(sourceChain, "WETH");
        message.extraArgs = abi.encode(bytes4(0x97a657c9), 0);

        targetData[1] = abi.encodeWithSignature(
            "ccipSend(uint64,(bytes,bytes,(address,uint256)[],address,bytes))", ccipArbitrumChainSelector, message
        );
        uint256[] memory values = new uint256[](2);
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        // Call reverts since message.data is not empty.
        vm.expectRevert(
            bytes(abi.encodeWithSelector(CCIPDecoderAndSanitizer.CCIPDecoderAndSanitizer__NonZeroDataLength.selector))
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Fix the data length, but set the extraArgs tag to invalid.
        message.data = "";
        message.extraArgs = abi.encode(bytes4(0x97a657c8), 0);
        targetData[1] = abi.encodeWithSignature(
            "ccipSend(uint64,(bytes,bytes,(address,uint256)[],address,bytes))", ccipArbitrumChainSelector, message
        );
        vm.expectRevert(
            bytes(abi.encodeWithSelector(CCIPDecoderAndSanitizer.CCIPDecoderAndSanitizer__InvalidExtraArgsTag.selector))
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Fix the tag, but set gas limit to non zero.
        message.extraArgs = abi.encode(bytes4(0x97a657c9), 1);
        targetData[1] = abi.encodeWithSignature(
            "ccipSend(uint64,(bytes,bytes,(address,uint256)[],address,bytes))", ccipArbitrumChainSelector, message
        );
        vm.expectRevert(
            bytes(abi.encodeWithSelector(CCIPDecoderAndSanitizer.CCIPDecoderAndSanitizer__NonZeroGasLimit.selector))
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Fix the gas limit and call now succeeds.
        message.extraArgs = abi.encode(bytes4(0x97a657c9), 0);
        targetData[1] = abi.encodeWithSignature(
            "ccipSend(uint64,(bytes,bytes,(address,uint256)[],address,bytes))", ccipArbitrumChainSelector, message
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
