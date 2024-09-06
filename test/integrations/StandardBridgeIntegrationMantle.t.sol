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

contract StandardBridgeIntegrationMantleTest is Test, MerkleTreeHelper {
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

    function testBridgingToMantleERC20() external {
        setSourceChainName("mainnet");
        _createForkAndSetup("MAINNET_RPC_URL", 20279353);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        deal(getAddress(sourceChain, "METH"), address(boringVault), 101e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory localTokens = new ERC20[](1);
        localTokens[0] = getERC20(sourceChain, "METH");
        ERC20[] memory remoteTokens = new ERC20[](1);
        remoteTokens[0] = getERC20("mantle", "METH");
        _addStandardBridgeLeafs(
            leafs,
            "mantle",
            getAddress("mantle", "crossDomainMessenger"),
            getAddress(sourceChain, "mantleResolvedDelegate"),
            getAddress(sourceChain, "mantleStandardBridge"),
            getAddress(sourceChain, "mantlePortal"),
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
        targets[0] = getAddress(sourceChain, "METH");
        targets[1] = getAddress(sourceChain, "mantleStandardBridge");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "mantleStandardBridge"), type(uint256).max
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

    function testBridgingToMantleETH() external {
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
            "mantle",
            getAddress("mantle", "crossDomainMessenger"),
            getAddress(sourceChain, "mantleResolvedDelegate"),
            getAddress(sourceChain, "mantleStandardBridge"),
            getAddress(sourceChain, "mantlePortal"),
            localTokens,
            remoteTokens
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "mantleStandardBridge");

        bytes[] memory targetData = new bytes[](1);

        targetData[0] = abi.encodeWithSignature("bridgeETHTo(address,uint32,bytes)", boringVault, 200_000, hex"");
        uint256[] memory values = new uint256[](1);
        values[0] = 100e18;
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testBridgingFromMantleERC20() external {
        setSourceChainName("mantle");
        _createForkAndSetup("MANTLE_RPC_URL", 68627116);
        setAddress(false, "mantle", "boringVault", address(boringVault));
        setAddress(false, "mantle", "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        deal(getAddress("mantle", "USDC"), address(boringVault), 101e6);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory localTokens = new ERC20[](1);
        localTokens[0] = getERC20("mantle", "USDC");
        ERC20[] memory remoteTokens = new ERC20[](1);
        remoteTokens[0] = getERC20("mainnet", "USDC");
        _addStandardBridgeLeafs(
            leafs,
            "mantle",
            address(0),
            address(0),
            getAddress("mantle", "standardBridge"),
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
        targets[0] = getAddress("mantle", "USDC");
        targets[1] = getAddress("mantle", "standardBridge");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress("mantle", "standardBridge"), type(uint256).max
        );

        targetData[1] = abi.encodeWithSignature(
            "bridgeERC20To(address,address,address,uint256,uint32,bytes)",
            localTokens[0],
            remoteTokens[0],
            boringVault,
            100e6,
            200_000,
            hex""
        );
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](2)
        );
    }

    function testBridgingFromMantleETH() external {
        setSourceChainName("mantle");
        _createForkAndSetup("MANTLE_RPC_URL", 68627116);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "managerAddress", address(1));
        setAddress(false, sourceChain, "accountantAddress", address(1));

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 101e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory localTokens = new ERC20[](1);
        localTokens[0] = getERC20(sourceChain, "WETH");
        ERC20[] memory remoteTokens = new ERC20[](1);
        remoteTokens[0] = getERC20("mainnet", "WETH");
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

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[2];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "standardBridge");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "standardBridge"), type(uint256).max
        );

        targetData[1] =
            abi.encodeWithSignature("bridgeETHTo(uint256,address,uint32,bytes)", 100e18, boringVault, 200_000, hex"");
        uint256[] memory values = new uint256[](2);
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testProvingWithdrawalTransactionFromMantle() external {
        setSourceChainName("mainnet");
        _createForkAndSetup("MAINNET_RPC_URL", 20671587);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory localTokens;
        ERC20[] memory remoteTokens;
        _addStandardBridgeLeafs(
            leafs,
            "mantle",
            getAddress("mantle", "crossDomainMessenger"),
            getAddress(sourceChain, "mantleResolvedDelegate"),
            getAddress(sourceChain, "mantleStandardBridge"),
            getAddress(sourceChain, "mantlePortal"),
            localTokens,
            remoteTokens
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "mantlePortal");

        bytes[] memory targetData = new bytes[](1);
        targetData[0] =
            hex"d69b2b1b00000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000102c0000000000000000000000000000000000000000000000000000000000000000b4fcd768d2fc8916c51b2f341664cc5481fcc3b459bb2217267d09fe08fc4328cc6cb4cfbe2e1693e7c84ac2485a0db35610d393a92e32f5348da9065530f2ba06555d32c0620dc45bfb5590d7f604a57848cf2b0835593a5ec45b632ccf34e300000000000000000000000000000000000000000000000000000000000003c00001000000000000000000000000000000000000000000000000000000000bb70000000000000000000000004200000000000000000000000000000000000007000000000000000000000000676a795fe6e43c17c668de16730c3f690feb7120000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000038d7ea4c68000000000000000000000000000000000000000000000000000000000000005ee9000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001c4ff8daf150001000000000000000000000000000000000000000000000000000000000bb7000000000000000000000000420000000000000000000000000000000000001000000000000000000000000095fc37a27a2f68e3a647cdc081f0a89bb47c3012000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000038d7ea4c68000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000a41635f5fd0000000000000000000000000463e60c7ce10e57911ab7bd1667eaa21de3e79b0000000000000000000000000463e60c7ce10e57911ab7bd1667eaa21de3e79b00000000000000000000000000000000000000000000000000038d7ea4c68000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000700000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000056000000000000000000000000000000000000000000000000000000000000007a000000000000000000000000000000000000000000000000000000000000009e00000000000000000000000000000000000000000000000000000000000000b600000000000000000000000000000000000000000000000000000000000000be00000000000000000000000000000000000000000000000000000000000000214f90211a0bb3af9f3715d354f1ac25020fc5c11ca6e923b2fa3db4f2bac83f279ce49395aa0927d7d8a743dc7c031d8ea01457616d917f88e9749d77f3771990d749aef4092a078cd21d0923048317fb5275c2491e8d304e31be6fe6e02e0d7b45b1847e24a27a074069cff21249d1e5fb384d0a8684f8533b054a4d7dee847df14c077b714e3fca0fa002cf586bd86ca75884f687a252d8fbba6b4a6bf409ee2107d97d8f490451ca0802ebd5fa6da43f00b8f7e10cacde44319adae439b858ac4d414e994f20fb0fca0ff7c0d1a801ab5247bd6183ab0af5d49acc438d9e8910ef6311e09bf0d09092da0d2a1aa8c477cd4e4198fbe403a6a62053643aa17778a099128304ac0101a99f9a0b83afeedb7dede912e96112fb558ee4aff94d709a0af2c09cda2da3d1ae46c77a045a5e68b218829a4e585291e7b23ec5ea36dd6a2650abc1813d0eef3dbb1c65fa05c472efdf301e7619d3b5897aa34e683806a76d0b256bedf12e911987eb46314a014c75ec9f367dffaa0740301decff218b1525b84c4e3d2d29e7ba93181b1fa77a0003434545bc6c2c0d663c9b9575f0d0574051815f9b8e3e3ceb5b60dea62230aa02c881a1d28dc49fcebc0a466820ac1fabb70c82b977d99e3380667c13da4f2fda0ac5e05435439d02c14b072aeca6ed63e82da7409afe96369bcbbc202f2e0eb68a0f8275031baabfed7a15c019f61f9163bbe1f03c11235dd9cf59465d9ddc76b95800000000000000000000000000000000000000000000000000000000000000000000000000000000000000214f90211a077f71b4abe641071a4e4b2e69f9a2448d2a983fbad00ff2da7316acc03075fc0a06a1bebe0375a3962255702105d6953bb70e824fd5e3d289339002d8eddf46c63a05b5fb2ec984d3e98e8bbd182ac726c1c6c4026043359ec75e56e0d272179b482a092c25286a598ac66cdb87b9719158286b73761ba708b62603721d2fdb2d70977a0e1da96a2b0eead4e20159251a2c75820fb70630ad8ec1d2ddea0d7311d3fbfcba0149d99167e0118b12f5700ae3f139402e3cff0818163756fe18fcc0d22fc7560a0ddc75cf79a7ecd144be44c959b1e8bcb05889ac07a2115f0b3ca24020dd82dfca0de3d9182274e82b693291646385ab929157e06ca06eb2b84312186dccc7196bfa0779a42d741ed059d7b3d655803958064b9c3f98b7e8fe51467dc54cf1067b564a0f3203aaed403fa2145c87145e427f11c009c4ae5519724c3bdc80cca371fa85fa090e64ca1d176f338dcb0de05bda7dd6ff3a7d89fba6011880651087feaa9c17ea07dc9112dc83ab4accd455b0431b52c2bef22c645757e26b57f56ad809962b150a0c1e75025b12e2eae9f6fff320c567b01511032aa66fb173a0224bb007f354b6fa065e056197f21e4e1a4d93c0d33f0f9d67be1ec8125510d07d4b0a8612124ebe5a08cd5e39e83fcc9617ce3cb75975e248396fd653855c3e68561916cfab6ad887ca0296177b926e3c37dbd2c56253e44827f63040c6961196581ae19c8c1ee6bbfb6800000000000000000000000000000000000000000000000000000000000000000000000000000000000000214f90211a0f66ceb6cefc0fcdf5668b989b65d6a5736fb2c95341653946140dfb96fda602da09c1f944fa98d5348f9bc5c1a410a33762491d1815ad9eed14372779beb5b054ea00b9a9a5fd87fde810b8cf4f370954059f59b6aa4a5ba8536d4ed66a8a5345549a05a98d9425aae89158537a0f0670b486068fcd5da156efe2a39791862d4c621d2a0ce944589768d53cdeea35c3ffb8ff9d620d64c8286f53cfe8bac46e258b46211a04d8c9e9c3c4792d172e93bcda0cf65b8490ca0dee8438f21130b5ba0698f95dea07f83d61f3cac6591f0a4678dff2ca86e09efe987ef5db266e07fb07573f12965a0edefaa1063201d8f8b179223e4ae0213b91ec360cd5fb33946676778fbe960d6a0ea225cb0921d687e79b3ded2c7a7dfd1aa414757c8e5db9ce310f52fc7b490b5a0f21e6e16f6f8a48e8dc523d29c2d51fd0ea1ee24b47f904e7190e1f57a43d50aa055fad1a48b77a796fa7aebf5f999085da83d4aef7dfa6aeaa2fef06824cb8d0ba075cf086692c76a9451cbf55ffedf3f65998ad1a293bd50fb34fbf2e393660fc6a0bfa41a09e3244f04fd1fe23566f7a233b27d790d63e56b781692c94c05929f57a09d0dd7fa9bfbf7283757b7ba97a4c3f93c0687d4849acb8172c9d9734d50d7a6a054a0fa7e40df3d5c335793922d83bc7553665c333404f6837cbc57312750e5cca0d58e304b96c7a94af780965e6313b17a27c9eedd3eb229ac4e8aa6036c12d2ba800000000000000000000000000000000000000000000000000000000000000000000000000000000000000214f90211a00bc6756a7484ab4ef99557c14f3f6a2408eeab79ab292acc2fa2bec52305848ea0f230df39e9ffcc63bf87aa4410b78f9f8b99ef2a4f3ef92c6577a7ba563d16d9a00cb5f36ce398970c92965db83dfae1623882e67d175e3502680c94f2aab64ea2a0e7b99dd0ff3f590ddf5bc9873b1eb7f0ca45341e07bb8f86b6fc0ff86d677daca08c6c0fd21695467513fea24cb363dc63493affe6f85c1fbad3663d42f4e18dbaa0d7f9e750e6f2ce4bef9cdb63ab89254b55caec65dcb641ede194a6973d35c86fa07cca7464836648ab37f1a5b83c508feebf72ea604cddad8c42128f97a2136dd8a093c1519e3987dec42dac5b81ee7a4a709aca3ac710b582fcd982db4a7df85d1ca0a533f62e286b5c9554075f56b4322b5ccc4f467866db12a6a261fdccd923ef37a0ce4ac7ee853aacd34f3cbbb687c660a6cde20b1830b00a35c820ab709f198e8ba0feb95851a9334e5ac0fa6deb7017faba63a9321a5d924c97f1e6daf1ae2647a0a0278a19ed9c2fe448c2fe662a5928db0c2fdcf061d67a515a46a49e1afab98e70a016a6b6d321b029c7ba3429399e99f9fe88a5e976eda7430cb601f7fcfdf3b043a0ae4d12dcce0df0eea6af36252d7365a3139e8cc0741a31d225aac7f0c4e957dea09ba8238f246f38e437514766fbea5dafb2d0a864836fcc925260c888949b7c32a00a7ab6a9b82b71518f4de80fe69bf3c595ae5c7fb24342991ba3ea69d0187529800000000000000000000000000000000000000000000000000000000000000000000000000000000000000154f9015180a003a85900e18b3c46544f35d39711ed32b49eef5d296e426dcc5385656f99e883a00676277b10aad4d493b82d69c555615728bc369211562a1dca48d138c15a7da7a038b37222de5b5a0602061618054ef29eec4116aef470c1d4a7dfdaec996bf37ca01dcb2b528e3cf10b8c5536da0be5cc0529e28686537ce4474304a3eb258e693fa0ef55ec79e084c57d70b52b2e0b0339a319b8a3f1b44adea1d347840d8526acf980a0dbb770ed488d2a1669e6d09b7fa827f913769094207f9a133023a71c5acc94d08080a0f7fa360ece4cc18e9857d019a2133e0803493037cda75129ab15c9c06922893280a00c4778f0182c08762f63d6ae00f233e5c163233028818b6f877c1691c27d945da0eb15ad5f25ae15ea7a0bbbb6c256ca7f4d4236a0cc8f84475879cfa0c4eb2de2a0c644e8bfd3b56224315ecc9b41a5801eabced39f0ef2d090eec1460e9d1759cb80800000000000000000000000000000000000000000000000000000000000000000000000000000000000000053f8518080808080808080808080a0b10dd64fac01bc4392887743fed15902502480336b3415ef20ca49f17a10f21780a06f811f1ea4edfdd77b6c52fc7dd3c8782696c139ea48a5631399d1da81c16fec808080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000021e09e20e82c3b4e79782a7c902059255926760c4f7a4aceacf7e4bba6a22183720100000000000000000000000000000000000000000000000000000000000000";

        uint256[] memory values = new uint256[](1);
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testFinalizingWithdrawalTransactionFromMantle() external {
        setSourceChainName("mainnet");
        _createForkAndSetup("MAINNET_RPC_URL", 20671049);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory localTokens;
        ERC20[] memory remoteTokens;
        _addStandardBridgeLeafs(
            leafs,
            "mantle",
            getAddress("mantle", "crossDomainMessenger"),
            getAddress(sourceChain, "mantleResolvedDelegate"),
            getAddress(sourceChain, "mantleStandardBridge"),
            getAddress(sourceChain, "mantlePortal"),
            localTokens,
            remoteTokens
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[2];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "mantlePortal");

        bytes[] memory targetData = new bytes[](1);
        targetData[0] =
            hex"2e71d4a40000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000006a6a70000000000000000000000004200000000000000000000000000000000000007000000000000000000000000676a795fe6e43c17c668de16730c3f690feb7120000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e1cc30dd1c1800000000000000000000000000000000000000000000000000000000000013f5c900000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001c4ff8daf15000000000000000000000000000000000000000000000000000000000006a6a7000000000000000000000000420000000000000000000000000000000000001000000000000000000000000095fc37a27a2f68e3a647cdc081f0a89bb47c3012000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e1cc30dd1c1800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000a41532ec3400000000000000000000000060ac6110947d66ada909b9881ed7368bace6066d00000000000000000000000060ac6110947d66ada909b9881ed7368bace6066d00000000000000000000000000000000000000000000000000e1cc30dd1c1800000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        uint256[] memory values = new uint256[](1);
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        address user = 0x60Ac6110947d66aDa909B9881ED7368BACe6066d;
        uint256 balanceDelta = user.balance;
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        balanceDelta = user.balance - balanceDelta;

        assertEq(balanceDelta, 0.06355638e18, "User should have received ~0.063 ETH");
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
