pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";

contract MockAaveOracle {
    using FixedPointMathLib for uint256;

    AccountantWithRateProviders public accountant;
    IChainlinkAggregator public chainlinkAggregator;

    constructor(address _accountant, address _chainlinkAggregator) {
        accountant = AccountantWithRateProviders(_accountant);
        chainlinkAggregator = IChainlinkAggregator(_chainlinkAggregator);
    }

    function latestAnswer() external view returns (int256) {
        uint256 rateOfShareInEth = accountant.getRate();
        uint256 rateOfBaseInUsd = uint256(chainlinkAggregator.latestAnswer());
        return int256(rateOfShareInEth.mulDivDown(rateOfBaseInUsd, 1e8));
    }
}

interface IChainlinkAggregator {
    function latestAnswer() external view returns (int256);
}
