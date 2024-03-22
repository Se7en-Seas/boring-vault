// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";

contract AccountantWithRateProviders is Auth, IRateProvider {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    // ========================================= STRUCTS =========================================

    /**
     * @param payoutAddress the address `claimFees` sends fees to
     * @param feesOwedInBase total pending fees owed in terms of base
     * @param totalSharesLastUpdate total amount of shares the last exchange rate update
     * @param exchangeRate the current exchange rate in terms of base
     * @param allowedExchangeRateChangeUpper the max allowed change to exchange rate from an update
     * @param allowedExchangeRateChangeLower the min allowed change to exchange rate from an update
     * @param lastUpdateTimestamp the block timestamp of the last exchange rate update
     * @param isPaused whether or not this contract is paused
     * @param minimumUpdateDelayInHours the minimum amount of time that must pass between
     *        exchange rate updates, such that the update won't trigger the contract to be paused
     * @param managementFee the management fee
     */
    struct AccountantState {
        address payoutAddress;
        uint128 feesOwedInBase;
        uint128 totalSharesLastUpdate;
        uint96 exchangeRate;
        uint16 allowedExchangeRateChangeUpper;
        uint16 allowedExchangeRateChangeLower;
        uint64 lastUpdateTimestamp;
        bool isPaused;
        uint8 minimumUpdateDelayInHours;
        uint16 managementFee;
    }

    /**
     * @param isPeggedToBase whether or not the asset is 1:1 with the base asset
     * @param rateProvider the rate provider for this asset if `isPeggedToBase` is false
     */
    struct RateProviderData {
        bool isPeggedToBase;
        IRateProvider rateProvider;
    }

    // ========================================= CONSTANTS =========================================

    /**
     * @notice 1 hour.
     */
    uint256 internal constant ONE_HOUR = 3_600;

    // ========================================= STATE =========================================

    /**
     * @notice Store the accountant state in 3 packed slots.
     */
    AccountantState public accountantState;

    /**
     * @notice Maps ERC20s to their RateProviderData.
     */
    mapping(ERC20 => RateProviderData) public rateProviderData;

    //============================== EVENTS ===============================

    event Paused();
    event Unpaused();
    event DelayInHoursUpdated(uint8 oldDelay, uint8 newDelay);
    event UpperBoundUpdated(uint16 oldBound, uint16 newBound);
    event LowerBoundUpdated(uint16 oldBound, uint16 newBound);
    event ManagementFeeUpdated(uint16 oldFee, uint16 newFee);
    event PayoutAddressUpdated(address oldPayout, address newPayout);
    event RateProviderUpdated(address asset, bool isPegged, address rateProvider);
    event ExchangeRateUpdated(uint96 oldRate, uint96 newRate, uint64 currentTime);
    event FeesClaimed(address feeAsset, uint256 amount);

    //============================== IMMUTABLES ===============================

    /**
     * @notice The base asset rates are provided in.
     */
    ERC20 public immutable base;

    /**
     * @notice The decimals rates are provided in.
     */
    uint8 public immutable decimals;

    /**
     * @notice The BoringVault this accountant is working with.
     *         Used to determine share supply for fee calculation.
     */
    BoringVault public immutable vault;

    /**
     * @notice One share of the BoringVault.
     */
    uint256 internal immutable ONE_SHARE;

    constructor(
        address _owner,
        address _vault,
        address payoutAddress,
        uint96 startingExchangeRate,
        address _base,
        uint16 allowedExchangeRateChangeUpper,
        uint16 allowedExchangeRateChangeLower,
        uint8 minimumUpdateDelayInHours,
        uint16 managementFee
    ) Auth(_owner, Authority(address(0))) {
        base = ERC20(_base);
        decimals = ERC20(_base).decimals();
        vault = BoringVault(payable(_vault));
        ONE_SHARE = 10 ** vault.decimals();
        accountantState = AccountantState({
            payoutAddress: payoutAddress,
            feesOwedInBase: 0,
            totalSharesLastUpdate: uint128(vault.totalSupply()),
            exchangeRate: startingExchangeRate,
            allowedExchangeRateChangeUpper: allowedExchangeRateChangeUpper,
            allowedExchangeRateChangeLower: allowedExchangeRateChangeLower,
            lastUpdateTimestamp: uint64(block.timestamp),
            isPaused: false,
            minimumUpdateDelayInHours: minimumUpdateDelayInHours,
            managementFee: managementFee
        });
    }

    // ========================================= ADMIN FUNCTIONS =========================================
    /**
     * @notice Pause this contract, which prevents future calls to `updateExchangeRate`, and any safe rate
     *         calls will revert.
     */
    function pause() external requiresAuth {
        accountantState.isPaused = true;
        emit Paused();
    }

    /**
     * @notice Unpause this contract, which allows future calls to `updateExchangeRate`, and any safe rate
     *         calls will stop reverting.
     */
    function unpause() external requiresAuth {
        accountantState.isPaused = false;
        emit Unpaused();
    }

    /**
     * @notice Update the minimum time delay between `updateExchangeRate` calls.
     * @dev There are no input requirements, as it is possible the admin would want
     *      the exchange rate updated as frequently as needed.
     */
    function updateDelay(uint8 minimumUpdateDelayInHours) external requiresAuth {
        uint8 oldDelay = accountantState.minimumUpdateDelayInHours;
        accountantState.minimumUpdateDelayInHours = minimumUpdateDelayInHours;
        emit DelayInHoursUpdated(oldDelay, minimumUpdateDelayInHours);
    }

    /**
     * @notice Update the allowed upper bound change of exchange rate between `updateExchangeRateCalls`.
     */
    function updateUpper(uint16 allowedExchangeRateChangeUpper) external requiresAuth {
        if (allowedExchangeRateChangeUpper < 1e4) revert("upper bound too small");
        uint16 oldBound = accountantState.allowedExchangeRateChangeUpper;
        accountantState.allowedExchangeRateChangeUpper = allowedExchangeRateChangeUpper;
        emit UpperBoundUpdated(oldBound, allowedExchangeRateChangeUpper);
    }

    /**
     * @notice Update the allowed lower bound change of exchange rate between `updateExchangeRateCalls`.
     */
    function updateLower(uint16 allowedExchangeRateChangeLower) external requiresAuth {
        if (allowedExchangeRateChangeLower > 1e4) revert("lower bound too large");
        uint16 oldBound = accountantState.allowedExchangeRateChangeLower;
        accountantState.allowedExchangeRateChangeLower = allowedExchangeRateChangeLower;
        emit LowerBoundUpdated(oldBound, allowedExchangeRateChangeLower);
    }

    /**
     * @notice Update the management fee to a new value.
     */
    function updateManagementFee(uint16 managementFee) external requiresAuth {
        if (managementFee > 0.2e4) revert("management fee too large");
        uint16 oldFee = accountantState.managementFee;
        accountantState.managementFee = managementFee;
        emit ManagementFeeUpdated(oldFee, managementFee);
    }

    /**
     * @notice Update the payout address fees are sent to.
     */
    function updatePayoutAddress(address payoutAddress) external requiresAuth {
        address oldPayout = accountantState.payoutAddress;
        accountantState.payoutAddress = payoutAddress;
        emit PayoutAddressUpdated(oldPayout, payoutAddress);
    }

    /**
     * @notice Update the rate provider data for a specific `asset`.
     * @dev Rate providers must return rates in terms of `base` and
     *      they must use the same decimals as `base`.
     */
    function setRateProviderData(ERC20 asset, bool isPeggedToBase, address rateProvider) external requiresAuth {
        rateProviderData[asset] =
            RateProviderData({isPeggedToBase: isPeggedToBase, rateProvider: IRateProvider(rateProvider)});
        emit RateProviderUpdated(address(asset), isPeggedToBase, rateProvider);
    }

    // ========================================= UPDATE EXCHANGE RATE/FEES FUNCTIONS =========================================

    /**
     * @notice Updates this contract exchangeRate.
     * @dev If new exchange rate is outside of accepted bounds, or if not enough time has passed, this
     *      will pause the contract, and this function will NOT calculate fees owed.
     */
    function updateExchangeRate(uint96 newExchangeRate) external requiresAuth {
        AccountantState storage state = accountantState;
        if (state.isPaused) revert("paused");
        uint64 currentTime = uint64(block.timestamp);
        uint256 currentExchangeRate = state.exchangeRate;
        uint256 currentTotalShares = vault.totalSupply();
        if (
            currentTime < state.lastUpdateTimestamp + (state.minimumUpdateDelayInHours * ONE_HOUR)
                || newExchangeRate > currentExchangeRate.mulDivDown(state.allowedExchangeRateChangeUpper, 1e4)
                || newExchangeRate < currentExchangeRate.mulDivDown(state.allowedExchangeRateChangeLower, 1e4)
        ) {
            // Instead of reverting, pause the contract. This way the exchange rate updater is able to update the exchange rate
            // to a better value, and pause it.
            state.isPaused = true;
        } else {
            // Only update fees if we are not paused.
            // Update fee accounting.
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

            state.feesOwedInBase += uint128(newFeesOwedInBase);
        }

        state.exchangeRate = newExchangeRate;
        state.totalSharesLastUpdate = uint128(currentTotalShares);
        state.lastUpdateTimestamp = currentTime;

        emit ExchangeRateUpdated(uint96(currentExchangeRate), newExchangeRate, currentTime);
    }

    /**
     * @notice Claim pending fees.
     * @dev This function must be called by the BoringVault.
     */
    function claimFees(ERC20 feeAsset) external requiresAuth {
        AccountantState storage state = accountantState;
        if (state.isPaused) revert("paused");
        if (state.feesOwedInBase == 0) revert("no fees owed");

        // Determine amount of fees owed in feeAsset.
        uint256 feesOwedInFeeAsset;
        RateProviderData memory data = rateProviderData[feeAsset];
        if (address(feeAsset) == address(base) || data.isPeggedToBase) {
            feesOwedInFeeAsset = state.feesOwedInBase;
        } else {
            uint256 rate = data.rateProvider.getRate();
            feesOwedInFeeAsset = uint256(state.feesOwedInBase).mulDivDown(rate, 10 ** decimals);
        }
        // Zero out fees owed.
        state.feesOwedInBase = 0;
        // Transfer fee asset to payout address.
        feeAsset.safeTransferFrom(msg.sender, state.payoutAddress, feesOwedInFeeAsset);

        emit FeesClaimed(address(feeAsset), feesOwedInFeeAsset);
    }

    // ========================================= RATE FUNCTIONS =========================================

    /**
     * @notice Get this BoringVault's current rate in the base.
     */
    function getRate() public view returns (uint256 rate) {
        rate = accountantState.exchangeRate;
    }

    /**
     * @notice Get this BoringVault's current rate in the base.
     * @dev Revert if paused.
     */
    function getRateSafe() external view returns (uint256 rate) {
        if (accountantState.isPaused) revert("paused");
        rate = getRate();
    }

    /**
     * @notice Get this BoringVault's current rate in the provided quote.
     * @dev `quote` must have its RateProviderData set, else this will revert.
     */
    function getRateInQuote(ERC20 quote) public view returns (uint256 rateInQuote) {
        if (address(quote) == address(base)) {
            rateInQuote = accountantState.exchangeRate;
        } else {
            RateProviderData memory data = rateProviderData[quote];
            if (data.isPeggedToBase) {
                rateInQuote = accountantState.exchangeRate;
            } else {
                uint256 quoteRate = data.rateProvider.getRate();
                uint256 oneQuote = 10 ** ERC20(quote).decimals();
                rateInQuote = oneQuote.mulDivDown(accountantState.exchangeRate, quoteRate);
            }
        }
    }

    /**
     * @notice Get this BoringVault's current rate in the provided quote.
     * @dev `quote` must have its RateProviderData set, else this will revert.
     * @dev Revert if paused.
     */
    function getRateInQuoteSafe(ERC20 quote) external view returns (uint256 rateInQuote) {
        if (accountantState.isPaused) revert("paused");
        rateInQuote = getRateInQuote(quote);
    }
}
