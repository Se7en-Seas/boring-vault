// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

interface IAaveV3Pool {
    function liquidationCall(address collateral, address debt, address user, uint256 debtToCover, bool receiveAToken)
        external;

    function supply(address asset, uint256, address onBehalfOf, uint16) external;
    function borrow(address asset, uint256, uint256, uint16, address onBehalfOf) external;
}
