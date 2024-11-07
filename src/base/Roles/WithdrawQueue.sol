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
contract WithdrawQueue is Auth, ReentrancyGuard, IPausable {
    using SafeTransferLib for BoringVault;
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    // ========================================= STRUCTS =========================================

    /**
     * @param allowWithdraws Whether or not withdrawals are allowed for this asset.
     * @param withdrawDelay The delay in seconds before a requested withdrawal can be completed.
     * @param completionWindow The window in seconds that a withdrawal can be completed after the maturity.
     * @param outstandingShares The total number of shares that are currently outstanding for an asset.
     * @param withdrawFee The fee that is charged when a withdrawal is completed.
     * @param maxLoss The maximum loss that can be incurred when completing a withdrawal, evaluating the
     *                exchange rate at time of withdraw, compared to time of completion.
     */
    struct WithdrawAsset {
        bool allowWithdraws;
        uint32 withdrawDelay;
        uint32 completionWindow;
        uint128 outstandingShares;
        uint16 withdrawFee;
        uint16 maxLoss;
    }

    /**
     * @param allowThirdPartyToComplete Whether or not a 3rd party can complete a withdraw on behalf of a user.
     * @param maxLoss The maximum loss that can be incurred when completing a withdrawal,
     *                use zero for global WithdrawAsset.maxLoss.
     * @param maturity The time at which the withdrawal can be completed.
     * @param shares The number of shares that are requested to be withdrawn.
     * @param exchangeRateAtTimeOfRequest The exchange rate at the time of the request.
     */
    struct WithdrawRequest {
        bool allowThirdPartyToComplete;
        uint16 maxLoss;
        uint40 maturity;
        uint96 shares;
        uint96 exchangeRateAtTimeOfRequest;
    }

    // ========================================= CONSTANTS =========================================

    /**
     * @notice The largest withdraw fee that can be set.
     */
    uint16 internal constant MAX_WITHDRAW_FEE = 0.2e4;

    /**
     * @notice The largest max loss that can be set.
     */
    uint16 internal constant MAX_LOSS = 0.5e4;

    /**
     * @notice The default completion window for a withdrawal asset.
     */
    uint32 internal constant DEFAULT_COMPLETION_WINDOW = 7 days;

    // ========================================= STATE =========================================

    /**
     * @notice The address that receives the rebalance fee when a withdrawal is completed.
     */
    address public feeAddress;

    /**
     * @notice Used to pause calls to `requestWithdraw`, and `completeWithdraw`.
     */
    bool public isPaused;

    /**
     * @notice Whether or not the contract should pull funds from the Boring Vault when completing a withdrawal,
     *         or use funds the BoringVault has previously sent to this contract.
     */
    bool public pullFundsFromVault;

    /**
     * @notice The mapping of assets to their respective withdrawal settings.
     */
    mapping(ERC20 => WithdrawAsset) public withdrawAssets;

    /**
     * @notice The mapping of users to withdraw asset to their withdrawal requests.
     */
    mapping(address => mapping(ERC20 => WithdrawRequest)) public withdrawRequests;

    uint256 public withdrawNonce; // TODO implement

    //============================== ERRORS ===============================

    error WithdrawQueue__WithdrawFeeTooHigh();
    error WithdrawQueue__MaxLossTooLarge();
    error WithdrawQueue__AlreadySetup();
    error WithdrawQueue__WithdrawsNotAllowed();
    error WithdrawQueue__WithdrawNotMatured();
    error WithdrawQueue__NoSharesToWithdraw();
    error WithdrawQueue__MaxLossExceeded();
    error WithdrawQueue__BadAddress();
    error WithdrawQueue__ThirdPartyCompletionNotAllowed();
    error WithdrawQueue__RequestPastCompletionWindow();
    error WithdrawQueue__Paused();
    error WithdrawQueue__CallerNotBoringVault();
    error WithdrawQueue__CannotWithdrawBoringToken();

    //============================== EVENTS ===============================
    // TODO add nonce
    event WithdrawRequested(address indexed account, ERC20 indexed asset, uint96 shares, uint40 maturity);
    event WithdrawCancelled(address indexed account, ERC20 indexed asset, uint96 shares);
    event WithdrawCompleted(address indexed account, ERC20 indexed asset, uint256 shares, uint256 assets);
    event FeeAddressSet(address newFeeAddress);
    event SetupWithdrawalsInAsset(address indexed asset, uint64 withdrawDelay, uint16 withdrawFee, uint16 maxLoss);
    event WithdrawDelayUpdated(address indexed asset, uint32 newWithdrawDelay);
    event CompletionWindowUpdated(address indexed asset, uint32 newCompletionWindow);
    event WithdrawFeeUpdated(address indexed asset, uint16 newWithdrawFee);
    event MaxLossUpdated(address indexed asset, uint16 newMaxLoss);
    event WithdrawalsStopped(address indexed asset);
    event ThirdPartyCompletionChanged(address indexed account, ERC20 indexed asset, bool allowed);
    event Paused();
    event Unpaused();
    event PullFundsFromVaultUpdated(bool _pullFundsFromVault);

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
        if (_feeAddress == address(0)) revert WithdrawQueue__BadAddress();
        feeAddress = _feeAddress;
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Pause this contract, which prevents future calls to `manageVaultWithMerkleVerification`.
     * @dev Callable by MULTISIG_ROLE.
     */
    function pause() external requiresAuth {
        isPaused = true;
        emit Paused();
    }

    /**
     * @notice Unpause this contract, which allows future calls to `manageVaultWithMerkleVerification`.
     * @dev Callable by MULTISIG_ROLE.
     */
    function unpause() external requiresAuth {
        isPaused = false;
        emit Unpaused();
    }

    /**
     * @notice Stops withdrawals for a specific asset.
     * @dev Callable by MULTISIG_ROLE.
     */
    function stopWithdrawalsInAsset(ERC20 asset) external requiresAuth {
        WithdrawAsset storage withdrawAsset = withdrawAssets[asset];
        if (!withdrawAsset.allowWithdraws) revert WithdrawQueue__WithdrawsNotAllowed();

        withdrawAsset.allowWithdraws = false;

        emit WithdrawalsStopped(address(asset));
    }

    /**
     * @notice Sets up the withdrawal settings for a specific asset.
     * @dev Callable by OWNER_ROLE.
     */
    function setupWithdrawAsset(
        ERC20 asset,
        uint32 withdrawDelay,
        uint32 completionWindow,
        uint16 withdrawFee,
        uint16 maxLoss
    ) external requiresAuth {
        WithdrawAsset storage withdrawAsset = withdrawAssets[asset];

        if (withdrawFee > MAX_WITHDRAW_FEE) revert WithdrawQueue__WithdrawFeeTooHigh();
        if (maxLoss > MAX_LOSS) revert WithdrawQueue__MaxLossTooLarge();

        if (withdrawAsset.allowWithdraws) revert WithdrawQueue__AlreadySetup();
        withdrawAsset.allowWithdraws = true;
        withdrawAsset.withdrawDelay = withdrawDelay;
        withdrawAsset.completionWindow = completionWindow;
        withdrawAsset.withdrawFee = withdrawFee;
        withdrawAsset.maxLoss = maxLoss;

        emit SetupWithdrawalsInAsset(address(asset), withdrawDelay, withdrawFee, maxLoss);
    }

    /**
     * @notice Changes the withdraw delay for a specific asset.
     * @dev Callable by MULTISIG_ROLE.
     */
    function changeWithdrawDelay(ERC20 asset, uint32 withdrawDelay) external requiresAuth {
        WithdrawAsset storage withdrawAsset = withdrawAssets[asset];
        if (!withdrawAsset.allowWithdraws) revert WithdrawQueue__WithdrawsNotAllowed();

        withdrawAsset.withdrawDelay = withdrawDelay;

        emit WithdrawDelayUpdated(address(asset), withdrawDelay);
    }

    /**
     * @notice Changes the completion window for a specific asset.
     * @dev Callable by MULTISIG_ROLE.
     */
    function changeCompletionWindow(ERC20 asset, uint32 completionWindow) external requiresAuth {
        WithdrawAsset storage withdrawAsset = withdrawAssets[asset];
        if (!withdrawAsset.allowWithdraws) revert WithdrawQueue__WithdrawsNotAllowed();

        withdrawAsset.completionWindow = completionWindow;

        emit CompletionWindowUpdated(address(asset), completionWindow);
    }

    /**
     * @notice Changes the withdraw fee for a specific asset.
     * @dev Callable by OWNER_ROLE.
     */
    function changeWithdrawFee(ERC20 asset, uint16 withdrawFee) external requiresAuth {
        WithdrawAsset storage withdrawAsset = withdrawAssets[asset];
        if (!withdrawAsset.allowWithdraws) revert WithdrawQueue__WithdrawsNotAllowed();

        if (withdrawFee > MAX_WITHDRAW_FEE) revert WithdrawQueue__WithdrawFeeTooHigh();

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
     *      Then all exisitng requests for that asset can be cancelled, and finally the maxLoss can be updated.
     */
    function changeMaxLoss(ERC20 asset, uint16 maxLoss) external requiresAuth {
        WithdrawAsset storage withdrawAsset = withdrawAssets[asset];
        if (!withdrawAsset.allowWithdraws) revert WithdrawQueue__WithdrawsNotAllowed();

        if (maxLoss > MAX_LOSS) revert WithdrawQueue__MaxLossTooLarge();

        withdrawAsset.maxLoss = maxLoss;

        emit MaxLossUpdated(address(asset), maxLoss);
    }

    /**
     * @notice Changes the fee address.
     * @dev Callable by STRATEGIST_MULTISIG_ROLE.
     */
    function setFeeAddress(address _feeAddress) external requiresAuth {
        if (_feeAddress == address(0)) revert WithdrawQueue__BadAddress();
        feeAddress = _feeAddress;

        emit FeeAddressSet(_feeAddress);
    }

    /**
     * @notice Cancels a user's withdrawal request.
     * @dev Callable by MULTISIG_ROLE, and STRATEGIST_MULTISIG_ROLE.
     */
    function cancelUserWithdraw(ERC20 asset, address user) external requiresAuth {
        _cancelWithdraw(asset, user);
    }

    /**
     * @notice Completes a user's withdrawal request.
     * @dev Admins can complete requests even if they are outside the completion window.
     * @dev Callable by MULTISIG_ROLE, and STRATEGIST_MULTISIG_ROLE.
     */
    function completeUserWithdraw(ERC20 asset, address user) external requiresAuth returns (uint256 assetsOut) {
        WithdrawAsset storage withdrawAsset = withdrawAssets[asset];
        WithdrawRequest storage req = withdrawRequests[user][asset];
        assetsOut = _completeWithdraw(asset, user, withdrawAsset, req);
    }

    // TODO could the spread only go to solver if they actually solve

    /**
     * @notice Changes the global setting for whether or not to pull funds from the vault when completing a withdrawal.
     * @dev Callable by OWNER_ROLE.
     */
    function setPullFundsFromVault(bool _pullFundsFromVault) external requiresAuth {
        pullFundsFromVault = _pullFundsFromVault;

        emit PullFundsFromVaultUpdated(_pullFundsFromVault);
    }

    /**
     * @notice Withdraws a non boring token from the contract.
     * @dev Callable by BoringVault.
     * @dev Eventhough withdrawing the BoringVault share from this contract requires
     *      a malicious leaf in the merkle tree, we explicitly revert if `token`
     *      is the BoringVault.
     * @dev For future reference if this function selector is ever changed, the
     *      associated function selector must be updated in `BaseDecoderAndSanitizer.sol`.
     */
    function withdrawNonBoringToken(ERC20 token, uint256 amount) external {
        if (msg.sender != address(boringVault)) revert WithdrawQueue__CallerNotBoringVault();
        if (address(token) == address(boringVault)) revert WithdrawQueue__CannotWithdrawBoringToken();

        if (amount == type(uint256).max) {
            amount = token.balanceOf(address(this));
        }

        token.safeTransfer(address(boringVault), amount);
    }

    // ========================================= PUBLIC FUNCTIONS =========================================

    /**
     * @notice Allows a user to set whether or not a 3rd party can complete withdraws on behalf of them.
     */
    function setAllowThirdPartyToComplete(ERC20 asset, bool allow) external requiresAuth {
        withdrawRequests[msg.sender][asset].allowThirdPartyToComplete = allow;

        emit ThirdPartyCompletionChanged(msg.sender, asset, allow);
    }

    // TODO permit method?
    /**
     * @notice Requests a withdrawal of shares for a specific asset.
     * @dev Publicly callable.
     */
    function requestWithdraw(ERC20 asset, uint96 shares, uint16 maxLoss, bool allowThirdPartyToComplete)
        external
        requiresAuth
        nonReentrant
    {
        if (isPaused) revert WithdrawQueue__Paused();
        WithdrawAsset storage withdrawAsset = withdrawAssets[asset];
        if (!withdrawAsset.allowWithdraws) revert WithdrawQueue__WithdrawsNotAllowed();
        if (maxLoss > MAX_LOSS) revert WithdrawQueue__MaxLossTooLarge();

        boringVault.safeTransferFrom(msg.sender, address(this), shares);

        withdrawAsset.outstandingShares += shares;

        WithdrawRequest storage req = withdrawRequests[msg.sender][asset];

        req.shares += shares;
        uint40 maturity = uint40(block.timestamp + withdrawAsset.withdrawDelay);
        req.maturity = maturity;
        req.exchangeRateAtTimeOfRequest = uint96(accountant.getRateInQuoteSafe(asset));
        req.maxLoss = maxLoss;
        req.allowThirdPartyToComplete = allowThirdPartyToComplete;

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
        if (isPaused) revert WithdrawQueue__Paused();
        WithdrawAsset storage withdrawAsset = withdrawAssets[asset];
        WithdrawRequest storage req = withdrawRequests[account][asset];
        uint32 completionWindow =
            withdrawAsset.completionWindow > 0 ? withdrawAsset.completionWindow : DEFAULT_COMPLETION_WINDOW;
        if (block.timestamp > (req.maturity + completionWindow)) revert WithdrawQueue__RequestPastCompletionWindow();
        if (msg.sender != account && !req.allowThirdPartyToComplete) {
            revert WithdrawQueue__ThirdPartyCompletionNotAllowed();
        }
        assetsOut = _completeWithdraw(asset, account, withdrawAsset, req);
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

    // TODO Add a function to view if a users requests have their maxLoss exceeded/ are ready to claim?
    function viewState(address account, ERC20[] memory assets) public view returns (WithdrawRequest[] memory req) {
        req = new WithdrawRequest[](assets.length);
        for (uint256 i = 0; i < assets.length; i++) {
            WithdrawRequest memory request = withdrawRequests[account][assets[i]];
            req[i] = WithdrawRequest({
                allowThirdPartyToComplete: request.allowThirdPartyToComplete,
                maxLoss: request.maxLoss,
                maturity: request.maturity,
                shares: request.shares,
                exchangeRateAtTimeOfRequest: request.exchangeRateAtTimeOfRequest
            });
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
        if (shares == 0) revert WithdrawQueue__NoSharesToWithdraw();
        withdrawAsset.outstandingShares -= shares;
        req.shares = 0;
        boringVault.safeTransfer(account, shares);

        emit WithdrawCancelled(account, asset, shares);
    }

    /**
     * @notice Internal helper function that implements shared logic for completing a user's withdrawal request.
     */
    function _completeWithdraw(
        ERC20 asset,
        address account,
        WithdrawAsset storage withdrawAsset,
        WithdrawRequest storage req
    ) internal returns (uint256 assetsToUser) {
        if (!withdrawAsset.allowWithdraws) revert WithdrawQueue__WithdrawsNotAllowed();

        if (block.timestamp < req.maturity) revert WithdrawQueue__WithdrawNotMatured();
        if (req.shares == 0) revert WithdrawQueue__NoSharesToWithdraw();

        uint256 currentExchangeRate = accountant.getRateInQuoteSafe(asset);

        uint256 minRate = req.exchangeRateAtTimeOfRequest < currentExchangeRate
            ? req.exchangeRateAtTimeOfRequest
            : currentExchangeRate;
        uint256 maxRate = req.exchangeRateAtTimeOfRequest < currentExchangeRate
            ? currentExchangeRate
            : req.exchangeRateAtTimeOfRequest;

        // Adjust the minimum rate by the withdraw fee.
        if (withdrawAsset.withdrawFee > 0) {
            minRate = minRate.mulDivDown(1e4 - withdrawAsset.withdrawFee, 1e4);
        }

        // If user has set a maxLoss use that, otherwise use the global maxLoss.
        uint16 maxLoss = req.maxLoss > 0 ? req.maxLoss : withdrawAsset.maxLoss;

        // When calculating maxLoss we want to take the maximum rate,
        // and then the withdraw fee adjusted minimum rate(Since that is the value they would receive).
        if (maxRate.mulDivDown(1e4 - maxLoss, maxLoss) > minRate) revert WithdrawQueue__MaxLossExceeded();

        // Adjust the maximum rate by the withdraw fee.
        if (withdrawAsset.withdrawFee > 0) {
            maxRate = maxRate.mulDivDown(1e4 - withdrawAsset.withdrawFee, 1e4);
        }

        uint256 shares = req.shares;

        // Safe to cast shares to a uint128 since req.shares is constrained to be less than 2^96.
        withdrawAsset.outstandingShares -= uint128(shares);

        assetsToUser = shares.mulDivDown(minRate, ONE_SHARE);
        uint256 totalAssets;
        if (currentExchangeRate > req.exchangeRateAtTimeOfRequest) {
            // Rebalance fee is non zero, redeem at maxRate.
            totalAssets = shares.mulDivDown(maxRate, ONE_SHARE);
        } else {
            // Rebalance fee is zero, redeem at minRate.
            totalAssets = assetsToUser;
        }

        req.shares = 0;

        if (pullFundsFromVault) {
            // Burn shares and withdraw assets.
            boringVault.exit(address(this), asset, totalAssets, address(this), shares);
        } else {
            // Burn shares.
            boringVault.exit(address(this), asset, 0, address(this), shares);
        }
        // Transfer assets to user.
        asset.safeTransfer(account, assetsToUser);

        // TODO parameter that lets you decide how much of the spread is given to the vault.

        // TODO change logic so bulk withdraws only do 1 transfer
        // TODO Solver address?
        if (totalAssets > assetsToUser) {
            // Transfer rebalance fee to feeAddress.
            asset.safeTransfer(feeAddress, totalAssets - assetsToUser);
        }

        emit WithdrawCompleted(account, asset, shares, assetsToUser);
    }
}
