// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract PendleRouterDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== ERRORS ===============================

    error PendleRouterDecoderAndSanitizer__AggregatorSwapsNotPermitted();
    error PendleRouterDecoderAndSanitizer__LimitOrderYtMismatch(address ytFound, address ytExpected);
    error PendleRouterDecoderAndSanitizer__NoBytes();

    //============================== PENDLEROUTER ===============================

    function mintSyFromToken(address user, address sy, uint256, DecoderCustomTypes.TokenInput calldata input)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        if (
            input.swapData.swapType != DecoderCustomTypes.SwapType.NONE || input.swapData.extRouter != address(0)
                || input.pendleSwap != address(0) || input.tokenIn != input.tokenMintSy
        ) revert PendleRouterDecoderAndSanitizer__AggregatorSwapsNotPermitted();

        addressesFound =
            abi.encodePacked(user, sy, input.tokenIn, input.tokenMintSy, input.pendleSwap, input.swapData.extRouter);
    }

    function mintPyFromSy(address user, address yt, uint256, uint256)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(user, yt);
    }

    function swapExactPtForYt(address user, address market, uint256, uint256, DecoderCustomTypes.ApproxParams calldata)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(user, market);
    }

    function swapExactYtForPt(address user, address market, uint256, uint256, DecoderCustomTypes.ApproxParams calldata)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(user, market);
    }

    function addLiquidityDualSyAndPt(address user, address market, uint256, uint256, uint256)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(user, market);
    }

    function removeLiquidityDualSyAndPt(address user, address market, uint256, uint256, uint256)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(user, market);
    }

    function redeemPyToSy(address user, address yt, uint256, uint256)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(user, yt);
    }

    function redeemSyToToken(address user, address sy, uint256, DecoderCustomTypes.TokenOutput calldata output)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        if (
            output.swapData.swapType != DecoderCustomTypes.SwapType.NONE || output.swapData.extRouter != address(0)
                || output.pendleSwap != address(0) || output.tokenOut != output.tokenRedeemSy
        ) revert PendleRouterDecoderAndSanitizer__AggregatorSwapsNotPermitted();

        addressesFound = abi.encodePacked(
            user, sy, output.tokenOut, output.tokenRedeemSy, output.pendleSwap, output.swapData.extRouter
        );
    }

    function redeemDueInterestAndRewards(
        address user,
        address[] calldata sys,
        address[] calldata yts,
        address[] calldata markets
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(user);
        uint256 sysLength = sys.length;
        for (uint256 i; i < sysLength; ++i) {
            addressesFound = abi.encodePacked(addressesFound, sys[i]);
        }
        uint256 ytsLength = yts.length;
        for (uint256 i; i < ytsLength; ++i) {
            addressesFound = abi.encodePacked(addressesFound, yts[i]);
        }
        uint256 marketsLength = markets.length;
        for (uint256 i; i < marketsLength; ++i) {
            addressesFound = abi.encodePacked(addressesFound, markets[i]);
        }
    }

    function swapExactSyForPt(
        address receiver,
        address market,
        uint256, /*exactSyIn*/
        uint256, /*minPtOut*/
        DecoderCustomTypes.ApproxParams calldata,
        DecoderCustomTypes.LimitOrderData calldata limit
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver, market, _sanitizeLimitOrderData(limit));
    }

    function swapExactPtForSy(
        address receiver,
        address market,
        uint256, /*exactPtIn*/
        uint256, /*minSyOut*/
        DecoderCustomTypes.LimitOrderData calldata limit
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver, market, _sanitizeLimitOrderData(limit));
    }

    function swapExactSyForYt(
        address receiver,
        address market,
        uint256, /*exactSyIn*/
        uint256, /*minYtOut*/
        DecoderCustomTypes.ApproxParams calldata, /*guessYtOut*/
        DecoderCustomTypes.LimitOrderData calldata limit
    ) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver, market, _sanitizeLimitOrderData(limit));
    }

    function swapExactYtForSy(
        address receiver,
        address market,
        uint256, /*exactYtIn*/
        uint256, /*minSyOut*/
        DecoderCustomTypes.LimitOrderData calldata limit
    ) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver, market, _sanitizeLimitOrderData(limit));
    }

    /**
     * @notice `params[i].order.token` is restricted to be either an input or an output token for the SY,
     *         so addressesFound only reports the YT address from the FillOrderParams, as the YT address derives
     *      The SY address which restricts the input and output tokens.
     */
    function fill(
        DecoderCustomTypes.FillOrderParams[] calldata params,
        address receiver,
        uint256, /*maxTaking*/
        bytes calldata optData,
        bytes calldata callback
    ) external pure virtual returns (bytes memory addressesFound) {
        if (optData.length > 0 || callback.length > 0) revert PendleRouterDecoderAndSanitizer__NoBytes();

        addressesFound = abi.encodePacked(receiver);

        address savedYt;
        // Iterate through params, and make sure all orders have the same yt.
        for (uint256 i; i < params.length; ++i) {
            if (savedYt == address(0)) {
                // Update saved yt.
                savedYt = params[i].order.YT;
            } else {
                // Make sure this orders YT matches the saved yt.
                if (savedYt != params[i].order.YT) {
                    revert PendleRouterDecoderAndSanitizer__LimitOrderYtMismatch(params[i].order.YT, savedYt);
                }
            }
        }

        // If yt is set, encode it.
        if (savedYt != address(0)) {
            addressesFound = abi.encodePacked(addressesFound, savedYt);
        }
    }

    function _sanitizeLimitOrderData(DecoderCustomTypes.LimitOrderData calldata limit)
        internal
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        if (limit.limitRouter != address(0)) {
            // Trying to fill limit orders.
            addressesFound = abi.encodePacked(limit.limitRouter);
            if (limit.optData.length > 0) revert PendleRouterDecoderAndSanitizer__NoBytes();

            address savedYt;
            // Make sure all normal fills have the same yt.
            for (uint256 i; i < limit.normalFills.length; ++i) {
                if (savedYt == address(0)) {
                    // Update saved yt.
                    savedYt = limit.normalFills[i].order.YT;
                } else {
                    // Make sure this orders YT matches the saved yt.
                    if (savedYt != limit.normalFills[i].order.YT) {
                        revert PendleRouterDecoderAndSanitizer__LimitOrderYtMismatch(
                            limit.normalFills[i].order.YT, savedYt
                        );
                    }
                }
            }
            // Make sure all flash fills have the same yt.
            for (uint256 i; i < limit.flashFills.length; ++i) {
                if (savedYt == address(0)) {
                    // Update saved yt.
                    savedYt = limit.flashFills[i].order.YT;
                } else {
                    // Make sure this orders YT matches the saved yt.
                    if (savedYt != limit.flashFills[i].order.YT) {
                        revert PendleRouterDecoderAndSanitizer__LimitOrderYtMismatch(
                            limit.flashFills[i].order.YT, savedYt
                        );
                    }
                }
            }

            // If yt is set, encode it.
            if (savedYt != address(0)) {
                addressesFound = abi.encodePacked(addressesFound, savedYt);
            }
        }
    }
}
