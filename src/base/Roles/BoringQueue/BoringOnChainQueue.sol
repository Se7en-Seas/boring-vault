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

    // TODO If easier to handle these can be made into uint128s
    struct OnChainWithdraw {
        uint256 nonce; // read from state, used to make it impossible for request Ids to be repeated.
        address user; // msg.sender
        address assetOut; // input sanitized
        uint256 amountOfShares; // input transfered in
        uint256 price; // derived from discount and current share price
        uint256 amountOfAssets; // derived from amountOfShares and price
        uint256 creationTime; // time withdraw was made
        uint24 secondsToDeadline; // in contract, from withdrawAsset? To get the deadline you take the creationTime and add the secondsToDeadline
    }

    // ========================================= CONSTANTS =========================================
    uint16 internal constant MAX_DISCOUNT = 0.3e4;
    uint24 internal constant MAXIMUM_MINIMUM_SECONDS_TO_DEADLINE = 30 days;

    // ========================================= GLOBAL STATE =========================================

    // Optionally instead of a set, it could just be a mapping of bytes32 -> bool or potentially to a special bool struct
    // struct {
    // bool usedBefore;
    // bool completed;
    // }
    EnumerableSet.Bytes32Set private _withdrawRequests;

    mapping(address => WithdrawAsset) public withdrawAssets; // Withdraw Asset Address -> WithdrawAsset

    uint248 public nonce;
    bool public isPaused;

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

    //============================== EVENTS ===============================

    event OnChainWithdrawRequested(
        bytes32 indexed requestId,
        address indexed user,
        address indexed assetOut,
        uint256 nonce,
        uint256 amountOfShares,
        uint256 price,
        uint256 amountOfAssets,
        uint256 creationTime,
        uint24 secondsToDeadline
    );

    event OnChainWithdrawCancelled(bytes32 indexed requestId, uint256 timestamp);

    event OnChainWithdrawSolved(bytes32 indexed requestId, uint256 timestamp);

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

    //============================== IMMUTABLES ===============================

    BoringVault public immutable boringVault;
    AccountantWithRateProviders public immutable accountant;
    uint256 internal immutable ONE_SHARE;

    constructor(address _owner, address _auth, address payable _boringVault, address _accountant)
        Auth(_owner, Authority(_auth))
    {
        boringVault = BoringVault(_boringVault);
        ONE_SHARE = 10 ** boringVault.decimals();
        accountant = AccountantWithRateProviders(_accountant);
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

    function requestOnChainWithdraw(ERC20 assetOut, uint256 amountOfShares, uint16 discount, uint24 secondsToDeadline)
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
        uint256 amountOfShares,
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
        if (request.user != msg.sender) revert BoringOnChainQueue__BadUser();

        requestId = _cancelUserOnChainWithdraw(request);
    }

    function replaceOnChainWithdraw(OnChainWithdraw calldata oldRequest, uint16 discount, uint24 secondsToDeadline)
        external
        requiresAuth
        returns (bytes32 oldRequestId, bytes32 newRequestId)
    {
        if (oldRequest.user != msg.sender) revert BoringOnChainQueue__BadUser();

        _beforeNewRequest(oldRequest.assetOut, oldRequest.amountOfShares, discount, secondsToDeadline);

        oldRequestId = _dequeueOnChainWithdraw(oldRequest);

        emit OnChainWithdrawCancelled(oldRequestId, block.timestamp);

        // Create new request.
        newRequestId = _queueOnChainWithdraw(
            oldRequest.user, oldRequest.assetOut, oldRequest.amountOfShares, discount, secondsToDeadline
        );
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
            emit OnChainWithdrawSolved(requestId, block.timestamp);
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

    function getWithdrawRequests() external view returns (bytes32[] memory) {
        return _withdrawRequests.values();
    }

    //============================= INTERNAL FUNCTIONS ==============================

    function _beforeNewRequest(address assetOut, uint256 amountOfShares, uint16 discount, uint24 secondsToDeadline)
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

    function _cancelUserOnChainWithdraw(OnChainWithdraw calldata request) internal returns (bytes32 requestId) {
        requestId = _dequeueOnChainWithdraw(request);
        boringVault.safeTransfer(request.user, request.amountOfShares);
        emit OnChainWithdrawCancelled(requestId, block.timestamp);
    }

    function _queueOnChainWithdraw(
        address user,
        address assetOut,
        uint256 amountOfShares,
        uint16 discount,
        uint24 secondsToDeadline
    ) internal returns (bytes32 requestId) {
        // Create new request.
        uint256 requestNonce = nonce;
        nonce++;
        uint256 price = accountant.getRateInQuoteSafe(ERC20(assetOut));
        price = price.mulDivDown(1e4 - discount, 1e4);
        uint256 amountOfAssets = amountOfShares.mulDivDown(price, ONE_SHARE);
        OnChainWithdraw memory req = OnChainWithdraw({
            nonce: requestNonce,
            user: user,
            assetOut: assetOut,
            amountOfShares: amountOfShares,
            price: price,
            amountOfAssets: amountOfAssets,
            creationTime: block.timestamp,
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
            price,
            amountOfAssets,
            block.timestamp,
            secondsToDeadline
        );
    }

    function _dequeueOnChainWithdraw(OnChainWithdraw calldata request) internal returns (bytes32 requestId) {
        // Remove request from queue.
        requestId = keccak256(abi.encode(request));
        bool removedFromSet = _withdrawRequests.remove(requestId);
        if (!removedFromSet) revert BoringOnChainQueue__RequestNotFound();
    }
}
