// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {AddressDecoder} from "src/base/AddressDecoder.sol";
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

    BoringVault public boring_vault;
    ManagerWithMerkleVerification public manager;
    TellerWithMultiAssetSupport public teller;
    AccountantWithRateProviders public accountant;
    AtomicQueue public atomic_queue;
    AtomicSolver public atomic_solver;
    address public addressDecoder;

    address public multisig = vm.addr(123456789);
    address public strategist = vm.addr(987654321);
    address public payout_address = vm.addr(777);
    address public weth_user = vm.addr(11);
    address public eeth_user = vm.addr(111);
    address public weeth_user = vm.addr(1111);
    ERC20 internal constant NATIVE_ERC20 = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    address public balancer_vault = vault;
    address public weEth_oracle = 0x3fa58b74e9a8eA8768eb33c8453e9C2Ed089A40a;
    address public weEth_irm = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19369928;
        _startFork(rpcKey, blockNumber);

        boring_vault = new BoringVault(multisig, "Boring Vault", "BV", 18);

        manager = new ManagerWithMerkleVerification(multisig, strategist, multisig, address(boring_vault), vault);

        accountant = new AccountantWithRateProviders(
            multisig,
            strategist,
            multisig,
            address(boring_vault),
            payout_address,
            1e18,
            address(WETH),
            1.001e4,
            0.999e4,
            1,
            0.2e4,
            0.01e4
        );

        teller = new TellerWithMultiAssetSupport(multisig, address(boring_vault), address(accountant), address(WETH));

        addressDecoder = address(new AddressDecoder());

        // Deploy queue.
        atomic_queue = new AtomicQueue();
        atomic_solver = new AtomicSolver(address(this), vault);

        vm.startPrank(multisig);
        boring_vault.grantRole(boring_vault.MINTER_ROLE(), address(teller));
        boring_vault.grantRole(boring_vault.BURNER_ROLE(), address(teller));
        boring_vault.grantRole(boring_vault.MANAGER_ROLE(), address(manager));
        manager.setAddressDecoder(address(addressDecoder));
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
        WETH.safeApprove(address(boring_vault), wETH_amount);
        teller.deposit(WETH, wETH_amount, 0, weth_user);
        vm.stopPrank();

        vm.startPrank(eeth_user);
        EETH.safeApprove(address(boring_vault), eETH_amount);
        teller.deposit(EETH, eETH_amount, 0, eeth_user);
        vm.stopPrank();

        vm.startPrank(weeth_user);
        WEETH.safeApprove(address(boring_vault), weETH_amount);
        teller.deposit(WEETH, weETH_amount, 0, weeth_user);
        vm.stopPrank();
    }

    function testWithdraw() external {}

    function testComplexStrategy() external {
        address[] memory allowed_address_arguments = new address[](16);
        allowed_address_arguments[0] = address(manager); // Flash loan recipient
        allowed_address_arguments[1] = address(WETH); // Flash loan borrow token, and for supply collateral loan token
        allowed_address_arguments[2] = address(boring_vault); // For on behalf of in morpho blue supplyCollateral
        allowed_address_arguments[3] = address(WEETH); // for supplyCollateral collateral token, and approve WEETH to spend our EETH
        allowed_address_arguments[4] = weEth_oracle; // The oracle needed for morpho blue market
        allowed_address_arguments[5] = weEth_irm; // The irm needed for morpho blue market
        allowed_address_arguments[6] = morphoBlue; // so we can approve it to spend WEETH.
        allowed_address_arguments[7] = uniswapV3PositionManager; // so we can approve it to spend WEETH.

        TargetSignature[] memory allowed_targets_selectors = new TargetSignature[](16);
        allowed_targets_selectors[0] = TargetSignature(address(WEETH), "wrap(uint256)");
        allowed_targets_selectors[1] = TargetSignature(balancer_vault, "flashLoan(address,address[],uint256[],bytes)");
        allowed_targets_selectors[2] = TargetSignature(address(WETH), "withdraw(uint256)");
        allowed_targets_selectors[3] = TargetSignature(EETH_LIQUIDITY_POOL, "deposit()");
        allowed_targets_selectors[4] = TargetSignature(
            morphoBlue, "supplyCollateral((address,address,address,address,uint256),uint256,address,bytes)"
        );
        allowed_targets_selectors[5] = TargetSignature(
            morphoBlue, "borrow((address,address,address,address,uint256),uint256,uint256,address,address)"
        );
        allowed_targets_selectors[6] = TargetSignature(address(EETH), "approve(address,uint256)");
        allowed_targets_selectors[7] = TargetSignature(address(WEETH), "approve(address,uint256)");
        allowed_targets_selectors[8] = TargetSignature(address(WETH), "approve(address,uint256)");

        (bytes32[][] memory allowed_targets_and_selectors_tree, bytes32[][] memory allowed_address_argument_tree) =
            _generateMerkleTrees(allowed_targets_selectors, allowed_address_arguments);

        vm.startPrank(multisig);
        manager.setAllowedTargetSelectorRoot(
            allowed_targets_and_selectors_tree[allowed_targets_and_selectors_tree.length - 1][0]
        );
        manager.setAllowedAddressArgumentRoot(
            allowed_address_argument_tree[allowed_address_argument_tree.length - 1][0]
        );
        vm.stopPrank();

        bytes32[][] memory target_proofs;
        bytes32[][][] memory arguments_proofs;
        address[] memory targets;
        bytes[] memory target_data;
        address[][] memory address_arguments;
        bytes memory flash_loan_data;
        {
            uint256 wEthToBorrow = 90e18 + 1;

            uint256[] memory values_in_flashloan = new uint256[](7);
            values_in_flashloan[1] = wEthToBorrow;

            targets = new address[](7);
            targets[0] = address(WETH);
            targets[1] = EETH_LIQUIDITY_POOL;
            targets[2] = address(EETH);
            targets[3] = address(WEETH);
            targets[4] = address(WEETH);
            targets[5] = morphoBlue;
            targets[6] = morphoBlue;

            string[] memory function_signatures_in_flashloan = new string[](7);
            function_signatures_in_flashloan[0] = "withdraw(uint256)";
            function_signatures_in_flashloan[1] = "deposit()";
            function_signatures_in_flashloan[2] = "approve(address,uint256)";
            function_signatures_in_flashloan[3] = "wrap(uint256)";
            function_signatures_in_flashloan[4] = "approve(address,uint256)";
            function_signatures_in_flashloan[5] =
                "supplyCollateral((address,address,address,address,uint256),uint256,address,bytes)";
            function_signatures_in_flashloan[6] =
                "borrow((address,address,address,address,uint256),uint256,uint256,address,address)";

            target_data = new bytes[](7);
            target_data[0] = abi.encodeWithSignature("withdraw(uint256)", wEthToBorrow); // Unwrap ETH
            target_data[1] = abi.encodeWithSignature("deposit()"); // convert ETH to eETH
            target_data[2] = abi.encodeWithSignature("approve(address,uint256)", address(WEETH), wEthToBorrow - 1); // approve weETH to spend eETH
            target_data[3] = abi.encodeWithSignature("wrap(uint256)", wEthToBorrow - 1); // wrap eETH for weETH
            target_data[4] = abi.encodeWithSignature("approve(address,uint256)", morphoBlue, type(uint256).max); // approve morpho blue to spend weETH
            target_data[5] = abi.encodeWithSignature(
                "supplyCollateral((address,address,address,address,uint256),uint256,address,bytes)",
                WETH,
                WEETH,
                weEth_oracle,
                weEth_irm,
                0.86e18,
                200e18,
                address(boring_vault),
                hex""
            ); // supply 100 weETH as collateral
            target_data[6] = abi.encodeWithSignature(
                "borrow((address,address,address,address,uint256),uint256,uint256,address,address)",
                WETH,
                WEETH,
                weEth_oracle,
                weEth_irm,
                0.86e18,
                wEthToBorrow,
                0,
                address(boring_vault),
                address(boring_vault)
            ); // Borrow wETH to repay loan

            address_arguments = new address[][](7);
            address_arguments[2] = new address[](1);
            address_arguments[2][0] = address(WEETH);

            address_arguments[4] = new address[](1);
            address_arguments[4][0] = address(morphoBlue);

            address_arguments[5] = new address[](5);
            address_arguments[5][0] = address(WETH);
            address_arguments[5][1] = address(WEETH);
            address_arguments[5][2] = address(weEth_oracle);
            address_arguments[5][3] = address(weEth_irm);
            address_arguments[5][4] = address(boring_vault);
            address_arguments[6] = new address[](6);
            address_arguments[6][0] = address(WETH);
            address_arguments[6][1] = address(WEETH);
            address_arguments[6][2] = address(weEth_oracle);
            address_arguments[6][3] = address(weEth_irm);
            address_arguments[6][4] = address(boring_vault);
            address_arguments[6][5] = address(boring_vault);

            (target_proofs, arguments_proofs) = _getProofsUsingTrees(
                targets,
                target_data,
                address_arguments,
                allowed_targets_and_selectors_tree,
                allowed_address_argument_tree
            );

            flash_loan_data = abi.encode(
                target_proofs,
                arguments_proofs,
                function_signatures_in_flashloan,
                targets,
                target_data,
                values_in_flashloan
            );
        }

        string[] memory function_signatures = new string[](5);
        function_signatures[0] = "approve(address,uint256)";
        function_signatures[1] = "wrap(uint256)";
        function_signatures[2] = "flashLoan(address,address[],uint256[],bytes)";
        function_signatures[3] = "approve(address,uint256)";
        function_signatures[4] = "approve(address,uint256)";

        uint256[] memory values = new uint256[](5);

        targets = new address[](5);
        targets[0] = address(EETH);
        targets[1] = address(WEETH);
        targets[2] = address(balancer_vault);
        targets[3] = address(WETH);
        targets[4] = address(WEETH);

        address[] memory tokens_to_borrow = new address[](1);
        tokens_to_borrow[0] = address(WETH);

        uint256[] memory amounts_to_borrow = new uint256[](1);
        amounts_to_borrow[0] = 90e18 + 1;

        target_data = new bytes[](5);
        target_data[0] = abi.encodeWithSignature("approve(address,uint256)", address(WEETH), 500e18); // approve weETH to spend eETH
        target_data[1] = abi.encodeWithSignature("wrap(uint256)", 500e18); // Wrap eETH for weETH.
        target_data[2] = abi.encodeWithSignature(
            "flashLoan(address,address[],uint256[],bytes)",
            address(manager),
            tokens_to_borrow,
            amounts_to_borrow,
            flash_loan_data
        ); // Perform flash loan
        target_data[3] = abi.encodeWithSignature("approve(address,uint256)", uniswapV3PositionManager, 100e18); // approve uniswap positions to spend wETH
        target_data[4] = abi.encodeWithSignature("approve(address,uint256)", uniswapV3PositionManager, 100e18); // approve uniswap positions to spend weETH

        address_arguments = new address[][](5);
        address_arguments[0] = new address[](1);
        address_arguments[0][0] = address(WEETH);
        address_arguments[2] = new address[](2);
        address_arguments[2][0] = address(manager);
        address_arguments[2][1] = address(WETH);
        address_arguments[3] = new address[](1);
        address_arguments[3][0] = uniswapV3PositionManager;
        address_arguments[4] = new address[](1);
        address_arguments[4][0] = uniswapV3PositionManager;

        (target_proofs, arguments_proofs) = _getProofsUsingTrees(
            targets, target_data, address_arguments, allowed_targets_and_selectors_tree, allowed_address_argument_tree
        );

        vm.startPrank(strategist);
        uint256 gas = gasleft();
        manager.manageVaultWithMerkleVerification(
            target_proofs, arguments_proofs, function_signatures, targets, target_data, values
        );
        console.log("Gas For Rebalance", gas - gasleft());
        vm.stopPrank();

        // take all eETH and wrap it.
        // balancer flashloan 90 weth
        // - unwrap, then mint EETH
        // - wrap EETH
        // - use 200 weETH as collateral on morpho blue, and borrow 90 weth to repay loan.

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

    function _getProofsUsingTrees(
        address[] memory targets,
        bytes[] memory target_data,
        address[][] memory address_arguments,
        bytes32[][] memory target_tree,
        bytes32[][] memory argument_tree
    ) internal pure returns (bytes32[][] memory target_proofs, bytes32[][][] memory argument_proofs) {
        target_proofs = new bytes32[][](targets.length);
        argument_proofs = new bytes32[][][](targets.length);
        for (uint256 i; i < targets.length; ++i) {
            // First generate target proof.
            bytes32 target_leaf = keccak256(abi.encodePacked(targets[i], bytes4(target_data[i])));
            target_proofs[i] = _generateProof(target_leaf, target_tree);
            // Iterate through address arguments for target and generate argument proofs.
            argument_proofs[i] = new bytes32[][](address_arguments[i].length);
            for (uint256 j; j < address_arguments[i].length; ++j) {
                bytes32 argument_leaf = keccak256(abi.encodePacked(address_arguments[i][j]));
                argument_proofs[i][j] = _generateProof(argument_leaf, argument_tree);
            }
        }
    }

    function _buildTrees(bytes32[][] memory merkle_tree_in)
        internal
        pure
        returns (bytes32[][] memory merkle_tree_out)
    {
        // We are adding another row to the merkle tree, so make merkle_tree_out be 1 longer.
        uint256 merkle_tree_in_length = merkle_tree_in.length;
        merkle_tree_out = new bytes32[][](merkle_tree_in_length + 1);
        uint256 layer_length;
        // Iterate through merkle_tree_in to copy over data.
        for (uint256 i; i < merkle_tree_in_length; ++i) {
            layer_length = merkle_tree_in[i].length;
            merkle_tree_out[i] = new bytes32[](layer_length);
            for (uint256 j; j < layer_length; ++j) {
                merkle_tree_out[i][j] = merkle_tree_in[i][j];
            }
        }

        uint256 next_layer_length;
        if (layer_length % 2 != 0) {
            next_layer_length = (layer_length + 1) / 2;
        } else {
            next_layer_length = layer_length / 2;
        }
        merkle_tree_out[merkle_tree_in_length] = new bytes32[](next_layer_length);
        uint256 count;
        for (uint256 i; i < layer_length; i += 2) {
            merkle_tree_out[merkle_tree_in_length][count] = _hashPair(
                merkle_tree_in[merkle_tree_in_length - 1][i], merkle_tree_in[merkle_tree_in_length - 1][i + 1]
            );
            count++;
        }

        if (next_layer_length > 1) {
            // We need to process the next layer of leaves.
            merkle_tree_out = _buildTrees(merkle_tree_out);
        }
    }

    struct TargetSignature {
        address target;
        string signature;
    }

    function _generateMerkleTrees(TargetSignature[] memory targets_signatures, address[] memory address_arguments)
        internal
        pure
        returns (bytes32[][] memory target_selector_tree, bytes32[][] memory address_arguments_tree)
    {
        // Handle target selector first
        {
            uint256 targets_length = targets_signatures.length;
            bytes32[][] memory leafs = new bytes32[][](1);
            leafs[0] = new bytes32[](targets_length);
            for (uint256 i; i < targets_length; ++i) {
                bytes4 selector = bytes4(keccak256(abi.encodePacked(targets_signatures[i].signature)));
                leafs[0][i] = keccak256(abi.encodePacked(targets_signatures[i].target, selector));
            }
            target_selector_tree = _buildTrees(leafs);
        }

        // Handle address arguments
        {
            uint256 arguments_length = address_arguments.length;
            bytes32[][] memory leafs = new bytes32[][](1);
            leafs[0] = new bytes32[](arguments_length);
            for (uint256 i; i < arguments_length; ++i) {
                leafs[0][i] = keccak256(abi.encodePacked(address_arguments[i]));
            }
            address_arguments_tree = _buildTrees(leafs);
        }
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
