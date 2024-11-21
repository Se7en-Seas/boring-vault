// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";


abstract contract FluidDexDecoderAndSanitizer is BaseDecoderAndSanitizer {

    /// @notice T2 and T3
     
     /*  
     *  @notice Vault T2 and T3 ((smart collateral, normal debt) / (normal collateral, smart debt))
     *  @notice T2 params on LHS, T3 on RHS -> T2ParamName/T3ParamName
     *  @dev   These use the same function sig, so I'm just grouping them together
     *  @param nftId The ID of the NFT representing the vault position, use 0 for a new position
     *  @param newColToken0/newCol The change in collateral amount (positive for deposit, negative for withdrawal) *  @param newColtoken1/newDebtToken0 The change in debt amount for token0 (positive for borrowing, negative for repayment)
     *  @param colSharesMinMax/newDebtToken1 The change in debt amount for token1 (positive for borrowing, negative for repayment)
     *  @param newDebt/debtSharesMinMax Min or max debt shares to mint or burn (positive for borrowing, negative for repayment)
     *  @param to The address to receive withdrawn collateral or borrowed tokens (if address(0), defaults to msg.sender)
     */ 
    function operate(
        uint256 /*nftId*/,
        int256 /*newColToken0 / newCol*/,
        int256 /*newColToken1 / newDebtToken0*/,
        int256 /*colSharesMinMax / newDebtToken1*/,
        int256 /*newDebt / debtSharesMinMax*/,
        address to
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(to); 
    }
    
    /* 
    *  @param nftId The ID of the NFT representing the vault position, use 0 for a new position
    *  @param perfectColShares The change in collateral shares (positive for deposit, negative for withdrawal)
    *  @param colToken0MinMax_ min or max collateral amount of token0 to withdraw or deposit (positive for deposit, negative for withdrawal)
    *  @param colToken1MinMax_ min or max collateral amount of token1 to withdraw or deposit (positive for deposit, negative for withdrawal)
    *  @param newDebt_ The change in debt amount (positive for borrowing, negative for repayment)
    *  @param to_ The address to receive withdrawn collateral or borrowed tokens (if address(0), defaults to msg.sender)
    */
    function operatePerfect(
        uint256 /*nftId*/,
        int256 /*perfectColShares*/,
        int256 /*colToken0MinMax*/,
        int256 /*colToken1MinMax*/,
        int256 /*newDebt*/,
        address to
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(to); 
    }


    /// @notice T4 (smart collateral, smart debt) 
    
    /*
    * @param nftId The ID of the NFT representing the vault position
    * @param newColToken0 The change in collateral amount for token0 (positive for deposit, negative for withdrawal)
    * @param newColToken1 The change in collateral amount for token1 (positive for deposit, negative for withdrawal)
    * @param colSharesMinMax Min or max collateral shares to mint or burn (positive for deposit, negative for withdrawal)
    * @param newDebtToken0 The change in debt amount for token0 (positive for borrowing, negative for repayment)
    * @param newDebtToken1 The change in debt amount for token1 (positive for borrowing, negative for repayment)
    * @param debtSharesMinMax Min or max debt shares to burn or mint (positive for borrowing, negative for repayment)
    * @param to The address to receive funds (if address(0), defaults to msg.sender)    
    */
    function operate(
        uint256 /*nftId*/,
        int256 /*newColToken0*/,
        int256 /*newColToken1*/,
        int256 /*colSharesMinMax*/,
        int256 /*newDebtToken0*/,
        int256 /*newDebtToken1*/,
        int256 /*debtSharesMinMax*/,
        address to
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(to); 
    }
    
    /*
    * @param nftId_ The ID of the NFT representing the vault position
    * @param perfectColShares_ The change in collateral shares (positive for deposit, negative for withdrawal)
    * @param colToken0MinMax_ Min or max collateral amount of token0 to withdraw or deposit (positive for deposit, negative for withdrawal)
    * @param colToken1MinMax_ Min or max collateral amount of token1 to withdraw or deposit (positive for deposit, negative for withdrawal)
    * @param perfectDebtShares_ The change in debt shares (positive for borrowing, negative for repayment)
    * @param debtToken0MinMax_ Min or max debt amount for token0 to borrow or payback (positive for borrowing, negative for repayment)
    * @param debtToken1MinMax_ Min or max debt amount for token1 to borrow or payback (positive for borrowing, negative for repayment)
    * @param to_ The address to receive funds (if address(0), defaults to msg.sender)
    */
    function operatePerfect(
        uint256 /*nftId*/,
        int256 /*perfectColShares*/,
        int256 /*colToken0MinMax*/,
        int256 /*colToken1MinMax*/,
        int256 /*perfectDebtShares*/,
        int256 /*debtToken0MinMax*/,
        int256 /*debtToken1MinMax*/,
        address to
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(to); 
    }
}
