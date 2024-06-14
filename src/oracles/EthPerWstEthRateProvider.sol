// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IRateProvider} from "./../interfaces/IRateProvider.sol";
import { IChainlink } from "@ion-protocol/interfaces/IChainlink.sol";
import { IWstEth } from "@ion-protocol/interfaces/ProviderInterfaces.sol";

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @notice Reports the price of wstETH in terms of ETH.
 *
 * @custom:security-contact security@molecularlabs.io
 */
contract EthPerWstEthRateProvider is IRateProvider {
    using SafeCast for int256;

    error MaxTimeFromLastUpdatePassed(uint256 blockTimestamp, uint256 lastUpdated);

    IChainlink public immutable ST_ETH_TO_ETH_CHAINLINK;
    IWstEth public immutable WST_ETH;

    uint256 public immutable MAX_TIME_FROM_LAST_UPDATE; // seconds

    /**
     * @param _stEthToEthChainlink The chainlink price feed for stETH/ETH.
     * @param _wstETH The wstETH contract address.
     */
    constructor(
        address _stEthToEthChainlink,
        address _wstETH,
        uint256 _maxTimeFromLastUpdate
    )
    {
        ST_ETH_TO_ETH_CHAINLINK = IChainlink(_stEthToEthChainlink);
        WST_ETH = IWstEth(_wstETH);
        MAX_TIME_FROM_LAST_UPDATE = _maxTimeFromLastUpdate;
    }

    /**
     * @notice Gets the price of wstETH in terms of ETH.
     * @dev If the beaconchain reserve decreases, the wstETH
     * to stEth conversion will be directly impacted, but the stEth to Eth
     * conversion will simply be determined by the chainlink price oracle.
     * @return ethPerWstEth price of wstETH in ETH. [WAD]
     */
    function getRate() public view returns (uint256 ethPerWstEth) {
        // get price from the protocol feed
        (, int256 _ethPerStEth,, uint256 lastUpdatedAt,) = ST_ETH_TO_ETH_CHAINLINK.latestRoundData(); // price of stETH denominated in ETH
        
        if (block.timestamp - lastUpdatedAt > MAX_TIME_FROM_LAST_UPDATE) revert MaxTimeFromLastUpdatePassed(block.timestamp, lastUpdatedAt);

        // ETH / wstETH = ETH / stETH * stETH / wstETH 
        uint256 ethPerStEth = _ethPerStEth.toUint256();
        ethPerWstEth = WST_ETH.getStETHByWstETH(ethPerStEth); // stEth per wstETH 
    }
}
