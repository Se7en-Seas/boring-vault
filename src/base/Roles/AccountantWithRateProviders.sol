// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {AccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

// TODO for tests, check quote rate stuff for things that should be pegged 1:1 like eETH and even steth
// base would be wETH.
contract AccountantWithRateProviders is AccessControlDefaultAdminRules, IRateProvider {
    using FixedPointMathLib for uint256;
    // a trusted 3rd party will write the exchange rate here, that the Teller will use for servicing user deposits and withdraws.
    // I think this contract could use multiple RATE contracts to convert between the base and the asset? Or maybe it should just assume a 1:1
    // Could use rates though, and jsut use a 1:1 rate for eETH and wETH, then use an actual rate for ETHx.

    bytes32 public constant EXCHANGE_RATE_UPDATER_ROLE = keccak256("EXCHANGE_RATE_UPDATER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // The base assets rates are provided in.
    address public immutable base;
    uint8 public immutable decimals;

    uint256 internal constant ONE_HOUR = 3_600;

    struct AccountantState {
        uint96 exchange_rate;
        uint16 allowed_exchange_rate_change_upper;
        uint16 allowed_exchange_rate_change_lower;
        uint64 last_update_timestamp;
        bool is_paused;
        uint8 minimum_update_delay_in_hours;
    }

    AccountantState public accountantState;

    struct RateProviderData {
        bool is_pegged_to_base;
        IRateProvider rate_provider;
        uint8 decimals; //TODO we dont use this, but probably should
    }

    mapping(address => RateProviderData) internal rate_provider_data; //admin can update this too.

    constructor(
        address _owner,
        address _updater,
        address _admin,
        uint96 _starting_exchange_rate,
        address _base,
        uint16 _allowed_exchange_rate_change_upper,
        uint16 _allowed_exchange_rate_change_lower,
        uint8 _minimum_update_delay_in_hours
    ) AccessControlDefaultAdminRules(3 days, _owner) {
        _grantRole(EXCHANGE_RATE_UPDATER_ROLE, _updater);
        _grantRole(ADMIN_ROLE, _admin);
        base = _base;
        decimals = ERC20(_base).decimals();
        accountantState = AccountantState({
            exchange_rate: _starting_exchange_rate,
            allowed_exchange_rate_change_upper: _allowed_exchange_rate_change_upper,
            allowed_exchange_rate_change_lower: _allowed_exchange_rate_change_lower,
            last_update_timestamp: uint64(block.timestamp),
            is_paused: false,
            minimum_update_delay_in_hours: _minimum_update_delay_in_hours
        });
    }

    // Admin has the power to pause or unpause it, and update delay, and upper/lower

    function getRate() external view returns (uint256 rate) {
        rate = accountantState.exchange_rate;
    }

    function getRateSafe() external view returns (uint256 rate) {
        if (accountantState.is_paused) revert("paused");
        rate = accountantState.exchange_rate;
    }

    function getRateInQuote(address quote) external view returns (uint256 rate_in_quote) {
        if (quote == base) {
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

    function getRateInQuoteSafe(address quote) external view returns (uint256 rate_in_quote) {
        if (accountantState.is_paused) revert("paused");
        if (quote == base) {
            rate_in_quote = accountantState.exchange_rate;
        } else {
            RateProviderData memory data = rate_provider_data[quote];
            if (data.is_pegged_to_base) {
                rate_in_quote = accountantState.exchange_rate;
            } else {
                uint256 quote_rate = rate_provider_data[quote].rate_provider.getRate();
                uint256 one_quote = 10 ** ERC20(quote).decimals();
                rate_in_quote = one_quote.mulDivDown(accountantState.exchange_rate, quote_rate);
            }
        }
    }

    function updateExchangeRate(uint96 _new_exchange_rate) external onlyRole(EXCHANGE_RATE_UPDATER_ROLE) {
        AccountantState storage state = accountantState;
        if (state.is_paused) revert("paused");
        uint64 current_time = uint64(block.timestamp);
        if (current_time < state.last_update_timestamp + (state.minimum_update_delay_in_hours * ONE_HOUR)) {
            revert("Minimum update delay not met");
        }
        uint256 current_exchange_rate = state.exchange_rate;

        // Check if new answer is outside bounds.
        if (
            _new_exchange_rate > current_exchange_rate.mulDivDown(state.allowed_exchange_rate_change_upper, 1e4)
                || _new_exchange_rate < current_exchange_rate.mulDivDown(state.allowed_exchange_rate_change_lower, 1e4)
        ) {
            state.is_paused = true;
        }
        state.last_update_timestamp = current_time;
        // TODO emit an event
    }

    // TODO Add in fee logic

    function claimFees() external {
        // safe transfer from caller, send the money to multiple
    }
}
