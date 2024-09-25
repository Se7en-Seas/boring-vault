// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {WETH} from "@solmate/tokens/WETH.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {BeforeTransferHook} from "src/interfaces/BeforeTransferHook.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {ReentrancyGuard} from "@solmate/utils/ReentrancyGuard.sol";
import {IPausable} from "src/interfaces/IPausable.sol";

// TODO more gas efficient bulk functions.
// TODO mulitcall

// TODO if user opts out of auto claiming, then the spread should be ised to offset the withdraw fee.
// otherwise spread goes to solver who auto claims for user.
contract BoringQueue is Auth, ReentrancyGuard, IPausable {
    using SafeTransferLib for BoringVault;
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    // I think this contract will have some shared logic used by both Queues.
}
