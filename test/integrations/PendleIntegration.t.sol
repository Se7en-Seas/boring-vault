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
    EtherFiLiquidDecoderAndSanitizer,
    PendleRouterDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/EtherFiLiquidDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract PendleIntegrationTest is Test, MerkleTreeHelper {
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

    function testPendleRouterSwapBetweenSyAndPt() external {
        deal(getAddress(sourceChain, "WEETH"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarket"));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](6);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[3];
        manageLeafs[2] = leafs[4];
        manageLeafs[3] = leafs[6];
        manageLeafs[4] = leafs[17];
        manageLeafs[5] = leafs[18];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](6);
        targets[0] = getAddress(sourceChain, "WEETH");
        targets[1] = getAddress(sourceChain, "pendleWeethSy");
        targets[2] = getAddress(sourceChain, "pendleEethPt");
        targets[3] = getAddress(sourceChain, "pendleRouter");
        targets[4] = getAddress(sourceChain, "pendleRouter");
        targets[5] = getAddress(sourceChain, "pendleRouter");

        bytes[] memory targetData = new bytes[](6);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "pendleRouter"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "pendleRouter"), type(uint256).max
        );
        targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "pendleRouter"), type(uint256).max
        );
        DecoderCustomTypes.SwapData memory swapData =
            DecoderCustomTypes.SwapData(DecoderCustomTypes.SwapType.NONE, address(0), hex"", false);
        DecoderCustomTypes.TokenInput memory tokenInput = DecoderCustomTypes.TokenInput(
            getAddress(sourceChain, "WEETH"), 1_000e18, getAddress(sourceChain, "WEETH"), address(0), swapData
        );
        targetData[3] = abi.encodeWithSignature(
            "mintSyFromToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            address(boringVault),
            getAddress(sourceChain, "pendleWeethSy"),
            0,
            tokenInput
        );
        DecoderCustomTypes.ApproxParams memory approxParams =
            DecoderCustomTypes.ApproxParams(0, type(uint256).max, 0, 2566, 1e14);
        DecoderCustomTypes.LimitOrderData memory limitOrderData;
        targetData[4] = abi.encodeWithSignature(
            "swapExactSyForPt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256),(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
            address(boringVault),
            getAddress(sourceChain, "pendleWeETHMarket"),
            1_000e18,
            0,
            approxParams,
            limitOrderData
        );
        targetData[5] = abi.encodeWithSignature(
            "swapExactPtForSy(address,address,uint256,uint256,(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
            address(boringVault),
            getAddress(sourceChain, "pendleWeETHMarket"),
            1067250850449490881768,
            0,
            limitOrderData
        );

        address[] memory decodersAndSanitizers = new address[](6);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](6);
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testPendleRouterIntegration() external {
        deal(getAddress(sourceChain, "WEETH"), address(boringVault), 1_000e18);

        // Need 4 approvals all for router, WEETH, SY, PT, YT
        // WEETH -> SY
        // SY/2 -> PY
        // swap YT for PT
        // swap PT for YT
        // add liquidity
        // remove liquidity
        // PY -> SY
        // SY -> WEETH
        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarket"));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](13);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[3];
        manageLeafs[2] = leafs[4];
        manageLeafs[3] = leafs[5];
        manageLeafs[4] = leafs[2];
        manageLeafs[5] = leafs[6];
        manageLeafs[6] = leafs[8];
        manageLeafs[7] = leafs[9];
        manageLeafs[8] = leafs[10];
        manageLeafs[9] = leafs[11];
        manageLeafs[10] = leafs[12];
        manageLeafs[11] = leafs[13];
        manageLeafs[12] = leafs[14];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](13);
        targets[0] = getAddress(sourceChain, "WEETH");
        targets[1] = getAddress(sourceChain, "pendleWeethSy");
        targets[2] = getAddress(sourceChain, "pendleEethPt");
        targets[3] = getAddress(sourceChain, "pendleEethYt");
        targets[4] = getAddress(sourceChain, "pendleWeETHMarket");
        targets[5] = getAddress(sourceChain, "pendleRouter");
        targets[6] = getAddress(sourceChain, "pendleRouter");
        targets[7] = getAddress(sourceChain, "pendleRouter");
        targets[8] = getAddress(sourceChain, "pendleRouter");
        targets[9] = getAddress(sourceChain, "pendleRouter");
        targets[10] = getAddress(sourceChain, "pendleRouter");
        targets[11] = getAddress(sourceChain, "pendleRouter");
        targets[12] = getAddress(sourceChain, "pendleRouter");

        bytes[] memory targetData = new bytes[](13);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "pendleRouter"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "pendleRouter"), type(uint256).max
        );
        targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "pendleRouter"), type(uint256).max
        );
        targetData[3] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "pendleRouter"), type(uint256).max
        );
        targetData[4] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "pendleRouter"), type(uint256).max
        );
        DecoderCustomTypes.SwapData memory swapData =
            DecoderCustomTypes.SwapData(DecoderCustomTypes.SwapType.NONE, address(0), hex"", false);
        DecoderCustomTypes.TokenInput memory tokenInput = DecoderCustomTypes.TokenInput(
            getAddress(sourceChain, "WEETH"), 1_000e18, getAddress(sourceChain, "WEETH"), address(0), swapData
        );
        targetData[5] = abi.encodeWithSignature(
            "mintSyFromToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            address(boringVault),
            getAddress(sourceChain, "pendleWeethSy"),
            0,
            tokenInput
        );
        targetData[6] = abi.encodeWithSignature(
            "mintPyFromSy(address,address,uint256,uint256)",
            address(boringVault),
            getAddress(sourceChain, "pendleEethYt"),
            100e18,
            0
        );
        DecoderCustomTypes.ApproxParams memory approxParams =
            DecoderCustomTypes.ApproxParams(0, type(uint256).max, 0, 2566, 1e14);
        targetData[7] = abi.encodeWithSignature(
            "swapExactYtForPt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            address(boringVault),
            getAddress(sourceChain, "pendleWeETHMarket"),
            10e18,
            0,
            approxParams
        );
        targetData[8] = abi.encodeWithSignature(
            "swapExactPtForYt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            address(boringVault),
            getAddress(sourceChain, "pendleWeETHMarket"),
            1e18,
            0,
            approxParams
        );
        targetData[9] = abi.encodeWithSignature(
            "addLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
            address(boringVault),
            getAddress(sourceChain, "pendleWeETHMarket"),
            1e18,
            1e18,
            0
        );
        targetData[10] = abi.encodeWithSignature(
            "removeLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
            address(boringVault),
            getAddress(sourceChain, "pendleWeETHMarket"),
            0.1e18,
            0,
            0
        );
        targetData[11] = abi.encodeWithSignature(
            "redeemPyToSy(address,address,uint256,uint256)",
            address(boringVault),
            getAddress(sourceChain, "pendleEethYt"),
            0.1e18,
            0
        );
        DecoderCustomTypes.TokenOutput memory tokenOutput = DecoderCustomTypes.TokenOutput(
            getAddress(sourceChain, "WEETH"), 0, getAddress(sourceChain, "WEETH"), address(0), swapData
        );
        targetData[12] = abi.encodeWithSignature(
            "redeemSyToToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            address(boringVault),
            getAddress(sourceChain, "pendleWeethSy"),
            1e18,
            tokenOutput
        );

        address[] memory decodersAndSanitizers = new address[](13);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[8] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[9] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[10] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[11] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[12] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](13);
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testPendleRouterReverts() external {
        deal(getAddress(sourceChain, "WEETH"), address(boringVault), 1_000e18);

        // Need 4 approvals all for router, WEETH, SY, PT, YT
        // WEETH -> SY
        // SY/2 -> PY
        // swap YT for PT
        // swap PT for YT
        // add liquidity
        // remove liquidity
        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarket"));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](13);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[3];
        manageLeafs[2] = leafs[4];
        manageLeafs[3] = leafs[5];
        manageLeafs[4] = leafs[2];
        manageLeafs[5] = leafs[6];
        manageLeafs[6] = leafs[8];
        manageLeafs[7] = leafs[9];
        manageLeafs[8] = leafs[10];
        manageLeafs[9] = leafs[11];
        manageLeafs[10] = leafs[12];
        manageLeafs[11] = leafs[13];
        manageLeafs[12] = leafs[14];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](13);
        targets[0] = getAddress(sourceChain, "WEETH");
        targets[1] = getAddress(sourceChain, "pendleWeethSy");
        targets[2] = getAddress(sourceChain, "pendleEethPt");
        targets[3] = getAddress(sourceChain, "pendleEethYt");
        targets[4] = getAddress(sourceChain, "pendleWeETHMarket");
        targets[5] = getAddress(sourceChain, "pendleRouter");
        targets[6] = getAddress(sourceChain, "pendleRouter");
        targets[7] = getAddress(sourceChain, "pendleRouter");
        targets[8] = getAddress(sourceChain, "pendleRouter");
        targets[9] = getAddress(sourceChain, "pendleRouter");
        targets[10] = getAddress(sourceChain, "pendleRouter");
        targets[11] = getAddress(sourceChain, "pendleRouter");
        targets[12] = getAddress(sourceChain, "pendleRouter");

        bytes[] memory targetData = new bytes[](13);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "pendleRouter"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "pendleRouter"), type(uint256).max
        );
        targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "pendleRouter"), type(uint256).max
        );
        targetData[3] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "pendleRouter"), type(uint256).max
        );
        targetData[4] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "pendleRouter"), type(uint256).max
        );
        DecoderCustomTypes.SwapData memory swapData =
            DecoderCustomTypes.SwapData(DecoderCustomTypes.SwapType.NONE, address(0), hex"", false);
        DecoderCustomTypes.TokenInput memory tokenInput = DecoderCustomTypes.TokenInput(
            getAddress(sourceChain, "WEETH"), 1_000e18, getAddress(sourceChain, "WEETH"), address(0), swapData
        );
        targetData[5] = abi.encodeWithSignature(
            "mintSyFromToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            address(boringVault),
            getAddress(sourceChain, "pendleWeethSy"),
            0,
            tokenInput
        );
        targetData[6] = abi.encodeWithSignature(
            "mintPyFromSy(address,address,uint256,uint256)",
            address(boringVault),
            getAddress(sourceChain, "pendleEethYt"),
            100e18,
            0
        );
        DecoderCustomTypes.ApproxParams memory approxParams =
            DecoderCustomTypes.ApproxParams(0, type(uint256).max, 0, 2566, 1e14);
        targetData[7] = abi.encodeWithSignature(
            "swapExactYtForPt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            address(boringVault),
            getAddress(sourceChain, "pendleWeETHMarket"),
            10e18,
            0,
            approxParams
        );
        targetData[8] = abi.encodeWithSignature(
            "swapExactPtForYt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            address(boringVault),
            getAddress(sourceChain, "pendleWeETHMarket"),
            1e18,
            0,
            approxParams
        );
        targetData[9] = abi.encodeWithSignature(
            "addLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
            address(boringVault),
            getAddress(sourceChain, "pendleWeETHMarket"),
            1e18,
            1e18,
            0
        );
        targetData[10] = abi.encodeWithSignature(
            "removeLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
            address(boringVault),
            getAddress(sourceChain, "pendleWeETHMarket"),
            0.1e18,
            0,
            0
        );
        targetData[11] = abi.encodeWithSignature(
            "redeemPyToSy(address,address,uint256,uint256)",
            address(boringVault),
            getAddress(sourceChain, "pendleEethYt"),
            0.1e18,
            0
        );
        DecoderCustomTypes.TokenOutput memory tokenOutput = DecoderCustomTypes.TokenOutput(
            getAddress(sourceChain, "WEETH"), 0, getAddress(sourceChain, "WEETH"), address(0), swapData
        );
        targetData[12] = abi.encodeWithSignature(
            "redeemSyToToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            address(boringVault),
            getAddress(sourceChain, "pendleWeethSy"),
            1e18,
            tokenOutput
        );

        address[] memory decodersAndSanitizers = new address[](13);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[8] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[9] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[10] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[11] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[12] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](13);

        // Change token input to try and swap.
        tokenInput = DecoderCustomTypes.TokenInput(
            getAddress(sourceChain, "EETH"), 1_000e18, getAddress(sourceChain, "WEETH"), address(0), swapData
        );
        targetData[5] = abi.encodeWithSignature(
            "mintSyFromToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            address(boringVault),
            getAddress(sourceChain, "pendleWeethSy"),
            0,
            tokenInput
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                PendleRouterDecoderAndSanitizer.PendleRouterDecoderAndSanitizer__AggregatorSwapsNotPermitted.selector
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Fix tokenInput
        tokenInput = DecoderCustomTypes.TokenInput(
            getAddress(sourceChain, "WEETH"), 1_000e18, getAddress(sourceChain, "WEETH"), address(0), swapData
        );
        targetData[5] = abi.encodeWithSignature(
            "mintSyFromToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            address(boringVault),
            getAddress(sourceChain, "pendleWeethSy"),
            0,
            tokenInput
        );

        // Try to make a swap when exiting
        tokenOutput = DecoderCustomTypes.TokenOutput(
            getAddress(sourceChain, "EETH"), 0, getAddress(sourceChain, "WEETH"), address(0), swapData
        );
        targetData[12] = abi.encodeWithSignature(
            "redeemSyToToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            address(boringVault),
            getAddress(sourceChain, "pendleWeethSy"),
            1e18,
            tokenOutput
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                PendleRouterDecoderAndSanitizer.PendleRouterDecoderAndSanitizer__AggregatorSwapsNotPermitted.selector
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Fix tokenOutput
        tokenOutput = DecoderCustomTypes.TokenOutput(
            getAddress(sourceChain, "WEETH"), 0, getAddress(sourceChain, "WEETH"), address(0), swapData
        );
        targetData[12] = abi.encodeWithSignature(
            "redeemSyToToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            address(boringVault),
            getAddress(sourceChain, "pendleWeethSy"),
            1e18,
            tokenOutput
        );

        // Call now works.
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
