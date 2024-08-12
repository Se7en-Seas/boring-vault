// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {
    BridgingDecoderAndSanitizer,
    ArbitrumNativeBridgeDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/BridgingDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract ArbitrumNativeBridgeIntegrationTest is Test, MerkleTreeHelper {
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

    address public weEthOracle = 0x3fa58b74e9a8eA8768eb33c8453e9C2Ed089A40a;
    address public weEthIrm = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;

    function setUp() external {}

    function testBridgingToArbitrumERC20() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        // uint256 blockNumber = 19369928;
        uint256 blockNumber = 19826676;
        _createForkAndSetup(rpcKey, blockNumber);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        deal(getAddress(sourceChain, "WEETH"), address(boringVault), 100e18);
        deal(address(boringVault), 1e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        ERC20[] memory bridgeAssets = new ERC20[](1);
        bridgeAssets[0] = ERC20(getAddress(sourceChain, "WEETH"));
        _addArbitrumNativeBridgeLeafs(leafs, bridgeAssets);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "WEETH");
        targets[1] = getAddress(sourceChain, "arbitrumL1GatewayRouter");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "arbitrumL1ERC20Gateway"), type(uint256).max
        );
        bytes memory bridgeData =
            hex"00000000000000000000000000000000000000000000000000008c4dd2524fc000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000";
        targetData[1] = abi.encodeWithSignature(
            "outboundTransfer(address,address,uint256,uint256,uint256,bytes)",
            getAddress(sourceChain, "WEETH"),
            address(boringVault),
            100e18,
            125062,
            60000000,
            bridgeData
        );
        uint256[] memory values = new uint256[](2);
        values[1] = 0.001e18;
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        // Make sure we revert is bridgeData is not formatted properly.
        bytes memory badFormedBridgeData = abi.encode(1, bytes("bad data"));
        targetData[1] = abi.encodeWithSignature(
            "outboundTransfer(address,address,uint256,uint256,uint256,bytes)",
            getAddress(sourceChain, "WEETH"),
            address(boringVault),
            100e18,
            125062,
            60000000,
            badFormedBridgeData
        );

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    ArbitrumNativeBridgeDecoderAndSanitizer
                        .ArbitrumNativeBridgeDecoderAndSanitizer__ExtraDataNotSupported
                        .selector
                )
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        targetData[1] = abi.encodeWithSignature(
            "outboundTransfer(address,address,uint256,uint256,uint256,bytes)",
            getAddress(sourceChain, "WEETH"),
            address(boringVault),
            100e18,
            125062,
            60000000,
            bridgeData
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testBridgingToArbitrumERC20CustomRefund() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        // uint256 blockNumber = 19369928;
        uint256 blockNumber = 19826676;
        _createForkAndSetup(rpcKey, blockNumber);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        deal(getAddress(sourceChain, "WEETH"), address(boringVault), 100e18);
        deal(address(boringVault), 1e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        ERC20[] memory bridgeAssets = new ERC20[](1);
        bridgeAssets[0] = ERC20(getAddress(sourceChain, "WEETH"));
        _addArbitrumNativeBridgeLeafs(leafs, bridgeAssets);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[2];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "WEETH");
        targets[1] = getAddress(sourceChain, "arbitrumL1GatewayRouter");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "arbitrumL1ERC20Gateway"), type(uint256).max
        );
        bytes memory bridgeData =
            hex"00000000000000000000000000000000000000000000000000008c4dd2524fc000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000";
        targetData[1] = abi.encodeWithSignature(
            "outboundTransferCustomRefund(address,address,address,uint256,uint256,uint256,bytes)",
            getAddress(sourceChain, "WEETH"),
            address(boringVault),
            address(boringVault),
            100e18,
            125062,
            60000000,
            bridgeData
        );
        uint256[] memory values = new uint256[](2);
        values[1] = 0.001e18;
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        bytes memory badFormedBridgeData = abi.encode(1, bytes("bad data"));
        targetData[1] = abi.encodeWithSignature(
            "outboundTransferCustomRefund(address,address,address,uint256,uint256,uint256,bytes)",
            getAddress(sourceChain, "WEETH"),
            address(boringVault),
            address(boringVault),
            100e18,
            125062,
            60000000,
            badFormedBridgeData
        );

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    ArbitrumNativeBridgeDecoderAndSanitizer
                        .ArbitrumNativeBridgeDecoderAndSanitizer__ExtraDataNotSupported
                        .selector
                )
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        targetData[1] = abi.encodeWithSignature(
            "outboundTransferCustomRefund(address,address,address,uint256,uint256,uint256,bytes)",
            getAddress(sourceChain, "WEETH"),
            address(boringVault),
            address(boringVault),
            100e18,
            125062,
            60000000,
            bridgeData
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    /// @notice This leaf wil not be used in a normal merkle tree so MerkleTreeHelper does not create this leaf.
    function testBridgingToArbitrumNative() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        // uint256 blockNumber = 19369928;
        uint256 blockNumber = 19826676;
        _createForkAndSetup(rpcKey, blockNumber);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        deal(address(boringVault), 100e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        leafs[0] = ManageLeaf(
            getAddress(sourceChain, "arbitrumDelayedInbox"),
            true,
            "depositEth()",
            new address[](0),
            "Deposit ETH into Arbitrum",
            rawDataDecoderAndSanitizer
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "arbitrumDelayedInbox");

        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature("depositEth()");
        uint256[] memory values = new uint256[](1);
        values[0] = 100e18;
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testClaimingBridgeFundsERC20() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 20191506;
        _createForkAndSetup(rpcKey, blockNumber);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        // For this test we will claim on behalf of another user so that we do not need to replicate complicated state setup to simulate a bridge from Arbitrum to Ethereum.
        address userToClaimFor = 0x2Cc5F72937939244AAcE3Ff96Cf8bD2fE0294ec6;

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        ERC20[] memory bridgeAssets = new ERC20[](1);
        bridgeAssets[0] = ERC20(getAddress(sourceChain, "WEETH"));
        _addArbitrumNativeBridgeLeafs(leafs, bridgeAssets);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[7];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "arbitrumOutbox");

        bytes[] memory targetData = new bytes[](1);
        bytes32[] memory proof = new bytes32[](17);
        proof[0] = 0x384ce53ea36b655f56c73c3db8e74c1726aa8d3e71b3aea74fae83f1b7cc6e35;
        proof[1] = 0xfa84233074aff7701e20ad26cfe1446a0a575a1df5dd3b609bd23d00298b12e4;
        proof[2] = 0x3588d9eb20e3957fc8038015289a94da9538cef15d2bdf0bffda3de7c61373c9;
        proof[3] = 0x68beaab8e8ca6489d94d91f6657129bd1f455d9023bfc8c518723e61cf18ba8b;
        proof[4] = 0xbef857b41573c73774443a5c6528e4048ef6d013ba648c38df6a31b683217da9;
        proof[5] = 0xc2904fa019ba8330eaa9c8244518ba79c8a7311fd26505eee383640e578fda23;
        proof[6] = 0x62a146969e8a12d8968d40a7fcc01cfa43b86d2a014dd9a5af87ae2e82972c6e;
        proof[7] = 0xb6d4c42cea399e521e7a25d7c20bdbbf7f443043d36265922908a3aef25ecbba;
        proof[8] = 0x948ddcccaa89313d2f9102f1792ec529bf78ed356a827e6e757f0eb1a84cc3f4;
        proof[9] = 0x36adcf7c76b7a98476939ac39c16f0fefa0f05cf781ae5f860b0662aa9d32e90;
        proof[10] = 0xe9bbcd0f5958686336d739327e8bc6255fe56672e4e5b15a01c22b6e5361a13c;
        proof[11] = 0x2ad4ae3ae0f5934f4b79b866f49bcb2ef6fee550deb309b2717c1e91e37cc226;
        proof[12] = 0x815ea3a0a2819747d8c6ab7870bad0a01b006d2333b876eadcf308bde637c9d2;
        proof[13] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        proof[14] = 0xe293e3dc5befe34c72d718dc7b2e5f5cfdeb11a8c3387f0811a76c1d8825903c;
        proof[15] = 0xc0425084107ea9f7a4118f5ed1e3566cda4e90b550363fc804df1e52ed5f2386;
        proof[16] = 0xb43a6b28077d49f37d58c87aec0b51f7bce13b648143f3295385f3b3d5ac3b9b;
        bytes memory bridgeData =
            hex"2e567b360000000000000000000000002260fac5e5542a773aa44fbcfedf7c193bc2c5990000000000000000000000002cc5f72937939244aace3ff96cf8bd2fe0294ec60000000000000000000000002cc5f72937939244aace3ff96cf8bd2fe0294ec60000000000000000000000000000000000000000000000000000000004735bf900000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000567b00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000";
        targetData[0] = abi.encodeWithSignature(
            "executeTransaction(bytes32[],uint256,address,address,uint256,uint256,uint256,uint256,bytes)",
            proof,
            121803,
            getAddress(arbitrum, "arbitrumL2Sender"),
            getAddress(sourceChain, "arbitrumL1ERC20Gateway"),
            224245394,
            20141384,
            1718988440,
            0,
            bridgeData
        );
        uint256[] memory values = new uint256[](1);
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        uint256 userWbtcBalanceBefore = getERC20(sourceChain, "WBTC").balanceOf(userToClaimFor);
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        uint256 userWbtcBalanceAfter = getERC20(sourceChain, "WBTC").balanceOf(userToClaimFor);

        assertGt(userWbtcBalanceAfter, userWbtcBalanceBefore, "User should have received wBTC.");
    }

    function testClaimingBridgeFundsNative() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 20188705;
        _createForkAndSetup(rpcKey, blockNumber);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        // For this test we will claim on behalf of another user so that we do not need to replicate complicated state setup to simulate a bridge from Arbitrum to Ethereum.
        address userToClaimFor = 0x8c140cbc0Fb9CcCDf698e0BeEc4faCA128d9d9E9;
        // To accomplish this using MerkleTreeHelper we need to override the boringVault address to be the users.
        setAddress(true, sourceChain, "boringVault", userToClaimFor);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        ERC20[] memory bridgeAssets = new ERC20[](1);
        bridgeAssets[0] = ERC20(getAddress(sourceChain, "WEETH"));
        _addArbitrumNativeBridgeLeafs(leafs, bridgeAssets);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[8];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "arbitrumOutbox");

        bytes[] memory targetData = new bytes[](1);
        bytes32[] memory proof = new bytes32[](17);
        proof[0] = 0x5d62aaf17167dd67495bfc433cdcb99a5854a34d009b3dade492077bc30cd91e;
        proof[1] = 0x222af0aec47c89da872fe3daabee037eed73acfbafe3c8c216dc90217e0c961c;
        proof[2] = 0x8455962d6f53adacadb9fea8504308f4fa0dea5ae13bf48d4155c55b3ca65a52;
        proof[3] = 0xa4b6b3c0ec3ada4f070f89de2afd6b72e2152b9b78d3243c82f7b457c03ccf74;
        proof[4] = 0x8148f59b31c9fc6f81a0543256d53bec36d230dd46f0dc6258f86bbbe7ea6c12;
        proof[5] = 0x7c2608b084388f5c368935d2c7c3a34a6057f45994c81dad6a783b17a00dbb59;
        proof[6] = 0x7bf97e36eb3352c95fff388d5be36297e1c1c8149a474c9e357b86b4a2cd5660;
        proof[7] = 0xb6d4c42cea399e521e7a25d7c20bdbbf7f443043d36265922908a3aef25ecbba;
        proof[8] = 0x948ddcccaa89313d2f9102f1792ec529bf78ed356a827e6e757f0eb1a84cc3f4;
        proof[9] = 0x36adcf7c76b7a98476939ac39c16f0fefa0f05cf781ae5f860b0662aa9d32e90;
        proof[10] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        proof[11] = 0x2ad4ae3ae0f5934f4b79b866f49bcb2ef6fee550deb309b2717c1e91e37cc226;
        proof[12] = 0x815ea3a0a2819747d8c6ab7870bad0a01b006d2333b876eadcf308bde637c9d2;
        proof[13] = 0x0000000000000000000000000000000000000000000000000000000000000000;
        proof[14] = 0xe293e3dc5befe34c72d718dc7b2e5f5cfdeb11a8c3387f0811a76c1d8825903c;
        proof[15] = 0xc0425084107ea9f7a4118f5ed1e3566cda4e90b550363fc804df1e52ed5f2386;
        proof[16] = 0xb43a6b28077d49f37d58c87aec0b51f7bce13b648143f3295385f3b3d5ac3b9b;
        uint256 expectedNative = 29555044972135104000;
        targetData[0] = abi.encodeWithSignature(
            "executeTransaction(bytes32[],uint256,address,address,uint256,uint256,uint256,uint256,bytes)",
            proof,
            121738,
            userToClaimFor,
            userToClaimFor,
            224084768,
            20138051,
            1718948280,
            expectedNative,
            hex""
        );
        uint256[] memory values = new uint256[](1);
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        uint256 userNativeBalanceBefore = userToClaimFor.balance;
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        uint256 userNativeBalanceAfter = userToClaimFor.balance;

        assertEq(
            userNativeBalanceAfter - userNativeBalanceBefore,
            expectedNative,
            "User should have received expected native."
        );
    }

    function testWithdrawingERC20FromArbitrum() external {
        setSourceChainName("arbitrum");
        // Setup forked environment.
        string memory rpcKey = "ARBITRUM_RPC_URL";
        uint256 blockNumber = 228366826;
        _createForkAndSetup(rpcKey, blockNumber);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        deal(getAddress(sourceChain, "WEETH"), address(boringVault), 100e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        ERC20[] memory bridgeAssets = new ERC20[](1);
        // Need to use mainnet addresses for the ERC20s.
        bridgeAssets[0] = ERC20(getAddress(mainnet, "WEETH"));
        _addArbitrumNativeBridgeLeafs(leafs, bridgeAssets);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "arbitrumL2GatewayRouter");

        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature(
            "outboundTransfer(address,address,uint256,bytes)",
            getAddress(mainnet, "WEETH"),
            address(boringVault),
            100e18,
            hex""
        );
        uint256[] memory values = new uint256[](1);
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        // If data is not empty it will revert.
        targetData[0] = abi.encodeWithSignature(
            "outboundTransfer(address,address,uint256,bytes)",
            getAddress(mainnet, "WEETH"),
            address(boringVault),
            100e18,
            hex"01"
        );
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    ArbitrumNativeBridgeDecoderAndSanitizer
                        .ArbitrumNativeBridgeDecoderAndSanitizer__ExtraDataNotSupported
                        .selector
                )
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        targetData[0] = abi.encodeWithSignature(
            "outboundTransfer(address,address,uint256,bytes)",
            getAddress(mainnet, "WEETH"),
            address(boringVault),
            100e18,
            hex""
        );
        // The manage call reverts with "InvalidEFOpcode", however this appears to be a foundry issue as the resulting sim succeeds on tenderly.
        vm.expectRevert();
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testWithdrawingNativeFromArbitrum() external {
        setSourceChainName("arbitrum");
        // Setup forked environment.
        string memory rpcKey = "ARBITRUM_RPC_URL";
        uint256 blockNumber = 228366826;
        _createForkAndSetup(rpcKey, blockNumber);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        deal(address(boringVault), 100e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        ERC20[] memory bridgeAssets = new ERC20[](1);
        // Need to use mainnet addresses for the ERC20s.
        bridgeAssets[0] = ERC20(getAddress(mainnet, "WEETH"));
        _addArbitrumNativeBridgeLeafs(leafs, bridgeAssets);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "arbitrumSys");

        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature("withdrawEth(address)", address(boringVault));
        uint256[] memory values = new uint256[](1);
        values[0] = 100e18;
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        // The manage call reverts with "InvalidEFOpcode", however this appears to be a foundry issue as the resulting sim succeeds on tenderly.
        vm.expectRevert();
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testRedeemCall() external {
        setSourceChainName("arbitrum");
        // Setup forked environment.
        string memory rpcKey = "ARBITRUM_RPC_URL";
        uint256 blockNumber = 226704376;
        _createForkAndSetup(rpcKey, blockNumber);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        deal(address(boringVault), 100e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        ERC20[] memory bridgeAssets = new ERC20[](1);
        // Need to use mainnet addresses for the ERC20s.
        bridgeAssets[0] = ERC20(getAddress(mainnet, "WEETH"));
        _addArbitrumNativeBridgeLeafs(leafs, bridgeAssets);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[2];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "arbitrumRetryableTx");

        bytes[] memory targetData = new bytes[](1);
        bytes32 ticketId = 0x4428b953549036adbaa880463ad3914eb1c0043ae017f8ea27bd0fa4f3842234;
        targetData[0] = abi.encodeWithSignature("redeem(bytes32)", ticketId);
        uint256[] memory values = new uint256[](1);
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        // The manage call reverts with "InvalidEFOpcode", however this appears to be a foundry issue as the resulting sim succeeds on tenderly.
        vm.expectRevert();
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testCreateRetryable() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        // uint256 blockNumber = 19369928;
        uint256 blockNumber = 19826676;
        _createForkAndSetup(rpcKey, blockNumber);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        deal(address(getAddress(sourceChain, "WEETH")), address(boringVault), 100e18);
        deal(address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        ERC20[] memory bridgeAssets = new ERC20[](1);
        bridgeAssets[0] = ERC20(getAddress(sourceChain, "WEETH"));
        _addArbitrumNativeBridgeLeafs(leafs, bridgeAssets);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[5];
        manageLeafs[1] = leafs[4];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "arbitrumDelayedInbox");
        targets[1] = getAddress(sourceChain, "arbitrumDelayedInbox");

        bytes[] memory targetData = new bytes[](2);
        address to = address(boringVault);
        uint256 l2CallValue = 0.1e18;
        uint256 maxSubmissionCost = 0.05e18;
        address excessFeeRefundAddress = address(boringVault);
        address callValueRefundAddress = address(boringVault);
        uint256 gasLimit = 25_000;
        uint256 maxFeePerGas = 0.01e9;
        bytes memory data = hex"";
        targetData[0] = abi.encodeWithSignature(
            "createRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,bytes)",
            to,
            l2CallValue,
            maxSubmissionCost,
            excessFeeRefundAddress,
            callValueRefundAddress,
            gasLimit,
            maxFeePerGas,
            data
        );
        targetData[1] = abi.encodeWithSignature(
            "unsafeCreateRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,bytes)",
            to,
            l2CallValue,
            maxSubmissionCost,
            excessFeeRefundAddress,
            callValueRefundAddress,
            gasLimit,
            maxFeePerGas,
            data
        );
        uint256[] memory values = new uint256[](2);
        values[0] = 1e18;
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Make sure we revert if gasLimit is too low.
        targetData[0] = abi.encodeWithSignature(
            "createRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,bytes)",
            to,
            l2CallValue,
            maxSubmissionCost,
            excessFeeRefundAddress,
            callValueRefundAddress,
            1,
            maxFeePerGas,
            data
        );
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    ArbitrumNativeBridgeDecoderAndSanitizer
                        .ArbitrumNativeBridgeDecoderAndSanitizer__GasLimitTooSmall
                        .selector
                )
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        targetData[0] = abi.encodeWithSignature(
            "createRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,bytes)",
            to,
            l2CallValue,
            maxSubmissionCost,
            excessFeeRefundAddress,
            callValueRefundAddress,
            gasLimit,
            maxFeePerGas,
            hex"00"
        );
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    ArbitrumNativeBridgeDecoderAndSanitizer
                        .ArbitrumNativeBridgeDecoderAndSanitizer__NoCallDataForRetryables
                        .selector
                )
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }
    // ========================================= HELPER FUNCTIONS =========================================

    function _createForkAndSetup(string memory rpcKey, uint256 blockNumber) internal {
        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new BridgingDecoderAndSanitizer(address(boringVault)));

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

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
