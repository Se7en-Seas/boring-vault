// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {
    EtherFiLiquidDecoderAndSanitizer,
    UniswapV3DecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/EtherFiLiquidDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract BalancerV2FlashloansIntegrationTest is Test, MerkleTreeHelper {
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
        uint256 blockNumber = 19826676;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(
            new EtherFiLiquidDecoderAndSanitizer(
                address(boringVault), getAddress(sourceChain, "uniswapV3NonFungiblePositionManager")
            )
        );

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
        rolesAuthority.setUserRole(getAddress(sourceChain, "vault"), BALANCER_VAULT_ROLE, true);
    }

    function testBalancerV2FlashloansIntegration() external {
        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDC"));
        // Add some extra leafs so we can do something during the flashloan.
        leafs[1] = ManageLeaf(
            address(this),
            false,
            "approve(address,uint256)",
            new address[](1),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[1].argumentAddresses[0] = getAddress(sourceChain, "USDC");
        leafs[2] = ManageLeaf(
            getAddress(sourceChain, "USDC"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[2].argumentAddresses[0] = address(this);
        // leaf[3] empty

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[2][0]);
        // Since the manager calls to itself to fulfill the flashloan, we need to set its root.
        manager.setManageRoot(address(manager), manageTree[2][0]);

        bytes memory userData;
        {
            uint256 flashLoanAmount = 1_000_000e6;
            // Build flashLoan data.
            address[] memory targets = new address[](2);
            targets[0] = getAddress(sourceChain, "USDC");
            targets[1] = address(this);
            bytes[] memory targetData = new bytes[](2);
            targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(this), flashLoanAmount);
            targetData[1] =
                abi.encodeWithSelector(ERC20.approve.selector, getAddress(sourceChain, "USDC"), flashLoanAmount);

            ManageLeaf[] memory flashLoanLeafs = new ManageLeaf[](2);
            flashLoanLeafs[0] = leafs[2];
            flashLoanLeafs[1] = leafs[1];

            bytes32[][] memory flashLoanManageProofs = _getProofsUsingTree(flashLoanLeafs, manageTree);

            uint256[] memory values = new uint256[](2);
            address[] memory dAs = new address[](2);
            dAs[0] = rawDataDecoderAndSanitizer;
            dAs[1] = rawDataDecoderAndSanitizer;
            userData = abi.encode(flashLoanManageProofs, dAs, targets, targetData, values);
        }
        {
            address[] memory targets = new address[](1);
            targets[0] = address(manager);

            address[] memory tokensToBorrow = new address[](1);
            tokensToBorrow[0] = getAddress(sourceChain, "USDC");
            uint256[] memory amountsToBorrow = new uint256[](1);
            amountsToBorrow[0] = 1_000_000e6;
            bytes[] memory targetData = new bytes[](1);
            targetData[0] = abi.encodeWithSelector(
                BalancerVault.flashLoan.selector, address(manager), tokensToBorrow, amountsToBorrow, userData
            );

            ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
            manageLeafs[0] = leafs[0];

            bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

            uint256[] memory values = new uint256[](1);
            address[] memory decodersAndSanitizers = new address[](1);
            decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
            manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

            assertTrue(iDidSomething == true, "Should have called doSomethingWithFlashLoan");
        }
    }

    function testBalancerV2FlashLoanReverts() external {
        // Deploy a new manager, setting the Balancer Vault as address(this)
        manager = new ManagerWithMerkleVerification(address(this), address(boringVault), address(this));
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
            BORING_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.flashLoan.selector, true
        );
        rolesAuthority.setRoleCapability(
            BALANCER_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.receiveFlashLoan.selector, true
        );
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        rolesAuthority.setUserRole(address(this), BALANCER_VAULT_ROLE, true);
        manager.setAuthority(rolesAuthority);

        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        leafs[0] = ManageLeaf(
            address(manager),
            false,
            "flashLoan(address,address[],uint256[],bytes)",
            new address[](2),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[0].argumentAddresses[0] = address(manager);
        leafs[0].argumentAddresses[1] = getAddress(sourceChain, "USDC");

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[2][0]);
        // Since the manager calls to itself to fulfill the flashloan, we need to set its root.
        manager.setManageRoot(address(manager), manageTree[2][0]);

        bytes memory userData = hex"DEAD";
        address[] memory targets = new address[](1);
        targets[0] = address(manager);

        address[] memory tokensToBorrow = new address[](1);
        tokensToBorrow[0] = getAddress(sourceChain, "USDC");
        uint256[] memory amountsToBorrow = new uint256[](1);
        amountsToBorrow[0] = 1_000_000e6;
        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSelector(
            BalancerVault.flashLoan.selector, address(manager), tokensToBorrow, amountsToBorrow, userData
        );

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        uint256[] memory values = new uint256[](1);
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        // Try performing a flash loan where receiveFlashLoan is not called.
        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FlashLoanNotExecuted.selector
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        doNothing = false;

        // Try performing a flash loan but with userData editted.
        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__BadFlashLoanIntentHash.selector
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // ========================================= FLASHLOAN TEST =========================================

    bool doNothing = true;

    function flashLoan(address, address[] calldata tokens, uint256[] calldata amounts, bytes memory userData)
        external
    {
        if (doNothing) {
            return;
        } else {
            // Edit userData.
            userData = hex"DEAD01";
            manager.receiveFlashLoan(tokens, amounts, amounts, userData);
        }
    }

    bool iDidSomething = false;

    // Call this function approve, so that we can use the standard decoder.
    function approve(ERC20 token, uint256 amount) external {
        token.safeTransferFrom(msg.sender, address(this), amount);
        token.safeTransfer(msg.sender, amount);
        iDidSomething = true;
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
