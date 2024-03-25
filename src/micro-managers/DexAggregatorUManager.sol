// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {AggregationRouterV5} from "src/interfaces/AggregationRouterV5.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {PriceRouter} from "src/interfaces/PriceRouter.sol";

// TODO should this implement some swap rate limiting logic?
/**
 * Required Merkle Root Leaves
 * - ERC20 approves with `router` spender.
 * - AggregationRouterV5.swap, with all desired addresses.
 */
contract DexAggregatorUManager is Auth {
    using FixedPointMathLib for uint256;

    // ========================================= CONSTANTS =========================================

    uint256 internal constant MAX_SLIPPAGE = 0.1e4;

    // ========================================= STATE =========================================

    /**
     * @notice Slippage check enforced after swaps.
     */
    uint16 public allowedSlippage = 0.0005e4;

    //============================== ERRORS ===============================

    error DexAggregatorUManager__Slippage();
    error DexAggregatorUManager__NewSlippageTooLarge();

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
     * @notice The 1Inch Router.
     */
    AggregationRouterV5 internal immutable router;

    /**
     * @notice The PriceRouter contract used to check slippage.
     */
    PriceRouter internal immutable priceRouter;

    constructor(address _owner, address _manager, address _boringVault, address _router, address _priceRouter)
        Auth(_owner, Authority(address(0)))
    {
        manager = ManagerWithMerkleVerification(_manager);
        boringVault = _boringVault;
        router = AggregationRouterV5(_router);
        priceRouter = PriceRouter(_priceRouter);
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Sets the maximum allowed slippage during a swap.
     */
    function setAllowedSlippage(uint16 _allowedSlippage) external requiresAuth {
        if (_allowedSlippage > MAX_SLIPPAGE) revert DexAggregatorUManager__NewSlippageTooLarge();
        emit SlippageUpdated(allowedSlippage, _allowedSlippage);
        allowedSlippage = _allowedSlippage;
    }

    /**
     * @notice Performs a swap using the 1inch Router, and enforces a slippage check.
     * @param manageProofs 2 manage proofs, the first one for the ERC20 approval, and the second
     *        for the router swap call
     * @param decodersAndSanitizers 2 DecodersAndSanitizers one that implements ERC20 approve, and one that
     *        implements AggregationRouterV5.swap
     */
    function swapWith1Inch(
        bytes32[][] calldata manageProofs,
        address[] calldata decodersAndSanitizers,
        ERC20 tokenIn,
        uint256 amountIn,
        ERC20 tokenOut,
        bytes calldata data
    ) external requiresAuth {
        address[] memory targets = new address[](2);
        bytes[] memory targetData = new bytes[](2);
        uint256[] memory values = new uint256[](2);
        // Build approve data.
        targets[0] = address(tokenIn);
        targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(router), amountIn);
        // values[0] = 0;

        // Build swap data
        targets[1] = address(router);
        targetData[1] = data;
        // values[1] = 0;

        uint256 tokenOutBalanceDelta = tokenOut.balanceOf(boringVault);

        // Make the manage call.
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        tokenOutBalanceDelta = tokenOut.balanceOf(boringVault) - tokenOutBalanceDelta;

        uint256 tokenOutQuotedInTokenIn = priceRouter.getValue(tokenOut, tokenOutBalanceDelta, tokenIn);

        // Check slippage.
        if (tokenOutQuotedInTokenIn < amountIn.mulDivDown(1e4 - allowedSlippage, 1e4)) {
            revert DexAggregatorUManager__Slippage();
        }

        // Check that full allowance was used, if not reuse the first proof and revoke it.
        if (tokenIn.allowance(boringVault, address(router)) > 0) {
            bytes32[][] memory revokeApproveProof = new bytes32[][](1);
            revokeApproveProof[0] = manageProofs[0];
            address[] memory revokeApproveDecodersAndSanitizers = new address[](1);
            revokeApproveDecodersAndSanitizers[0] = decodersAndSanitizers[0];
            targets = new address[](1);
            targetData = new bytes[](1);
            values = new uint256[](1);
            targets[0] = address(tokenIn);
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
