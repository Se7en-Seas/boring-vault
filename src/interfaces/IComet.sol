// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

interface IComet {
    function baseToken() external view returns (address);
    function absorb(address absorber, address[] calldata accounts) external;
    function buyCollateral(address asset, uint256 minAmount, uint256 baseAmount, address recipient) external;
}
