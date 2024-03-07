// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RawDataDecoderAndSanitizer} from "src/base/RawDataDecoderAndSanitizer.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {AtomicQueue} from "src/atomic-queue/AtomicQueue.sol";
import {AtomicSolver} from "src/atomic-queue/AtomicSolver.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {IWEETH} from "src/interfaces/IStaking.sol";
import {ILiquidityPool} from "src/interfaces/IStaking.sol";
import {WETH} from "@solmate/tokens/WETH.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract BoringVaultV0Test is Test, MainnetAddresses {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    BoringVault public boringVault;
    ManagerWithMerkleVerification public manager;
    TellerWithMultiAssetSupport public teller;
    AccountantWithRateProviders public accountant;
    AtomicQueue public atomic_queue;
    AtomicSolver public atomic_solver;
    address public rawDataDecoderAndSanitizer;

    address public multisig = vm.addr(123456789);
    address public strategist = vm.addr(987654321);
    address public payout_address = vm.addr(777);
    address public weth_user = vm.addr(11);
    address public eeth_user = vm.addr(111);
    address public weeth_user = vm.addr(1111);
    ERC20 internal constant NATIVE_ERC20 = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    address public balancer_vault = vault;
    address public weEthOracle = 0x3fa58b74e9a8eA8768eb33c8453e9C2Ed089A40a;
    address public weEthIrm = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19369928;
        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(multisig, "Boring Vault", "BV", 18);

        manager = new ManagerWithMerkleVerification(multisig, strategist, multisig, address(boringVault), vault);

        accountant = new AccountantWithRateProviders(
            multisig,
            strategist,
            multisig,
            address(boringVault),
            payout_address,
            1e18,
            address(WETH),
            1.001e4,
            0.999e4,
            1,
            0.01e4
        );

        teller = new TellerWithMultiAssetSupport(multisig, address(boringVault), address(accountant), address(WETH));

        rawDataDecoderAndSanitizer = address(new RawDataDecoderAndSanitizer(uniswapV3NonFungiblePositionManager));

        // Deploy queue.
        atomic_queue = new AtomicQueue();
        atomic_solver = new AtomicSolver(address(this), vault);

        vm.startPrank(multisig);
        boringVault.grantRole(boringVault.MINTER_ROLE(), address(teller));
        boringVault.grantRole(boringVault.BURNER_ROLE(), address(teller));
        boringVault.grantRole(boringVault.MANAGER_ROLE(), address(manager));
        manager.setRawDataDecoderAndSanitizer(address(rawDataDecoderAndSanitizer));
        accountant.setRateProviderData(EETH, true, address(0));
        accountant.setRateProviderData(WEETH, false, address(WEETH_RATE_PROVIDER));
        teller.grantRole(teller.ADMIN_ROLE(), multisig);
        teller.grantRole(teller.ON_RAMP_ROLE(), address(atomic_solver));
        teller.grantRole(teller.OFF_RAMP_ROLE(), address(atomic_solver));
        teller.addAsset(WETH);
        teller.addAsset(NATIVE_ERC20);
        teller.addAsset(EETH);
        teller.addAsset(WEETH);
        vm.stopPrank();

        uint256 wETH_amount = 1_500e18;
        deal(address(WETH), weth_user, wETH_amount);
        uint256 eETH_amount = 500e18;
        deal(eeth_user, eETH_amount + 1);
        vm.prank(eeth_user);
        ILiquidityPool(EETH_LIQUIDITY_POOL).deposit{value: eETH_amount + 1}();
        uint256 weETH_amount = uint256(1_000e18).mulDivDown(1e18, IRateProvider(WEETH_RATE_PROVIDER).getRate());
        deal(address(WEETH), weeth_user, weETH_amount);

        vm.startPrank(weth_user);
        WETH.safeApprove(address(boringVault), wETH_amount);
        teller.deposit(WETH, wETH_amount, 0, weth_user);
        vm.stopPrank();

        vm.startPrank(eeth_user);
        EETH.safeApprove(address(boringVault), eETH_amount);
        teller.deposit(EETH, eETH_amount, 0, eeth_user);
        vm.stopPrank();

        vm.startPrank(weeth_user);
        WEETH.safeApprove(address(boringVault), weETH_amount);
        teller.deposit(WEETH, weETH_amount, 0, weeth_user);
        vm.stopPrank();
    }

    function testWithdraw() external {}

    function testComplexStrategy() external {
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        leafs[0] = ManageLeaf(address(EETH), "approve(address,uint256)", new address[](1));
        leafs[0].argumentAddresses[0] = address(WEETH);
        leafs[1] = ManageLeaf(address(WEETH), "approve(address,uint256)", new address[](1));
        leafs[1].argumentAddresses[0] = morphoBlue;
        leafs[2] = ManageLeaf(address(WEETH), "wrap(uint256)", new address[](0));
        leafs[3] = ManageLeaf(address(WEETH), "unwrap(uint256)", new address[](0));
        leafs[4] = ManageLeaf(vault, "flashLoan(address,address[],uint256[],bytes)", new address[](2));
        leafs[4].argumentAddresses[0] = address(manager);
        leafs[4].argumentAddresses[1] = address(WETH);
        leafs[5] = ManageLeaf(address(WETH), "withdraw(uint256)", new address[](0));
        leafs[6] = ManageLeaf(address(EETH_LIQUIDITY_POOL), "deposit()", new address[](0));
        leafs[7] = ManageLeaf(
            morphoBlue,
            "supplyCollateral((address,address,address,address,uint256),uint256,address,bytes)",
            new address[](5)
        );
        leafs[7].argumentAddresses[0] = address(WETH);
        leafs[7].argumentAddresses[1] = address(WEETH);
        leafs[7].argumentAddresses[2] = weEthOracle;
        leafs[7].argumentAddresses[3] = weEthIrm;
        leafs[7].argumentAddresses[4] = address(boringVault);
        leafs[8] = ManageLeaf(
            morphoBlue,
            "borrow((address,address,address,address,uint256),uint256,uint256,address,address)",
            new address[](6)
        );
        leafs[8].argumentAddresses[0] = address(WETH);
        leafs[8].argumentAddresses[1] = address(WEETH);
        leafs[8].argumentAddresses[2] = weEthOracle;
        leafs[8].argumentAddresses[3] = weEthIrm;
        leafs[8].argumentAddresses[4] = address(boringVault);
        leafs[8].argumentAddresses[5] = address(boringVault);
        leafs[9] = ManageLeaf(address(WETH), "approve(address,uint256)", new address[](1));
        leafs[9].argumentAddresses[0] = uniswapV3PositionManager;
        leafs[10] = ManageLeaf(address(WEETH), "approve(address,uint256)", new address[](1));
        leafs[10].argumentAddresses[0] = uniswapV3PositionManager;

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        vm.startPrank(multisig);
        manager.setManageRoot(manageTree[manageTree.length - 1][0]);
        vm.stopPrank();

        bytes32[][] memory manageProofs;
        address[] memory targets;
        bytes[] memory targetData;
        bytes memory flashLoanData;
        {
            uint256 wEthToBorrow = 90e18 + 1;

            uint256[] memory valuesInFlashloan = new uint256[](7);
            valuesInFlashloan[1] = wEthToBorrow;

            targets = new address[](7);
            targets[0] = address(WETH);
            targets[1] = EETH_LIQUIDITY_POOL;
            targets[2] = address(EETH);
            targets[3] = address(WEETH);
            targets[4] = address(WEETH);
            targets[5] = morphoBlue;
            targets[6] = morphoBlue;

            string[] memory functionSignaturesInFlashLoan = new string[](7);
            functionSignaturesInFlashLoan[0] = "withdraw(uint256)";
            functionSignaturesInFlashLoan[1] = "deposit()";
            functionSignaturesInFlashLoan[2] = "approve(address,uint256)";
            functionSignaturesInFlashLoan[3] = "wrap(uint256)";
            functionSignaturesInFlashLoan[4] = "approve(address,uint256)";
            functionSignaturesInFlashLoan[5] =
                "supplyCollateral((address,address,address,address,uint256),uint256,address,bytes)";
            functionSignaturesInFlashLoan[6] =
                "borrow((address,address,address,address,uint256),uint256,uint256,address,address)";

            targetData = new bytes[](7);
            targetData[0] = abi.encodeWithSignature("withdraw(uint256)", wEthToBorrow); // Unwrap ETH
            targetData[1] = abi.encodeWithSignature("deposit()"); // convert ETH to eETH
            targetData[2] = abi.encodeWithSignature("approve(address,uint256)", address(WEETH), wEthToBorrow - 1); // approve weETH to spend eETH
            targetData[3] = abi.encodeWithSignature("wrap(uint256)", wEthToBorrow - 1); // wrap eETH for weETH
            targetData[4] = abi.encodeWithSignature("approve(address,uint256)", morphoBlue, type(uint256).max); // approve morpho blue to spend weETH
            targetData[5] = abi.encodeWithSignature(
                "supplyCollateral((address,address,address,address,uint256),uint256,address,bytes)",
                WETH,
                WEETH,
                weEthOracle,
                weEthIrm,
                0.86e18,
                200e18,
                address(boringVault),
                hex""
            ); // supply 100 weETH as collateral
            targetData[6] = abi.encodeWithSignature(
                "borrow((address,address,address,address,uint256),uint256,uint256,address,address)",
                WETH,
                WEETH,
                weEthOracle,
                weEthIrm,
                0.86e18,
                wEthToBorrow,
                0,
                address(boringVault),
                address(boringVault)
            ); // Borrow wETH to repay loan

            ManageLeaf[] memory flashLoanLeafs = new ManageLeaf[](7);
            flashLoanLeafs[0] = leafs[5];
            flashLoanLeafs[1] = leafs[6];
            flashLoanLeafs[2] = leafs[0];
            flashLoanLeafs[3] = leafs[2];
            flashLoanLeafs[4] = leafs[1];
            flashLoanLeafs[5] = leafs[7];
            flashLoanLeafs[6] = leafs[8];

            manageProofs = _getProofsUsingTree(flashLoanLeafs, manageTree);

            flashLoanData =
                abi.encode(manageProofs, functionSignaturesInFlashLoan, targets, targetData, valuesInFlashloan);
        }

        string[] memory functionSignatures = new string[](5);
        functionSignatures[0] = "approve(address,uint256)";
        functionSignatures[1] = "wrap(uint256)";
        functionSignatures[2] = "flashLoan(address,address[],uint256[],bytes)";
        functionSignatures[3] = "approve(address,uint256)";
        functionSignatures[4] = "approve(address,uint256)";

        uint256[] memory values = new uint256[](5);

        targets = new address[](5);
        targets[0] = address(EETH);
        targets[1] = address(WEETH);
        targets[2] = address(balancer_vault);
        targets[3] = address(WETH);
        targets[4] = address(WEETH);

        address[] memory tokensToBorrow = new address[](1);
        tokensToBorrow[0] = address(WETH);

        uint256[] memory amountsToBorrow = new uint256[](1);
        amountsToBorrow[0] = 90e18 + 1;

        targetData = new bytes[](5);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", address(WEETH), 500e18); // approve weETH to spend eETH
        targetData[1] = abi.encodeWithSignature("wrap(uint256)", 500e18); // Wrap eETH for weETH.
        targetData[2] = abi.encodeWithSignature(
            "flashLoan(address,address[],uint256[],bytes)",
            address(manager),
            tokensToBorrow,
            amountsToBorrow,
            flashLoanData
        ); // Perform flash loan
        targetData[3] = abi.encodeWithSignature("approve(address,uint256)", uniswapV3PositionManager, 100e18); // approve uniswap positions to spend wETH
        targetData[4] = abi.encodeWithSignature("approve(address,uint256)", uniswapV3PositionManager, 100e18); // approve uniswap positions to spend weETH

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](5);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[2];
        manageLeafs[2] = leafs[4];
        manageLeafs[3] = leafs[9];
        manageLeafs[4] = leafs[10];

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        // take all eETH and wrap it.
        // balancer flashloan 90 weth
        // - unwrap, then mint EETH
        // - wrap EETH
        // - use 200 weETH as collateral on morpho blue, and borrow 90 weth to repay loan.

        vm.startPrank(strategist);
        uint256 gas = gasleft();
        manager.manageVaultWithMerkleVerification(manageProofs, functionSignatures, targets, targetData, values);
        console.log("Gas For Rebalance", gas - gasleft());
        vm.stopPrank();

        // take 250 weETH and 250 wETH to join Uniswap V3 5 bps pool
        // take 250 weETH and 250 wETH to join the Curve pool
        // take 250 weETH and 250 wETH to join balancer ezETH, weETH, rswETH pool
        // take 100 weETH and mint pendle PT and YT tokens.
        // take 250 weETH and 250 wETH to LP into pendle LP weETH PT pool.
        // take 100 or so and deposit into sommelier vault

        // TODO also take some of thge curve and balancer LP and put it into convex/aura

        // Pass some time

        // Harest rewards, or simulate harvesting rewards

        // unwind all positions
    }
    //

    // ========================================= HELPER FUNCTIONS =========================================

    // TODO use the atomic queue to handle withdraws.
    function _handleWithdraw() internal {}

    function _generateProof(bytes32 leaf, bytes32[][] memory tree) internal pure returns (bytes32[] memory proof) {
        // The length of each proof is the height of the tree - 1.
        uint256 tree_length = tree.length;
        proof = new bytes32[](tree_length - 1);

        // Build the proof
        for (uint256 i; i < tree_length - 1; ++i) {
            // For each layer we need to find the leaf.
            for (uint256 j; j < tree[i].length; ++j) {
                if (leaf == tree[i][j]) {
                    // We have found the leaf, so now figure out if the proof needs the next leaf or the previous one.
                    proof[i] = j % 2 == 0 ? tree[i][j + 1] : tree[i][j - 1];
                    leaf = _hashPair(leaf, proof[i]);
                    break;
                }
            }
        }
    }

    function _getProofsUsingTree(ManageLeaf[] memory manageLeafs, bytes32[][] memory tree)
        internal
        pure
        returns (bytes32[][] memory proofs)
    {
        proofs = new bytes32[][](manageLeafs.length);
        for (uint256 i; i < manageLeafs.length; ++i) {
            // Generate manage proof.
            bytes4 selector = bytes4(keccak256(abi.encodePacked(manageLeafs[i].signature)));
            bytes memory rawDigest = abi.encodePacked(manageLeafs[i].target, selector);
            uint256 argumentAddressesLength = manageLeafs[i].argumentAddresses.length;
            for (uint256 j; j < argumentAddressesLength; ++j) {
                rawDigest = abi.encodePacked(rawDigest, manageLeafs[i].argumentAddresses[j]);
            }
            bytes32 leaf = keccak256(rawDigest);
            proofs[i] = _generateProof(leaf, tree);
        }
    }

    function _buildTrees(bytes32[][] memory merkleTreeIn) internal pure returns (bytes32[][] memory merkleTreeOut) {
        // We are adding another row to the merkle tree, so make merkleTreeOut be 1 longer.
        uint256 merkleTreeIn_length = merkleTreeIn.length;
        merkleTreeOut = new bytes32[][](merkleTreeIn_length + 1);
        uint256 layer_length;
        // Iterate through merkleTreeIn to copy over data.
        for (uint256 i; i < merkleTreeIn_length; ++i) {
            layer_length = merkleTreeIn[i].length;
            merkleTreeOut[i] = new bytes32[](layer_length);
            for (uint256 j; j < layer_length; ++j) {
                merkleTreeOut[i][j] = merkleTreeIn[i][j];
            }
        }

        uint256 next_layer_length;
        if (layer_length % 2 != 0) {
            next_layer_length = (layer_length + 1) / 2;
        } else {
            next_layer_length = layer_length / 2;
        }
        merkleTreeOut[merkleTreeIn_length] = new bytes32[](next_layer_length);
        uint256 count;
        for (uint256 i; i < layer_length; i += 2) {
            merkleTreeOut[merkleTreeIn_length][count] =
                _hashPair(merkleTreeIn[merkleTreeIn_length - 1][i], merkleTreeIn[merkleTreeIn_length - 1][i + 1]);
            count++;
        }

        if (next_layer_length > 1) {
            // We need to process the next layer of leaves.
            merkleTreeOut = _buildTrees(merkleTreeOut);
        }
    }

    struct ManageLeaf {
        address target;
        string signature;
        address[] argumentAddresses;
    }

    function _generateMerkleTree(ManageLeaf[] memory manageLeafs) internal pure returns (bytes32[][] memory tree) {
        uint256 leafsLength = manageLeafs.length;
        bytes32[][] memory leafs = new bytes32[][](1);
        leafs[0] = new bytes32[](leafsLength);
        for (uint256 i; i < leafsLength; ++i) {
            bytes4 selector = bytes4(keccak256(abi.encodePacked(manageLeafs[i].signature)));
            bytes memory rawDigest = abi.encodePacked(manageLeafs[i].target, selector);
            uint256 argumentAddressesLength = manageLeafs[i].argumentAddresses.length;
            for (uint256 j; j < argumentAddressesLength; ++j) {
                rawDigest = abi.encodePacked(rawDigest, manageLeafs[i].argumentAddresses[j]);
            }
            leafs[0][i] = keccak256(rawDigest);
        }
        tree = _buildTrees(leafs);
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
