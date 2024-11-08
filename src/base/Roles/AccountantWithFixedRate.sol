// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {IPausable} from "src/interfaces/IPausable.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";

contract AccountantWithFixedRate is AccountantWithRateProviders {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    // ========================================= STRUCTS =========================================

    /**
     * @notice State for the fixed rate accountant.
     * @param yieldEarnedInBase The yield earned in base.
     * @param yieldDistributor The address of the yield distributor.
     */
    struct FixedRateAccountantState {
        uint96 yieldEarnedInBase;
        address yieldDistributor;
    }

    // ========================================= STATE =========================================

    /**
     * @notice State for the fixed rate accountant.
     */
    FixedRateAccountantState public fixedRateAccountantState;

    //============================== ERRORS ===============================

    error AccountantWithFixedRate__HighWaterMarkCannotChange();
    error AccountantWithFixedRate__StartingExchangeRateCannotBeGreaterThanFixed();
    error AccountantWithFixedRate__UnsafeUint96Cast();
    error AccountantWithFixedRate__OnlyCallableByYieldDistributor();
    error AccountantWithFixedRate__ZeroYieldOwed();

    //============================== EVENTS ===============================

    event YieldClaimed(address indexed yieldAsset, uint256 amount);
    event YieldDistributorUpdated(address indexed yieldDistributor);

    //============================== IMMUTABLES ===============================

    /**
     * @notice The fixed exchange rate.
     */
    uint96 internal immutable fixedExchangeRate;

    constructor(
        address _owner,
        address _vault,
        address payoutAddress,
        uint96 startingExchangeRate,
        address _base,
        uint16 allowedExchangeRateChangeUpper,
        uint16 allowedExchangeRateChangeLower,
        uint24 minimumUpdateDelayInSeconds,
        uint16 platformFee,
        uint16 performanceFee
    )
        AccountantWithRateProviders(
            _owner,
            _vault,
            payoutAddress,
            startingExchangeRate,
            _base,
            allowedExchangeRateChangeUpper,
            allowedExchangeRateChangeLower,
            minimumUpdateDelayInSeconds,
            platformFee,
            performanceFee
        )
    {
        fixedExchangeRate = uint96(10 ** decimals);
        if (startingExchangeRate > fixedExchangeRate) {
            revert AccountantWithFixedRate__StartingExchangeRateCannotBeGreaterThanFixed();
        }
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Set the yield distributor.
     */
    function setYieldDistributor(address yieldDistributor) external requiresAuth {
        fixedRateAccountantState.yieldDistributor = yieldDistributor;
        emit YieldDistributorUpdated(yieldDistributor);
    }

    /**
     * @notice Reset the highwater mark.
     * @dev This function is overridden to prevent it from being called.
     */
    function resetHighwaterMark() external view override requiresAuth {
        revert AccountantWithFixedRate__HighWaterMarkCannotChange();
    }

    // ========================================= CLAIM YIELD FUNCTION =========================================

    /**
     * @notice Claim yield owed to the yield distributor.
     * @dev Callable by the yield distributor.
     */
    function claimYield(ERC20 yieldAsset) external {
        FixedRateAccountantState storage frState = fixedRateAccountantState;
        if (msg.sender != frState.yieldDistributor) revert AccountantWithFixedRate__OnlyCallableByYieldDistributor();

        AccountantState storage state = accountantState;
        if (state.isPaused) revert AccountantWithRateProviders__Paused();
        if (frState.yieldEarnedInBase == 0) revert AccountantWithFixedRate__ZeroYieldOwed();

        // Determine amount of yield earned in yieldAsset.
        uint256 yieldOwedInYieldAsset;
        RateProviderData memory data = rateProviderData[yieldAsset];
        if (address(yieldAsset) == address(base)) {
            yieldOwedInYieldAsset = frState.yieldEarnedInBase;
        } else {
            uint8 yieldAssetDecimals = ERC20(yieldAsset).decimals();
            uint256 feesOwedInBaseUsingYieldAssetDecimals =
                _changeDecimals(frState.yieldEarnedInBase, decimals, yieldAssetDecimals);
            if (data.isPeggedToBase) {
                yieldOwedInYieldAsset = feesOwedInBaseUsingYieldAssetDecimals;
            } else {
                uint256 rate = data.rateProvider.getRate();
                yieldOwedInYieldAsset = feesOwedInBaseUsingYieldAssetDecimals.mulDivDown(10 ** yieldAssetDecimals, rate);
            }
        }
        // Zero out yield earned.
        frState.yieldEarnedInBase = 0;
        // Transfer fee asset to payout address.
        yieldAsset.safeTransferFrom(address(vault), frState.yieldDistributor, yieldOwedInYieldAsset);

        emit YieldClaimed(address(yieldAsset), yieldOwedInYieldAsset);
    }

    // ========================================= VIEW FUNCTIONS =========================================

    /**
     * @notice Preview the result of an update to the exchange rate.
     * @return updateWillPause Whether the update will pause the contract.
     * @return newFeesOwedInBase The new fees owed in base.
     * @return totalFeesOwedInBase The total fees owed in base.
     */
    function previewUpdateExchangeRate(uint96 newExchangeRate)
        external
        view
        override
        returns (bool updateWillPause, uint256 newFeesOwedInBase, uint256 totalFeesOwedInBase)
    {
        (
            bool shouldPause,
            AccountantState storage state,
            uint64 currentTime,
            uint256 currentExchangeRate,
            uint256 currentTotalShares
        ) = _beforeUpdateExchangeRate(newExchangeRate);
        updateWillPause = shouldPause;
        totalFeesOwedInBase = state.feesOwedInBase;
        if (!shouldPause) {
            if (newExchangeRate > fixedExchangeRate) {
                (uint256 platformFeesOwedInBase, uint256 shareSupplyToUse) = _calculatePlatformFee(
                    state.totalSharesLastUpdate,
                    state.lastUpdateTimestamp,
                    state.platformFee,
                    newExchangeRate,
                    currentExchangeRate,
                    currentTotalShares,
                    currentTime
                );

                (uint256 performanceFeesOwedInBase, uint256 yieldEarned) =
                    _calculatePerformanceFee(newExchangeRate, shareSupplyToUse, fixedExchangeRate, state.performanceFee);
                if (yieldEarned < (platformFeesOwedInBase + performanceFeesOwedInBase)) {
                    // This means that the platform fee + performance fee is greater than or equal to the exchange rate appreciation,
                    // so the platform fee is forfeited, but yield and performance fees are still calculated.
                    newFeesOwedInBase = performanceFeesOwedInBase;
                } else {
                    newFeesOwedInBase = platformFeesOwedInBase + performanceFeesOwedInBase;
                }
                totalFeesOwedInBase += newFeesOwedInBase;
            }
        }
    }

    // ========================================= INTERNAL HELPER FUNCTIONS =========================================

    /**
     * @notice Override set exchange rate logic to ensure it never exceeds the fixed rate,
     *         but it is allowed to be less than or equal to the fixed rate.
     */
    function _setExchangeRate(uint96 newExchangeRate, AccountantState storage state)
        internal
        override
        returns (uint96)
    {
        if (newExchangeRate < fixedExchangeRate) {
            state.exchangeRate = newExchangeRate;
        } else {
            state.exchangeRate = fixedExchangeRate;
            newExchangeRate = fixedExchangeRate;
        }
        return newExchangeRate;
    }

    /**
     * @notice Calculate fees owed in base.
     * @dev We only update fees and yield earned if we are above the fixed rate.
     *      Because if we are below the fixed rate there is no yield, and no fees should
     *      be taken as the focus is on getting the rate back to the fixed rate.
     * @dev If the platform fee + performance fee is greater than or equal to the exchange rate appreciation,
     *      then the platform fee is forfeited, but yield and performance fees are still calculated.
     */
    function _calculateFeesOwed(
        AccountantState storage state,
        uint96 newExchangeRate,
        uint256 currentExchangeRate,
        uint256 currentTotalShares,
        uint64 currentTime
    ) internal override {
        // Only update fees if we are above the fixed rate.
        if (newExchangeRate > fixedExchangeRate) {
            // Account for platform fees.
            (uint256 platformFeesOwedInBase, uint256 shareSupplyToUse) = _calculatePlatformFee(
                state.totalSharesLastUpdate,
                state.lastUpdateTimestamp,
                state.platformFee,
                newExchangeRate,
                currentExchangeRate,
                currentTotalShares,
                currentTime
            );

            // Account for performance fees.
            (uint256 performanceFeesOwedInBase, uint256 yieldEarned) =
                _calculatePerformanceFee(newExchangeRate, shareSupplyToUse, fixedExchangeRate, state.performanceFee);

            uint256 feesOwedInBase;
            if (yieldEarned < (platformFeesOwedInBase + performanceFeesOwedInBase)) {
                // This means that the platform fee + performance fee is greater than or equal to the exchange rate appreciation,
                // so the platform fee is forfeited, but yield and performance fees are still calculated.
                feesOwedInBase = performanceFeesOwedInBase;
            } else {
                feesOwedInBase = platformFeesOwedInBase + performanceFeesOwedInBase;
            }
            // Since performance fees are a percentage of yield earned, we know this will never underflow.
            yieldEarned -= feesOwedInBase;

            // We intentionally do not update highwater mark since this is a fixed rate accountant.
            // state.highwaterMark = newExchangeRate;

            // Add yield earned to fixed rate accountant state.
            if (yieldEarned > type(uint96).max) {
                revert AccountantWithFixedRate__UnsafeUint96Cast();
            }
            fixedRateAccountantState.yieldEarnedInBase += uint96(yieldEarned);
            state.feesOwedInBase += uint128(feesOwedInBase);
        }
    }
}
