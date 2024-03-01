// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

contract AccountantWithTimeWeightedAverageRate {
// a trusted 3rd party will write the exchange rate here, that the Teller will use for servicing user deposits and withdraws.
// I think this contract could use multiple RATE contracts to convert between the base and the asset? Or maybe it should just assume a 1:1
// Could use rates though, and jsut use a 1:1 rate for eETH and wETH, then use an actual rate for ETHx.
}
