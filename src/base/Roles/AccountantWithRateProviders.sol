// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {AccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {console} from "@forge-std/Test.sol"; //TODO remove this

// TODO for tests, check quote rate stuff for things that should be pegged 1:1 like eETH and even steth
// base would be wETH.
contract AccountantWithRateProviders is AccessControlDefaultAdminRules, IRateProvider {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;
    // a trusted 3rd party will write the exchange rate here, that the Teller will use for servicing user deposits and withdraws.
    // I think this contract could use multiple RATE contracts to convert between the base and the asset? Or maybe it should just assume a 1:1
    // Could use rates though, and jsut use a 1:1 rate for eETH and wETH, then use an actual rate for ETHx.

    bytes32 public constant EXCHANGE_RATE_UPDATER_ROLE = keccak256("EXCHANGE_RATE_UPDATER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // The base assets rates are provided in.
    ERC20 public immutable base;
    uint8 public immutable decimals;
    BoringVault public immutable vault;
    uint256 internal immutable ONE_SHARE;

    uint256 internal constant ONE_HOUR = 3_600;

    struct AccountantState {
        address payout_address;
        uint128 fees_owed_in_base;
        uint128 total_shares_last_update;
        uint96 exchange_rate;
        uint16 allowed_exchange_rate_change_upper;
        uint16 allowed_exchange_rate_change_lower;
        uint64 last_update_timestamp;
        bool is_paused;
        uint8 minimum_update_delay_in_hours;
        uint16 management_fee;
    }

    AccountantState public accountantState;

    struct RateProviderData {
        bool is_pegged_to_base;
        IRateProvider rate_provider;
    }

    mapping(ERC20 => RateProviderData) public rate_provider_data; //admin can update this too.

    constructor(
        address _owner,
        address _updater,
        address _admin,
        address _vault,
        address _payout_address,
        uint96 _starting_exchange_rate,
        address _base,
        uint16 _allowed_exchange_rate_change_upper,
        uint16 _allowed_exchange_rate_change_lower,
        uint8 _minimum_update_delay_in_hours,
        uint16 _management_fee
    ) AccessControlDefaultAdminRules(3 days, _owner) {
        _grantRole(EXCHANGE_RATE_UPDATER_ROLE, _updater);
        _grantRole(ADMIN_ROLE, _admin);
        base = ERC20(_base);
        decimals = ERC20(_base).decimals();
        vault = BoringVault(payable(_vault));
        ONE_SHARE = 10 ** vault.decimals();
        accountantState = AccountantState({
            payout_address: _payout_address,
            fees_owed_in_base: 0,
            total_shares_last_update: uint128(vault.totalSupply()),
            exchange_rate: _starting_exchange_rate,
            allowed_exchange_rate_change_upper: _allowed_exchange_rate_change_upper,
            allowed_exchange_rate_change_lower: _allowed_exchange_rate_change_lower,
            last_update_timestamp: uint64(block.timestamp),
            is_paused: false,
            minimum_update_delay_in_hours: _minimum_update_delay_in_hours,
            management_fee: _management_fee
        });
    }

    // ========================================= ADMIN FUNCTIONS =========================================
    // TODO add logical limits, and events.
    // TODO make a new role
    function pause() external onlyRole(ADMIN_ROLE) {
        accountantState.is_paused = true;
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        accountantState.is_paused = false;
    }

    function updateDelay(uint8 _minimum_update_delay_in_hours) external onlyRole(ADMIN_ROLE) {
        accountantState.minimum_update_delay_in_hours = _minimum_update_delay_in_hours;
    }

    function updateUpper(uint16 _allowed_exchange_rate_change_upper) external onlyRole(ADMIN_ROLE) {
        accountantState.allowed_exchange_rate_change_upper = _allowed_exchange_rate_change_upper;
    }

    function updateLower(uint16 _allowed_exchange_rate_change_lower) external onlyRole(ADMIN_ROLE) {
        accountantState.allowed_exchange_rate_change_lower = _allowed_exchange_rate_change_lower;
    }

    function updateManagementFee(uint16 _management_fee) external onlyRole(ADMIN_ROLE) {
        accountantState.management_fee = _management_fee;
    }

    function updatePayoutAddress(address _payout_address) external onlyRole(ADMIN_ROLE) {
        accountantState.payout_address = _payout_address;
    }

    // Rate providers must return rates in terms of `base` and they must use the same decimals as `base`.
    function setRateProviderData(ERC20 _asset, bool _is_pegged_to_base, address _rate_provider)
        external
        onlyRole(ADMIN_ROLE)
    {
        rate_provider_data[_asset] =
            RateProviderData({is_pegged_to_base: _is_pegged_to_base, rate_provider: IRateProvider(_rate_provider)});
    }

    // ========================================= UPDATE EXCHANGE RATE/FEES FUNCTIONS =========================================

    function updateExchangeRate(uint96 _new_exchange_rate) external onlyRole(EXCHANGE_RATE_UPDATER_ROLE) {
        AccountantState storage state = accountantState;
        if (state.is_paused) revert("paused");
        uint64 current_time = uint64(block.timestamp);
        uint256 current_exchange_rate = state.exchange_rate;
        uint256 current_total_shares = vault.totalSupply();
        if (
            current_time < state.last_update_timestamp + (state.minimum_update_delay_in_hours * ONE_HOUR)
                || _new_exchange_rate > current_exchange_rate.mulDivDown(state.allowed_exchange_rate_change_upper, 1e4)
                || _new_exchange_rate < current_exchange_rate.mulDivDown(state.allowed_exchange_rate_change_lower, 1e4)
        ) {
            // Instead of reverting, pause the contract. This way the exchange rate updater is able to update the exchange rate
            // to a better value, and pause it.
            state.is_paused = true;
        } else {
            // Only update fees adn hwm if we are not paused.
            // Update fee accounting.
            uint256 share_supply_to_use = current_total_shares;
            // Use the minimum between current total supply and total supply for last update.
            if (state.total_shares_last_update < share_supply_to_use) {
                share_supply_to_use = state.total_shares_last_update;
            }

            // Determine management fees owned.
            uint256 time_delta = current_time - state.last_update_timestamp;
            uint256 minimum_assets = _new_exchange_rate > current_exchange_rate
                ? share_supply_to_use.mulDivDown(current_exchange_rate, ONE_SHARE)
                : share_supply_to_use.mulDivDown(_new_exchange_rate, ONE_SHARE);
            uint256 management_fees_annual = minimum_assets.mulDivDown(state.management_fee, 1e4);
            uint256 new_fees_owed_in_base = management_fees_annual.mulDivDown(time_delta, 365 days);

            state.fees_owed_in_base += uint128(new_fees_owed_in_base);
        }

        state.exchange_rate = _new_exchange_rate;
        state.total_shares_last_update = uint128(current_total_shares);
        state.last_update_timestamp = current_time;
        // TODO emit an event
    }

    function claimFees(ERC20 fee_asset) external {
        require(msg.sender == address(vault), "only vault");
        AccountantState storage state = accountantState;
        if (state.is_paused) revert("paused");
        if (state.fees_owed_in_base == 0) revert("no fees owed");

        // Determine amount of fees owed in fee_asset.
        uint256 fees_owed_in_fee_asset;
        RateProviderData memory data = rate_provider_data[fee_asset];
        if (address(fee_asset) == address(base) || data.is_pegged_to_base) {
            fees_owed_in_fee_asset = state.fees_owed_in_base;
        } else {
            uint256 rate = data.rate_provider.getRate();
            fees_owed_in_fee_asset = uint256(state.fees_owed_in_base).mulDivDown(rate, 10 ** decimals);
        }
        // Zero out fees owed.
        state.fees_owed_in_base = 0;
        // Transfer fee asset to payout address.
        fee_asset.safeTransferFrom(msg.sender, state.payout_address, fees_owed_in_fee_asset);
    }

    // ========================================= RATE FUNCTIONS =========================================

    function getRate() public view returns (uint256 rate) {
        rate = accountantState.exchange_rate;
    }

    function getRateSafe() external view returns (uint256 rate) {
        if (accountantState.is_paused) revert("paused");
        rate = getRate();
    }

    function getRateInQuote(ERC20 quote) public view returns (uint256 rate_in_quote) {
        if (address(quote) == address(base)) {
            rate_in_quote = accountantState.exchange_rate;
        } else {
            RateProviderData memory data = rate_provider_data[quote];
            if (data.is_pegged_to_base) {
                rate_in_quote = accountantState.exchange_rate;
            } else {
                uint256 quote_rate = data.rate_provider.getRate();
                uint256 one_quote = 10 ** ERC20(quote).decimals();
                rate_in_quote = one_quote.mulDivDown(accountantState.exchange_rate, quote_rate);
            }
        }
    }

    function getRateInQuoteSafe(ERC20 quote) external view returns (uint256 rate_in_quote) {
        if (accountantState.is_paused) revert("paused");
        rate_in_quote = getRateInQuote(quote);
    }
}
