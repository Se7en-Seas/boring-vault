// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {UManager, FixedPointMathLib, ManagerWithMerkleVerification, ERC20} from "src/micro-managers/UManager.sol";
import {IUniswapV3Router} from "src/interfaces/IUniswapV3Router.sol";
import {PriceRouter} from "src/interfaces/PriceRouter.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";

/**
 * Required Merkle Root Leaves
 * - ERC20 approves with `router` spender.
 * - IUniswapV3Router.exactInput(params), with all desired paths.
 */
contract DexSwapperUManager is UManager {
    using FixedPointMathLib for uint256;

    // ========================================= STRUCTS =========================================
    /**
     * @notice Data needed to swap in a Curve pool
     * @dev This was made into a struct to prevent stack too deep errors.
     */
    struct CurveInfo {
        address pool;
        ERC20 assetIn;
        ERC20 assetOut;
        bytes4 selector;
    }

    // ========================================= CONSTANTS =========================================

    uint256 internal constant MAX_SLIPPAGE = 0.1e4;

    // ========================================= STATE =========================================

    /**
     * @notice Slippage check enforced after swaps.
     */
    uint16 public allowedSlippage = 0.0005e4;

    //============================== ERRORS ===============================

    error DexSwapperUManager__Slippage();
    error DexSwapperUManager__NewSlippageTooLarge();
    error DexSwapperUManager__UniswapV3BadPathOrFees();

    //============================== EVENTS ===============================

    event SlippageUpdated(uint16 oldSlippage, uint16 newSlippage);

    //============================== IMMUTABLES ===============================

    /**
     * @notice The UniswapV3 Router.
     */
    IUniswapV3Router internal immutable router;

    /**
     * @notice The BalancerVault this uManager works with.
     */
    BalancerVault internal immutable balancerVault;

    /**
     * @notice The PriceRouter contract used to check slippage.
     */
    PriceRouter internal immutable priceRouter;

    constructor(
        address _owner,
        address _manager,
        address _boringVault,
        address _router,
        address _balancerVault,
        address _priceRouter
    ) UManager(_owner, _manager, _boringVault) {
        router = IUniswapV3Router(_router);
        balancerVault = BalancerVault(_balancerVault);
        priceRouter = PriceRouter(_priceRouter);
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Sets the maximum allowed slippage during a swap.
     * @dev Callable by MULTISIG_ROLE.
     */
    function setAllowedSlippage(uint16 _allowedSlippage) external requiresAuth {
        if (_allowedSlippage > MAX_SLIPPAGE) revert DexSwapperUManager__NewSlippageTooLarge();
        emit SlippageUpdated(allowedSlippage, _allowedSlippage);
        allowedSlippage = _allowedSlippage;
    }

    /**
     * @notice Performs a swap using the UniswapV3 Router, and enforces a slippage check.
     * @param manageProofs 2 manage proofs, the first one for the ERC20 approval, and the second
     *        for the router exactInput call
     * @param decodersAndSanitizers 2 DecodersAndSanitizers one that implements ERC20 approve, and one that
     *        implements IUniswapV3Router.exactInput(params)
     * @param path the ERC20 token swap path
     * @param fees the fees to specify which pools to swap with
     * @param amountIn the amount of path[0] to swap
     * @param amountOutMinimum the minimum amount of path[path.length - 1] to get out from the swap
     * @param deadline the swap deadline
     * @dev Callable by STRATEGIST_ROLE.
     */
    function swapWithUniswapV3(
        bytes32[][] calldata manageProofs,
        address[] calldata decodersAndSanitizers,
        ERC20[] memory path,
        uint24[] memory fees,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint256 deadline
    ) external requiresAuth enforceRateLimit {
        address[] memory targets = new address[](2);
        bytes[] memory targetData = new bytes[](2);
        uint256[] memory values = new uint256[](2);
        // Build first approve data.
        targets[0] = address(path[0]);
        targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(router), amountIn);
        // values[0] = 0;

        // Build ExactInputParams.
        {
            if (path.length - 1 != fees.length) revert DexSwapperUManager__UniswapV3BadPathOrFees();
            bytes memory packedPath = abi.encodePacked(path[0]);
            for (uint256 i; i < fees.length; ++i) {
                packedPath = abi.encodePacked(packedPath, fees[i], path[i + 1]);
            }
            IUniswapV3Router.ExactInputParams memory params = IUniswapV3Router.ExactInputParams({
                path: packedPath,
                recipient: boringVault,
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: amountOutMinimum
            });
            targets[1] = address(router);
            targetData[1] = abi.encodeWithSelector(IUniswapV3Router.exactInput.selector, params);
            // values[1] = 0;
        }

        ERC20 tokenOut = path[path.length - 1];
        uint256 tokenOutBalanceDelta = tokenOut.balanceOf(boringVault);

        // Make the manage call.
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        tokenOutBalanceDelta = tokenOut.balanceOf(boringVault) - tokenOutBalanceDelta;

        uint256 tokenOutQuotedInTokenIn = priceRouter.getValue(tokenOut, tokenOutBalanceDelta, path[0]);

        if (tokenOutQuotedInTokenIn < amountIn.mulDivDown(1e4 - allowedSlippage, 1e4)) {
            revert DexSwapperUManager__Slippage();
        }

        // Check that full allowance was used, if not reuse the first proof and revoke it.
        if (path[0].allowance(boringVault, address(router)) > 0) {
            bytes32[][] memory revokeApproveProof = new bytes32[][](1);
            revokeApproveProof[0] = manageProofs[0];
            address[] memory revokeApproveDecodersAndSanitizers = new address[](1);
            revokeApproveDecodersAndSanitizers[0] = decodersAndSanitizers[0];
            targets = new address[](1);
            targetData = new bytes[](1);
            values = new uint256[](1);
            targets[0] = address(path[0]);
            targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(router), 0);

            // Revoke unused approval.
            manager.manageVaultWithMerkleVerification(
                revokeApproveProof, revokeApproveDecodersAndSanitizers, targets, targetData, values
            );
        }
    }

    /**
     * @notice Performs a swap using the BalancerV2 Vault, and enforces a slippage check.
     * @param manageProofs 2 manage proofs, the first one for the ERC20 approval, and the second for the swap
     * @param decodersAndSanitizers 2 DecodersAndSanitizers one that implements ERC20 approve, and one that implements BalancerV2Vault.swap
     * @param singleSwap the swap data
     * @param funds the fund management data
     * @param limit the maximum amount of assetIn to swap, or the minimum amount of assets out to receive
     * @param deadline the swap deadline
     * @dev Callable by STRATEGIST_ROLE.
     */
    function swapWithBalancerV2(
        bytes32[][] calldata manageProofs,
        address[] calldata decodersAndSanitizers,
        DecoderCustomTypes.SingleSwap calldata singleSwap,
        DecoderCustomTypes.FundManagement calldata funds,
        uint256 limit,
        uint256 deadline
    ) external requiresAuth enforceRateLimit {
        address[] memory targets = new address[](2);
        bytes[] memory targetData = new bytes[](2);
        uint256[] memory values = new uint256[](2);
        // Build first approve data.
        targets[0] = singleSwap.assetIn;
        uint256 approvalAmount = singleSwap.kind == DecoderCustomTypes.SwapKind.GIVEN_IN ? singleSwap.amount : limit;
        targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(balancerVault), approvalAmount);
        // values[0] = 0;

        targets[1] = address(balancerVault);
        targetData[1] = abi.encodeWithSelector(balancerVault.swap.selector, singleSwap, funds, limit, deadline);
        // values[0] = 0;

        uint256 tokenInDelta = singleSwap.kind == DecoderCustomTypes.SwapKind.GIVEN_IN
            ? singleSwap.amount
            : ERC20(singleSwap.assetIn).balanceOf(boringVault);
        uint256 tokenOutDelta = singleSwap.kind == DecoderCustomTypes.SwapKind.GIVEN_OUT
            ? singleSwap.amount
            : ERC20(singleSwap.assetOut).balanceOf(boringVault);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        if (singleSwap.kind == DecoderCustomTypes.SwapKind.GIVEN_IN) {
            tokenOutDelta = ERC20(singleSwap.assetOut).balanceOf(boringVault) - tokenOutDelta;
        } else {
            tokenInDelta = tokenInDelta - ERC20(singleSwap.assetIn).balanceOf(boringVault);
        }

        uint256 tokenOutQuotedInTokenIn =
            priceRouter.getValue(ERC20(singleSwap.assetOut), tokenOutDelta, ERC20(singleSwap.assetIn));

        if (tokenOutQuotedInTokenIn < tokenInDelta.mulDivDown(1e4 - allowedSlippage, 1e4)) {
            revert DexSwapperUManager__Slippage();
        }

        // Check that full allowance was used, if not reuse the first proof and revoke it.
        if (ERC20(singleSwap.assetIn).allowance(boringVault, address(balancerVault)) > 0) {
            bytes32[][] memory revokeApproveProof = new bytes32[][](1);
            revokeApproveProof[0] = manageProofs[0];
            address[] memory revokeApproveDecodersAndSanitizers = new address[](1);
            revokeApproveDecodersAndSanitizers[0] = decodersAndSanitizers[0];
            targets = new address[](1);
            targetData = new bytes[](1);
            values = new uint256[](1);
            targets[0] = singleSwap.assetIn;
            targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(balancerVault), 0);

            // Revoke unused approval.
            manager.manageVaultWithMerkleVerification(
                revokeApproveProof, revokeApproveDecodersAndSanitizers, targets, targetData, values
            );
        }
    }

    /**
     * @notice Performs a swap using a Curve pool, and enforces a slippage check.
     * @param manageProofs 2 manage proofs, the first one for the ERC20 approval, and the second for the swap
     * @param decodersAndSanitizers 2 DecodersAndSanitizers one that implements ERC20 approve, and one that implements CurvePool.exchange
     * @param info the Curve pool info
     * @param i the index of the token to swap from
     * @param j the index of the token to swap to
     * @param dx the amount of token i to swap
     * @param min_dy the minimum amount of token j to receive
     * @dev Callable by STRATEGIST_ROLE.
     */
    function swapWithCurve(
        bytes32[][] memory manageProofs,
        address[] memory decodersAndSanitizers,
        CurveInfo memory info,
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 min_dy
    ) external requiresAuth enforceRateLimit {
        address[] memory targets = new address[](2);
        bytes[] memory targetData = new bytes[](2);
        uint256[] memory values = new uint256[](2);
        // Build first approve data.
        targets[0] = address(info.assetIn);
        targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, info.pool, dx);
        // values[0] = 0;

        targets[1] = info.pool;
        targetData[1] = abi.encodeWithSelector(info.selector, i, j, dx, min_dy);
        // values[0] = 0;

        uint256 tokenOutDelta = info.assetOut.balanceOf(boringVault);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        tokenOutDelta = info.assetOut.balanceOf(boringVault) - tokenOutDelta;

        uint256 tokenOutQuotedInTokenIn = priceRouter.getValue(info.assetOut, tokenOutDelta, info.assetIn);

        if (tokenOutQuotedInTokenIn < dx.mulDivDown(1e4 - allowedSlippage, 1e4)) {
            revert DexSwapperUManager__Slippage();
        }

        // Check that full allowance was used, if not reuse the first proof and revoke it.
        if (info.assetIn.allowance(boringVault, info.pool) > 0) {
            bytes32[][] memory revokeApproveProof = new bytes32[][](1);
            revokeApproveProof[0] = manageProofs[0];
            address[] memory revokeApproveDecodersAndSanitizers = new address[](1);
            revokeApproveDecodersAndSanitizers[0] = decodersAndSanitizers[0];
            targets = new address[](1);
            targetData = new bytes[](1);
            values = new uint256[](1);
            targets[0] = address(info.assetIn);
            targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, info.pool, 0);

            // Revoke unused approval.
            manager.manageVaultWithMerkleVerification(
                revokeApproveProof, revokeApproveDecodersAndSanitizers, targets, targetData, values
            );
        }
    }
}
