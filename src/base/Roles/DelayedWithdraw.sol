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

contract DelayedWithdraw is Auth, ReentrancyGuard {
    using SafeTransferLib for BoringVault;
    using FixedPointMathLib for uint256;

    // ========================================= STRUCTS =========================================

    /**
     * @param allowWithdraws Whether or not withdrawals are allowed for this asset.
     * @param withdrawDelay The delay in seconds before a requested withdrawal can be completed.
     * @param outstandingShares The total number of shares that are currently outstanding for an asset.
     * @param withdrawFee The fee that is charged when a withdrawal is completed.
     * @param maxLoss The maximum loss that can be incurred when completing a withdrawal, evaluating the
     *                exchange rate at time of withdraw, compared to time of completion.
     */
    struct WithdrawAsset {
        bool allowWithdraws;
        uint64 withdrawDelay;
        uint128 outstandingShares;
        uint16 withdrawFee;
        uint16 maxLoss;
    }

    /**
     * @param maturity The time at which the withdrawal can be completed.
     * @param shares The number of shares that are requested to be withdrawn.
     * @param exchangeRateAtTimeOfRequest The exchange rate at the time of the request.
     */
    struct WithdrawRequest {
        uint64 maturity;
        uint96 shares;
        uint96 exchangeRateAtTimeOfRequest;
    }

    // ========================================= STATE =========================================

    /**
     * @notice The address that receives the fee when a withdrawal is completed.
     */
    address public feeAddress;

    /**
     * @notice The mapping of assets to their respective withdrawal settings.
     */
    mapping(ERC20 => WithdrawAsset) public withdrawAssets;

    /**
     * @notice The mapping of users to withdraw asset to their withdrawal requests.
     */
    mapping(address => mapping(ERC20 => WithdrawRequest)) public withdrawRequests;

    //============================== ERRORS ===============================

    error DelayedWithdraw__WithdrawFeeTooHigh();
    error DelayedWithdraw__MaxLossTooLarge();
    error DelayedWithdraw__AlreadySetup();
    error DelayedWithdraw__WithdrawsNotAllowed();
    error DelayedWithdraw__WithdrawNotMatured();
    error DelayedWithdraw__NoSharesToWithdraw();
    error DelayedWithdraw__MaxLossExceeded();
    error DelayedWithdraw__BadAddress();

    //============================== EVENTS ===============================

    event WithdrawRequested(address indexed account, ERC20 indexed asset, uint96 shares, uint64 maturity);
    event WithdrawCancelled(address indexed account, ERC20 indexed asset, uint96 shares);
    event WithdrawCompleted(address indexed account, ERC20 indexed asset, uint256 shares, uint256 assets);
    event FeeAddressSet(address newFeeAddress);
    event SetupWithdrawalsInAsset(address indexed asset, uint64 withdrawDelay, uint16 withdrawFee, uint16 maxLoss);
    event WithdrawDelayUpdated(address indexed asset, uint64 newWithdrawDelay);
    event WithdrawFeeUpdated(address indexed asset, uint16 newWithdrawFee);
    event MaxLossUpdated(address indexed asset, uint16 newMaxLoss);
    event WithdrawalsStopped(address indexed asset);

    //============================== IMMUTABLES ===============================

    /**
     * @notice The accountant contract that is used to get the exchange rate of assets.
     */
    AccountantWithRateProviders internal immutable accountant;

    /**
     * @notice The BoringVault contract that users are withdrawing from.
     */
    BoringVault internal immutable boringVault;

    /**
     * @notice Constant that represents 1 share.
     */
    uint256 internal immutable ONE_SHARE;

    constructor(address _owner, address _boringVault, address _accountant, address _feeAddress)
        Auth(_owner, Authority(address(0)))
    {
        accountant = AccountantWithRateProviders(_accountant);
        boringVault = BoringVault(payable(_boringVault));
        ONE_SHARE = 10 ** boringVault.decimals();
        if (_feeAddress == address(0)) revert DelayedWithdraw__BadAddress();
        feeAddress = _feeAddress;
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Stops withdrawals for a specific asset.
     * @dev Callable by MULTISIG_ROLE.
     */
    function stopWithdrawalsInAsset(ERC20 asset) external requiresAuth {
        WithdrawAsset storage withdrawAsset = withdrawAssets[asset];
        if (!withdrawAsset.allowWithdraws) revert DelayedWithdraw__WithdrawsNotAllowed();

        withdrawAsset.allowWithdraws = false;

        emit WithdrawalsStopped(address(asset));
    }

    /**
     * @notice Sets up the withdrawal settings for a specific asset.
     * @dev Callable by MULTISIG_ROLE.
     */
    function setupWithdrawAsset(ERC20 asset, uint64 withdrawDelay, uint16 withdrawFee, uint16 maxLoss)
        public
        requiresAuth
    {
        WithdrawAsset storage withdrawAsset = withdrawAssets[asset];

        if (withdrawFee > 0.2e4) revert DelayedWithdraw__WithdrawFeeTooHigh();
        if (maxLoss > 0.5e4) revert DelayedWithdraw__MaxLossTooLarge();

        if (withdrawAsset.allowWithdraws) revert DelayedWithdraw__AlreadySetup();
        withdrawAsset.withdrawDelay = withdrawDelay;
        withdrawAsset.allowWithdraws = true;
        withdrawAsset.withdrawFee = withdrawFee;
        withdrawAsset.maxLoss = maxLoss;

        emit SetupWithdrawalsInAsset(address(asset), withdrawDelay, withdrawFee, maxLoss);
    }

    /**
     * @notice Changes the withdraw delay for a specific asset.
     * @dev Callable by MULTISIG_ROLE.
     */
    function changeWithdrawDelay(ERC20 asset, uint64 withdrawDelay) external requiresAuth {
        WithdrawAsset storage withdrawAsset = withdrawAssets[asset];
        if (!withdrawAsset.allowWithdraws) revert DelayedWithdraw__WithdrawsNotAllowed();

        withdrawAsset.withdrawDelay = withdrawDelay;

        emit WithdrawDelayUpdated(address(asset), withdrawDelay);
    }

    /**
     * @notice Changes the withdraw fee for a specific asset.
     * @dev Callable by OWNER_ROLE.
     */
    function changeWithdrawFee(ERC20 asset, uint16 withdrawFee) external requiresAuth {
        WithdrawAsset storage withdrawAsset = withdrawAssets[asset];
        if (!withdrawAsset.allowWithdraws) revert DelayedWithdraw__WithdrawsNotAllowed();

        if (withdrawFee > 0.2e4) revert DelayedWithdraw__WithdrawFeeTooHigh();

        withdrawAsset.withdrawFee = withdrawFee;

        emit WithdrawFeeUpdated(address(asset), withdrawFee);
    }

    /**
     * @notice Changes the max loss for a specific asset.
     * @dev Callable by OWNER_ROLE.
     * @dev Since maxLoss is a global value based off some withdraw asset, it is possible that a user
     *      creates a request, then the maxLoss is updated to some value the user is not comfortable with.
     *      In this case the user should cancel their request. However this is not always possible, so a
     *      better course of action would be if the maxLoss needs to be updated, the asset can be fully removed.
     *      Then all exisitng requets for that asset can be cancelled, and finally the maxLoss can be updated.
     *  // TODO we could requires that the outstanding shares is zero for an asset in order to update the maxLoss?
     */
    function changeMaxLoss(ERC20 asset, uint16 maxLoss) external requiresAuth {
        WithdrawAsset storage withdrawAsset = withdrawAssets[asset];
        if (!withdrawAsset.allowWithdraws) revert DelayedWithdraw__WithdrawsNotAllowed();

        if (maxLoss > 0.5e4) revert DelayedWithdraw__MaxLossTooLarge();

        withdrawAsset.maxLoss = maxLoss;

        emit MaxLossUpdated(address(asset), maxLoss);
    }

    /**
     * @notice Changes the fee address.
     * @dev Callable by STRATEGIST_MULTISIG_ROLE.
     */
    function setFeeAddress(address _feeAddress) external requiresAuth {
        if (_feeAddress == address(0)) revert DelayedWithdraw__BadAddress();
        feeAddress = _feeAddress;

        emit FeeAddressSet(_feeAddress);
    }

    /**
     * @notice Cancels a user's withdrawal request.
     * @dev Callable by MULTISIG_ROLE, and STRATEGIST_MULTISIG_ROLE.
     */
    function cancelUserWithdraw(ERC20 asset, address user) public requiresAuth {
        _cancelWithdraw(asset, user);
    }

    // ========================================= PUBLIC FUNCTIONS =========================================

    /**
     * @notice Requests a withdrawal of shares for a specific asset.
     * @dev Publicly callable.
     */
    function requestWithdraw(ERC20 asset, uint96 shares) external requiresAuth nonReentrant {
        WithdrawAsset storage withdrawAsset = withdrawAssets[asset];
        if (!withdrawAsset.allowWithdraws) revert DelayedWithdraw__WithdrawsNotAllowed();

        boringVault.safeTransferFrom(msg.sender, address(this), shares);

        withdrawAsset.outstandingShares += shares;

        WithdrawRequest storage req = withdrawRequests[msg.sender][asset];

        req.shares += shares;
        uint64 maturity = uint64(block.timestamp + withdrawAsset.withdrawDelay);
        req.maturity = maturity;
        req.exchangeRateAtTimeOfRequest = uint96(accountant.getRateInQuoteSafe(asset));

        emit WithdrawRequested(msg.sender, asset, shares, maturity);
    }

    /**
     * @notice Cancels msg.sender's withdrawal request.
     * @dev Publicly callable.
     */
    function cancelWithdraw(ERC20 asset) external requiresAuth nonReentrant {
        _cancelWithdraw(asset, msg.sender);
    }

    /**
     * @notice Completes a user's withdrawal request.
     * @dev Publicly callable.
     */
    function completeWithdraw(ERC20 asset, address account)
        external
        requiresAuth
        nonReentrant
        returns (uint256 assetsOut)
    {
        WithdrawAsset storage withdrawAsset = withdrawAssets[asset];
        if (!withdrawAsset.allowWithdraws) revert DelayedWithdraw__WithdrawsNotAllowed();

        WithdrawRequest storage req = withdrawRequests[account][asset];
        if (block.timestamp < req.maturity) revert DelayedWithdraw__WithdrawNotMatured();
        if (req.shares == 0) revert DelayedWithdraw__NoSharesToWithdraw();

        uint256 currentExchangeRate = accountant.getRateInQuoteSafe(asset);

        uint256 minRate = req.exchangeRateAtTimeOfRequest < currentExchangeRate
            ? req.exchangeRateAtTimeOfRequest
            : currentExchangeRate;
        uint256 maxRate = req.exchangeRateAtTimeOfRequest < currentExchangeRate
            ? currentExchangeRate
            : req.exchangeRateAtTimeOfRequest;

        // Make sure minRate * maxLoss is greater than or equal to maxRate.
        if (minRate.mulDivDown(1e4 + withdrawAsset.maxLoss, 1e4) < maxRate) revert DelayedWithdraw__MaxLossExceeded();

        uint256 shares = req.shares;

        // Safe to cast shares to a uint128 since req.shares is constrained to be less than 2^96.
        withdrawAsset.outstandingShares -= uint128(shares);

        if (withdrawAsset.withdrawFee > 0) {
            // Handle withdraw fee.
            uint256 fee = uint256(shares).mulDivDown(withdrawAsset.withdrawFee, 1e4);
            shares -= fee;

            // Transfer fee to feeAddress.
            boringVault.safeTransfer(feeAddress, fee);
        }

        // Calculate assets out.
        assetsOut = shares.mulDivDown(minRate, ONE_SHARE);

        req.shares = 0;

        boringVault.exit(account, asset, assetsOut, address(this), shares);

        emit WithdrawCompleted(account, asset, shares, assetsOut);
    }

    // ========================================= VIEW FUNCTIONS =========================================

    /**
     * @notice Helper function to view the outstanding withdraw debt for a specific asset.
     */
    function viewOutstandingDebt(ERC20 asset) public view returns (uint256 debt) {
        uint256 rate = accountant.getRateInQuoteSafe(asset);

        debt = rate.mulDivDown(withdrawAssets[asset].outstandingShares, ONE_SHARE);
    }

    /**
     * @notice Helper function to view the outstanding withdraw debt for multiple assets.
     */
    function viewOutstandingDebts(ERC20[] calldata assets) external view returns (uint256[] memory debts) {
        debts = new uint256[](assets.length);
        for (uint256 i = 0; i < assets.length; i++) {
            debts[i] = viewOutstandingDebt(assets[i]);
        }
    }

    // ========================================= INTERNAL FUNCTIONS =========================================

    /**
     * @notice Internal helper function that implements shared logic for cancelling a user's withdrawal request.
     */
    function _cancelWithdraw(ERC20 asset, address account) internal {
        WithdrawAsset storage withdrawAsset = withdrawAssets[asset];
        // We do not check if `asset` is allowed, to handle edge cases where the asset is no longer allowed.

        WithdrawRequest storage req = withdrawRequests[account][asset];
        uint96 shares = req.shares;
        if (shares == 0) revert DelayedWithdraw__NoSharesToWithdraw();
        withdrawAsset.outstandingShares -= shares;
        req.shares = 0;
        boringVault.safeTransfer(account, shares);

        emit WithdrawCancelled(account, asset, shares);
    }
}