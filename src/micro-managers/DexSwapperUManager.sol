// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IUniswapV3Router} from "src/interfaces/IUniswapV3Router.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {PriceRouter} from "src/interfaces/PriceRouter.sol";

/**
 * Required Merkle Root Leaves
 * - ERC20 approves with `router` spender.
 * - IUniswapV3Router.exactInput(params), with all desired paths.
 */
contract DexSwapperUManager is Auth {
    using FixedPointMathLib for uint256;

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
     * @notice The ManagerWithMerkleVerification this uManager works with.
     */
    ManagerWithMerkleVerification internal immutable manager;

    /**
     * @notice The BoringVault this uManager works with.
     */
    address internal immutable boringVault;

    /**
     * @notice The UniswapV3 Router.
     */
    IUniswapV3Router internal immutable router;

    /**
     * @notice The PriceRouter contract used to check slippage.
     */
    PriceRouter internal immutable priceRouter;

    constructor(address _owner, address _manager, address _boringVault, address _router, address _priceRouter)
        Auth(_owner, Authority(address(0)))
    {
        manager = ManagerWithMerkleVerification(_manager);
        boringVault = _boringVault;
        router = IUniswapV3Router(_router);
        priceRouter = PriceRouter(_priceRouter);
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Sets the maximum allowed slippage during a swap.
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
     */
    function swapWithUniswapV3(
        bytes32[][] calldata manageProofs,
        address[] calldata decodersAndSanitizers,
        ERC20[] memory path,
        uint24[] memory fees,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint256 deadline
    ) external requiresAuth {
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
     * @notice Allows auth to set token approvals to zero.
     */
    function revokeTokenApproval(
        bytes32[][] calldata manageProofs,
        address[] calldata decodersAndSanitizers,
        ERC20[] calldata tokens,
        address[] calldata spenders
    ) external requiresAuth {
        uint256 tokensLength = tokens.length;
        address[] memory targets = new address[](tokensLength);
        bytes[] memory targetData = new bytes[](tokensLength);
        uint256[] memory values = new uint256[](tokensLength);

        for (uint256 i; i < tokensLength; ++i) {
            targets[i] = address(tokens[i]);
            targetData[i] = abi.encodeWithSelector(ERC20.approve.selector, spenders[i], 0);
            // values[i] = 0;
        }

        // Make the manage call.
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }
}
