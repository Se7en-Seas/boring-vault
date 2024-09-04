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

contract ScrollBridgeIntegrationTest is Test, MerkleTreeHelper {
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

    function testBridgingToScrollETH() external {
        setSourceChainName("mainnet");
        _createForkAndSetup("MAINNET_RPC_URL", 20279353);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        deal(address(boringVault), 101e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory localTokens;
        _addScrollNativeBridgeLeafs(leafs, "scroll", localTokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "scrollMessenger");

        bytes[] memory targetData = new bytes[](1);

        targetData[0] =
            abi.encodeWithSignature("sendMessage(address,uint256,bytes,uint256)", boringVault, 100e18, hex"", 168_000);
        uint256[] memory values = new uint256[](1);
        values[0] = 100.01e18;
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testClaimingFromScrollETH() external {
        setSourceChainName("mainnet");
        _createForkAndSetup("MAINNET_RPC_URL", 20678804);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        address user = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b;
        // Set boring vault address to be user address so we can claim on their behalf.
        setAddress(true, sourceChain, "boringVault", user);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory localTokens;
        _addScrollNativeBridgeLeafs(leafs, "scroll", localTokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "scrollMessenger");

        bytes[] memory targetData = new bytes[](1);
        targetData[0] =
            hex"c311b6fc0000000000000000000000000463e60c7ce10e57911ab7bd1667eaa21de3e79b0000000000000000000000000463e60c7ce10e57911ab7bd1667eaa21de3e79b0000000000000000000000000000000000000000000000000011c37937e080000000000000000000000000000000000000000000000000000000000000029f3200000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004cbad000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000002404f8fd76bde615ad7b189bbc83ab74928b94aca719837a84c75a1448c02e818ee5c796c22021daa49f5b617717385cee7c1dba3cab425e9351843580d17b3d0de1198b396da7013cb81eb13d4cf47ba9020634b00efe80b4f16d5b2df27b51480ee42428fc96e9f3356c5b15349a353d1581385699be140e38d6b3f0433d3cf7e0b025acdb81c0bd17c1a11f2c15924356be689bf6fa588da0675ba62066357ae1feaf91e82c8d24fc3942a367ab92c07225811e82a59a4dde998ad6eba3608ba887c22bd8750d34016ac3c66b5ff102dacdd73f6b014e710b51e8022af9a1968ffd70157e48063fc33c97a050f7f640233bf646cc98d9524c6b92bcf3ab56f8346003e8aadcfdf97b73204cc0cdcbda60267939dfe9a3772686d8d0cba8db50d5d2b8ecc2855a118351f655006cbb595aaa743745d5a1991a0a51a4b8d786db39ac3d5cf1f6e81389da326a94735554e7bb39522a49d7eac4a27ef133277392d25ea01eda7e0b89fbe3876bb4a2473c59821d325c43bee53ca3b04e24e2d96d09bfaaecfb97aa9f700b94a55f08ce7ee796b1d982685784fd263db24e2ccf8e9c1df82d9c4b87413eae2ef048f94b4d3554cea73d92b0f7af96e0271c691e2bb5c67add7c6caf302256adedf7ab114da0acfe870d449a3a489f781d659e8becc88fd29d4629534ddaf0aa9400efac1e01e3754ecba17fc050fb30a9993d4d7992733e50f526ec2fa19a22b31e8ed50f23cd1fdf94c9154ed3a7609a2f1ff981f52e25d1e9ce7d1acb85caba116b8ea68633ca77967016b316f606f74d55061e0";

        uint256[] memory values = new uint256[](1);
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        uint256 userETHBalanceDelta = user.balance;
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        userETHBalanceDelta = user.balance - userETHBalanceDelta;
        assertEq(userETHBalanceDelta, 0.005e18, "User should have received 0.005 ETH");
    }

    function testBridgingToScrollERC20() external {
        setSourceChainName("mainnet");
        _createForkAndSetup("MAINNET_RPC_URL", 20279353);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        deal(getAddress(sourceChain, "DAI"), address(boringVault), 101e18);
        deal(address(boringVault), 1e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory localTokens = new ERC20[](1);
        localTokens[0] = getERC20(sourceChain, "DAI");
        _addScrollNativeBridgeLeafs(leafs, "scroll", localTokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[1];
        manageLeafs[1] = leafs[2];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "DAI");
        targets[1] = getAddress(sourceChain, "scrollGatewayRouter");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "scrollGatewayRouter"), 100e18);
        targetData[1] = abi.encodeWithSignature(
            "depositERC20(address,address,uint256,uint256)", getAddress(sourceChain, "DAI"), boringVault, 100e18, 180000
        );
        uint256[] memory values = new uint256[](2);
        values[1] = 0.0001e18;
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testClaimingFromScrollERC20() external {
        setSourceChainName("mainnet");
        _createForkAndSetup("MAINNET_RPC_URL", 20678805);
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "accountantAddress", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "managerAddress", rawDataDecoderAndSanitizer);

        address user = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b;

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory localTokens = new ERC20[](1);
        localTokens[0] = getERC20(sourceChain, "DAI");
        _addScrollNativeBridgeLeafs(leafs, "scroll", localTokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[4];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "scrollMessenger");

        bytes[] memory targetData = new bytes[](1);
        targetData[0] =
            hex"c311b6fc000000000000000000000000ac78dff3a87b5b534e366a93e785a0ce8fa6cc6200000000000000000000000067260a8b73c5b77b55c1805218a42a7a6f98f51500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000029f3000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001e000000000000000000000000000000000000000000000000000000000000000e484bd13b00000000000000000000000006b175474e89094c44da98b954eedeac495271d0f000000000000000000000000ca77eb3fefe3725dc33bccb54edefc3d9f764f970000000000000000000000000463e60c7ce10e57911ab7bd1667eaa21de3e79b0000000000000000000000000463e60c7ce10e57911ab7bd1667eaa21de3e79b0000000000000000000000000000000000000000000000001bbf8e3156425d8f00000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004cbad0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000024056d96488ab8604e03c935b2f88a63210207234e7b33d7110e7e8cd0c230fe488949bedba3b345f4117f027043a3bda7851aa58edf4317e8c4e92904c29274a471198b396da7013cb81eb13d4cf47ba9020634b00efe80b4f16d5b2df27b51480ee42428fc96e9f3356c5b15349a353d1581385699be140e38d6b3f0433d3cf7e0b025acdb81c0bd17c1a11f2c15924356be689bf6fa588da0675ba62066357ae1feaf91e82c8d24fc3942a367ab92c07225811e82a59a4dde998ad6eba3608ba887c22bd8750d34016ac3c66b5ff102dacdd73f6b014e710b51e8022af9a1968ffd70157e48063fc33c97a050f7f640233bf646cc98d9524c6b92bcf3ab56f8346003e8aadcfdf97b73204cc0cdcbda60267939dfe9a3772686d8d0cba8db50d5d2b8ecc2855a118351f655006cbb595aaa743745d5a1991a0a51a4b8d786db39ac3d5cf1f6e81389da326a94735554e7bb39522a49d7eac4a27ef133277392d25ea01eda7e0b89fbe3876bb4a2473c59821d325c43bee53ca3b04e24e2d96d09bfaaecfb97aa9f700b94a55f08ce7ee796b1d982685784fd263db24e2ccf8e9c1df82d9c4b87413eae2ef048f94b4d3554cea73d92b0f7af96e0271c691e2bb5c67add7c6caf302256adedf7ab114da0acfe870d449a3a489f781d659e8becc88fd29d4629534ddaf0aa9400efac1e01e3754ecba17fc050fb30a9993d4d7992733e50f526ec2fa19a22b31e8ed50f23cd1fdf94c9154ed3a7609a2f1ff981f52e25d1e9ce7d1acb85caba116b8ea68633ca77967016b316f606f74d55061e0";

        uint256[] memory values = new uint256[](1);
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        uint256 userDAIBalanceDelta = localTokens[0].balanceOf(user);
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        userDAIBalanceDelta = localTokens[0].balanceOf(user) - userDAIBalanceDelta;

        assertEq(userDAIBalanceDelta, 1.999473102127521167e18, "User should have received ~2 DAI");
    }

    // function testBridgingToMainnetETH() external {
    //     setSourceChainName("scroll");
    //     _createForkAndSetup("SCROLL_RPC_URL", 9022390);
    //     setAddress(false, sourceChain, "boringVault", address(boringVault));
    //     setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

    //     deal(address(boringVault), 101e18);

    //     ManageLeaf[] memory leafs = new ManageLeaf[](8);
    //     ERC20[] memory localTokens;
    //     _addScrollNativeBridgeLeafs(leafs, "mainnet", localTokens);

    //     bytes32[][] memory manageTree = _generateMerkleTree(leafs);

    //     manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

    //     ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
    //     manageLeafs[0] = leafs[0];

    //     bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

    //     address[] memory targets = new address[](1);
    //     targets[0] = getAddress(sourceChain, "scrollMessenger");

    //     bytes[] memory targetData = new bytes[](1);
    //     targetData[0] =
    //         abi.encodeWithSignature("sendMessage(address,uint256,bytes,uint256)", boringVault, 100e18, hex"", 0);
    //     uint256[] memory values = new uint256[](1);
    //     values[0] = 100e18;
    //     address[] memory decodersAndSanitizers = new address[](1);
    //     decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

    //     manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    // }

    // function testBridgingToMainnetERC20() external {
    //     setSourceChainName("scroll");
    //     _createForkAndSetup("SCROLL_RPC_URL", 9022390);
    //     setAddress(false, sourceChain, "boringVault", address(boringVault));
    //     setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

    //     deal(getAddress(sourceChain, "DAI"), address(boringVault), 101e18);
    //     deal(address(boringVault), 1e18);

    //     ManageLeaf[] memory leafs = new ManageLeaf[](8);
    //     ERC20[] memory localTokens = new ERC20[](1);
    //     localTokens[0] = getERC20(sourceChain, "DAI");
    //     _addScrollNativeBridgeLeafs(leafs, "scroll", localTokens);

    //     bytes32[][] memory manageTree = _generateMerkleTree(leafs);

    //     manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

    //     ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
    //     manageLeafs[0] = leafs[0];
    //     manageLeafs[1] = leafs[1];

    //     bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

    //     address[] memory targets = new address[](2);
    //     targets[0] = getAddress(sourceChain, "DAI");
    //     targets[1] = getAddress(sourceChain, "scrollGatewayRouter");

    //     bytes[] memory targetData = new bytes[](2);
    //     targetData[0] =
    //         abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "scrollGatewayRouter"), 100e18);
    //     targetData[1] = abi.encodeWithSignature(
    //         "withdrawERC20(address,address,uint256,uint256)", getAddress(sourceChain, "DAI"), boringVault, 100e18, 0
    //     );
    //     uint256[] memory values = new uint256[](2);
    //     address[] memory decodersAndSanitizers = new address[](2);
    //     decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
    //     decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

    //     manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    // }

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
