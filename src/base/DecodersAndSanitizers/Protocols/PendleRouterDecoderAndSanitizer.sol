// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract PendleRouterDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== ERRORS ===============================

    error PendleRouterDecoderAndSanitizer__AggregatorSwapsNotPermitted();

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
        if (limit.limitRouter != address(0) || limit.normalFills.length > 0 || limit.flashFills.length > 0) {
            revert PendleRouterDecoderAndSanitizer__AggregatorSwapsNotPermitted();
        }
        addressesFound = abi.encodePacked(receiver, market);
    }

    function swapExactPtForSy(
        address receiver,
        address market,
        uint256, /*exactPtIn*/
        uint256, /*minSyOut*/
        DecoderCustomTypes.LimitOrderData calldata limit
    ) external pure virtual returns (bytes memory addressesFound) {
        if (limit.limitRouter != address(0) || limit.normalFills.length > 0 || limit.flashFills.length > 0) {
            revert PendleRouterDecoderAndSanitizer__AggregatorSwapsNotPermitted();
        }
        addressesFound = abi.encodePacked(receiver, market);
    }
}
