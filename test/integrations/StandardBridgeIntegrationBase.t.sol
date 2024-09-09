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

contract StandardBridgeIntegrationBaseTest is Test, MerkleTreeHelper {
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

    function testBridgingToBaseERC20() external {
        setSourceChainName("mainnet");
        _createForkAndSetup("MAINNET_RPC_URL", 20279353);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 101e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory localTokens = new ERC20[](1);
        localTokens[0] = getERC20(sourceChain, "WETH");
        ERC20[] memory remoteTokens = new ERC20[](1);
        remoteTokens[0] = getERC20("base", "WETH");
        _addStandardBridgeLeafs(
            leafs,
            "base",
            getAddress("base", "crossDomainMessenger"),
            getAddress(sourceChain, "baseResolvedDelegate"),
            getAddress(sourceChain, "baseStandardBridge"),
            getAddress(sourceChain, "basePortal"),
            localTokens,
            remoteTokens
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "baseStandardBridge");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "baseStandardBridge"), type(uint256).max
        );

        targetData[1] = abi.encodeWithSignature(
            "bridgeERC20To(address,address,address,uint256,uint32,bytes)",
            localTokens[0],
            remoteTokens[0],
            boringVault,
            100e18,
            200_000,
            hex""
        );
        uint256[] memory values = new uint256[](2);
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testBridgingToBaseETH() external {
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
            "base",
            getAddress("base", "crossDomainMessenger"),
            getAddress(sourceChain, "baseResolvedDelegate"),
            getAddress(sourceChain, "baseStandardBridge"),
            getAddress(sourceChain, "basePortal"),
            localTokens,
            remoteTokens
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "baseStandardBridge");

        bytes[] memory targetData = new bytes[](1);

        targetData[0] = abi.encodeWithSignature("bridgeETHTo(address,uint32,bytes)", boringVault, 200_000, hex"");
        uint256[] memory values = new uint256[](1);
        values[0] = 100e18;
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testBridgingFromBaseERC20() external {
        setSourceChainName("base");
        _createForkAndSetup("BASE_RPC_URL", 16933485);
        setAddress(false, "base", "boringVault", address(boringVault));
        setAddress(false, "base", "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        deal(getAddress("base", "WETH"), address(boringVault), 101e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory localTokens = new ERC20[](1);
        localTokens[0] = getERC20("base", "WETH");
        ERC20[] memory remoteTokens = new ERC20[](1);
        remoteTokens[0] = getERC20("mainnet", "WETH");
        _addStandardBridgeLeafs(
            leafs,
            "base",
            address(0),
            address(0),
            getAddress("base", "standardBridge"),
            address(0),
            localTokens,
            remoteTokens
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress("base", "WETH");
        targets[1] = getAddress("base", "standardBridge");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress("base", "standardBridge"), type(uint256).max);

        targetData[1] = abi.encodeWithSignature(
            "bridgeERC20To(address,address,address,uint256,uint32,bytes)",
            localTokens[0],
            remoteTokens[0],
            boringVault,
            100e18,
            200_000,
            hex""
        );
        uint256[] memory values = new uint256[](2);
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testBridgingFromBaseETH() external {
        setSourceChainName("base");
        _createForkAndSetup("BASE_RPC_URL", 16933485);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        deal(address(boringVault), 101e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory localTokens;
        ERC20[] memory remoteTokens;
        _addStandardBridgeLeafs(
            leafs,
            "mainnet",
            address(0),
            address(0),
            getAddress(sourceChain, "standardBridge"),
            address(0),
            localTokens,
            remoteTokens
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "standardBridge");

        bytes[] memory targetData = new bytes[](1);

        targetData[0] = abi.encodeWithSignature("bridgeETHTo(address,uint32,bytes)", boringVault, 200_000, hex"");
        uint256[] memory values = new uint256[](1);
        values[0] = 100e18;
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testProvingWithdrawalTransactionFromBase() external {
        setSourceChainName("mainnet");
        _createForkAndSetup("MAINNET_RPC_URL", 20278158);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory localTokens;
        ERC20[] memory remoteTokens;
        _addStandardBridgeLeafs(
            leafs,
            "base",
            getAddress("base", "crossDomainMessenger"),
            getAddress(sourceChain, "baseResolvedDelegate"),
            getAddress(sourceChain, "baseStandardBridge"),
            getAddress(sourceChain, "basePortal"),
            localTokens,
            remoteTokens
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "basePortal");

        bytes[] memory targetData = new bytes[](1);
        targetData[0] =
            hex"4870496f00000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000024b90000000000000000000000000000000000000000000000000000000000000000a5d73cd7ebe94832951b79e4c67d7799791a4ef657e81a731eefcb7ba13ee4c4d8e679069e96a37505de4d5c3ed3450aff65ca569121bea6edc266555fa8729a5c09029e3d8a8a03b14e105071dea827ffb907d121fd4cd0380e2959a8dbe16700000000000000000000000000000000000000000000000000000000000003a000010000000000000000000000000000000000000000000000000000000161350000000000000000000000004200000000000000000000000000000000000007000000000000000000000000866e82a600a1414e583f7f13623f1ac5d58b0afa00000000000000000000000000000000000000000000000000005af3107a40000000000000000000000000000000000000000000000000000000000000077f2e00000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001c4d764ad0b0001000000000000000000000000000000000000000000000000000000004f2700000000000000000000000042000000000000000000000000000000000000100000000000000000000000003154cf16ccdb4c6d922629664174b904d80f2c3500000000000000000000000000000000000000000000000000005af3107a40000000000000000000000000000000000000000000000000000000000000030d4000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000c41635f5fd0000000000000000000000000463e60c7ce10e57911ab7bd1667eaa21de3e79b0000000000000000000000000463e60c7ce10e57911ab7bd1667eaa21de3e79b00000000000000000000000000000000000000000000000000005af3107a40000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000b73757065726272696467650000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000005400000000000000000000000000000000000000000000000000000000000000780000000000000000000000000000000000000000000000000000000000000094000000000000000000000000000000000000000000000000000000000000009c00000000000000000000000000000000000000000000000000000000000000214f90211a077c5f0be8fd555077bb2b2d9cf9d6e9ee93b2848c9429bf181bb308a45ff5515a01b0f64b1ad3d70205796d9eda2f138b4f4f0984c51310166e594dca77917cb43a025720c2513d931b35765c2defb4c802fffc68bb64e1704da8e58d6bf28cea307a02a2359495f91c1f4ba91e53a65b562c782b14d879cff967971cbe85f05c92103a054cf58ce25ea8bc572b21132b49e5d051e3bce6629f1682be1f365781c07f6cda0a9995f54cac14703442341e60f1b4d33c90166d5fc73e040268179639bbe1900a05a51a8e5e5e87e43a15a810fd0a111d87c9901588f1c467cbbde1ee79985a8afa0b3eb51daf3611a515cb18ae980746b4ba053f3b36a5685decfc386fdac571bc3a0752a493026d3ae351828b7a3cad5e4c56ddebe850f24d74edbfa86966d84535ca0fc452b2b66f14761f2fcb5745646a3b34aa7429363908077659c25aac20a3dc6a05f6b6b38024330d11b120a8541f5e5155958ee87e577763cf14376a6ff65934ca01f4ac7fe7e33158343136519bf880f780fb5cab2cf155fad1a42b5539917f0f2a04fab3f6d3d970983cd8d45e762ca0e42e2c874e0c2039bb021b8162145c0eadca0ea9a7745690cb7ffc97894335022ca410e6a1bb81d523c3bafc552c835445714a0815be1df7d3bd2591d60925496c843ad7584bf92ee3e4ca0af3629280811d858a0454facb405e818e0dbbe9b4f2929164f17ccc35754c5851d6532281a929bdf73800000000000000000000000000000000000000000000000000000000000000000000000000000000000000214f90211a00d422f19ed14cab1edb817fbd9474e7fb52716526d7e88cda98769fd204800eda020aba23d1885a9425fcc54877887f883ce52bd51f5cce7df8a75da7a0220914fa05b190ff1e29be958577e6f0962103babb40a5532f0a808817c4cae1cbd6668a2a0327ae8dc776b953f8edfe9086b79d4c2cbce741c5ccabae56cc01e9d70c4db10a070dbb3027c52c417e819841671bc74c448260237769fe6af209fc6f7e4e6436aa02f0cfe805fc1d207aeaad85cf9a59965bb510ac855e8fbe466760f9df9e846daa0f723d23e49b8042763492cf371c49945ec9abdfc716ff775ffa538c725fb8eafa02aa9b593fcbfdb46cbf219c2505aed29e3d13baa438a7dd73394e63afa16e01ea07a92abab74ab48157a96053fc5762c708b5c20ab7455114fdedfef1d192df4f2a0dcdd76f839965d3bf4e758efb234d349ca415a0915094a31bf9503817ce5cdada0033d82df2012b1676be7a61777240df969dde2b4ccbafacd1d29417fd155a56ca033c36a7c28d7fb5751ed79682cffe6cba2b38fb97c548e551d714612b753f9aba0a37f811e7561a1dc3dfdd142975e92f7fe898118183ec4f2e9f693c9543f9014a0392a349215a5189f96bd897b57812de05e8117328e7cd8a60be5e43a4bc0c10da009d47ef156b942b852382b999ebc956b445b9fc8be81d982885c03c67b9b85f0a041d550089adc4c4e8922f162d688eb0d1af7343c136ca6a8c799656a538939f5800000000000000000000000000000000000000000000000000000000000000000000000000000000000000214f90211a0a1479af71114e23558722a777f4f24911c40df666dc800f39c22bf35f5a9b7ada00a434445d9dfa5a6aa0da00a7e61c1e7de3f830243abcd6bf6f373fd4a6b1feaa0850472278241b0a0316ed0f4d021b7995d555c5997a9a9f6369542a1c4d42311a00cd79aa99ac6961a0e5ddc888f8b23ff40f871a79773535427fe6efc597a4a66a0acad8f2874a6cc3f2e85ae37783599dac92bb9704fa12273526d328838b38b5fa0cc9f1a897bf56c2b57feb87e7f6225c5a222b7f2e090a1fa81a775a1d3eca50ca00e5178bf31d9811496653b5d24a020b47943b6b4f6eece82da225ddf63ee8356a05cc86112825d7cadcaa6da51dbf5c7bd78c3b29512dc1e8881175baf9d76cf3aa0e4d4f2878bc677ca379763afe3e4c0bec274fb06fc1b3f5ce63fdfa9a132ac2ea0dc4aee50eb0837c2cd45ee6bb543eaa7f9fd8f5453f8f0d0396c6311553ff1e2a08ef13528e32d515061842016f82d35b4eba9eefe693e6e3cb813c916d358f9ada0d92f3febd6bea499c3c890dc915c986ddf143a6f2f9bc423b7491618b170f89da0d65b4b0b297be851ff4137ba9b8d6fe3dc3d1b63896c7e4355ac9ef02c380d60a02e556d7770ed0ca1b9b606a48489d26bcec735ab3ea21587ad66e50510dc00a5a01edfb33fe6e471a285b293486b632bafbfd80e2834545befa4f5014c38565a0fa0f7e23ed63c6acac30c28c19c314389938230e9fa0713e09e1658918261f2fe81800000000000000000000000000000000000000000000000000000000000000000000000000000000000000194f90191a0675392ec915bb9acfa57899931905b35671ac0e82d4d3f525d07e46e5550611aa0b6facc9b5d1f428122e320b6a9e544536a5307378cf1f99748f6f8f56d79e78f80a00dbb39d950fe3305ac4b04a082a37886a874da51d10c28f6a4c0034103cd610f80a07267bbf87ace9887f8e4d1fefca45ee6cf9d045f4d8fde8c9716f041e58b2152a0ecd2e293a9ceccc259a1e197588d1623d1fafc00061b7bc18a405e96070a4c2fa0bb22a17cbf6d4963f194315c4b1ea3aae6bb8b3c0754b345884140200192df1780a0311f61373e1058e3c5ba2cf5b80f169b0ea5c5c01e85161a00f2dd3b057bdc92a0dc33d84d10fe0bd9a41050cc31cbc9aed4030cf231c141ad74e72825e8ac35e4a066dbb822f47a18ccecf608600f1d3bc3b01bd2b53b2a5270fc55186f4ca5397da04f62e9db67050870794643bf9f4532e19ac197e6a5201ae7dcf992156d01281da0cea493ee91b16c69f8bb63f4961d4e3b4db4f07e5cea2049b64f14253153c7b280a0c62c5061d4d8c5e9ac5a100d43d7e4f571b0638ace5f9ea2278eb66cbd67343e800000000000000000000000000000000000000000000000000000000000000000000000000000000000000053f85180808080808080808080a083f414bfe3189871d242245a8ed70f5a67e3a69d8e6176a2e645db32c9d6d563808080a05de3ae8a761e8347d73b708503f1ed27b7adf1c50a7ca2858a2f4efd2b7f95a28080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000021e09e3b5257568c18358f7d9a4f94c642a8930bdc0eecd4c5e78575fa856d3d020100000000000000000000000000000000000000000000000000000000000000";

        uint256[] memory values = new uint256[](1);
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testFinalizingWithdrawalTransactionFromBase() external {
        setSourceChainName("mainnet");
        _createForkAndSetup("MAINNET_RPC_URL", 20279615);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory localTokens;
        ERC20[] memory remoteTokens;
        _addStandardBridgeLeafs(
            leafs,
            "base",
            getAddress("base", "crossDomainMessenger"),
            getAddress(sourceChain, "baseResolvedDelegate"),
            getAddress(sourceChain, "baseStandardBridge"),
            getAddress(sourceChain, "basePortal"),
            localTokens,
            remoteTokens
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[2];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "basePortal");

        bytes[] memory targetData = new bytes[](1);
        targetData[0] =
            hex"8c3152e900000000000000000000000000000000000000000000000000000000000000200001000000000000000000000000000000000000000000000000000000015daf0000000000000000000000004200000000000000000000000000000000000007000000000000000000000000866e82a600a1414e583f7f13623f1ac5d58b0afa00000000000000000000000000000000000000000000000000d8b72d434c80000000000000000000000000000000000000000000000000000000000000077f2e00000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001c4d764ad0b0001000000000000000000000000000000000000000000000000000000004ba100000000000000000000000042000000000000000000000000000000000000100000000000000000000000003154cf16ccdb4c6d922629664174b904d80f2c3500000000000000000000000000000000000000000000000000d8b72d434c80000000000000000000000000000000000000000000000000000000000000030d4000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000c41635f5fd0000000000000000000000006a9f1e3a3da0fa9858e279df0dbe8890382f3b430000000000000000000000006a9f1e3a3da0fa9858e279df0dbe8890382f3b4300000000000000000000000000000000000000000000000000d8b72d434c80000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000b73757065726272696467650000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        uint256[] memory values = new uint256[](1);
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        address user = 0x6a9f1E3A3dA0fa9858e279df0dBE8890382F3B43;
        uint256 balanceDelta = user.balance;
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        balanceDelta = user.balance - balanceDelta;

        assertEq(balanceDelta, 0.061e18, "User should have received 0.061 ETH");
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
