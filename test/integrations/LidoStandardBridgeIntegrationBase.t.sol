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
    LidoStandardBridgeDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/BridgingDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract LidoStandardBridgeIntegrationBaseTest is Test, MerkleTreeHelper {
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

    function testBridgingWstETHToBase() external {
        setSourceChainName("mainnet");
        _createForkAndSetup("MAINNET_RPC_URL", 20279353);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ERC20 localToken = getERC20(sourceChain, "WSTETH");
        ERC20 remoteToken = getERC20("base", "WSTETH");

        deal(address(localToken), address(boringVault), 101e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addLidoStandardBridgeLeafs(
            leafs,
            "base",
            getAddress("base", "crossDomainMessenger"),
            getAddress(sourceChain, "lidoBaseResolvedDelegate"),
            getAddress(sourceChain, "lidoBaseStandardBridge"),
            getAddress(sourceChain, "lidoBasePortal")
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = address(localToken);
        targets[1] = getAddress(sourceChain, "lidoBaseStandardBridge");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "lidoBaseStandardBridge"), type(uint256).max
        );

        targetData[1] = abi.encodeWithSignature(
            "depositERC20To(address,address,address,uint256,uint32,bytes)",
            localToken,
            remoteToken,
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

    function testBridgingWstETHFromBase() external {
        setSourceChainName("base");
        _createForkAndSetup("BASE_RPC_URL", 16933485);
        setAddress(false, "base", "boringVault", address(boringVault));
        setAddress(false, "base", "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ERC20 localToken = getERC20(sourceChain, "WSTETH");

        deal(address(localToken), address(boringVault), 101e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addLidoStandardBridgeLeafs(
            leafs, "mainnet", address(0), address(0), getAddress(sourceChain, "l2ERC20TokenBridge"), address(0)
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = address(localToken);
        targets[1] = getAddress(sourceChain, "l2ERC20TokenBridge");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "l2ERC20TokenBridge"), type(uint256).max
        );

        targetData[1] = abi.encodeWithSignature(
            "withdrawTo(address,address,uint256,uint32,bytes)", localToken, boringVault, 100e18, 200_000, hex""
        );
        uint256[] memory values = new uint256[](2);
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testProvingWithdrawalTransactionFromBase() external {
        setSourceChainName("mainnet");
        _createForkAndSetup("MAINNET_RPC_URL", 20893217);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addLidoStandardBridgeLeafs(
            leafs,
            "base",
            getAddress("base", "crossDomainMessenger"),
            getAddress(sourceChain, "lidoBaseResolvedDelegate"),
            getAddress(sourceChain, "lidoBaseStandardBridge"),
            getAddress(sourceChain, "lidoBasePortal")
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
            hex"4870496f00000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000002cc600000000000000000000000000000000000000000000000000000000000000009dc296c08f033ae7a1c9babd71c65ac7f1cbdc541f8ad6a36b3271dc4822478bed46571cbd9b789bcf6fba69bf65e74ffbe3bcbba5cf3047207a847716709603c0713650d39aeca558645a393682190100912b07c1ef1af5f01527247abb924800000000000000000000000000000000000000000000000000000000000003e00001000000000000000000000000000000000000000000000000000000017dee0000000000000000000000004200000000000000000000000000000000000007000000000000000000000000866e82a600a1414e583f7f13623f1ac5d58b0afa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007832e00000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000204d764ad0b0001000000000000000000000000000000000000000000000000000000006bb9000000000000000000000000ac9d11cd4d7ef6e54f14643a393f68ca014287ab0000000000000000000000009de443adc5a411e83f1878ef24c3f52c61571e7200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030d4000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000104a9f9e6750000000000000000000000007f39c581f595b53c5cb19bd0b3f8da6c935e2ca0000000000000000000000000c1cba3fcea344f92d9239c08c0568f6f2f0ee4520000000000000000000000000463e60c7ce10e57911ab7bd1667eaa21de3e79b0000000000000000000000000463e60c7ce10e57911ab7bd1667eaa21de3e79b00000000000000000000000000000000000000000000000000005af3107a400000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000b73757065726272696467650000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000005400000000000000000000000000000000000000000000000000000000000000780000000000000000000000000000000000000000000000000000000000000090000000000000000000000000000000000000000000000000000000000000009a00000000000000000000000000000000000000000000000000000000000000214f90211a0b93881d4b03dc2e58b3aa93dd00154bbf311cfb36c2fd99512ef4b6afdc1fc52a0fc0af2570d9d8fb22ad5e68bd949de9bfde500f19353a3155bdfc080a86eb378a04d7827ee28b61c7e39dd1506dc6df86055c853cf19da48f8149c5c85909210d0a052e25b9dabfc3c02fd8a699d0b0b93d871d8aea6b47b02949905fcd7dc1a49dca0467586834e10a2d087333f4e54ce7f130b564e27fbcb8b7c03093af594c8221fa0fa60f605f32361bdcc327e31c67a086b528395e724a3c32afc9640e9e807ad4ca0e1a929621db8c3338e0e309fa175483e2761243c2abe25487c8fd798d8312ac0a0a1ffae25a4060398d2b794596d254c629fd1c906c56cacc7734debca6a40e404a07a198a722b82e895a508aa4fe56d46414e15a6f76807a60c3c9491ce8c23149ba00a592aefc015059c3490e98a4f0570837109b69a24cc512b4a5bcc23f0d5442da0c258b4c7777eaf7cd319d39cb34f4f39934733f4d0eee0843f430a2039dd4131a087c0c1dc0ae391e6b689cd6b87ff223397aab873772cdc173924f43c14580185a0c173bc7357e54a123e1b7f28e15012cf51ceef308b95e9321e817e314724a314a0ec5ff0370251395551e1872222d63323737a51662eb4fff9e63050eddbcfb985a0da03f47c1af4f0268902b2bfa3cb82435740cac45db639955f6211ba0744abcfa065e8b9575e9ab19977f026dde3ec63b5d5c6159394d93cc36f8e3f4b8b676a7b800000000000000000000000000000000000000000000000000000000000000000000000000000000000000214f90211a0ab4e2415a6030fbc7529424f9947635a657177f4b8919eed049e06162c842039a0aef986a4a109317b1f8eba40e418b9014bb31aa8e3a1586a0060f939370ac2eaa0b9a90541e69de71c4c3121eb1bdfe3556382ca3ab1c46bfbfad742c99e35a7f8a0a27be9ef3dcaede87b0cb94e4b429f3d57aee0f962589a4ecc33c7346f4078f2a04f5dcc30ca80f78a988f13f84f1e932f1dcb9a24349831a52a65378d79c168d2a0e7bf19f93fb036fd6165442a09e51a633e9645b6604b1274e22a8f63a25df34ba07cf07267ca106ca8e8277de1ad4495cb798eb6d766d6f63b972447ea07a70d55a0f9e2e4dbb7b0f0ad4ce95bd8af3d0e181b086cef18fea2d285b4be960f78d297a09649ec1c9c867c2b0628cafdee9b53ce18767c8a1fef8c4e1015dde6c98741fca009db7a2fa7cd8f45423f860c3e2cd66c1bc7549791a71cb27fafa0d9adb16757a07b00680929884e5a24e33a27bf5b6ae49082e8a09a2c9e293ea0483fdf99efc0a02252303a1b5cddd49c74cb8b6c8e67c1fa79abd96dd38b0faeead537c9d2f0efa02e29b7f8ee718f7a86cdd59a5810f2473daa4956aa7bcaef663d87207dfccc65a01f52b6bb3250c15ec2d97457265cbc7b5fe9f731e16ef8b4abd931a58be79cbca0166cfd0033a68cdb4e5edc6562ad6c70acbb66a27b014d71fa3c49c94d21c737a01b1cbfee6071f8008c9eaefcde8c4213b3d55839291f9debebec9971c77047d5800000000000000000000000000000000000000000000000000000000000000000000000000000000000000214f90211a0600c0da86f4feb50df1d8038672570afbf0fbca05ce257a9b8df838dca018ddaa0df4df992964b0e29eef229a9616c018ab5f0e930d93cf535cb58230342d3e460a0b80e37b8aaacd11eba3758b789cb7fa80d7236f54be0243a29bf65f0db6b0f6aa030eb8059b099fca521e18bad154340236a114bb37801e8f833e1a8acf5286b24a018e01ebf45816edc25b70806dd9e829d8ca8fe2ebd1b84747d937069c5b35beca03e557f33091205cdc4c31ca272745b0f222172e503faed6d93af7455c34d7943a03f3a513928b361eddbe14d190136dbc83da11662314b208ced94e535e826cbc7a0f99b4cfc1acaf92ffba5388ff647169cbd8ddef87138a7556e508935a7bd20eba0c2ee9b9183edd78e794aacb09a6689e2687779bbd475f5ce18d36c5c4d8a1669a059a83708b4f357a30d60658033e1ca089faa56d1f92a4e1b2e7e725c9c08734ba041b7b51b148852c61dde58843f3443b6c85374bb6e372ae7dcc5cf17fbbfdf05a002edbd18debb2dbb24e198c6cdc920c4e280c20602f1fb1ff7721047da03b4c4a02275cd809d4bfdf3b3d22e932189078d9f43d47f2923c56b364a605561f3f4aca00bcdfadc251c585e2722d814b2a0f3c715dc14b05fc1bbcbe443d9e47d569df7a08084c546f72e01044d9cb0082cadf0fe160a606b1d3a7f37ae900110952f2e23a071dae67d3566f001b570190467a1e8468b23ecfe4e37b26fc73c2d3335afae14800000000000000000000000000000000000000000000000000000000000000000000000000000000000000154f90151a0a2e98d2803be552a8f69ba7413ece092029b0d5f4e1ff6e7e412aafb46fe21aca02f94e87a8cb539729e5086c974349c6031c475f3152f94604812f1aa8e5c8531a0a954348f10f03cfc34821c92cd2d74f23558e5f86f810d8741fcb6da20b9be30a0867a1a0df5eb68aae60e988cf5c2bd6fed49f9c32f977e7ef75f01f511907ae5a0ed3bfecb297d160b57179cc04647fc26e0abf4c283997be3d8eaafaecf4d6686808080a025c4e411447f0ce09dd6c4259496df928decb05db71770f14a39c464ba9d755480a0d2b0bae7e9a578e5f47755e0139eb97840b6f3e0115ebbfccf4d226186766314a0eb873e7a1407d66b4f66504265266f809e1af6d4729010c17cdad313d91dd7f3a0a2f50dc7ecb189661ea0206e6be66731a5212b35757a95e826665fdd7372aaf78080a07f63802e75daa50a7076feacece75bc51966236b07c3cda54b6bc08f22beb8ce800000000000000000000000000000000000000000000000000000000000000000000000000000000000000073f871808080808080808080a06e38ec2036ace1fdec15d10ecc72a3196d1afeac832ed7c530649261588a73ce80a0621676e85dd2652519da24225edec5a7471c841405430312c41623f6fe2566a180a0ac3cf8c8c0f949d8fc32796a4457110aed16f317011e1a4516a24473a3d68872808080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000021e09e31a50a4fd2f1f5f7d8137ff691c83c9f12753b89c8924cda18752e44cd290100000000000000000000000000000000000000000000000000000000000000";

        uint256[] memory values = new uint256[](1);
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // Note we use the exact same test from the StandardBridgeIntegrationBaseTest because withdraw contracts are the SAME.
    // Witht the exception of using the new decoder and leaf creation function.
    function testFinalizingWithdrawalTransactionFromBase() external {
        setSourceChainName("mainnet");
        _createForkAndSetup("MAINNET_RPC_URL", 20279615);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addLidoStandardBridgeLeafs(
            leafs,
            "base",
            getAddress("base", "crossDomainMessenger"),
            getAddress(sourceChain, "lidoBaseResolvedDelegate"),
            getAddress(sourceChain, "lidoBaseStandardBridge"),
            getAddress(sourceChain, "lidoBasePortal")
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[3];

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
