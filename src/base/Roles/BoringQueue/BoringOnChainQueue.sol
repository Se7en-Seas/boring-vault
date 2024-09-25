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

contract BoringOnChainQueue is Auth, ReentrancyGuard, IPausable {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using SafeTransferLib for BoringVault;
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    struct WithdrawAsset {
        bool allowWithdraws;
        uint24 secondsToMature;
        uint24 secondsToDeadline;
        uint16 maxLoss;
        uint16 minDiscount;
        uint16 maxDiscount;
        uint128 totalShares;
    }

    EnumerableSet.Bytes32Set private _withdrawRequests;

    mapping(address => mapping(address => WithdrawAsset)) public withdrawAssets; // BoringVault -> Asset -> WithdrawAsset

    struct OnChainWithdraw {
        // Information
        uint256 nonce; // read from state, used to make it impossible for request Ids to be repeated.
        address boringVault; //input sanitized
        address accountant; // input sanitized
        address assetOut; // input sanitized
        address user; // msg.sender
        uint256 amountOfShares; // input transfered in
        uint256 price; // derived from discount and current share price
        uint256 creationTime; // time withdraw was made
        uint16 maxLoss; // input
        uint16 discount; // input this doesnt actually need to be stored.
        uint24 secondsToMature; // in contract, from withdrawAsset? To get maturity you take the creation time and add the secondsToMature
        uint24 secondsToDeadline; // in contract, from withdrawAsset? To get the deadline you take the creationTime and add the secondsToDeadline
            // Or the deadline in seconds is optionally user provided
    }

    uint256 public nonce;

    event OnChainWithdrawRequested(bytes32 indexed requestId, address indexed user, address indexed boringVault, address indexed accountant, address indexed assetOut, uint256 amountOfShares, uint256 price, uint256 creationTime, uint16 maxLoss, uint16 discount, uint24 secondsToMature, uint24 secondsToDeadline);

    function requestOnChainWithdraw(
        ERC20 boringVault,
        AccountantWithRateProviders accountant,
        ERC20 assetOut,
        uint256 amountOfShares,
        uint16 maxLoss,
        uint16 discount,
        uint24 secondsToDeadline
    ) external requiresAuth returns(bytes32 requestId) {
        // sanitize boringVault, accountant, assetOut

        uint256 price = accountant.getRateInQuoteSafe(ERC20(assetOut));
        price = price.mulDivDown(1e4 - discount, 1e4);
        OnChainWithdraw memory req = OnChainWithdraw({
            nonce: nonce,
            boringVault: address(boringVault),
            accountant: address(accountant),
            assetOut: address(assetOut),
            user: msg.sender,
            amountOfShares: amountOfShares,
            price: price,
            creationTime: block.timestamp,
            maxLoss: maxLoss,
            discount: discount,
            secondsToMature: withdrawAssets[boringVault][assetOut].secondsToMature,
            secondsToDeadline: secondsToDeadline
        });

        requestId = keccak256(abi.encodePacked(req))

        bool addedToSet = _withdrawRequests.add(requestId);
        // Optionally instead of a set, it could just be a mapping of bytes32 -> bool or potentially to a special bool struct

        require(addedToSet, "Request already exists");
    }

    // What if we look at the current exchange rate, and compare it to the price.
    // If price is higher than the exchange rate, share price has gone down, so we want to recalculate the price.

    // What is the price isnt an input rather we calculate it based off the current share price and the discount they set
    // If the price is lower than the current share price, we just give them the price set in the contract
    // If it is higher than we calculate a new price, and compare it to the old price using the maxLoss
}
