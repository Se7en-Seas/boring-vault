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

    address public feeAddress;
    // TODO something to set this

    //TODO could do some global slippage check instead of individual users, could even be stored in the WithdrawAsset struct
    // then on withdraw we look at the current exchange rate and make sure it is close enough to the one they had when the request was made. that might be simpler for people to integrate

    struct WithdrawAsset {
        bool allowWithdraws;
        uint64 withdrawDelay;
        uint128 outstandingShares;
        uint16 withdrawFee;
        uint16 maxLoss; // If the exchange rate at time of completion is less than the exchange rate at time of request
        // we require that it is greater than some minimum 
        // TODO actually I Think maxLoss should just constrain that the two exchange rates are within that rnage of eachother, cuz it is a loss with exchange rate went to the moon*
    }

    struct WithdrawRequest {
        uint64 maturity;
        uint96 shares;
        uint96 exchangeRateAtTimeOfRequest;
    }

    event WithdrawRequested(address indexed account, ERC20 indexed asset, uint96 shares, uint64 maturity);
    event WithdrawCancelled(address indexed account, ERC20 indexed asset, uint96 shares);
    event WithdrawCompleted(address indexed account, ERC20 indexed asset, uint96 shares, uint256 assets);

    mapping(ERC20 => WithdrawAsset) public withdrawAssets;
    mapping(address => mapping(ERC20 => WithdrawRequest)) public withdrawRequests;

    AccountantWithRateProviders internal immutable accountant;
    BoringVault internal immutable boringVault;
    uint256 internal immutable ONE_SHARE;

    constructor(address _owner, address payable _boringVault, address _accountant, address _feeAddress)
        Auth(_owner, Authority(address(0)))
    {
        accountant = AccountantWithRateProviders(_accountant);
        boringVault = BoringVault(_boringVault);
        ONE_SHARE = 10 ** boringVault.decimals();
        if (feeAddress == address(0)) revert("Bad Address");
        feeAddress = _feeAddress;
    }

    function stopWithdrawalsInAsset(ERC20 asset) extenral requiresAuth {
        withdrawAssets[asset].allowWithdaws = false;
    }

    function setupWithdrawAsset(ERC20 asset, uint64 withdrawDelay, uint16 withdrawFee, uint16 maxLoss) public requiresAuth {
        WithdrawAsset storage withdrawAsset = withdrawAssets[asset];

        if (withdrawFee > 0.2e4) revert ("Too high");
        if (maxLoss > 0.5e4) revert ("Too large");

        if (withdrawAsset.allowWithdraws || withdrawAsset.outstandingShares > 0) revert("Already setup");
        withdrawAsset.withdrawDelay = withdrawDelay;
        withdrawAsset.allowWithdraws = allowWithdraws;
        withdrawAsset.withdrawFee = withdrawFee;
        withdrawAsset.maxLoss = maxLoss;

        // TODO emit event.
    }

    function setPayoutAddress(address _feeAddress) external requiresAuth {
        if (feeAddress == address(0)) revert("Bad Address");
        feeAddress = _feeAddress;

        // TODO emit event
    }

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
        if (shares == 0) revert("No shares to withdraw.");
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

        // TODO constrain rates to be within maxLoss of eachother.

        uint256 currentExchangeRate = accountant.getRateInQuoteSafe(asset);
        uint256 rateToUse = currentExchangeRate < req.exchangeRateAtTimeOfRequest
            ? currentExchangeRate
            : req.exchangeRateAtTimeOfRequest;

        uint96 shares = req.shares;

        // TODO remove fee from shares, and send to payout address.

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
