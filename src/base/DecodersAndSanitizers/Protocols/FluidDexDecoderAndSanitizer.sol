// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";


abstract contract FluidDexDecoderAndSanitizer is BaseDecoderAndSanitizer {
    /*  @notice nftId_ The ID of the NFT representing the vault position, if 0 then new position
     *  @param newCol_ The change in collateral amount (positive for deposit, negative for withdrawal)
     *  @param newDebtToken0_ The change in debt amount for token0 (positive for borrowing, negative for repayment)
     *  @param newDebtToken1_ The change in debt amount for token1 (positive for borrowing, negative for repayment)
     *  @param debtSharesMinMax_ Min or max debt shares to mint or burn (positive for borrowing, negative for repayment)
     *  @param to_ The address to receive withdrawn collateral or borrowed tokens (if address(0), defaults to msg.sender)
    */ 
    function operate(
        uint256 /*nftId_*/,
        int256 /*newCol_*/,
        int256 /*newDebtToken0_*/,
        int256 /*newDebtToken1_*/,
        int256 /*debtSharesMinMax_*/,
        address to
    ) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(to); 
    }
}
