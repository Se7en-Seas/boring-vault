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

    struct WithdrawAsset {
        bool allowWithdraws;
        uint24 minimumSecondsToDeadline; // default deadline if user provides zero
        uint16 minDiscount;
        uint16 maxDiscount;
        uint96 minimumShares;
    }

    // Downside though is that you could possibly run into block gas limit errors if the min share amount was too low and someone was spamming txs
    // though you can still look at events in order to solve withdraws.
    // TODO if we wanted to add in maturity logic we can reduce nonce size by 24 bits, and add a uint24 secondsToMaturity
    // That would also go in the WithdrawAsset data
    // TODO this would be nice since we could feasibly then setup some more automated way users can claim their withdraws themselves.
    struct OnChainWithdraw {
        uint128 nonce; // read from state, used to make it impossible for request Ids to be repeated.
        address user; // msg.sender
        address assetOut; // input sanitized
        uint128 amountOfShares; // input transfered in
        uint128 amountOfAssets; // derived from amountOfShares and price
        uint40 creationTime; // time withdraw was made
        uint24 secondsToDeadline; // in contract, from withdrawAsset? To get the deadline you take the creationTime and add the secondsToDeadline
    }

    // ========================================= CONSTANTS =========================================
    uint16 internal constant MAX_DISCOUNT = 0.3e4;
    uint24 internal constant MAXIMUM_MINIMUM_SECONDS_TO_DEADLINE = 30 days;

    // ========================================= GLOBAL STATE =========================================

    EnumerableSet.Bytes32Set private _withdrawRequests;

    mapping(bytes32 => OnChainWithdraw) internal onChainWithdraws; // Request Id -> OnChainWithdraw

    mapping(address => WithdrawAsset) public withdrawAssets; // Withdraw Asset Address -> WithdrawAsset

    uint128 public nonce = 1; // start on 1 since nonce 0 is considered invalid
    bool public isPaused;
    bool public trackWithdrawsOnChain;

    //============================== ERRORS ===============================

    error BoringOnChainQueue__Paused();
    error BoringOnChainQueue__WithdrawsNotAllowedForAsset();
    error BoringOnChainQueue__BadDiscount();
    error BoringOnChainQueue__BadShareAmount();
    error BoringOnChainQueue__BadDeadline();
    error BoringOnChainQueue__BadUser();
    error BoringOnChainQueue__DeadlinePassed();
    error BoringOnChainQueue__Keccak256Collision();
    error BoringOnChainQueue__RequestNotFound();
    error BoringOnChainQueue__PermitFailedAndAllowanceTooLow();
    error BoringOnChainQueue__MAX_DISCOUNT();
    error BoringOnChainQueue__MAXIMUM_MINIMUM_SECONDS_TO_DEADLINE();
    error BoringOnChainQueue__SolveAssetMismatch();
    error BoringOnChainQueue__ZeroNonce();
    error BoringOnChainQueue__Overflow();

    //============================== EVENTS ===============================

    event OnChainWithdrawRequested(
        bytes32 indexed requestId,
        address indexed user,
        address indexed assetOut,
        uint256 nonce,
        uint256 amountOfShares,
        uint256 amountOfAssets,
        uint256 creationTime,
        uint24 secondsToDeadline
    );

    event OnChainWithdrawCancelled(bytes32 indexed requestId, address indexed user, uint256 timestamp);

    event OnChainWithdrawSolved(bytes32 indexed requestId, address indexed user, uint256 timestamp);

    event WithdrawAssetSetup(
        address indexed assetOut,
        uint24 minimumSecondsToDeadline,
        uint16 minDiscount,
        uint16 maxDiscount,
        uint96 minimumShares
    );

    event WithdrawAssetStopped(address indexed assetOut);

    event WithdrawAssetUpdated(
        address indexed assetOut,
        uint24 minimumSecondsToDeadline,
        uint16 minDiscount,
        uint16 maxDiscount,
        uint96 minimumShares
    );

    event Paused();

    event Unpaused();

    event TrackWithdrawsOnChainToggled(bool newState);

    //============================== IMMUTABLES ===============================

    BoringVault public immutable boringVault;
    AccountantWithRateProviders public immutable accountant;
    uint256 internal immutable ONE_SHARE;

    constructor(
        address _owner,
        address _auth,
        address payable _boringVault,
        address _accountant,
        bool _trackWithdrawsOnChain
    ) Auth(_owner, Authority(_auth)) {
        boringVault = BoringVault(_boringVault);
        ONE_SHARE = 10 ** boringVault.decimals();
        accountant = AccountantWithRateProviders(_accountant);
        trackWithdrawsOnChain = _trackWithdrawsOnChain;
    }

    //=============================== ADMIN FUNCTIONS ================================

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

    function toggleTrackWithdrawsOnChain() external requiresAuth {
        bool oldState = trackWithdrawsOnChain;
        trackWithdrawsOnChain = !oldState;
        emit TrackWithdrawsOnChainToggled(!oldState);
    }

    function setupWithdrawAsset(
        address assetOut,
        uint24 minimumSecondsToDeadline,
        uint16 minDiscount,
        uint16 maxDiscount,
        uint96 minimumShares
    ) external requiresAuth {
        // Validate input.
        if (maxDiscount > MAX_DISCOUNT) revert BoringOnChainQueue__MAX_DISCOUNT();
        if (minimumSecondsToDeadline > MAXIMUM_MINIMUM_SECONDS_TO_DEADLINE) {
            revert BoringOnChainQueue__MAXIMUM_MINIMUM_SECONDS_TO_DEADLINE();
        }
        if (minDiscount > maxDiscount) revert BoringOnChainQueue__BadDiscount();
        // Make sure accountant can price it.
        accountant.getRateInQuoteSafe(ERC20(assetOut));

        withdrawAssets[assetOut] = WithdrawAsset({
            allowWithdraws: true,
            minimumSecondsToDeadline: minimumSecondsToDeadline,
            minDiscount: minDiscount,
            maxDiscount: maxDiscount,
            minimumShares: minimumShares
        });

        emit WithdrawAssetSetup(assetOut, minimumSecondsToDeadline, minDiscount, maxDiscount, minimumShares);
    }

    function stopWithdrawsInAsset(address assetOut) external requiresAuth {
        withdrawAssets[assetOut].allowWithdraws = false;
        emit WithdrawAssetStopped(assetOut);
    }

    function updateWithdrawAsset(
        address assetOut,
        uint24 minimumSecondsToDeadline,
        uint16 minDiscount,
        uint16 maxDiscount,
        uint96 minimumShares
    ) external requiresAuth {
        // Validate input.
        if (maxDiscount > MAX_DISCOUNT) revert BoringOnChainQueue__MAX_DISCOUNT();
        if (minimumSecondsToDeadline > MAXIMUM_MINIMUM_SECONDS_TO_DEADLINE) {
            revert BoringOnChainQueue__MAXIMUM_MINIMUM_SECONDS_TO_DEADLINE();
        }
        if (minDiscount > maxDiscount) revert BoringOnChainQueue__BadDiscount();

        WithdrawAsset storage withdrawAsset = withdrawAssets[assetOut];
        if (!withdrawAsset.allowWithdraws) revert BoringOnChainQueue__WithdrawsNotAllowedForAsset();
        withdrawAsset.minimumSecondsToDeadline = minimumSecondsToDeadline;
        withdrawAsset.minDiscount = minDiscount;
        withdrawAsset.maxDiscount = maxDiscount;
        withdrawAsset.minimumShares = minimumShares;

        emit WithdrawAssetUpdated(assetOut, minimumSecondsToDeadline, minDiscount, maxDiscount, minimumShares);
    }

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

    function requestOnChainWithdraw(ERC20 assetOut, uint128 amountOfShares, uint16 discount, uint24 secondsToDeadline)
        external
        requiresAuth
        returns (bytes32 requestId)
    {
        _beforeNewRequest(address(assetOut), amountOfShares, discount, secondsToDeadline);

        boringVault.safeTransferFrom(msg.sender, address(this), amountOfShares);

        requestId = _queueOnChainWithdraw(msg.sender, address(assetOut), amountOfShares, discount, secondsToDeadline);
    }

    function requestOnChainWithdrawWithPermit(
        ERC20 assetOut,
        uint128 amountOfShares,
        uint16 discount,
        uint24 secondsToDeadline,
        uint256 permitDeadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external requiresAuth returns (bytes32 requestId) {
        _beforeNewRequest(address(assetOut), amountOfShares, discount, secondsToDeadline);

        try boringVault.permit(msg.sender, address(this), amountOfShares, permitDeadline, v, r, s) {}
        catch {
            if (boringVault.allowance(msg.sender, address(this)) < amountOfShares) {
                revert BoringOnChainQueue__PermitFailedAndAllowanceTooLow();
            }
        }
        requestId = _queueOnChainWithdraw(msg.sender, address(assetOut), amountOfShares, discount, secondsToDeadline);
    }

    function cancelOnChainWithdraw(OnChainWithdraw calldata request)
        external
        requiresAuth
        returns (bytes32 requestId)
    {
        requestId = _cancelOnChainWithdraw(request);
    }

    function cancelOnChainWithdrawUsingRequestId(bytes32 requestId)
        external
        requiresAuth
        returns (OnChainWithdraw memory request)
    {
        request = onChainWithdraws[requestId];
        if (request.nonce == 0) revert BoringOnChainQueue__ZeroNonce();
        _cancelOnChainWithdraw(request);
    }

    function replaceOnChainWithdraw(OnChainWithdraw calldata oldRequest, uint16 discount, uint24 secondsToDeadline)
        external
        requiresAuth
        returns (bytes32 oldRequestId, bytes32 newRequestId)
    {
        (oldRequestId, newRequestId) = _replaceOnChainWithdraw(oldRequest, discount, secondsToDeadline);
    }

    function replaceOnChainWithdrawUsingRequestId(bytes32 oldRequestId, uint16 discount, uint24 secondsToDeadline)
        external
        requiresAuth
        returns (OnChainWithdraw memory oldRequest, bytes32 newRequestId)
    {
        oldRequest = onChainWithdraws[oldRequestId];
        if (oldRequest.nonce == 0) revert BoringOnChainQueue__ZeroNonce();
        (, newRequestId) = _replaceOnChainWithdraw(oldRequest, discount, secondsToDeadline);
    }

    //============================== SOLVER FUNCTIONS ===============================

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
            uint256 deadline = requests[i].creationTime + requests[i].secondsToDeadline;
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

    function getRequestIds() external view returns (bytes32[] memory) {
        return _withdrawRequests.values();
    }

    // @notice does not verify nonce is zero, as you could have not been tracking withdraws for a period of time
    function getWithdrawRequests()
        external
        view
        returns (bytes32[] memory requestIds, OnChainWithdraw[] memory requests)
    {
        requestIds = _withdrawRequests.values();
        uint256 requestsLength = requestIds.length;
        requests = new OnChainWithdraw[](requestsLength);
        for (uint256 i = 0; i < requestsLength; ++i) {
            requests[i] = onChainWithdraws[requestIds[i]];
        }
    }

    function getOnChainWithdraw(bytes32 requestId) external view returns (OnChainWithdraw memory) {
        OnChainWithdraw memory request = onChainWithdraws[requestId];
        if (request.nonce == 0) revert BoringOnChainQueue__ZeroNonce();
        return onChainWithdraws[requestId];
    }

    //============================= INTERNAL FUNCTIONS ==============================

    function _beforeNewRequest(address assetOut, uint128 amountOfShares, uint16 discount, uint24 secondsToDeadline)
        internal
        view
    {
        if (isPaused) revert BoringOnChainQueue__Paused();

        WithdrawAsset memory withdrawAsset = withdrawAssets[assetOut];

        if (!withdrawAsset.allowWithdraws) revert BoringOnChainQueue__WithdrawsNotAllowedForAsset();
        if (discount < withdrawAsset.minDiscount || discount > withdrawAsset.maxDiscount) {
            revert BoringOnChainQueue__BadDiscount();
        }
        if (amountOfShares < withdrawAsset.minimumShares) revert BoringOnChainQueue__BadShareAmount();
        if (secondsToDeadline < withdrawAsset.minimumSecondsToDeadline) revert BoringOnChainQueue__BadDeadline();
    }

    function _cancelOnChainWithdraw(OnChainWithdraw memory request) internal returns (bytes32 requestId) {
        if (request.user != msg.sender) revert BoringOnChainQueue__BadUser();

        requestId = _cancelUserOnChainWithdraw(request);
    }

    function _cancelUserOnChainWithdraw(OnChainWithdraw memory request) internal returns (bytes32 requestId) {
        requestId = _dequeueOnChainWithdraw(request);
        boringVault.safeTransfer(request.user, request.amountOfShares);
        emit OnChainWithdrawCancelled(requestId, request.user, block.timestamp);
    }

    function _replaceOnChainWithdraw(OnChainWithdraw memory oldRequest, uint16 discount, uint24 secondsToDeadline)
        internal
        returns (bytes32 oldRequestId, bytes32 newRequestId)
    {
        if (oldRequest.user != msg.sender) revert BoringOnChainQueue__BadUser();

        _beforeNewRequest(oldRequest.assetOut, oldRequest.amountOfShares, discount, secondsToDeadline);

        oldRequestId = _dequeueOnChainWithdraw(oldRequest);

        emit OnChainWithdrawCancelled(oldRequestId, oldRequest.user, block.timestamp);

        // Create new request.
        newRequestId = _queueOnChainWithdraw(
            oldRequest.user, oldRequest.assetOut, oldRequest.amountOfShares, discount, secondsToDeadline
        );
    }

    function _queueOnChainWithdraw(
        address user,
        address assetOut,
        uint128 amountOfShares,
        uint16 discount,
        uint24 secondsToDeadline
    ) internal returns (bytes32 requestId) {
        // Create new request.
        uint128 requestNonce = nonce;
        nonce++;
        uint256 price = accountant.getRateInQuoteSafe(ERC20(assetOut));
        price = price.mulDivDown(1e4 - discount, 1e4);
        uint256 amountOfAssets = uint256(amountOfShares).mulDivDown(price, ONE_SHARE);
        if (amountOfAssets > type(uint128).max) revert BoringOnChainQueue__Overflow();
        OnChainWithdraw memory req = OnChainWithdraw({
            nonce: requestNonce,
            user: user,
            assetOut: assetOut,
            amountOfShares: amountOfShares,
            amountOfAssets: uint128(amountOfAssets),
            creationTime: uint40(block.timestamp), // Safe to cast to uint40 as it won't overflow for 10s of thousands of years
            secondsToDeadline: secondsToDeadline
        });

        requestId = keccak256(abi.encode(req));

        if (trackWithdrawsOnChain) {
            // Save withdraw request on chain.
            // TODO does this actually work? Maybe cuz there are no dynamic types?
            onChainWithdraws[requestId] = req;
        }

        bool addedToSet = _withdrawRequests.add(requestId);

        if (!addedToSet) revert BoringOnChainQueue__Keccak256Collision();

        emit OnChainWithdrawRequested(
            requestId, user, assetOut, requestNonce, amountOfShares, amountOfAssets, block.timestamp, secondsToDeadline
        );
    }

    function _dequeueOnChainWithdraw(OnChainWithdraw memory request) internal returns (bytes32 requestId) {
        // Remove request from queue.
        requestId = keccak256(abi.encode(request));
        bool removedFromSet = _withdrawRequests.remove(requestId);
        if (!removedFromSet) revert BoringOnChainQueue__RequestNotFound();
        // TODO see what is more gas efficient if you are not tracking requests, should it read the bool, and only delete it if we are tracking?
        // TODO might be worth it to remove this, just so that you have the history stored on chain?
        delete onChainWithdraws[requestId];
    }
}
