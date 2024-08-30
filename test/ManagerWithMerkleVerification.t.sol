// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {
    EtherFiLiquidDecoderAndSanitizer,
    MorphoBlueDecoderAndSanitizer,
    UniswapV3DecoderAndSanitizer,
    BalancerV2DecoderAndSanitizer,
    PendleRouterDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/EtherFiLiquidDecoderAndSanitizer.sol";
import {EtherFiLiquidUsdDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidUsdDecoderAndSanitizer.sol";
import {LidoLiquidDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LidoLiquidDecoderAndSanitizer.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {IUniswapV3Router} from "src/interfaces/IUniswapV3Router.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {
    PointFarmingDecoderAndSanitizer,
    EigenLayerLSTStakingDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/PointFarmingDecoderAndSanitizer.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract ManagerWithMerkleVerificationTest is Test, MerkleTreeHelper {
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

    ERC20 internal USDC;
    ERC20 internal USDT;
    address internal vault;
    address internal uniswapV3NonFungiblePositionManager;

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        // uint256 blockNumber = 19369928;
        uint256 blockNumber = 19826676;
        // uint256 blockNumber = 20036275;

        _startFork(rpcKey, blockNumber);

        USDC = getERC20(sourceChain, "USDC");
        USDT = getERC20(sourceChain, "USDT");
        vault = getAddress(sourceChain, "vault");
        uniswapV3NonFungiblePositionManager = getAddress(sourceChain, "uniswapV3NonFungiblePositionManager");

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager = new ManagerWithMerkleVerification(address(this), address(boringVault), vault);

        rawDataDecoderAndSanitizer =
            address(new EtherFiLiquidDecoderAndSanitizer(address(boringVault), uniswapV3NonFungiblePositionManager));
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
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
        rolesAuthority.setUserRole(vault, BALANCER_VAULT_ROLE, true);

        // Allow the boring vault to receive ETH.
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);
    }

    function testManagerMerkleVerificationHappyPath() external {
        // Allow the manager to call the USDC approve function to a specific address,
        // and the USDT transfer function to a specific address.
        address usdcSpender = vm.addr(0xDEAD);
        address usdtTo = vm.addr(0xDEAD1);
        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        leafs[0] = ManageLeaf(
            address(USDC), false, "approve(address,uint256)", new address[](1), "", rawDataDecoderAndSanitizer
        );
        leafs[0].argumentAddresses[0] = usdcSpender;
        leafs[1] = ManageLeaf(
            address(USDT), false, "approve(address,uint256)", new address[](1), "", rawDataDecoderAndSanitizer
        );
        leafs[1].argumentAddresses[0] = usdtTo;

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[1][0]);

        address[] memory targets = new address[](2);
        targets[0] = address(USDC);
        targets[1] = address(USDT);

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, usdcSpender, 777);
        targetData[1] = abi.encodeWithSelector(ERC20.approve.selector, usdtTo, 777);

        (bytes32[][] memory manageProofs) = _getProofsUsingTree(leafs, manageTree);

        uint256[] memory values = new uint256[](2);

        deal(address(USDT), address(boringVault), 777);

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256 gas = gasleft();
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        console.log("Gas used", gas - gasleft());

        assertEq(USDC.allowance(address(boringVault), usdcSpender), 777, "USDC should have an allowance");
        assertEq(USDT.allowance(address(boringVault), usdtTo), 777, "USDT should have have an allowance");
    }

    function testReverts() external {
        bytes32[][] memory manageProofs;
        address[] memory targets;
        targets = new address[](1);
        bytes[] memory targetData;
        uint256[] memory values;
        address[] memory decodersAndSanitizers;

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__InvalidManageProofLength.selector
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        manageProofs = new bytes32[][](1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__InvalidTargetDataLength.selector
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        targetData = new bytes[](1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__InvalidValuesLength.selector
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        values = new uint256[](1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__InvalidDecodersAndSanitizersLength.selector
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        decodersAndSanitizers = new address[](1);

        targets[0] = address(USDC);
        targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(this), 1_000);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector,
                targets[0],
                targetData[0],
                values[0]
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Set the manage root to be the leaf of the USDC approve function
        bytes32 manageRoot = keccak256(
            abi.encodePacked(rawDataDecoderAndSanitizer, targets[0], false, bytes4(targetData[0]), address(this))
        );
        manager.setManageRoot(address(this), manageRoot);

        // Call now works.
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Check `flashLoan`
        address[] memory tokens;
        uint256[] memory amounts;

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__OnlyCallableByBoringVault.selector
            )
        );
        manager.flashLoan(address(this), tokens, amounts, abi.encode(0));

        // Check `receiveFlashLoan`
        uint256[] memory feeAmounts;

        address attacker = vm.addr(1);
        vm.startPrank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__OnlyCallableByBalancerVault.selector
            )
        );
        manager.receiveFlashLoan(tokens, amounts, feeAmounts, abi.encode(0));
        vm.stopPrank();

        // Someone else initiated a flash loan
        vm.startPrank(vault);
        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FlashLoanNotInProgress.selector
            )
        );
        manager.receiveFlashLoan(tokens, amounts, feeAmounts, abi.encode(0));
        vm.stopPrank();
    }

    function testManagementMintingSharesRevert() external {
        deal(address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        leafs[0] =
            ManageLeaf(address(this), false, "withdraw(uint256)", new address[](0), "", rawDataDecoderAndSanitizer);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = address(this);

        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature("withdraw(uint256)", 1);

        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification
                    .ManagerWithMerkleVerification__TotalSupplyMustRemainConstantDuringManagement
                    .selector
            )
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](1)
        );
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function withdraw(uint256 amount) external {
        boringVault.enter(address(0), ERC20(address(0)), 0, address(this), amount);
    }

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
