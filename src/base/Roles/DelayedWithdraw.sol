// SPDX-License-Identifier: MIT
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

contract DelayedWithdraw is Auth {
    using SafeTransferLib for BoringVault;
    using FixedPointMathLib for uint256;

    struct WithdrawAsset {
        uint64 withdrawDelay;
        bool allowWithdraws;
        uint128 outstandingShares;
    }
    /* fee? */

    struct WithdrawRequest {
        uint64 maturity;
        uint96 shares;
        uint96 exchangeRateAtTimeOfRequest;
    }
    // TODO add minExchangeRate?

    event WithdrawRequested(address indexed account, ERC20 indexed asset, uint96 shares, uint64 maturity);
    event WithdrawCancelled(address indexed account, ERC20 indexed asset, uint96 shares);
    event WithdrawCompleted(address indexed account, ERC20 indexed asset, uint96 shares, uint256 assets);

    mapping(ERC20 => WithdrawAsset) public withdrawAssets;
    mapping(address => mapping(ERC20 => WithdrawRequest)) public withdrawRequests;

    AccountantWithRateProviders internal immutable accountant;
    BoringVault internal immutable boringVault;
    uint256 internal immutable ONE_SHARE;

    constructor(address _owner, address payable _boringVault, address _accountant)
        Auth(_owner, Authority(address(0)))
    {
        accountant = AccountantWithRateProviders(_accountant);
        boringVault = BoringVault(_boringVault);
        ONE_SHARE = 10 ** boringVault.decimals();
    }

    function setWithdrawAsset(ERC20 asset, uint64 withdrawDelay, bool allowWithdraws) public requiresAuth {
        WithdrawAsset storage withdrawAsset = withdrawAssets[asset];
        withdrawAsset.withdrawDelay = withdrawDelay;
        withdrawAsset.allowWithdraws = allowWithdraws;

        // TODO emit event.
    }
    // TODO withdraw asset fee logic that sends BV shares to people rebalancing BoringVault.

    function requestWithdraw(uint96 shares, ERC20 asset) public requiresAuth {
        WithdrawAsset storage withdrawAsset = withdrawAssets[asset];
        if (!withdrawAsset.allowWithdraws) revert("Withdraws not allowed for asset.");

        boringVault.safeTransferFrom(msg.sender, address(this), shares);

        withdrawAsset.outstandingShares += shares;

        WithdrawRequest storage req = withdrawRequests[msg.sender][asset];

        req.shares += shares;
        uint64 maturity = uint64(block.timestamp + withdrawAsset.withdrawDelay);
        req.maturity = maturity;
        req.exchangeRateAtTimeOfRequest = uint96(accountant.getRateInQuoteSafe(asset));

        emit WithdrawRequested(msg.sender, asset, shares, maturity);
    }

    function _cancelWithdraw(address account, ERC20 asset) internal {
        WithdrawAsset storage withdrawAsset = withdrawAssets[asset];
        if (!withdrawAsset.allowWithdraws) revert("Withdraws not allowed for asset.");

        WithdrawRequest storage req = withdrawRequests[account][asset];
        uint96 shares = req.shares;
        withdrawAsset.outstandingShares -= shares;
        req.shares = 0;
        boringVault.safeTransfer(account, shares);

        emit WithdrawCancelled(account, asset, shares);
    }

    function cancelWithdraw(ERC20 asset) public requiresAuth {
        _cancelWithdraw(msg.sender, asset);
    }

    function cancelWithdraw(address account, ERC20 asset) public requiresAuth {
        _cancelWithdraw(account, asset);
    }

    function completeWithdraw(address account, ERC20 asset) public requiresAuth {
        WithdrawAsset storage withdrawAsset = withdrawAssets[asset];
        if (!withdrawAsset.allowWithdraws) revert("Withdraws not allowed for asset.");

        WithdrawRequest storage req = withdrawRequests[account][asset];
        if (block.timestamp < req.maturity) revert("Withdraw not matured yet.");
        if (req.shares == 0) revert("No shares to withdraw.");

        uint256 currentExchangeRate = accountant.getRateInQuoteSafe(asset);
        uint256 rateToUse = currentExchangeRate < req.exchangeRateAtTimeOfRequest
            ? currentExchangeRate
            : req.exchangeRateAtTimeOfRequest;

        uint96 shares = req.shares;

        withdrawAsset.outstandingShares -= shares;
        uint256 assetsOut = uint256(shares).mulDivDown(rateToUse, ONE_SHARE);

        req.shares = 0;

        boringVault.exit(account, asset, assetsOut, address(this), shares);

        emit WithdrawCompleted(account, asset, shares, assetsOut);
    }

    function viewOutstandingDebt(ERC20 asset) public view returns (uint256 debt) {
        uint256 rate = accountant.getRateInQuoteSafe(asset);

        debt = rate.mulDivDown(withdrawAssets[asset].outstandingShares, ONE_SHARE);
    }

    function viewOutstandingDebts(ERC20[] calldata assets) external view returns (uint256[] memory debts) {
        debts = new uint256[](assets.length);
        for (uint256 i = 0; i < assets.length; i++) {
            debts[i] = viewOutstandingDebt(assets[i]);
        }
    }
}
