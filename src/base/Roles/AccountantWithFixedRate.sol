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

    struct FixedRateAccountantState {
        uint96 yieldEarnedInBase;
        address yieldDistributor;
    }

    // ========================================= STATE =========================================

    FixedRateAccountantState public fixedRateAccountantState;

    //============================== ERRORS ===============================

    error AccountantWithFixedRate__HighWaterMarkCannotChange();
    error AccountantWithFixedRate__StartingExchangeRateCannotBeGreaterThanFixed();
    error AccountantWithFixedRate__UnsafeUint96Cast();
    error AccountantWithFixedRate__OnlyCallableByYieldDistributor();
    error AccountantWithFixedRate__ZeroYieldOwed();
    error AccountantWithFixedRate__FeesResultInRateBelowFixed();

    //============================== EVENTS ===============================

    event YieldClaimed(address indexed yieldAsset, uint256 amount);

    //============================== IMMUTABLES ===============================

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
        uint16 managementFee,
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
            managementFee,
            performanceFee
        )
    {
        fixedExchangeRate = uint96(10 ** decimals);
        if (startingExchangeRate > fixedExchangeRate) {
            revert AccountantWithFixedRate__StartingExchangeRateCannotBeGreaterThanFixed();
        }
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    function resetHighwaterMark() external view override requiresAuth {
        revert AccountantWithFixedRate__HighWaterMarkCannotChange();
    }

    // ========================================= UPDATE EXCHANGE RATE/FEES/YIELD FUNCTIONS =========================================

    /**
     * @notice Updates this contract exchangeRate.
     * @dev If new exchange rate is outside of accepted bounds, or if not enough time has passed, this
     *      will pause the contract, and this function will NOT calculate fees owed.
     * @dev Callable by UPDATE_EXCHANGE_RATE_ROLE.
     */
    function updateExchangeRate(uint96 newExchangeRate) external override requiresAuth {
        AccountantState storage state = accountantState;
        if (state.isPaused) revert AccountantWithRateProviders__Paused();
        uint64 currentTime = uint64(block.timestamp);
        uint256 currentExchangeRate = state.exchangeRate;
        uint256 currentTotalShares = vault.totalSupply();
        if (
            currentTime < state.lastUpdateTimestamp + state.minimumUpdateDelayInSeconds
                || newExchangeRate > currentExchangeRate.mulDivDown(state.allowedExchangeRateChangeUpper, 1e4)
                || newExchangeRate < currentExchangeRate.mulDivDown(state.allowedExchangeRateChangeLower, 1e4)
        ) {
            // Instead of reverting, pause the contract. This way the exchange rate updater is able to update the exchange rate
            // to a better value, and pause it.
            state.isPaused = true;
        } else {
            _calculateFeesOwed(state, newExchangeRate, currentExchangeRate, currentTotalShares, currentTime);
        }

        // Exchange rate can not go above fixed exchange rate.
        if (newExchangeRate < fixedExchangeRate) {
            state.exchangeRate = newExchangeRate;
        } else {
            // state.exchangeRate = fixedExchangeRate; // TODO does this bork tests
            newExchangeRate = fixedExchangeRate;
        }
        state.totalSharesLastUpdate = uint128(currentTotalShares);
        state.lastUpdateTimestamp = currentTime;

        emit ExchangeRateUpdated(uint96(currentExchangeRate), newExchangeRate, currentTime);
    }

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
                changeDecimals(frState.yieldEarnedInBase, decimals, yieldAssetDecimals);
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

    // ========================================= INTERNAL HELPER FUNCTIONS =========================================
    /**
     * @notice Calculate fees owed in base.
     * @dev This function will update the highwater mark if the new exchange rate is higher.
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
            uint256 shareSupplyToUse = currentTotalShares;
            // Use the minimum between current total supply and total supply for last update.
            if (state.totalSharesLastUpdate < shareSupplyToUse) {
                shareSupplyToUse = state.totalSharesLastUpdate;
            }

            // Determine management fees owned.
            uint256 timeDelta = currentTime - state.lastUpdateTimestamp;
            uint256 minimumAssets = newExchangeRate > currentExchangeRate
                ? shareSupplyToUse.mulDivDown(currentExchangeRate, ONE_SHARE)
                : shareSupplyToUse.mulDivDown(newExchangeRate, ONE_SHARE);
            uint256 managementFeesAnnual = minimumAssets.mulDivDown(state.managementFee, 1e4);
            uint256 newFeesOwedInBase = managementFeesAnnual.mulDivDown(timeDelta, 365 days);

            // Account for performance fees.
            uint256 changeInExchangeRate = newExchangeRate - fixedExchangeRate;
            uint256 yieldEarnedInBase = changeInExchangeRate.mulDivDown(shareSupplyToUse, ONE_SHARE);
            if (state.performanceFee > 0) {
                uint256 performanceFeesOwedInBase = yieldEarnedInBase.mulDivDown(state.performanceFee, 1e4);
                newFeesOwedInBase += performanceFeesOwedInBase;
                if (yieldEarnedInBase < newFeesOwedInBase) {
                    revert AccountantWithFixedRate__FeesResultInRateBelowFixed();
                }
                yieldEarnedInBase -= newFeesOwedInBase;
            }
            // We intentionally do not update highwater mark since this is a fixed rate accountant.
            // state.highwaterMark = newExchangeRate;

            // Add yield earned to fixed rate accountant state.
            if (yieldEarnedInBase > type(uint96).max) {
                revert AccountantWithFixedRate__UnsafeUint96Cast();
            }
            fixedRateAccountantState.yieldEarnedInBase += uint96(yieldEarnedInBase);
            state.feesOwedInBase += uint128(newFeesOwedInBase);
        }
    }
}
