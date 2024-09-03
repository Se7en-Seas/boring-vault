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

contract StandardBridgeIntegrationZircuitTest is Test, MerkleTreeHelper {
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

    function testBridgingToZircuitETH() external {
        setSourceChainName("mainnet");
        _createForkAndSetup("MAINNET_RPC_URL", 20279353);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        deal(address(boringVault), 101e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory localTokens;
        ERC20[] memory remoteTokens;
        _addStandardBridgeLeafs(
            leafs,
            "zircuit",
            getAddress("zircuit", "crossDomainMessenger"),
            getAddress(sourceChain, "zircuitResolvedDelegate"),
            getAddress(sourceChain, "zircuitStandardBridge"),
            getAddress(sourceChain, "zircuitPortal"),
            localTokens,
            remoteTokens
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "zircuitStandardBridge");

        bytes[] memory targetData = new bytes[](1);

        targetData[0] = abi.encodeWithSignature("bridgeETHTo(address,uint32,bytes)", boringVault, 200_000, hex"");
        uint256[] memory values = new uint256[](1);
        values[0] = 100e18;
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    /// @notice Need an archive node to create the fork, but no majors providers support it atm.
    // function testBridgingFromZircuitETH() external {
    //     setSourceChainName("zircuit");
    //     _createForkAndSetup("ZIRCUIT_RPC_URL", 68627116);
    //     setAddress(false, sourceChain, "boringVault", address(boringVault));
    //     setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
    //     setAddress(false, sourceChain, "managerAddress", address(1));
    //     setAddress(false, sourceChain, "accountantAddress", address(1));

    //     deal(address(boringVault), 101e18);

    //     ManageLeaf[] memory leafs = new ManageLeaf[](8);
    //     ERC20[] memory localTokens;
    //     ERC20[] memory remoteTokens;
    //     _addStandardBridgeLeafs(
    //         leafs,
    //         "mainnet",
    //         address(0),
    //         address(0),
    //         getAddress(sourceChain, "standardBridge"),
    //         address(0),
    //         localTokens,
    //         remoteTokens
    //     );

    //     bytes32[][] memory manageTree = _generateMerkleTree(leafs);

    //     manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

    //     ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
    //     manageLeafs[0] = leafs[2];

    //     bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

    //     address[] memory targets = new address[](1);
    //     targets[0] = getAddress(sourceChain, "standardBridge");

    //     bytes[] memory targetData = new bytes[](1);
    //     targetData[0] = abi.encodeWithSignature("bridgeETHTo(address,uint32,bytes)", boringVault, 200_000, hex"");
    //     uint256[] memory values = new uint256[](1);
    //     values[0] = 100e18;
    //     address[] memory decodersAndSanitizers = new address[](1);
    //     decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

    //     manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    // }

    function testProvingWithdrawalTransactionFromZircuit() external {
        setSourceChainName("mainnet");
        _createForkAndSetup("MAINNET_RPC_URL", 20671840);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory localTokens;
        ERC20[] memory remoteTokens;
        _addStandardBridgeLeafs(
            leafs,
            "zircuit",
            getAddress("zircuit", "crossDomainMessenger"),
            getAddress(sourceChain, "zircuitResolvedDelegate"),
            getAddress(sourceChain, "zircuitStandardBridge"),
            getAddress(sourceChain, "zircuitPortal"),
            localTokens,
            remoteTokens
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "zircuitPortal");

        bytes[] memory targetData = new bytes[](1);
        targetData[0] =
            hex"4870496f00000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000001a68000000000000000000000000000000000000000000000000000000000000000097266f33e6f76f7b1ae6469a851fdbbaac56a7a6bb3615c8e5cd161135b66719441fdb26831712fa18c0de84b0d4140fbc23445d30d2ddc984f8d422ee40cf58bbab96b31c11a37257476d134a8bb27cc6a75ff7f76d2d10e3598f9178baae34000000000000000000000000000000000000000000000000000000000000038000010000000000000000000000000000000000000000000000000000000001ef00000000000000000000000042000000000000000000000000000000000000070000000000000000000000002a721cbe81a128be0f01040e3353c3805a5ea0910000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004638800000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001a4d764ad0b00010000000000000000000000000000000000000000000000000000000001ef0000000000000000000000004200000000000000000000000000000000000010000000000000000000000000386b76d9ca5f5fb150b6bfb35cf5379b22b26dd80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000a41635f5fd0000000000000000000000000463e60c7ce10e57911ab7bd1667eaa21de3e79b0000000000000000000000000463e60c7ce10e57911ab7bd1667eaa21de3e79b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000002c0000000000000000000000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000005a00000000000000000000000000000000000000000000000000000000000000214f90211a0dddcd40e94788ea8b05f85eee884ef58db2dd87b75c0d3e36d729ab135dfc8cda098afe94486023c411083c6f25a7f568541f8b8a13ad19ee32ba95e12af37aecca04f57df61aa21490243e1d9f3787503615cb94810f1f7774361e1ffeb642e024ca0eedaa76b2ca11b80e5c36ea45c800c36339eaab0bcaab0723a9d2909888d07b8a05972fbdcda4033f7182c4306ba82ddc646760db9cc842e860c791ea59f967a24a0a1641ca7495f85fa1ff76fbbea1ebfa9782103292605eb2d8a671bb6e942edfca061159234161cfdd37e0beadd02936ef65624b2b7798c0e9f8542e39025c0ba65a0b835bec76bbe3c0eb21079680b78963dad8a5ca7fbd79df1cf9df4e9de674605a0f4bfa24477e0056a57a0101b10c9f39d3017f6459eb8993641bca01321f0f46ea0daf6fadc7f90c4318efd5846575f7bd977aecdf27a6ea082b9218c03c59db0e3a01660ad6af15e62cdc9a64de53e59f9793e9e85642b2e563dfdf0267f59306891a034c0472bfded6548267e2694ea2d245738f38c8f9fe4cc6346cc9aba89add0e9a0e4947b9e40f1aa0fa22d929a6e4958de1f4f2f9b524eaa9e35e82640e04870c8a0d41795f943f69a4ce9f5484a1e88bca24c370012965d68e8725121d028cfbb82a0974c788570198a34e31c81e89e8063b9309d2bd906a605f9a738d12ba30bafe7a00b11a9cab18a065e0f4982749ff3fbafbeb59d6623be2ef0acdcc8703fcabedd800000000000000000000000000000000000000000000000000000000000000000000000000000000000000214f90211a03af14c05daa028c2527347d3efac5c5977097e18e1827d7ef08a3e728aa3ffe6a00a6d9cabc7a33af6f0a94ea186d228eaaa65f522c37913e46c2c672fb68b6fe3a061f3545a520a8635523ed49aa90a943f5f2220d8c01c412ad845fd37bdd7bad9a07900a4bc859c375db15ca6af40ac94a584f63fa403fe1448f5b72b62ebd66777a0c5a19de529f6b6d7e05c07759c5aa5fafb54a4af8625124f9aa16ae0ae5057c5a055641148519bb6b97572bd952c7029ad0efb345e1dc87860408e8fd9d30fefb3a0d3c26befb907030c3679599f86dd528578252d20d57ded21c2fcab3d5b450a70a00e9bab4edddd2600968870c2c1b0f3aab4cf2c3007b1712cdc5c8b3a2de94a4aa08b76d80ffd54943b89023818362ba280b180d4c51245c18ab547ad079470f29fa059c6dfaa811a14a096e281bc1143ed8ba1d0704080fcf3ddbbb3307a54efd83ca0446ac953b3ad07fae8a4485a936aea7c9ba0e0eb5304f1d28a0c297bb3d1d3eda058437809868ff5f94c52ad41185bdab572548f2c9aaad36403501b7bb1bbb6eba07dcd02b7cff7c43699a40a973a0ba6e064b86c329f4354593555d3d2a3514c14a0c641b31cf391aa8b6a72a492ee9a61516814244f2c452d1c8ac2c61e03c23fafa08a2137b74e6132ba254ea1abcd783468c88710d3dc169baa0aaeac08ad567c02a08d0e86de1fadabb00104bcd21017d00f564cced24abb6457f6f1acf5da71e28e800000000000000000000000000000000000000000000000000000000000000000000000000000000000000073f8718080808080a05435dbb9e647b998d3db63aa8e5f3135abc48eab5cf7b9777fcd58fb64543da480a079999dfbbd000925f4a561a9fc5e708866dffc57d850586f379f8a19401afec480a0337232509617a796b7939a3c6349446c7c43d45bad4dddd8b62e06e7be7c911f80808080808080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000022e19f36e2d71ff427ecffce08c3bcd70448faf204e90df3b510b8c2a9c9acbc06c901000000000000000000000000000000000000000000000000000000000000";

        uint256[] memory values = new uint256[](1);
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testFinalizingWithdrawalTransactionFromZircuit() external {
        setSourceChainName("mainnet");
        _createForkAndSetup("MAINNET_RPC_URL", 20671586);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory localTokens;
        ERC20[] memory remoteTokens;
        _addStandardBridgeLeafs(
            leafs,
            "zircuit",
            getAddress("zircuit", "crossDomainMessenger"),
            getAddress(sourceChain, "zircuitResolvedDelegate"),
            getAddress(sourceChain, "zircuitStandardBridge"),
            getAddress(sourceChain, "zircuitPortal"),
            localTokens,
            remoteTokens
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[2];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "zircuitPortal");

        bytes[] memory targetData = new bytes[](1);
        targetData[0] =
            hex"8c3152e9000000000000000000000000000000000000000000000000000000000000002000010000000000000000000000000000000000000000000000000000000001e200000000000000000000000042000000000000000000000000000000000000070000000000000000000000002a721cbe81a128be0f01040e3353c3805a5ea09100000000000000000000000000000000000000000000000000597e2be9e46000000000000000000000000000000000000000000000000000000000000004638800000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001a4d764ad0b00010000000000000000000000000000000000000000000000000000000001e20000000000000000000000004200000000000000000000000000000000000010000000000000000000000000386b76d9ca5f5fb150b6bfb35cf5379b22b26dd800000000000000000000000000000000000000000000000000597e2be9e46000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000a41635f5fd000000000000000000000000db2dcad7c06376c4f65c4bc3441316d738c7d864000000000000000000000000db2dcad7c06376c4f65c4bc3441316d738c7d86400000000000000000000000000000000000000000000000000597e2be9e46000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        uint256[] memory values = new uint256[](1);
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        address user = 0xdB2dcaD7C06376C4F65C4bC3441316D738C7D864;
        uint256 balanceDelta = user.balance;
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        balanceDelta = user.balance - balanceDelta;

        assertEq(balanceDelta, 0.02519e18, "User should have received ~0.025 ETH");
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
