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
    StandardBridgeDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/BridgingDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract LineaBridgeIntegrationTest is Test, MerkleTreeHelper {
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

    function setUp() external {}

    function testBridgingToLineaETH() external {
        setSourceChainName("mainnet");
        _createForkAndSetup("MAINNET_RPC_URL", 20279353);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        deal(address(boringVault), 101e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory localTokens;
        _addLineaNativeBridgeLeafs(leafs, "linea", localTokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "lineaMessageService");

        bytes[] memory targetData = new bytes[](1);

        targetData[0] = abi.encodeWithSignature("sendMessage(address,uint256,bytes)", boringVault, 0, hex"");
        uint256[] memory values = new uint256[](1);
        values[0] = 100e18;
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testClaimingFromLineaETH() external {
        setSourceChainName("mainnet");
        _createForkAndSetup("MAINNET_RPC_URL", 20671268);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        address user = 0x456ea2A50a3D2dD7FA61bAc38e24C672250E2e9b;
        // Set boring vault address to be user address so we can claim on their behalf.
        setAddress(true, sourceChain, "boringVault", user);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory localTokens;
        _addLineaNativeBridgeLeafs(leafs, "linea", localTokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "lineaMessageService");

        bytes[] memory targetData = new bytes[](1);
        targetData[0] =
            hex"6463fb2a0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000128640000000000000000000000000000000000000000000000000000000000000004000000000000000000000000456ea2a50a3d2dd7fa61bac38e24c672250e2e9b000000000000000000000000456ea2a50a3d2dd7fa61bac38e24c672250e2e9b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000de0b6b3a764000000000000000000000000000000000000000000000000000000000000000000004f791ee738a2dda5dc7ba829e6048b5bed54f545fb76362b9292a6395f112e7500000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000005477276e6af918954740f482799e043c475970bdcb02a975102bcbf65e76182b95e0d21673ac1f2cfe71aaebf5aff0e3a1b4b7490933e94a032792f4987983f192e6eda078996719befa8d5e1a92a0a285c0b2c11662517912dd5b3831b1818c0689a4fbfb4b66594c13883e04c6fe19904190a3004f32bb5adfac67c31f12e55e58769b32a1beaf1ea27375a44095a0d1fb664ce2dd358e7fcbfb78c26a193440000000000000000000000000000000000000000000000000000000000000000";

        uint256[] memory values = new uint256[](1);
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        uint256 userETHBalanceDelta = user.balance;
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        userETHBalanceDelta = user.balance - userETHBalanceDelta;
        assertEq(userETHBalanceDelta, 1e18, "User should have received 1 ETH");
    }

    function testBridgingToLineaERC20() external {
        setSourceChainName("mainnet");
        _createForkAndSetup("MAINNET_RPC_URL", 20279353);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        deal(getAddress(sourceChain, "DAI"), address(boringVault), 101e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory localTokens = new ERC20[](1);
        localTokens[0] = getERC20(sourceChain, "DAI");
        _addLineaNativeBridgeLeafs(leafs, "linea", localTokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "DAI");
        targets[1] = getAddress(sourceChain, "tokenBridge");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "tokenBridge"), 100e18);
        targetData[1] = abi.encodeWithSignature(
            "bridgeToken(address,uint256,address)", getAddress(sourceChain, "DAI"), 100e18, boringVault
        );
        uint256[] memory values = new uint256[](2);
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testClaimingFromLineaERC20() external {
        setSourceChainName("mainnet");
        _createForkAndSetup("MAINNET_RPC_URL", 20671658);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        address user = 0x868a595fe5f765a753ACc4756C4201e013f6Edaa;

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory localTokens = new ERC20[](1);
        localTokens[0] = getERC20(sourceChain, "USDT");
        _addLineaNativeBridgeLeafs(leafs, "linea", localTokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[3];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "lineaMessageService");

        bytes[] memory targetData = new bytes[](1);
        targetData[0] =
            hex"6463fb2a00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000001297f0000000000000000000000000000000000000000000000000000000000000008000000000000000000000000353012dc4a9a6cf55c941badc267f82004a8ceb9000000000000000000000000051f1d88f0af5763fb888ec4378b4d8b29ea33190000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006edfb609ba976312d02535d13c5f1aadbcc0819e1fa3b8afdf90c577ff04a2ca000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000055219beafaaf7db76b2216d7117d7d6a3335fa2d24c01af79b2df9f2fd9d926ca30ef52dc4e3deafbfca5d9d26393cccecd234af8770f27bd706820ba35a7ce7f656467d79822eeeb11fd789c0658c7fb3e9e3b9a029f6aeb88610d673b1779939b649318a5dd6bdc71bdf5023785bfc9adcf9c61199d5bab8a502c97bb247086186f3882e76cc163565af4de2cac935e2446ab043f8e4a4abd7a318fd8ba745600000000000000000000000000000000000000000000000000000000000000c4e4d27451000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec700000000000000000000000000000000000000000000000000000002551b3075000000000000000000000000868a595fe5f765a753acc4756c4201e013f6edaa000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        uint256[] memory values = new uint256[](1);
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        uint256 userUSDTBalanceDelta = localTokens[0].balanceOf(user);
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        userUSDTBalanceDelta = localTokens[0].balanceOf(user) - userUSDTBalanceDelta;

        assertEq(userUSDTBalanceDelta, 10_017.779829e6, "User should have received ~10,000 USDDT");
    }

    function testBridgingToMainnetETH() external {
        setSourceChainName("linea");
        _createForkAndSetup("LINEA_RPC_URL", 9022390);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        deal(address(boringVault), 101e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory localTokens;
        _addLineaNativeBridgeLeafs(leafs, "mainnet", localTokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "lineaMessageService");

        bytes[] memory targetData = new bytes[](1);
        uint256 fee = 100000000000000;
        targetData[0] = abi.encodeWithSignature("sendMessage(address,uint256,bytes)", boringVault, fee, hex"");

        uint256[] memory values = new uint256[](1);
        values[0] = 100e18 + fee;
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testClaimingFromMainnetETH() external {
        setSourceChainName("linea");
        _createForkAndSetup("LINEA_RPC_URL", 8987665);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        address user = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b;
        // Set boring vault address to be user address so we can claim on their behalf.
        setAddress(true, sourceChain, "boringVault", user);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory localTokens;
        _addLineaNativeBridgeLeafs(leafs, "mainnet", localTokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "lineaMessageService");

        bytes[] memory targetData = new bytes[](1);
        targetData[0] =
            hex"491e09360000000000000000000000000463e60c7ce10e57911ab7bd1667eaa21de3e79b0000000000000000000000000463e60c7ce10e57911ab7bd1667eaa21de3e79b00000000000000000000000000000000000000000000000000000b919b2b84e00000000000000000000000000000000000000000000000000001c6bf52634000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000ab2290000000000000000000000000000000000000000000000000000000000000000";

        uint256[] memory values = new uint256[](1);
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        uint256 userETHBalanceDelta = user.balance;
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        userETHBalanceDelta = user.balance - userETHBalanceDelta;

        assertEq(userETHBalanceDelta, 512720001484000, "User should have received ~0.0005 ETH");
    }

    function testBridgingToMainnetERC20() external {
        setSourceChainName("linea");
        _createForkAndSetup("LINEA_RPC_URL", 9022390);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        deal(getAddress(sourceChain, "DAI"), address(boringVault), 101e18);
        deal(address(boringVault), 1e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory localTokens = new ERC20[](1);
        localTokens[0] = getERC20(sourceChain, "DAI");
        _addLineaNativeBridgeLeafs(leafs, "linea", localTokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[2];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "DAI");
        targets[1] = getAddress(sourceChain, "tokenBridge");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "tokenBridge"), 100e18);
        targetData[1] = abi.encodeWithSignature(
            "bridgeToken(address,uint256,address)", getAddress(sourceChain, "DAI"), 100e18, boringVault
        );
        uint256[] memory values = new uint256[](2);
        values[1] = 0.0001e18;
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testClaimingFromMainnetERC20() external {
        setSourceChainName("linea");
        _createForkAndSetup("LINEA_RPC_URL", 8989040);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        address user = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b;

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory localTokens = new ERC20[](1);
        localTokens[0] = getERC20(sourceChain, "DAI");
        _addLineaNativeBridgeLeafs(leafs, "mainnet", localTokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[3];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "lineaMessageService");

        bytes[] memory targetData = new bytes[](1);
        targetData[0] =
            hex"491e0936000000000000000000000000051f1d88f0af5763fb888ec4378b4d8b29ea3319000000000000000000000000353012dc4a9a6cf55c941badc267f82004a8ceb900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000ab22f00000000000000000000000000000000000000000000000000000000000000c4e4d274510000000000000000000000006b175474e89094c44da98b954eedeac495271d0f0000000000000000000000000000000000000000000000001bc16d674ec800000000000000000000000000000463e60c7ce10e57911ab7bd1667eaa21de3e79b000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
        uint256[] memory values = new uint256[](1);
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        uint256 userDaiBalanceDelta = localTokens[0].balanceOf(user);
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        userDaiBalanceDelta = localTokens[0].balanceOf(user) - userDaiBalanceDelta;

        assertEq(userDaiBalanceDelta, 2e18, "User should have received 2 DAI");
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _createForkAndSetup(string memory rpcKey, uint256 blockNumber) internal {
        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager = new ManagerWithMerkleVerification(address(this), address(boringVault), address(0));

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
        rolesAuthority.setUserRole(address(0), BALANCER_VAULT_ROLE, true);

        // Allow the boring vault to receive ETH.
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);
    }

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
