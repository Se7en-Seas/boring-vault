// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ReentrancyGuard} from "@solmate/utils/ReentrancyGuard.sol";
import {IAtomicSolver} from "./IAtomicSolver.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {IPausable} from "src/interfaces/IPausable.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";

/**
 * @title AtomicQueue
 * @notice Allows users to create `AtomicRequests` that specify an ERC20 asset to `offer`
 *         and an ERC20 asset to `want` in return.
 * @notice Making atomic requests where the exchange rate between offer and want is not
 *         relatively stable is effectively the same as placing a limit order between
 *         those assets, so requests can be filled at a rate worse than the current market rate.
 * @notice It is possible for a user to make multiple requests that use the same offer asset.
 *         If this is done it is important that the user has approved the queue to spend the
 *         total amount of assets aggregated from all their requests, and to also have enough
 *         `offer` asset to cover the aggregate total request of `offerAmount`.
 * @author crispymangoes
 */
contract AtomicQueue is Auth, ReentrancyGuard, IPausable {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    // ========================================= STRUCTS =========================================

    /**
     * @notice Stores request information needed to fulfill a users atomic request.
     * @param deadline unix timestamp for when request is no longer valid
     * @param atomicPrice the price in terms of `want` asset the user wants their `offer` assets "sold" at
     * @dev atomicPrice MUST be in terms of `want` asset decimals.
     * @param offerAmount the amount of `offer` asset the user wants converted to `want` asset
     * @param inSolve bool used during solves to prevent duplicate users, and to prevent redoing multiple checks
     */
    struct AtomicRequest {
        uint64 deadline; // deadline to fulfill request
        uint88 atomicPrice; // In terms of want asset decimals
        uint96 offerAmount; // The amount of offer asset the user wants to sell.
        bool inSolve; // Indicates whether this user is currently having their request fulfilled.
    }

    /**
     * @notice Used in `viewSolveMetaData` helper function to return data in a clean struct.
     * @param user the address of the user
     * @param flags 8 bits indicating the state of the user only the first 4 bits are used XXXX0000
     *              Either all flags are false(user is solvable) or only 1 is true(an error occurred).
     *              From right to left
     *              - 0: indicates user deadline has passed.
     *              - 1: indicates user request has zero offer amount.
     *              - 2: indicates user does not have enough offer asset in wallet.
     *              - 3: indicates user has not given AtomicQueue approval.
     * @param assetsToOffer the amount of offer asset to solve
     * @param assetsForWant the amount of assets users want for their offer assets
     */
    struct SolveMetaData {
        address user;
        uint8 flags;
        uint256 assetsToOffer;
        uint256 assetsForWant;
    }

    /**
     * @notice Used in `viewVerboseSolveMetaData` helper function to return data in a clean struct.
     * @param user the address of the user
     * @param deadlineExceeded indicates if the user has passed their deadline
     * @param zeroOfferAmount indicates if the user has a zero offer amount
     * @param insufficientOfferBalance indicates if the user has insufficient offer balance
     * @param insufficientOfferAllowance indicates if the user has insufficient offer allowance
     * @param assetsToOffer the amount of offer asset to solve
     * @param assetsForWant the amount of assets users want for their offer assets
     */
    struct VerboseSolveMetaData {
        address user;
        bool deadlineExceeded;
        bool zeroOfferAmount;
        bool insufficientOfferBalance;
        bool insufficientOfferAllowance;
        uint256 assetsToOffer;
        uint256 assetsForWant;
    }

    // ========================================= CONSTANTS =========================================

    /**
     * @notice When using safeUpdateAtomicRequest, this is the max discount that can be applied.
     */
    uint256 public constant MAX_DISCOUNT = 0.01e6;

    // ========================================= GLOBAL STATE =========================================

    /**
     * @notice Maps user address to offer asset to want asset to a AtomicRequest struct.
     */
    mapping(address => mapping(ERC20 => mapping(ERC20 => AtomicRequest))) public userAtomicRequest;

    /**
     * @notice Used to pause calls to `updateAtomicRequest` and `solve`.
     */
    bool public isPaused;

    //============================== ERRORS ===============================

    error AtomicQueue__UserRepeated(address user);
    error AtomicQueue__RequestDeadlineExceeded(address user);
    error AtomicQueue__UserNotInSolve(address user);
    error AtomicQueue__ZeroOfferAmount(address user);
    error AtomicQueue__SafeRequestOfferAmountGreaterThanOfferBalance(uint256 offerAmount, uint256 offerBalance);
    error AtomicQueue__SafeRequestDeadlineExceeded(uint256 deadline);
    error AtomicQueue__SafeRequestInsufficientOfferAllowance(uint256 offerAmount, uint256 offerAllowance);
    error AtomicQueue__SafeRequestOfferAmountZero();
    error AtomicQueue__SafeRequestDiscountTooLarge();
    error AtomicQueue__SafeRequestAccountantOfferMismatch();
    error AtomicQueue__SafeRequestCannotCastToUint88();
    error AtomicQueue__Paused();

    //============================== EVENTS ===============================

    /**
     * @notice Emitted when `updateAtomicRequest` is called.
     */
    event AtomicRequestUpdated(
        address indexed user,
        address indexed offerToken,
        address indexed wantToken,
        uint256 amount,
        uint256 deadline,
        uint256 minPrice,
        uint256 timestamp
    );

    /**
     * @notice Emitted when `solve` exchanges a users offer asset for their want asset.
     */
    event AtomicRequestFulfilled(
        address indexed user,
        address indexed offerToken,
        address indexed wantToken,
        uint256 offerAmountSpent,
        uint256 wantAmountReceived,
        uint256 timestamp
    );

    /**
     * @notice Emitted when the contract is paused.
     */
    event Paused();

    /**
     * @notice Emitted when the contract is unpaused.
     */
    event Unpaused();

    //============================== IMMUTABLES ===============================

    constructor(address _owner, Authority _auth) Auth(_owner, _auth) {}

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Pause this contract, which prevents future calls to `updateExchangeRate`, and any safe rate
     *         calls will revert.
     * @dev Callable by MULTISIG_ROLE.
     */
    function pause() external requiresAuth {
        isPaused = true;
        emit Paused();
    }

    /**
     * @notice Unpause this contract, which allows future calls to `updateExchangeRate`, and any safe rate
     *         calls will stop reverting.
     * @dev Callable by MULTISIG_ROLE.
     */
    function unpause() external requiresAuth {
        isPaused = false;
        emit Unpaused();
    }

    //============================== USER FUNCTIONS ===============================

    /**
     * @notice Get a users Atomic Request.
     * @param user the address of the user to get the request for
     * @param offer the ERC0 token they want to exchange for the want
     * @param want the ERC20 token they want in exchange for the offer
     */
    function getUserAtomicRequest(address user, ERC20 offer, ERC20 want) external view returns (AtomicRequest memory) {
        return userAtomicRequest[user][offer][want];
    }

    /**
     * @notice Helper function that returns either
     *         true: Withdraw request is valid.
     *         false: Withdraw request is not valid.
     * @dev It is possible for a withdraw request to return false from this function, but using the
     *      request in `updateAtomicRequest` will succeed, but solvers will not be able to include
     *      the user in `solve` unless some other state is changed.
     * @param offer the ERC0 token they want to exchange for the want
     * @param user the address of the user making the request
     * @param userRequest the request struct to validate
     */
    function isAtomicRequestValid(ERC20 offer, address user, AtomicRequest calldata userRequest)
        external
        view
        returns (bool)
    {
        // Validate amount.
        if (userRequest.offerAmount > offer.balanceOf(user)) return false;
        // Validate deadline.
        if (block.timestamp > userRequest.deadline) return false;
        // Validate approval.
        if (offer.allowance(user, address(this)) < userRequest.offerAmount) return false;
        // Validate offerAmount is nonzero.
        if (userRequest.offerAmount == 0) return false;
        // Validate atomicPrice is nonzero.
        if (userRequest.atomicPrice == 0) return false;

        return true;
    }

    /**
     * @notice Allows user to add/update their withdraw request.
     * @notice It is possible for a withdraw request with a zero atomicPrice to be made, and solved.
     *         If this happens, users will be selling their shares for no assets in return.
     *         To determine a safe atomicPrice, share.previewRedeem should be used to get
     *         a good share price, then the user can lower it from there to make their request fill faster.
     * @param offer the ERC20 token the user is offering in exchange for the want
     * @param want the ERC20 token the user wants in exchange for offer
     * @param userRequest the users request
     */
    function updateAtomicRequest(ERC20 offer, ERC20 want, AtomicRequest memory userRequest)
        external
        nonReentrant
        requiresAuth
    {
        _updateAtomicRequest(offer, want, userRequest);
    }

    /**
     * @notice Mostly identical to `updateAtomicRequest` but with additional checks to ensure the request is safe.
     * @notice Adds in accountant and discount to calculate a safe atomicPrice.
     * @dev This function will completely ignore the provided atomic price and calculate a new one based off the
     *      the accountant rate in quote and the discount provided.
     * @param accountant the accountant to use to get the rate in quote
     * @param discount the discount to apply to the rate in quote
     */
    function safeUpdateAtomicRequest(
        ERC20 offer,
        ERC20 want,
        AtomicRequest memory userRequest,
        AccountantWithRateProviders accountant,
        uint256 discount
    ) external nonReentrant requiresAuth {
        // Validate amount.
        uint256 offerBalance = offer.balanceOf(msg.sender);
        if (userRequest.offerAmount > offerBalance) {
            revert AtomicQueue__SafeRequestOfferAmountGreaterThanOfferBalance(userRequest.offerAmount, offerBalance);
        }
        // Validate deadline.
        if (block.timestamp > userRequest.deadline) {
            revert AtomicQueue__SafeRequestDeadlineExceeded(userRequest.deadline);
        }
        // Validate approval.
        uint256 offerAllowance = offer.allowance(msg.sender, address(this));
        if (offerAllowance < userRequest.offerAmount) {
            revert AtomicQueue__SafeRequestInsufficientOfferAllowance(userRequest.offerAmount, offerAllowance);
        }
        // Validate offerAmount is nonzero.
        if (userRequest.offerAmount == 0) revert AtomicQueue__SafeRequestOfferAmountZero();
        // Calculate atomic price.
        if (discount > MAX_DISCOUNT) revert AtomicQueue__SafeRequestDiscountTooLarge();
        if (address(offer) != address(accountant.vault())) revert AtomicQueue__SafeRequestAccountantOfferMismatch();
        uint256 safeRate = accountant.getRateInQuoteSafe(want);
        uint256 safeAtomicPrice = safeRate.mulDivDown(1e6 - discount, 1e6);
        if (safeAtomicPrice > type(uint88).max) revert AtomicQueue__SafeRequestCannotCastToUint88();
        userRequest.atomicPrice = uint88(safeAtomicPrice);
        _updateAtomicRequest(offer, want, userRequest);
    }

    //============================== SOLVER FUNCTIONS ===============================

    /**
     * @notice Called by solvers in order to exchange offer asset for want asset.
     * @notice Solvers are optimistically transferred the offer asset, then are required to
     *         approve this contract to spend enough of want assets to cover all requests.
     * @dev It is very likely `solve` TXs will be front run if broadcasted to public mem pools,
     *      so solvers should use private mem pools.
     * @param offer the ERC20 offer token to solve for
     * @param want the ERC20 want token to solve for
     * @param users an array of user addresses to solve for
     * @param runData extra data that is passed back to solver when `finishSolve` is called
     * @param solver the address to make `finishSolve` callback to
     */
    function solve(ERC20 offer, ERC20 want, address[] calldata users, bytes calldata runData, address solver)
        external
        nonReentrant
        requiresAuth
    {
        if (isPaused) revert AtomicQueue__Paused();

        // Save offer asset decimals.
        uint8 offerDecimals = offer.decimals();

        uint256 assetsToOffer;
        uint256 assetsForWant;
        for (uint256 i; i < users.length; ++i) {
            AtomicRequest storage request = userAtomicRequest[users[i]][offer][want];

            if (request.inSolve) revert AtomicQueue__UserRepeated(users[i]);
            if (block.timestamp > request.deadline) revert AtomicQueue__RequestDeadlineExceeded(users[i]);
            if (request.offerAmount == 0) revert AtomicQueue__ZeroOfferAmount(users[i]);

            // User gets whatever their atomic price * offerAmount is.
            assetsForWant += _calculateAssetAmount(request.offerAmount, request.atomicPrice, offerDecimals);

            // If all checks above passed, the users request is valid and should be fulfilled.
            assetsToOffer += request.offerAmount;
            request.inSolve = true;
            // Transfer shares from user to solver.
            offer.safeTransferFrom(users[i], solver, request.offerAmount);
        }

        IAtomicSolver(solver).finishSolve(runData, msg.sender, offer, want, assetsToOffer, assetsForWant);

        for (uint256 i; i < users.length; ++i) {
            AtomicRequest storage request = userAtomicRequest[users[i]][offer][want];

            if (request.inSolve) {
                // We know that the minimum price and deadline arguments are satisfied since this can only be true if they were.

                // Send user their share of assets.
                uint256 assetsToUser = _calculateAssetAmount(request.offerAmount, request.atomicPrice, offerDecimals);

                want.safeTransferFrom(solver, users[i], assetsToUser);

                emit AtomicRequestFulfilled(
                    users[i], address(offer), address(want), request.offerAmount, assetsToUser, block.timestamp
                );

                // Set shares to withdraw to 0.
                request.offerAmount = 0;
                request.inSolve = false;
            } else {
                revert AtomicQueue__UserNotInSolve(users[i]);
            }
        }
    }

    /**
     * @notice Helper function solvers can use to determine if users are solvable, and the required amounts to do so.
     * @notice Repeated users are not accounted for in this setup, so if solvers have repeat users in their `users`
     *         array the results can be wrong.
     * @dev Since a user can have multiple requests with the same offer asset but different want asset, it is
     *      possible for `viewSolveMetaData` to report no errors, but for a solve to fail, if any solves were done
     *      between the time `viewSolveMetaData` and before `solve` is called.
     * @param offer the ERC20 offer token to check for solvability
     * @param want the ERC20 want token to check for solvability
     * @param users an array of user addresses to check for solvability
     */
    function viewSolveMetaData(ERC20 offer, ERC20 want, address[] calldata users)
        external
        view
        returns (SolveMetaData[] memory metaData, uint256 totalAssetsForWant, uint256 totalAssetsToOffer)
    {
        // Save offer asset decimals.
        uint8 offerDecimals = offer.decimals();

        // Setup meta data.
        metaData = new SolveMetaData[](users.length);

        for (uint256 i; i < users.length; ++i) {
            AtomicRequest memory request = userAtomicRequest[users[i]][offer][want];

            metaData[i].user = users[i];

            if (block.timestamp > request.deadline) {
                metaData[i].flags |= uint8(1);
            }
            if (request.offerAmount == 0) {
                metaData[i].flags |= uint8(1) << 1;
            }
            if (offer.balanceOf(users[i]) < request.offerAmount) {
                metaData[i].flags |= uint8(1) << 2;
            }
            if (offer.allowance(users[i], address(this)) < request.offerAmount) {
                metaData[i].flags |= uint8(1) << 3;
            }

            metaData[i].assetsToOffer = request.offerAmount;

            // User gets whatever their execution share price is.
            uint256 userAssets = _calculateAssetAmount(request.offerAmount, request.atomicPrice, offerDecimals);
            metaData[i].assetsForWant = userAssets;

            // If flags is zero, no errors occurred.
            if (metaData[i].flags == 0) {
                totalAssetsForWant += userAssets;
                totalAssetsToOffer += request.offerAmount;
            }
        }
    }

    /**
     * @notice Helper function solvers can use to determine if users are solvable, and the required amounts to do so.
     * @notice Repeated users are not accounted for in this setup, so if solvers have repeat users in their `users`
     *         array the results can be wrong.
     * @dev Since a user can have multiple requests with the same offer asset but different want asset, it is
     *      possible for `viewSolveMetaData` to report no errors, but for a solve to fail, if any solves were done
     *      between the time `viewSolveMetaData` and before `solve` is called.
     * @param offer the ERC20 offer token to check for solvability
     * @param want the ERC20 want token to check for solvability
     * @param users an array of user addresses to check for solvability
     */
    function viewVerboseSolveMetaData(ERC20 offer, ERC20 want, address[] calldata users)
        external
        view
        returns (VerboseSolveMetaData[] memory metaData, uint256 totalAssetsForWant, uint256 totalAssetsToOffer)
    {
        // Save offer asset decimals.
        uint8 offerDecimals = offer.decimals();

        // Setup meta data.
        metaData = new VerboseSolveMetaData[](users.length);

        for (uint256 i; i < users.length; ++i) {
            AtomicRequest memory request = userAtomicRequest[users[i]][offer][want];

            metaData[i].user = users[i];

            if (block.timestamp > request.deadline) {
                metaData[i].deadlineExceeded = true;
            }
            if (request.offerAmount == 0) {
                metaData[i].zeroOfferAmount = true;
            }
            if (offer.balanceOf(users[i]) < request.offerAmount) {
                metaData[i].insufficientOfferBalance = true;
            }
            if (offer.allowance(users[i], address(this)) < request.offerAmount) {
                metaData[i].insufficientOfferAllowance = true;
            }

            metaData[i].assetsToOffer = request.offerAmount;

            // User gets whatever their execution share price is.
            uint256 userAssets = _calculateAssetAmount(request.offerAmount, request.atomicPrice, offerDecimals);
            metaData[i].assetsForWant = userAssets;

            // If flags is zero, no errors occurred.
            if (
                !metaData[i].deadlineExceeded && !metaData[i].zeroOfferAmount && !metaData[i].insufficientOfferBalance
                    && !metaData[i].insufficientOfferAllowance
            ) {
                totalAssetsForWant += userAssets;
                totalAssetsToOffer += request.offerAmount;
            }
        }
    }

    //============================== INTERNAL FUNCTIONS ===============================

    /**
     * @notice Allows user to add/update their withdraw request.
     * @notice It is possible for a withdraw request with a zero atomicPrice to be made, and solved.
     *         If this happens, users will be selling their shares for no assets in return.
     *         To determine a safe atomicPrice, share.previewRedeem should be used to get
     *         a good share price, then the user can lower it from there to make their request fill faster.
     * @param offer the ERC20 token the user is offering in exchange for the want
     * @param want the ERC20 token the user wants in exchange for offer
     * @param userRequest the users request
     */
    function _updateAtomicRequest(ERC20 offer, ERC20 want, AtomicRequest memory userRequest) internal {
        if (isPaused) revert AtomicQueue__Paused();
        AtomicRequest storage request = userAtomicRequest[msg.sender][offer][want];

        request.deadline = userRequest.deadline;
        request.atomicPrice = userRequest.atomicPrice;
        request.offerAmount = userRequest.offerAmount;

        // Emit full amount user has.
        emit AtomicRequestUpdated(
            msg.sender,
            address(offer),
            address(want),
            userRequest.offerAmount,
            userRequest.deadline,
            userRequest.atomicPrice,
            block.timestamp
        );
    }

    /**
     * @notice Helper function to calculate the amount of want assets a users wants in exchange for
     *         `offerAmount` of offer asset.
     */
    function _calculateAssetAmount(uint256 offerAmount, uint256 atomicPrice, uint8 offerDecimals)
        internal
        pure
        returns (uint256)
    {
        return atomicPrice.mulDivDown(offerAmount, 10 ** offerDecimals);
    }
}
