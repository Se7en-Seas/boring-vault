// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {StakingDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/StakingDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract StakingIntegrationsTest is Test, MerkleTreeHelper {
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

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        // uint256 blockNumber = 19369928;
        uint256 blockNumber = 19826676;
        // uint256 blockNumber = 20036275;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new StakingDecoderAndSanitizer(address(boringVault)));

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(1));

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

    function testEtherFiIntegration() external {
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 100e18);

        // unwrap weth
        // mint eETH
        // wrap eETH
        // unwrap weETH
        // unstaking eETH
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addNativeLeafs(leafs);
        _addEtherFiLeafs(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](7);
        manageLeafs[0] = leafs[1];
        manageLeafs[1] = leafs[4];
        manageLeafs[2] = leafs[2];
        manageLeafs[3] = leafs[7];
        manageLeafs[4] = leafs[8];
        manageLeafs[5] = leafs[3];
        manageLeafs[6] = leafs[5];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](7);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "EETH_LIQUIDITY_POOL");
        targets[2] = getAddress(sourceChain, "EETH");
        targets[3] = getAddress(sourceChain, "WEETH");
        targets[4] = getAddress(sourceChain, "WEETH");
        targets[5] = getAddress(sourceChain, "EETH");
        targets[6] = getAddress(sourceChain, "EETH_LIQUIDITY_POOL");

        bytes[] memory targetData = new bytes[](7);
        targetData[0] = abi.encodeWithSignature("withdraw(uint256)", 100e18);
        targetData[1] = abi.encodeWithSignature("deposit()");
        targetData[2] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "WEETH"), type(uint256).max);
        targetData[3] = abi.encodeWithSignature("wrap(uint256)", 100e18 - 1);
        uint256 weETHAmount = 96346539735660261219;
        targetData[4] = abi.encodeWithSignature("unwrap(uint256)", weETHAmount);
        targetData[5] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "EETH_LIQUIDITY_POOL"), type(uint256).max
        );
        targetData[6] = abi.encodeWithSignature("requestWithdraw(address,uint256)", address(boringVault), 100e18 - 2);
        uint256[] memory values = new uint256[](7);
        values[1] = 100e18;
        address[] memory decodersAndSanitizers = new address[](7);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        uint256 withdrawRequestId = 17743;

        _finalizeRequest(withdrawRequestId, 100e18 - 2);

        manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[6];
        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](1);
        targets[0] = getAddress(sourceChain, "withdrawalRequestNft");

        targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature("claimWithdraw(uint256)", withdrawRequestId);
        values = new uint256[](1);

        decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testLidoIntegration() external {
        deal(address(boringVault), 1_000e18);

        // Call submit
        // call approve
        // wrap it
        // unwrap it
        // Request a withdrawal
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addLidoLeafs(leafs);
        // leafs[5] = ManageLeaf(unstETH, false, "requestWithdrawals(uint256[],address)", new address[](1));
        // leafs[5].argumentAddresses[0] = address(boringVault);
        // leafs[6] = ManageLeaf(unstETH, false, "claimWithdrawal(uint256)", new address[](0));
        // leafs[7] = ManageLeaf(unstETH, false, "claimWithdrawals(uint256[],uint256[])", new address[](0));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](6);
        manageLeafs[0] = leafs[2];
        manageLeafs[1] = leafs[0];
        manageLeafs[2] = leafs[6];
        manageLeafs[3] = leafs[7];
        manageLeafs[4] = leafs[1];
        manageLeafs[5] = leafs[3];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](6);
        targets[0] = getAddress(sourceChain, "STETH");
        targets[1] = getAddress(sourceChain, "STETH");
        targets[2] = getAddress(sourceChain, "WSTETH");
        targets[3] = getAddress(sourceChain, "WSTETH");
        targets[4] = getAddress(sourceChain, "STETH");
        targets[5] = getAddress(sourceChain, "unstETH");

        bytes[] memory targetData = new bytes[](6);
        targetData[0] = abi.encodeWithSignature("submit(address)", address(0));
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "WSTETH"), type(uint256).max);
        targetData[2] = abi.encodeWithSignature("wrap(uint256)", 100e18);
        targetData[3] = abi.encodeWithSignature("unwrap(uint256)", 10e18);
        targetData[4] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "unstETH"), type(uint256).max);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100e18;
        amounts[1] = 100e18;
        amounts[2] = 100e18;
        targetData[5] = abi.encodeWithSignature("requestWithdrawals(uint256[],address)", amounts, address(boringVault));

        address[] memory decodersAndSanitizers = new address[](6);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](6);
        values[0] = 1_000e18;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Finalize withdraw requests.
        address admin = IUNSTETH(getAddress(sourceChain, "unstETH")).getRoleMember(
            IUNSTETH(getAddress(sourceChain, "unstETH")).FINALIZE_ROLE(), 0
        );
        deal(admin, 300e18);
        vm.startPrank(admin);
        IUNSTETH(getAddress(sourceChain, "unstETH")).finalize{value: 100e18}(37_767, type(uint256).max);
        IUNSTETH(getAddress(sourceChain, "unstETH")).finalize{value: 100e18}(37_768, type(uint256).max);
        IUNSTETH(getAddress(sourceChain, "unstETH")).finalize{value: 100e18}(37_769, type(uint256).max);
        vm.stopPrank();

        manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[4];
        manageLeafs[1] = leafs[5];

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](2);
        targets[0] = getAddress(sourceChain, "unstETH");
        targets[1] = getAddress(sourceChain, "unstETH");

        targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("claimWithdrawal(uint256)", 37_767);
        uint256[] memory ids = new uint256[](2);
        ids[0] = 37_768;
        ids[1] = 37_769;
        uint256[] memory hints = IUNSTETH(getAddress(sourceChain, "unstETH")).findCheckpointHints(
            ids, 100, IUNSTETH(getAddress(sourceChain, "unstETH")).getLastCheckpointIndex()
        );
        targetData[1] = abi.encodeWithSignature("claimWithdrawals(uint256[],uint256[])", ids, hints);

        decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        values = new uint256[](2);

        uint256 boringVaultETHBalance = address(boringVault).balance;
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertEq(
            address(boringVault).balance - boringVaultETHBalance,
            300e18,
            "BoringVault should have received 300 ETH from withdrawals"
        );
    }

    function testNativeWrapperIntegration() external {
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 100e18);

        // Unwrap all WETH
        // mint WETH via deposit
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addNativeLeafs(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[1];
        manageLeafs[1] = leafs[0];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "WETH");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("withdraw(uint256)", 100e18);
        targetData[1] = abi.encodeWithSignature("deposit()");
        uint256[] memory values = new uint256[](2);
        values[1] = 100e18;
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // function testSwellIntegration() external {
    //     deal(getAddress(sourceChain, "WETH"), address(boringVault), 100e18);

    //     // unwrap weth
    //     // mint swETH
    //     // unstaking swETH
    //     ManageLeaf[] memory leafs = new ManageLeaf[](8);
    //     leafs[0] = ManageLeaf(getAddress(sourceChain, "WETH"), false, "withdraw(uint256)", new address[](0));
    //     leafs[1] = ManageLeaf(address(SWETH), true, "deposit()", new address[](0));
    //     leafs[2] = ManageLeaf(address(SWETH), false, "approve(address,uint256)", new address[](1));
    //     leafs[2].argumentAddresses[0] = swEXIT;
    //     leafs[3] = ManageLeaf(swEXIT, false, "createWithdrawRequest(uint256)", new address[](0));
    //     leafs[4] = ManageLeaf(swEXIT, false, "finalizeWithdrawal(uint256)", new address[](0));

    //     bytes32[][] memory manageTree = _generateMerkleTree(leafs);

    //     manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

    //     ManageLeaf[] memory manageLeafs = new ManageLeaf[](4);
    //     manageLeafs[0] = leafs[0];
    //     manageLeafs[1] = leafs[1];
    //     manageLeafs[2] = leafs[2];
    //     manageLeafs[3] = leafs[3];
    //     bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

    //     address[] memory targets = new address[](4);
    //     targets[0] = getAddress(sourceChain, "WETH");
    //     targets[1] = address(SWETH);
    //     targets[2] = address(SWETH);
    //     targets[3] = address(swEXIT);

    //     bytes[] memory targetData = new bytes[](4);
    //     targetData[0] = abi.encodeWithSignature("withdraw(uint256)", 100e18);
    //     targetData[1] = abi.encodeWithSignature("deposit()");
    //     targetData[2] = abi.encodeWithSignature("approve(address,uint256)", swEXIT, type(uint256).max);
    //     uint256 expectedSweth = 94453026416214353277;
    //     targetData[3] = abi.encodeWithSignature("createWithdrawRequest(uint256)", expectedSweth);
    //     uint256[] memory values = new uint256[](4);
    //     values[1] = 100e18;
    //     address[] memory decodersAndSanitizers = new address[](4);
    //     decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
    //     decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
    //     decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
    //     decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
    //     manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

    //     uint256 withdrawRequestId = 5286;

    //     _finalizeSwellRequest(withdrawRequestId);

    //     manageLeafs = new ManageLeaf[](1);
    //     manageLeafs[0] = leafs[4];
    //     manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

    //     targets = new address[](1);
    //     targets[0] = swEXIT;

    //     targetData = new bytes[](1);
    //     targetData[0] = abi.encodeWithSignature("finalizeWithdrawal(uint256)", withdrawRequestId);
    //     values = new uint256[](1);

    //     decodersAndSanitizers = new address[](1);
    //     decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
    //     manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

    //     assertApproxEqAbs(address(boringVault).balance, 100e18, 1, "BoringVault should have withdrawn and got ETH.");
    // }

    // function testMantleIntegration() external {
    //     deal(getAddress(sourceChain, "WETH"), address(boringVault), 100e18);

    //     // unwrap weth
    //     // mint swETH
    //     // unstaking swETH
    //     ManageLeaf[] memory leafs = new ManageLeaf[](8);
    //     leafs[0] = ManageLeaf(getAddress(sourceChain, "WETH"), false, "withdraw(uint256)", new address[](0));
    //     leafs[1] = ManageLeaf(mantleLspStaking, true, "stake(uint256)", new address[](0));
    //     leafs[2] = ManageLeaf(address(METH), false, "approve(address,uint256)", new address[](1));
    //     leafs[2].argumentAddresses[0] = mantleLspStaking;
    //     leafs[3] = ManageLeaf(mantleLspStaking, false, "unstakeRequest(uint128,uint128)", new address[](0));
    //     leafs[4] = ManageLeaf(mantleLspStaking, false, "claimUnstakeRequest(uint256)", new address[](0));

    //     bytes32[][] memory manageTree = _generateMerkleTree(leafs);

    //     manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

    //     ManageLeaf[] memory manageLeafs = new ManageLeaf[](4);
    //     manageLeafs[0] = leafs[0];
    //     manageLeafs[1] = leafs[1];
    //     manageLeafs[2] = leafs[2];
    //     manageLeafs[3] = leafs[3];
    //     bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

    //     address[] memory targets = new address[](4);
    //     targets[0] = getAddress(sourceChain, "WETH");
    //     targets[1] = mantleLspStaking;
    //     targets[2] = address(METH);
    //     targets[3] = mantleLspStaking;

    //     bytes[] memory targetData = new bytes[](4);
    //     targetData[0] = abi.encodeWithSignature("withdraw(uint256)", 100e18);
    //     targetData[1] = abi.encodeWithSignature("stake(uint256)", 0);
    //     targetData[2] = abi.encodeWithSignature("approve(address,uint256)", mantleLspStaking, type(uint256).max);
    //     uint256 expectedMeth = 96846201237918440407;
    //     targetData[3] = abi.encodeWithSignature("unstakeRequest(uint128,uint128)", expectedMeth, 0);
    //     uint256[] memory values = new uint256[](4);
    //     values[1] = 100e18;
    //     address[] memory decodersAndSanitizers = new address[](4);
    //     decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
    //     decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
    //     decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
    //     decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

    //     // Go back in time, so that request can be finalized immediately.
    //     vm.roll(block.number - 10_200);
    //     manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

    //     uint256 withdrawRequestId = 1500;

    //     _finalizeMantleRequest(2_000e18);

    //     manageLeafs = new ManageLeaf[](1);
    //     manageLeafs[0] = leafs[4];
    //     manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

    //     targets = new address[](1);
    //     targets[0] = mantleLspStaking;

    //     targetData = new bytes[](1);
    //     targetData[0] = abi.encodeWithSignature("claimUnstakeRequest(uint256)", withdrawRequestId);
    //     values = new uint256[](1);

    //     decodersAndSanitizers = new address[](1);
    //     decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
    //     manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

    //     assertApproxEqRel(
    //         address(boringVault).balance, 100e18, 0.0005e18, "BoringVault should have withdrawn and got ETH."
    //     );
    // }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }

    function _finalizeRequest(uint256 requestId, uint256 amount) internal {
        // Spoof unstEth contract into finalizing our request.
        IWithdrawRequestNft w = IWithdrawRequestNft(getAddress(sourceChain, "withdrawalRequestNft"));
        address owner = w.owner();
        vm.startPrank(owner);
        w.updateAdmin(address(this), true);
        vm.stopPrank();

        ILiquidityPool lp = ILiquidityPool(getAddress(sourceChain, "EETH_LIQUIDITY_POOL"));

        deal(address(this), amount);
        lp.deposit{value: amount}();
        address admin = lp.etherFiAdminContract();

        vm.startPrank(admin);
        lp.addEthAmountLockedForWithdrawal(uint128(amount));
        vm.stopPrank();

        w.finalizeRequests(requestId);
    }

    function _finalizeSwellRequest(uint256 requestId) internal {
        // Give dpeositManager a ton of ETH to cover all withdraws.
        deal(getAddress(sourceChain, "depositManager"), type(uint96).max);
        vm.startPrank(0x289d600447A74B952AD16F0BD53b8eaAac2d2D71);
        ISWEXIT(getAddress(sourceChain, "swEXIT")).processWithdrawals(requestId);
        vm.stopPrank();
    }

    function _finalizeMantleRequest(uint256 amount) internal {
        vm.roll(block.number + 10_201);
        deal(getAddress(sourceChain, "mantleLspStaking"), amount);

        vm.prank(getAddress(sourceChain, "mantleLspStaking"));
        MantleStaking(0x38fDF7b489316e03eD8754ad339cb5c4483FDcf9).allocateETH{value: amount}();
    }

    function withdraw(uint256 amount) external {
        boringVault.enter(address(0), ERC20(address(0)), 0, address(this), amount);
    }
}

interface IRequest {
    struct UnstakeRequest {
        uint64 blockNumber;
        address requester;
        uint128 id;
        uint128 mETHLocked;
        uint128 ethRequested;
        uint128 cumulativeETHRequested;
    }

    function requestByID(uint256 id) external view returns (UnstakeRequest memory);
}

interface IOracle {
    struct OracleRecord {
        uint64 updateStartBlock;
        uint64 updateEndBlock;
        uint64 currentNumValidatorsNotWithdrawable;
        uint64 cumulativeNumValidatorsWithdrawable;
        uint128 windowWithdrawnPrincipalAmount;
        uint128 windowWithdrawnRewardAmount;
        uint128 currentTotalValidatorBalance;
        uint128 cumulativeProcessedDepositAmount;
    }

    function latestRecord() external view returns (OracleRecord memory);
}

interface MantleStaking {
    function allocateETH() external payable;
    function allocatedETHForClaims() external view returns (uint256);
}

interface IWithdrawRequestNft {
    struct WithdrawRequest {
        uint96 amountOfEEth;
        uint96 shareOfEEth;
        bool isValid;
        uint32 feeGwei;
    }

    function claimWithdraw(uint256 tokenId) external;

    function getRequest(uint256 requestId) external view returns (WithdrawRequest memory);

    function finalizeRequests(uint256 requestId) external;

    function owner() external view returns (address);

    function updateAdmin(address admin, bool isAdmin) external;
}

interface ILiquidityPool {
    function deposit() external payable returns (uint256);

    function requestWithdraw(address recipient, uint256 amount) external returns (uint256);

    function amountForShare(uint256 shares) external view returns (uint256);

    function etherFiAdminContract() external view returns (address);

    function addEthAmountLockedForWithdrawal(uint128 _amount) external;
}

interface IUNSTETH {
    function finalize(uint256 _lastRequestIdToBeFinalized, uint256 _maxShareRate) external payable;

    function getRoleMember(bytes32 role, uint256 index) external view returns (address);

    function FINALIZE_ROLE() external view returns (bytes32);

    function findCheckpointHints(uint256[] memory requestIds, uint256 firstIndex, uint256 lastIndex)
        external
        view
        returns (uint256[] memory);

    function getLastCheckpointIndex() external view returns (uint256);
}

interface ISWEXIT {
    function processWithdrawals(uint256 id) external;
}

interface AccessControlManager {
    function grantRole(bytes32 role, address account) external;
}

interface EthenaSusde {
    function cooldownDuration() external view returns (uint24);
    function cooldowns(address) external view returns (uint104 cooldownEnd, uint152 underlyingAmount);
}
