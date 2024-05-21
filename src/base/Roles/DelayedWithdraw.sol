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
    }
    /* fee? */

    struct WithdrawRequest {
        uint64 maturity;
        uint96 shares;
        uint96 exchangeRateAtTimeOfRequest;
    }

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

    function requestWithdraw(uint96 shares, ERC20 asset) public requiresAuth {
        WithdrawAsset memory withdrawAsset = withdrawAssets[asset];
        if (!withdrawAsset.allowWithdraws) revert("Withdraws not allowed for asset.");

        boringVault.safeTransferFrom(msg.sender, address(this), shares);

        WithdrawRequest storage req = withdrawRequests[msg.sender][asset];

        req.shares += shares;
        req.maturity = uint64(block.timestamp + withdrawAsset.withdrawDelay);
        req.exchangeRateAtTimeOfRequest = uint96(accountant.getRateInQuoteSafe(asset));
    }

    function _cancelWithdraw(address account, ERC20 asset) internal {
        WithdrawRequest storage req = withdrawRequests[account][asset];
        uint256 shares = req.shares;
        req.shares = 0;
        boringVault.safeTransfer(account, shares);
    }

    function cancelWithdraw(ERC20 asset) public requiresAuth {
        _cancelWithdraw(msg.sender, asset);
    }

    function cancelWithdraw(address account, ERC20 asset) public requiresAuth {
        _cancelWithdraw(account, asset);
    }

    function completeWithdraw(ERC20 asset) public requiresAuth {
        WithdrawRequest storage req = withdrawRequests[msg.sender][asset];
        if (block.timestamp < req.maturity) revert("Withdraw not matured yet.");
        if (req.shares == 0) revert("No shares to withdraw.");

        uint256 currentExchangeRate = accountant.getRateInQuoteSafe(asset);
        uint256 rateToUse = currentExchangeRate < req.exchangeRateAtTimeOfRequest
            ? currentExchangeRate
            : req.exchangeRateAtTimeOfRequest;

        uint256 shares = req.shares;

        uint256 assetsOut = shares.mulDivDown(rateToUse, ONE_SHARE);

        req.shares = 0;

        boringVault.exit(msg.sender, asset, assetsOut, address(this), shares);
    }

    // assetsOut = shareAmount.mulDivDown(accountant.getRateInQuoteSafe(withdrawAsset), ONE_SHARE);
    // if (assetsOut < minimumAssets) revert TellerWithMultiAssetSupport__MinimumAssetsNotMet();
    // vault.exit(to, withdrawAsset, assetsOut, msg.sender, shareAmount);
    // emit BulkWithdraw(address(withdrawAsset), shareAmount);
}
