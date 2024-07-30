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
    PendleRouterDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/EtherFiLiquidDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract PendleLimitOrderIntegrationTest is Test, MerkleTreeHelper {
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
        uint256 blockNumber = 20421105;

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

    function testPendleLimitOrdersFill() external {
        // Mint Super Symbiotic YT to Boring Vault
        deal(getAddress(sourceChain, "pendleEethYtDecember"), address(boringVault), 10_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        _addPendleLimitOrderLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarketDecember"));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[3];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "pendleEethYtDecember");
        targets[1] = getAddress(sourceChain, "pendleLimitOrderRouter");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "pendleLimitOrderRouter"), type(uint256).max
        );
        DecoderCustomTypes.FillOrderParams[] memory orders = new DecoderCustomTypes.FillOrderParams[](1);
        orders[0].order = DecoderCustomTypes.Order({
            salt: 8373482081934227929253689972963323292519685394038939188831665232063109942581,
            expiry: 1723946188,
            nonce: 0,
            orderType: DecoderCustomTypes.OrderType.SY_FOR_YT,
            token: 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee,
            YT: 0x129e6B5DBC0Ecc12F9e486C5BC9cDF1a6A80bc6A,
            maker: 0x9fb1750Da6266a05601855bb62767eBC742707B1,
            receiver: 0x9fb1750Da6266a05601855bb62767eBC742707B1,
            makingAmount: 16158236360418398872,
            lnImpliedRate: 67658648473814805,
            failSafeRate: 900000000000000000,
            permit: hex""
        });
        orders[0].signature =
            hex"89c53ba1ee3f7edd13d82cf5de29bbf0fd9ff3a48de32ec3651bd89f0196bbed0fcf94c12d1853cf935cac31c6900159bf157e29ad17d3e2a04dedf1247849d91c";
        orders[0].makingAmount = 1687467958106575287;
        targetData[1] = abi.encodeWithSignature(
            "fill(((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],address,uint256,bytes,bytes)",
            orders,
            boringVault,
            100e18,
            hex"",
            hex""
        );

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertGt(
            getERC20(sourceChain, "pendleWeethSyDecember").balanceOf(address(boringVault)),
            0,
            "BoringVault should have SY"
        );
    }

    function testPendleLimitOrdersSwapExactSyForPt() external {
        // Mint Super Symbiotic SY to Boring Vault
        deal(getAddress(sourceChain, "pendleWeethSyDecember"), address(boringVault), 100e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarketDecember"), true);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[3]; // Approve router to spend SY
        manageLeafs[1] = leafs[19]; // call swapExactSyForPt
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "pendleWeethSyDecember");
        targets[1] = getAddress(sourceChain, "pendleRouter");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "pendleRouter"), type(uint256).max
        );
        DecoderCustomTypes.ApproxParams memory approxParams = DecoderCustomTypes.ApproxParams(
            21114594311676358609, 107181111776638002478, 42229188623352717218, 30, 11629871223418
        );
        DecoderCustomTypes.LimitOrderData memory limitOrderData;
        limitOrderData.limitRouter = getAddress(sourceChain, "pendleLimitOrderRouter");
        limitOrderData.epsSkipMarket = 0;
        limitOrderData.flashFills = new DecoderCustomTypes.FillOrderParams[](1);
        limitOrderData.flashFills[0].order = DecoderCustomTypes.Order({
            salt: 8373482081934227929253689972963323292519685394038939188831665232063109942581,
            expiry: 1723946188,
            nonce: 0,
            orderType: DecoderCustomTypes.OrderType.SY_FOR_YT,
            token: 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee,
            YT: 0x129e6B5DBC0Ecc12F9e486C5BC9cDF1a6A80bc6A,
            maker: 0x9fb1750Da6266a05601855bb62767eBC742707B1,
            receiver: 0x9fb1750Da6266a05601855bb62767eBC742707B1,
            makingAmount: 16158236360418398872,
            lnImpliedRate: 67658648473814805,
            failSafeRate: 900000000000000000,
            permit: hex""
        });
        limitOrderData.flashFills[0].signature =
            hex"89c53ba1ee3f7edd13d82cf5de29bbf0fd9ff3a48de32ec3651bd89f0196bbed0fcf94c12d1853cf935cac31c6900159bf157e29ad17d3e2a04dedf1247849d91c";
        limitOrderData.flashFills[0].makingAmount = 1687467958106575287;
        targetData[1] = abi.encodeWithSignature(
            "swapExactSyForPt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256),(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
            address(boringVault),
            getAddress(sourceChain, "pendleWeETHMarketDecember"),
            100e18,
            0,
            approxParams,
            limitOrderData
        );

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        uint256 ptBalance = getERC20(sourceChain, "pendleEethPtDecember").balanceOf(address(boringVault));
        assertGt(ptBalance, 100e18, "PT balance should be greater than 100.");
    }

    // TODO revert tests

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
