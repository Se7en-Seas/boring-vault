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
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IBoringSolver} from "src/base/Roles/BoringQueue/IBoringSolver.sol";

contract BoringOnChainQueue is Auth, ReentrancyGuard, IPausable {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using SafeTransferLib for BoringVault;
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    // ========================================= STRUCTS =========================================

    /**
     * @param allowWithdraws Whether or not withdraws are allowed for this asset.
     * @param secondsToMaturity The time in seconds it takes for the asset to mature.
     * @param minimumSecondsToDeadline The minimum time in seconds a withdraw request must be valid for before it is expired
     * @param minDiscount The minimum discount allowed for a withdraw request.
     * @param maxDiscount The maximum discount allowed for a withdraw request.
     * @param minimumShares The minimum amount of shares that can be withdrawn.
     */
    struct WithdrawAsset {
        bool allowWithdraws;
        uint24 secondsToMaturity;
        uint24 minimumSecondsToDeadline; // default deadline if user provides zero
        uint16 minDiscount;
        uint16 maxDiscount;
        uint96 minimumShares;
    }

    /**
     * @param nonce The nonce of the request, used to make it impossible for request Ids to be repeated.
     * @param user The user that made the request.
     * @param assetOut The asset that the user wants to withdraw.
     * @param amountOfShares The amount of shares the user wants to withdraw.
     * @param amountOfAssets The amount of assets the user will receive.
     * @param creationTime The time the request was made.
     * @param secondsToMaturity The time in seconds it takes for the asset to mature.
     * @param secondsToDeadline The time in seconds the request is valid for.
     */
    struct OnChainWithdraw {
        uint96 nonce; // read from state, used to make it impossible for request Ids to be repeated.
        address user; // msg.sender
        address assetOut; // input sanitized
        uint128 amountOfShares; // input transfered in
        uint128 amountOfAssets; // derived from amountOfShares and price
        uint40 creationTime; // time withdraw was made
        uint24 secondsToMaturity; // in contract, from withdrawAsset?
        uint24 secondsToDeadline; // in contract, from withdrawAsset? To get the deadline you take the creationTime add seconds to maturity, add the secondsToDeadline
    }

    // ========================================= CONSTANTS =========================================
    /**
     * @notice The maximum discount allowed for a withdraw asset.
     */
    uint16 internal constant MAX_DISCOUNT = 0.3e4;

    /**
     * @notice The maximum time in seconds a withdraw asset can take to mature.
     */
    uint24 internal constant MAXIMUM_SECONDS_TO_MATURITY = 30 days;

    /**
     * @notice Caps the minimum time in seconds a withdraw request must be valid for before it is expired.
     */
    uint24 internal constant MAXIMUM_MINIMUM_SECONDS_TO_DEADLINE = 30 days;

    // ========================================= MODIFIERS =========================================

    /**
     * @notice Ensure that the request user is the same as the message sender.
     */
    modifier onlyRequestUser(address requestUser, address msgSender) {
        if (requestUser != msgSender) revert BoringOnChainQueue__BadUser();
        _;
    }

    // ========================================= GLOBAL STATE =========================================

    /**
     * @notice Open Zeppelin EnumerableSet to store all withdraw requests, by there request Id.
     */
    EnumerableSet.Bytes32Set private _withdrawRequests;

    /**
     * @notice Mapping of asset addresses to WithdrawAssets.
     */
    mapping(address => WithdrawAsset) public withdrawAssets;

    /**
     * @notice The nonce of the next request.
     * @dev The purpose of this nonce is to prevent request Ids from being repeated.
     * @dev Start at 1, since 0 is considered invalid.
     * @dev When incrementing the nonce, an unchecked block is used to save gas.
     *      This is safe because you can not feasibly make a request, and then cause an overflow
     *      in the same block such that you can make 2 requests with the same request Id.
     *      And even if you did, the tx would revert with a keccak256 collision error.
     */
    uint96 public nonce = 1;

    /**
     * @notice Whether or not the contract is paused.
     */
    bool public isPaused;

    //============================== ERRORS ===============================

    error BoringOnChainQueue__Paused();
    error BoringOnChainQueue__WithdrawsNotAllowedForAsset();
    error BoringOnChainQueue__BadDiscount();
    error BoringOnChainQueue__BadShareAmount();
    error BoringOnChainQueue__BadDeadline();
    error BoringOnChainQueue__BadUser();
    error BoringOnChainQueue__DeadlinePassed();
    error BoringOnChainQueue__NotMatured();
    error BoringOnChainQueue__Keccak256Collision();
    error BoringOnChainQueue__RequestNotFound();
    error BoringOnChainQueue__PermitFailedAndAllowanceTooLow();
    error BoringOnChainQueue__MAX_DISCOUNT();
    error BoringOnChainQueue__MAXIMUM_MINIMUM_SECONDS_TO_DEADLINE();
    error BoringOnChainQueue__SolveAssetMismatch();
    error BoringOnChainQueue__Overflow();
    error BoringOnChainQueue__MAXIMUM_SECONDS_TO_MATURITY();
    error BoringOnChainQueue__BadInput();
    error BoringOnChainQueue__RescueCannotTakeSharesFromActiveRequests();

    //============================== EVENTS ===============================

    event OnChainWithdrawRequested(
        bytes32 indexed requestId,
        address indexed user,
        address indexed assetOut,
        uint96 nonce,
        uint128 amountOfShares,
        uint128 amountOfAssets,
        uint40 creationTime,
        uint24 secondsToMaturity,
        uint24 secondsToDeadline
    );

    event OnChainWithdrawCancelled(bytes32 indexed requestId, address indexed user, uint256 timestamp);

    event OnChainWithdrawSolved(bytes32 indexed requestId, address indexed user, uint256 timestamp);

    event WithdrawAssetSetup(
        address indexed assetOut,
        uint24 secondsToMaturity,
        uint24 minimumSecondsToDeadline,
        uint16 minDiscount,
        uint16 maxDiscount,
        uint96 minimumShares
    );

    event WithdrawAssetStopped(address indexed assetOut);

    event WithdrawAssetUpdated(
        address indexed assetOut,
        uint24 minimumSecondsToDeadline,
        uint24 secondsToMaturity,
        uint16 minDiscount,
        uint16 maxDiscount,
        uint96 minimumShares
    );

    event Paused();

    event Unpaused();

    event TrackWithdrawsOnChainToggled(bool newState);

    //============================== IMMUTABLES ===============================

    /**
     * @notice The BoringVault contract to withdraw from.
     */
    BoringVault public immutable boringVault;

    /**
     * @notice The AccountantWithRateProviders contract to get rates from.
     */
    AccountantWithRateProviders public immutable accountant;

    /**
     * @notice One BoringVault share.
     */
    uint256 public immutable ONE_SHARE;

    constructor(address _owner, address _auth, address payable _boringVault, address _accountant)
        Auth(_owner, Authority(_auth))
    {
        boringVault = BoringVault(_boringVault);
        ONE_SHARE = 10 ** boringVault.decimals();
        accountant = AccountantWithRateProviders(_accountant);
    }

    //=============================== ADMIN FUNCTIONS ================================

    /**
     * @notice Allows the owner to rescue tokens from the contract.
     * @dev The owner can only withdraw BoringVault shares if they are accidentally sent to this contract.
     *      Shares from active withdraw requests are not withdrawable.
     * @param token The token to rescue.
     * @param amount The amount to rescue.
     * @param to The address to send the rescued tokens to.
     * @param activeRequests The active withdraw requests, query `getWithdrawRequests`, or read events to get them.
     * @dev Provided activeRequests must match the order of active requests in the queue.
     */
    function rescueTokens(ERC20 token, uint256 amount, address to, OnChainWithdraw[] calldata activeRequests)
        external
        requiresAuth
    {
        if (address(token) == address(boringVault)) {
            bytes32[] memory requestIds = _withdrawRequests.values();
            uint256 requestIdsLength = requestIds.length;
            if (activeRequests.length != requestIdsLength) revert BoringOnChainQueue__BadInput();
            // Iterate through provided activeRequests, and hash each one to compare to the requestIds.
            // Also track the sum of shares to make sure it is less than or equal to the amount.
            uint256 activeRequestShareSum;
            for (uint256 i = 0; i < requestIdsLength; ++i) {
                if (keccak256(abi.encode(activeRequests[i])) != requestIds[i]) revert BoringOnChainQueue__BadInput();
                activeRequestShareSum += activeRequests[i].amountOfShares;
            }
            uint256 freeShares = boringVault.balanceOf(address(this)) - activeRequestShareSum;
            if (amount == type(uint256).max) amount = freeShares;
            else if (amount > freeShares) revert BoringOnChainQueue__RescueCannotTakeSharesFromActiveRequests();
        } else {
            if (amount == type(uint256).max) amount = token.balanceOf(address(this));
        }
        token.safeTransfer(to, amount);
    }

    /**
     * @notice Pause this contract, which prevents future calls to any functions that
     *         create new requests, or solve active requests.
     * @dev Callable by MULTISIG_ROLE.
     */
    function pause() external requiresAuth {
        isPaused = true;
        emit Paused();
    }

    /**
     * @notice Unpause this contract, which allows future calls to any functions that
     *         create new requests, or solve active requests.
     * @dev Callable by MULTISIG_ROLE.
     */
    function unpause() external requiresAuth {
        isPaused = false;
        emit Unpaused();
    }

    /**
     * @notice Update a new withdraw asset or existing.
     * @dev Callable by MULTISIG_ROLE.
     * @param assetOut The asset to withdraw.
     * @param secondsToMaturity The time in seconds it takes for the withdraw to mature.
     * @param minimumSecondsToDeadline The minimum time in seconds a withdraw request must be valid for before it is expired.
     * @param minDiscount The minimum discount allowed for a withdraw request.
     * @param maxDiscount The maximum discount allowed for a withdraw request.
     * @param minimumShares The minimum amount of shares that can be withdrawn.
     */
    function updateWithdrawAsset(
        address assetOut,
        uint24 secondsToMaturity,
        uint24 minimumSecondsToDeadline,
        uint16 minDiscount,
        uint16 maxDiscount,
        uint96 minimumShares
    ) external requiresAuth {
        // Validate input.
        if (maxDiscount > MAX_DISCOUNT) revert BoringOnChainQueue__MAX_DISCOUNT();
        if (secondsToMaturity > MAXIMUM_SECONDS_TO_MATURITY) {
            revert BoringOnChainQueue__MAXIMUM_SECONDS_TO_MATURITY();
        }
        if (minimumSecondsToDeadline > MAXIMUM_MINIMUM_SECONDS_TO_DEADLINE) {
            revert BoringOnChainQueue__MAXIMUM_MINIMUM_SECONDS_TO_DEADLINE();
        }
        if (minDiscount > maxDiscount) revert BoringOnChainQueue__BadDiscount();
        // Make sure accountant can price it.
        accountant.getRateInQuoteSafe(ERC20(assetOut));

        withdrawAssets[assetOut] = WithdrawAsset({
            allowWithdraws: true,
            secondsToMaturity: secondsToMaturity,
            minimumSecondsToDeadline: minimumSecondsToDeadline,
            minDiscount: minDiscount,
            maxDiscount: maxDiscount,
            minimumShares: minimumShares
        });

        emit WithdrawAssetUpdated(
            assetOut, secondsToMaturity, minimumSecondsToDeadline, minDiscount, maxDiscount, minimumShares
        );
    }

    /**
     * @notice Stop withdraws in an asset.
     * @dev Callable by MULTISIG_ROLE.
     * @param assetOut The asset to stop withdraws in.
     */
    function stopWithdrawsInAsset(address assetOut) external requiresAuth {
        withdrawAssets[assetOut].allowWithdraws = false;
        emit WithdrawAssetStopped(assetOut);
    }

    /**
     * @notice Cancel multiple user withdraws.
     * @dev Callable by STRATEGIST_MULTISIG_ROLE.
     */
    function cancelUserWithdraws(OnChainWithdraw[] calldata requests)
        external
        requiresAuth
        returns (bytes32[] memory canceledRequestIds)
    {
        uint256 requestsLength = requests.length;
        canceledRequestIds = new bytes32[](requestsLength);
        for (uint256 i = 0; i < requestsLength; ++i) {
            canceledRequestIds[i] = _cancelUserOnChainWithdraw(requests[i]);
        }
    }

    //=============================== USER FUNCTIONS ================================

    /**
     * @notice Request an on-chain withdraw.
     * @param assetOut The asset to withdraw.
     * @param amountOfShares The amount of shares to withdraw.
     * @param discount The discount to apply to the withdraw in bps.
     * @param secondsToDeadline The time in seconds the request is valid for.
     * @return requestId The request Id.
     */
    function requestOnChainWithdraw(address assetOut, uint128 amountOfShares, uint16 discount, uint24 secondsToDeadline)
        external
        requiresAuth
        returns (bytes32 requestId)
    {
        WithdrawAsset memory withdrawAsset = withdrawAssets[assetOut];

        _beforeNewRequest(withdrawAsset, amountOfShares, discount, secondsToDeadline);

        boringVault.safeTransferFrom(msg.sender, address(this), amountOfShares);

        (requestId,) = _queueOnChainWithdraw(
            msg.sender, assetOut, amountOfShares, discount, withdrawAsset.secondsToMaturity, secondsToDeadline
        );
    }

    /**
     * @notice Request an on-chain withdraw with permit.
     * @param assetOut The asset to withdraw.
     * @param amountOfShares The amount of shares to withdraw.
     * @param discount The discount to apply to the withdraw in bps.
     * @param secondsToDeadline The time in seconds the request is valid for.
     * @param permitDeadline The deadline for the permit.
     * @param v The v value of the permit signature.
     * @param r The r value of the permit signature.
     * @param s The s value of the permit signature.
     * @return requestId The request Id.
     */
    function requestOnChainWithdrawWithPermit(
        address assetOut,
        uint128 amountOfShares,
        uint16 discount,
        uint24 secondsToDeadline,
        uint256 permitDeadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external requiresAuth returns (bytes32 requestId) {
        WithdrawAsset memory withdrawAsset = withdrawAssets[assetOut];

        _beforeNewRequest(withdrawAsset, amountOfShares, discount, secondsToDeadline);

        try boringVault.permit(msg.sender, address(this), amountOfShares, permitDeadline, v, r, s) {}
        catch {
            if (boringVault.allowance(msg.sender, address(this)) < amountOfShares) {
                revert BoringOnChainQueue__PermitFailedAndAllowanceTooLow();
            }
        }
        (requestId,) = _queueOnChainWithdraw(
            msg.sender, assetOut, amountOfShares, discount, withdrawAsset.secondsToMaturity, secondsToDeadline
        );
    }

    /**
     * @notice Cancel an on-chain withdraw.
     * @param request The request to cancel.
     * @return requestId The request Id.
     */
    function cancelOnChainWithdraw(OnChainWithdraw calldata request)
        external
        requiresAuth
        onlyRequestUser(request.user, msg.sender)
        returns (bytes32 requestId)
    {
        requestId = _cancelUserOnChainWithdraw(request);
    }

    /**
     * @notice Replace an on-chain withdraw.
     * @param oldRequest The request to replace.
     * @param discount The discount to apply to the new withdraw request in bps.
     * @param secondsToDeadline The time in seconds the new withdraw request is valid for.
     * @return oldRequestId The request Id of the old withdraw request.
     * @return newRequestId The request Id of the new withdraw request.
     */
    function replaceOnChainWithdraw(OnChainWithdraw calldata oldRequest, uint16 discount, uint24 secondsToDeadline)
        external
        requiresAuth
        onlyRequestUser(oldRequest.user, msg.sender)
        returns (bytes32 oldRequestId, bytes32 newRequestId)
    {
        (oldRequestId, newRequestId) = _replaceOnChainWithdraw(oldRequest, discount, secondsToDeadline);
    }

    //============================== SOLVER FUNCTIONS ===============================

    /**
     * @notice Solve multiple on-chain withdraws.
     * @dev If `solveData` is empty, this contract will skip the callback function.
     * @param requests The requests to solve.
     * @param solveData The data to use to solve the requests.
     * @param solver The address of the solver.
     */
    function solveOnChainWithdraws(OnChainWithdraw[] calldata requests, bytes calldata solveData, address solver)
        external
        requiresAuth
    {
        if (isPaused) revert BoringOnChainQueue__Paused();

        ERC20 solveAsset = ERC20(requests[0].assetOut);
        uint256 requiredAssets;
        uint256 totalShares;
        uint256 requestsLength = requests.length;
        for (uint256 i = 0; i < requestsLength; ++i) {
            if (address(solveAsset) != requests[i].assetOut) revert BoringOnChainQueue__SolveAssetMismatch();
            uint256 maturity = requests[i].creationTime + requests[i].secondsToMaturity;
            if (block.timestamp < maturity) revert BoringOnChainQueue__NotMatured();
            uint256 deadline = maturity + requests[i].secondsToDeadline;
            if (block.timestamp > deadline) revert BoringOnChainQueue__DeadlinePassed();
            requiredAssets += requests[i].amountOfAssets;
            totalShares += requests[i].amountOfShares;
            bytes32 requestId = _dequeueOnChainWithdraw(requests[i]);
            emit OnChainWithdrawSolved(requestId, requests[i].user, block.timestamp);
        }

        // Transfer shares to solver.
        boringVault.safeTransfer(solver, totalShares);

        // Run callback function if data is provided.
        if (solveData.length > 0) {
            IBoringSolver(solver).boringSolve(
                msg.sender, address(boringVault), address(solveAsset), totalShares, requiredAssets, solveData
            );
        }

        for (uint256 i = 0; i < requestsLength; ++i) {
            solveAsset.safeTransferFrom(solver, requests[i].user, requests[i].amountOfAssets);
        }
    }

    //============================== VIEW FUNCTIONS ===============================

    /**
     * @notice Get all request Ids currently in the queue.
     * @dev Includes requests that are not mature, matured, and expired. But does not include requests that have been solved.
     * @return requestIds The request Ids.
     */
    function getRequestIds() external view returns (bytes32[] memory) {
        return _withdrawRequests.values();
    }

    /**
     * @notice Get the request Id for a request.
     * @param request The request.
     * @return requestId The request Id.
     */
    function getRequestId(OnChainWithdraw calldata request) external pure returns (bytes32 requestId) {
        return keccak256(abi.encode(request));
    }

    //============================= INTERNAL FUNCTIONS ==============================

    /**
     * @notice Before a new request is made, validate the input.
     * @param withdrawAsset The withdraw asset.
     * @param amountOfShares The amount of shares to withdraw.
     * @param discount The discount to apply to the withdraw in bps.
     * @param secondsToDeadline The time in seconds the request is valid for.
     */
    function _beforeNewRequest(
        WithdrawAsset memory withdrawAsset,
        uint128 amountOfShares,
        uint16 discount,
        uint24 secondsToDeadline
    ) internal view virtual {
        if (isPaused) revert BoringOnChainQueue__Paused();

        if (!withdrawAsset.allowWithdraws) revert BoringOnChainQueue__WithdrawsNotAllowedForAsset();
        if (discount < withdrawAsset.minDiscount || discount > withdrawAsset.maxDiscount) {
            revert BoringOnChainQueue__BadDiscount();
        }
        if (amountOfShares < withdrawAsset.minimumShares) revert BoringOnChainQueue__BadShareAmount();
        if (secondsToDeadline < withdrawAsset.minimumSecondsToDeadline) revert BoringOnChainQueue__BadDeadline();
    }

    /**
     * @notice Cancel an on-chain withdraw.
     * @param request The request to cancel.
     * @return requestId The request Id.
     */
    function _cancelUserOnChainWithdraw(OnChainWithdraw calldata request)
        internal
        virtual
        returns (bytes32 requestId)
    {
        requestId = _dequeueOnChainWithdraw(request);
        boringVault.safeTransfer(request.user, request.amountOfShares);
        emit OnChainWithdrawCancelled(requestId, request.user, block.timestamp);
    }

    /**
     * @notice Replace an on-chain withdraw.
     * @param oldRequest The request to replace.
     * @param discount The discount to apply to the new withdraw request in bps.
     * @param secondsToDeadline The time in seconds the new withdraw request is valid for.
     * @return oldRequestId The request Id of the old withdraw request.
     * @return newRequestId The request Id of the new withdraw request.
     */
    function _replaceOnChainWithdraw(OnChainWithdraw calldata oldRequest, uint16 discount, uint24 secondsToDeadline)
        internal
        virtual
        returns (bytes32 oldRequestId, bytes32 newRequestId)
    {
        WithdrawAsset memory withdrawAsset = withdrawAssets[oldRequest.assetOut];

        _beforeNewRequest(withdrawAsset, oldRequest.amountOfShares, discount, secondsToDeadline);

        oldRequestId = _dequeueOnChainWithdraw(oldRequest);

        emit OnChainWithdrawCancelled(oldRequestId, oldRequest.user, block.timestamp);

        // Create new request.
        (newRequestId,) = _queueOnChainWithdraw(
            oldRequest.user,
            oldRequest.assetOut,
            oldRequest.amountOfShares,
            discount,
            withdrawAsset.secondsToMaturity,
            secondsToDeadline
        );
    }

    /**
     * @notice Queue an on-chain withdraw.
     * @dev Reverts if the request is already in the queue. Though this should be impossible.
     * @param user The user that made the request.
     * @param assetOut The asset to withdraw.
     * @param amountOfShares The amount of shares to withdraw.
     * @param discount The discount to apply to the withdraw in bps.
     * @param secondsToMaturity The time in seconds it takes for the asset to mature.
     * @param secondsToDeadline The time in seconds the request is valid for.
     * @return requestId The request Id.
     */
    function _queueOnChainWithdraw(
        address user,
        address assetOut,
        uint128 amountOfShares,
        uint16 discount,
        uint24 secondsToMaturity,
        uint24 secondsToDeadline
    ) internal virtual returns (bytes32 requestId, OnChainWithdraw memory req) {
        // Create new request.
        uint96 requestNonce;
        // See nonce definition for unchecked safety.
        unchecked {
            // Set request nonce as current nonce, then increment nonce.
            requestNonce = nonce++;
        }

        uint128 amountOfAssets128;
        {
            uint256 price = accountant.getRateInQuoteSafe(ERC20(assetOut));
            price = price.mulDivDown(1e4 - discount, 1e4);
            uint256 amountOfAssets = uint256(amountOfShares).mulDivDown(price, ONE_SHARE);
            if (amountOfAssets > type(uint128).max) revert BoringOnChainQueue__Overflow();
            amountOfAssets128 = uint128(amountOfAssets);
        }
        uint40 timeNow = uint40(block.timestamp); // Safe to cast to uint40 as it won't overflow for 10s of thousands of years
        req = OnChainWithdraw({
            nonce: requestNonce,
            user: user,
            assetOut: assetOut,
            amountOfShares: amountOfShares,
            amountOfAssets: amountOfAssets128,
            creationTime: timeNow,
            secondsToMaturity: secondsToMaturity,
            secondsToDeadline: secondsToDeadline
        });

        requestId = keccak256(abi.encode(req));

        bool addedToSet = _withdrawRequests.add(requestId);

        if (!addedToSet) revert BoringOnChainQueue__Keccak256Collision();

        emit OnChainWithdrawRequested(
            requestId,
            user,
            assetOut,
            requestNonce,
            amountOfShares,
            amountOfAssets128,
            timeNow,
            secondsToMaturity,
            secondsToDeadline
        );
    }

    /**
     * @notice Dequeue an on-chain withdraw.
     * @dev Reverts if the request is not in the queue.
     * @dev Does not remove the request from the onChainWithdraws mapping, so that
     *      it can be referenced later by off-chain systems if needed.
     * @param request The request to dequeue.
     * @return requestId The request Id.
     */
    function _dequeueOnChainWithdraw(OnChainWithdraw calldata request) internal virtual returns (bytes32 requestId) {
        // Remove request from queue.
        requestId = keccak256(abi.encode(request));
        bool removedFromSet = _withdrawRequests.remove(requestId);
        if (!removedFromSet) revert BoringOnChainQueue__RequestNotFound();
    }
}
