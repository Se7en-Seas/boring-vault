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
    MorphoBlueDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/EtherFiLiquidDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract MorphoBlueIntegrationTest is Test, MerkleTreeHelper {
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

    function testMorphoBlueIntegration() external {
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 100e18);
        deal(getAddress(sourceChain, "WEETH"), address(boringVault), 100e18);

        // supply weth
        // withdraw weth
        // supply weeth
        // borrow weth
        // repay weth
        // withdraw weeth.
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "weETH_wETH_86_market"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "weETH_wETH_86_market"));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](8);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];
        manageLeafs[3] = leafs[3];
        manageLeafs[4] = leafs[4];
        manageLeafs[5] = leafs[5];
        manageLeafs[6] = leafs[6];
        manageLeafs[7] = leafs[7];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](8);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "morphoBlue");
        targets[2] = getAddress(sourceChain, "morphoBlue");
        targets[3] = getAddress(sourceChain, "WEETH");
        targets[4] = getAddress(sourceChain, "morphoBlue");
        targets[5] = getAddress(sourceChain, "morphoBlue");
        targets[6] = getAddress(sourceChain, "morphoBlue");
        targets[7] = getAddress(sourceChain, "morphoBlue");

        bytes[] memory targetData = new bytes[](8);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "morphoBlue"), type(uint256).max
        );
        DecoderCustomTypes.MarketParams memory params = DecoderCustomTypes.MarketParams(
            getAddress(sourceChain, "WETH"), getAddress(sourceChain, "WEETH"), weEthOracle, weEthIrm, 0.86e18
        );
        targetData[1] = abi.encodeWithSignature(
            "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            params,
            100e18,
            0,
            address(boringVault),
            hex""
        );
        targetData[2] = abi.encodeWithSignature(
            "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
            params,
            100e18 - 1,
            0,
            address(boringVault),
            address(boringVault)
        );
        targetData[3] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "morphoBlue"), type(uint256).max
        );
        targetData[4] = abi.encodeWithSignature(
            "supplyCollateral((address,address,address,address,uint256),uint256,address,bytes)",
            params,
            100e18,
            address(boringVault),
            hex""
        );
        targetData[5] = abi.encodeWithSignature(
            "borrow((address,address,address,address,uint256),uint256,uint256,address,address)",
            params,
            10e18,
            0,
            address(boringVault),
            address(boringVault)
        );
        targetData[6] = abi.encodeWithSignature(
            "repay((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            params,
            10e18,
            0,
            address(boringVault),
            hex""
        );
        targetData[7] = abi.encodeWithSignature(
            "withdrawCollateral((address,address,address,address,uint256),uint256,address,address)",
            params,
            90e18,
            address(boringVault),
            address(boringVault)
        );

        address[] memory decodersAndSanitizers = new address[](8);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](8)
        );
    }

    function testMorphoBlueIntegrationReverts() external {
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 100e18);
        deal(getAddress(sourceChain, "WEETH"), address(boringVault), 100e18);

        // supply weth
        // withdraw weth
        // supply weeth
        // borrow weth
        // repay weth
        // withdraw weeth.
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "weETH_wETH_86_market"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "weETH_wETH_86_market"));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](8);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];
        manageLeafs[3] = leafs[3];
        manageLeafs[4] = leafs[4];
        manageLeafs[5] = leafs[5];
        manageLeafs[6] = leafs[6];
        manageLeafs[7] = leafs[7];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](8);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "morphoBlue");
        targets[2] = getAddress(sourceChain, "morphoBlue");
        targets[3] = getAddress(sourceChain, "WEETH");
        targets[4] = getAddress(sourceChain, "morphoBlue");
        targets[5] = getAddress(sourceChain, "morphoBlue");
        targets[6] = getAddress(sourceChain, "morphoBlue");
        targets[7] = getAddress(sourceChain, "morphoBlue");

        bytes[] memory targetData = new bytes[](8);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "morphoBlue"), type(uint256).max
        );
        DecoderCustomTypes.MarketParams memory params = DecoderCustomTypes.MarketParams(
            getAddress(sourceChain, "WETH"), getAddress(sourceChain, "WEETH"), weEthOracle, weEthIrm, 0.86e18
        );
        targetData[1] = abi.encodeWithSignature(
            "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            params,
            100e18,
            0,
            address(boringVault),
            hex""
        );
        targetData[2] = abi.encodeWithSignature(
            "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
            params,
            100e18 - 1,
            0,
            address(boringVault),
            address(boringVault)
        );
        targetData[3] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "morphoBlue"), type(uint256).max
        );
        targetData[4] = abi.encodeWithSignature(
            "supplyCollateral((address,address,address,address,uint256),uint256,address,bytes)",
            params,
            100e18,
            address(boringVault),
            hex""
        );
        targetData[5] = abi.encodeWithSignature(
            "borrow((address,address,address,address,uint256),uint256,uint256,address,address)",
            params,
            10e18,
            0,
            address(boringVault),
            address(boringVault)
        );
        targetData[6] = abi.encodeWithSignature(
            "repay((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            params,
            10e18,
            0,
            address(boringVault),
            hex""
        );
        targetData[7] = abi.encodeWithSignature(
            "withdrawCollateral((address,address,address,address,uint256),uint256,address,address)",
            params,
            90e18,
            address(boringVault),
            address(boringVault)
        );

        address[] memory decodersAndSanitizers = new address[](8);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;

        // Pass in callback data to supply.
        targetData[1] = abi.encodeWithSignature(
            "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            params,
            100e18,
            0,
            address(boringVault),
            hex"DEAD"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                MorphoBlueDecoderAndSanitizer.MorphoBlueDecoderAndSanitizer__CallbackNotSupported.selector
            )
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](8)
        );

        // Fix supply call.
        targetData[1] = abi.encodeWithSignature(
            "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            params,
            100e18,
            0,
            address(boringVault),
            hex""
        );

        // Pass in callback data to supply collateral
        targetData[4] = abi.encodeWithSignature(
            "supplyCollateral((address,address,address,address,uint256),uint256,address,bytes)",
            params,
            100e18,
            address(boringVault),
            hex"DEAD"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                MorphoBlueDecoderAndSanitizer.MorphoBlueDecoderAndSanitizer__CallbackNotSupported.selector
            )
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](8)
        );

        // Fix supply collateral call
        targetData[4] = abi.encodeWithSignature(
            "supplyCollateral((address,address,address,address,uint256),uint256,address,bytes)",
            params,
            100e18,
            address(boringVault),
            hex""
        );

        // Pass in callback data to repay
        targetData[6] = abi.encodeWithSignature(
            "repay((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            params,
            10e18,
            0,
            address(boringVault),
            hex"DEAD"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                MorphoBlueDecoderAndSanitizer.MorphoBlueDecoderAndSanitizer__CallbackNotSupported.selector
            )
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](8)
        );

        // Fix repay call
        targetData[6] = abi.encodeWithSignature(
            "repay((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            params,
            10e18,
            0,
            address(boringVault),
            hex""
        );

        // Call now works.
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](8)
        );
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
