// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";

contract BoringOnChainQueueWithTracking is BoringOnChainQueue {
    // ========================================= GLOBAL STATE =========================================

    /**
     * @notice Whether or not to track withdraws on chain.
     */
    bool public trackWithdrawsOnChain;

    /**
     * @notice Mapping of request Ids to OnChainWithdraws.
     */
    mapping(bytes32 => OnChainWithdraw) internal onChainWithdraws;

    //============================== ERRORS ===============================

    error BoringOnChainQueue__ZeroNonce();

    //============================== IMMUTABLES ===============================

    constructor(
        address _owner,
        address _auth,
        address payable _boringVault,
        address _accountant,
        bool _trackWithdrawsOnChain
    ) BoringOnChainQueue(_owner, _auth, _boringVault, _accountant) {
        trackWithdrawsOnChain = _trackWithdrawsOnChain;
    }

    //=============================== ADMIN FUNCTIONS ================================

    /**
     * @notice Toggle whether or not to track withdraws on chain.
     * @dev Callable by MULTISIG_ROLE.
     */
    function toggleTrackWithdrawsOnChain() external requiresAuth {
        bool oldState = trackWithdrawsOnChain;
        trackWithdrawsOnChain = !oldState;
        emit TrackWithdrawsOnChainToggled(!oldState);
    }

    //=============================== USER FUNCTIONS ================================

    /**
     * @notice Cancel an on-chain withdraw using the request Id.
     */
    function cancelOnChainWithdrawUsingRequestId(bytes32 requestId)
        external
        requiresAuth
        returns (OnChainWithdraw memory request)
    {
        request = getOnChainWithdraw(requestId);
        _cancelOnChainWithdrawWithUserCheck(request);
    }

    /**
     * @notice Replace an on-chain withdraw using the request Id.
     * @dev Reverts if the request is not mature.
     * @param oldRequestId The request Id to replace.
     * @param discount The discount to apply to the withdraw in bps.
     * @param secondsToDeadline The time in seconds the request is valid for.
     * @return oldRequest The old request.
     * @return newRequestId The new request Id.
     */
    function replaceOnChainWithdrawUsingRequestId(bytes32 oldRequestId, uint16 discount, uint24 secondsToDeadline)
        external
        requiresAuth
        returns (OnChainWithdraw memory oldRequest, bytes32 newRequestId)
    {
        oldRequest = getOnChainWithdraw(oldRequestId);
        (, newRequestId) = _replaceOnChainWithdrawWithUserCheck(oldRequest, discount, secondsToDeadline);
    }

    //============================== VIEW FUNCTIONS ===============================

    /**
     * @notice Get all withdraw requests.
     * @dev Includes requests that are not mature, matured, and expired. But does not include requests that have been solved.
     * @dev Does not verify nonce is zero, as you could have not been tracking withdraws for a period of time.
     * @dev If withdraws are made when not tracking, they will show up as empty requests here.
     */
    function getWithdrawRequests()
        external
        view
        returns (bytes32[] memory requestIds, OnChainWithdraw[] memory requests)
    {
        requestIds = getRequestIds();
        uint256 requestsLength = requestIds.length;
        requests = new OnChainWithdraw[](requestsLength);
        for (uint256 i = 0; i < requestsLength; ++i) {
            requests[i] = onChainWithdraws[requestIds[i]];
        }
    }

    /**
     * @notice Get a withdraw request.
     * @dev Does verify nonce is non-zero.
     * @param requestId The request Id.
     * @return request The request.
     */
    function getOnChainWithdraw(bytes32 requestId) public view returns (OnChainWithdraw memory) {
        OnChainWithdraw memory request = onChainWithdraws[requestId];
        if (request.nonce == 0) revert BoringOnChainQueue__ZeroNonce();
        return onChainWithdraws[requestId];
    }

    //============================= INTERNAL FUNCTIONS ==============================

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
    ) internal override returns (bytes32 requestId, OnChainWithdraw memory req) {
        (requestId, req) =
            super._queueOnChainWithdraw(user, assetOut, amountOfShares, discount, secondsToMaturity, secondsToDeadline);

        if (trackWithdrawsOnChain) {
            // Save withdraw request on chain.
            onChainWithdraws[requestId] = req;
        }
    }
}
