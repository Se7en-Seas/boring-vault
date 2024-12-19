// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Rate Limiter
 * @dev Extends LayerZero's evm-oapp v2 RateLimiter contract. The original contract only supports rate limiting for outbound messages.
 * This contract adds support for rate limiting inbound messages.
 */

abstract contract PairwiseRateLimiter {
    /**
     * @notice Rate Limit struct.
     * @param amountInFlight The amount in the current window.
     * @param lastUpdated Timestamp representing the last time the rate limit was checked or updated.
     * @param limit This represents the maximum allowed amount within a given window.
     * @param window Defines the duration of the rate limiting window.
     */
    struct RateLimit {
        uint256 amountInFlight;
        uint256 lastUpdated;
        uint256 limit;
        uint256 window;
    }

    /**
     * @notice Rate Limit Configuration struct.
     * @param dstEid The peer endpoint id.
     * @param limit This represents the maximum allowed amount within a given window.
     * @param window Defines the duration of the rate limiting window.
     */
    struct RateLimitConfig {
        uint32 peerEid;
        uint256 limit;
        uint256 window;
    }

    /**
     * @dev Mapping from peer endpoint id to RateLimit Configurations.
     */
    mapping(uint32 dstEid => RateLimit limit) public outboundRateLimits;
    mapping(uint32 srcEid => RateLimit limit) public inboundRateLimits;

    /**
     * @notice Emitted when _setRateLimits occurs.
     * @param rateLimitConfigs An array of `RateLimitConfig` structs representing the rate limit configurations set.
     * - `peerEid`: The peer endpoint id.
     * - `limit`: This represents the maximum allowed amount within a given window.
     * - `window`: Defines the duration of the rate limiting window.
     */
    event OutboundRateLimitsChanged(RateLimitConfig[] rateLimitConfigs);
    event InboundRateLimitsChanged(RateLimitConfig[] rateLimitConfigs);

    /**
     * @notice Error that is thrown when an amount exceeds the rate_limit.
     */
    error OutboundRateLimitExceeded();
    error InboundRateLimitExceeded() ;

    /**
     * @notice Get the current amount that can be sent to this peer endpoint id for the given rate limit window.
     * @param _dstEid The destination endpoint id.
     * @return outboundAmountInFlight The current amount that was sent.
     * @return amountCanBeSent The amount that can be sent.
     */
    function getAmountCanBeSent(
        uint32 _dstEid
    ) external view virtual returns (uint256 outboundAmountInFlight, uint256 amountCanBeSent) {
        RateLimit memory rl = outboundRateLimits[_dstEid];
        return _amountCanBeSent(rl.amountInFlight, rl.lastUpdated, rl.limit, rl.window);
    }

    /**
     * @notice Get the current amount that can received from this peer endpoint for the given rate limit window.
     * @param _srcEid The source endpoint id.
     * @return inboundAmountInFlight The current amount has been received.
     * @return amountCanBeReceived The amount that be received.
     */
    function getAmountCanBeReceived(
        uint32 _srcEid
    ) external view virtual returns (uint256 inboundAmountInFlight, uint256 amountCanBeReceived) {
        RateLimit memory rl = inboundRateLimits[_srcEid];
        return _amountCanBeSent(rl.amountInFlight, rl.lastUpdated, rl.limit, rl.window);
    }    

    /**
     * @notice Sets the Rate Limit.
     * @param _rateLimitConfigs A `RateLimitConfig` struct representing the rate limit configuration.
     * - `dstEid`: The destination endpoint id.
     * - `limit`: This represents the maximum allowed amount within a given window.
     * - `window`: Defines the duration of the rate limiting window.
     */
    function _setOutboundRateLimits(RateLimitConfig[] memory _rateLimitConfigs) internal virtual {
        unchecked {
            for (uint256 i = 0; i < _rateLimitConfigs.length; i++) {
                RateLimit storage rl = outboundRateLimits[_rateLimitConfigs[i].peerEid];

                // @dev Ensure we checkpoint the existing rate limit as to not retroactively apply the new decay rate.
                _checkAndUpdateOutboundRateLimit(_rateLimitConfigs[i].peerEid, 0);

                // @dev Does NOT reset the amountInFlight/lastUpdated of an existing rate limit.
                rl.limit = _rateLimitConfigs[i].limit;
                rl.window = _rateLimitConfigs[i].window;
            }
        }
        emit OutboundRateLimitsChanged(_rateLimitConfigs);
    }

    /**
     * @notice Sets the Rate Limit.
     * @param _rateLimitConfigs A `RateLimitConfig` struct representing the rate limit configuration.
     * - `srcEid`: The source endpoint id.
     * - `limit`: This represents the maximum allowed amount within a given window.
     * - `window`: Defines the duration of the rate limiting window.
     */
    function _setInboundRateLimits(RateLimitConfig[] memory _rateLimitConfigs) internal virtual {
        unchecked {
            for (uint256 i = 0; i < _rateLimitConfigs.length; i++) {
                RateLimit storage rl = inboundRateLimits[_rateLimitConfigs[i].peerEid];

                // @dev Ensure we checkpoint the existing rate limit as to not retroactively apply the new decay rate.
                _checkAndUpdateInboundRateLimit(_rateLimitConfigs[i].peerEid, 0);

                // @dev Does NOT reset the amountInFlight/lastUpdated of an existing rate limit.
                rl.limit = _rateLimitConfigs[i].limit;
                rl.window = _rateLimitConfigs[i].window;
            }
        }
        emit InboundRateLimitsChanged(_rateLimitConfigs);
    }

    /**
     * @notice Checks current amount in flight and amount that can be sent for a given rate limit window.
     * @param _amountInFlight The amount in the current window.
     * @param _lastUpdated Timestamp representing the last time the rate limit was checked or updated.
     * @param _limit This represents the maximum allowed amount within a given window.
     * @param _window Defines the duration of the rate limiting window.
     * @return currentAmountInFlight The amount in the current window.
     * @return amountCanBeSent The amount that can be sent.
     */
    function _amountCanBeSent(
        uint256 _amountInFlight,
        uint256 _lastUpdated,
        uint256 _limit,
        uint256 _window
    ) internal view virtual returns (uint256 currentAmountInFlight, uint256 amountCanBeSent) {
        uint256 timeSinceLastDeposit = block.timestamp - _lastUpdated;
        if (timeSinceLastDeposit >= _window) {
            currentAmountInFlight = 0;
            amountCanBeSent = _limit;
        } else {
            // @dev Presumes linear decay.
            uint256 decay = (_limit * timeSinceLastDeposit) / _window;
            currentAmountInFlight = _amountInFlight <= decay ? 0 : _amountInFlight - decay;
            // @dev In the event the _limit is lowered, and the 'in-flight' amount is higher than the _limit, set to 0.
            amountCanBeSent = _limit <= currentAmountInFlight ? 0 : _limit - currentAmountInFlight;
        }
    }

    /**
     * @notice Verifies whether the specified amount falls within the rate limit constraints for the targeted
     * endpoint ID. On successful verification, it updates amountInFlight and lastUpdated. If the amount exceeds
     * the rate limit, the operation reverts.
     * @param _dstEid The destination endpoint id.
     * @param _amount The amount to check for rate limit constraints.
     */
    function _checkAndUpdateOutboundRateLimit(uint32 _dstEid, uint256 _amount) internal virtual {
        // @dev By default dstEid that have not been explicitly set will return amountCanBeSent == 0.
        RateLimit storage rl = outboundRateLimits[_dstEid];

        (uint256 currentAmountInFlight, uint256 amountCanBeSent) = _amountCanBeSent(
            rl.amountInFlight,
            rl.lastUpdated,
            rl.limit,
            rl.window
        );
        if (_amount > amountCanBeSent) revert OutboundRateLimitExceeded();

        // @dev Update the storage to contain the new amount and current timestamp.
        rl.amountInFlight = currentAmountInFlight + _amount;
        rl.lastUpdated = block.timestamp;
    }

    /**
     * @notice Verifies whether the specified amount falls within the rate limit constraints for the targeted
     * endpoint ID. On successful verification, it updates amountInFlight and lastUpdated. If the amount exceeds
     * the rate limit, the operation reverts.
     * @param _srcEid The source endpoint id.
     * @param _amount The amount to check for rate limit constraints.
     */
    function _checkAndUpdateInboundRateLimit(uint32 _srcEid, uint256 _amount) internal virtual {
        // @dev By default dstEid that have not been explicitly set will return amountCanBeSent == 0.
        RateLimit storage rl = inboundRateLimits[_srcEid];

        (uint256 currentAmountInFlight, uint256 amountCanBeSent) = _amountCanBeSent(
            rl.amountInFlight,
            rl.lastUpdated,
            rl.limit,
            rl.window
        );
        if (_amount > amountCanBeSent) revert InboundRateLimitExceeded();

        // @dev Update the storage to contain the new amount and current timestamp.
        rl.amountInFlight = currentAmountInFlight + _amount;
        rl.lastUpdated = block.timestamp;
    }
}
