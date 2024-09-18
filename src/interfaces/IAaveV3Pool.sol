// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

interface IAaveV3Pool {
    function liquidationCall(address collateral, address debt, address user, uint256 debtToCover, bool receiveAToken)
        external;
}
