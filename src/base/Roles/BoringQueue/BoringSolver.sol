// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {BoringOnChainQueue, ERC20, SafeTransferLib} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {IBoringSolver} from "src/base/Roles/BoringQueue/IBoringSolver.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";

contract BoringSolver is IBoringSolver, Auth, Multicall {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    // ========================================= ENUMS =========================================
    enum SolveType {
        BORING_REDEEM, // Fill multiple user requests with a single transaction.
        BORING_REDEEM_MINT // Fill multiple user requests to redeem shares and mint new shares.

    }

    //============================== ERRORS ===============================
    error BoringSolver___WrongInitiator();
    error BoringSolver___BoringVaultTellerMismatch(address boringVault, address teller);
    error BoringSolver___OnlySelf();
    error BoringSolver___FailedToSolve();
    error BoringSolver___OnlyQueue();

    //============================== IMMUTABLES ===============================

    BoringOnChainQueue internal immutable queue;

    constructor(address _owner, address _auth, address _queue) Auth(_owner, Authority(_auth)) {
        queue = BoringOnChainQueue(_queue);
    }

    //============================== ADMIN FUNCTIONS ===============================

    /**
     * @notice Allows the owner to rescue tokens from the contract.
     * @dev This should not normally be used, but it is possible that when performing a MIGRATION_REDEEM,
     *      the redemption of Cellar shares will return assets other than BoringVault shares.
     *      If the amount of assets is significant, it is very likely the solve will revert, but it is
     *      not guaranteed to revert, hence this function.
     */
    function rescueTokens(ERC20 token, uint256 amount) external requiresAuth {
        if (amount == type(uint256).max) amount = token.balanceOf(address(this));
        token.safeTransfer(msg.sender, amount);
    }

    //============================== ADMIN SOLVE FUNCTIONS ===============================

    /**
     * @notice Solve multiple user requests to redeem Boring Vault shares.
     */
    function boringRedeemSolve(BoringOnChainQueue.OnChainWithdraw[] calldata requests, address teller)
        external
        requiresAuth
    {
        bytes memory solveData = abi.encode(SolveType.BORING_REDEEM, msg.sender, teller, true);

        queue.solveOnChainWithdraws(requests, solveData, address(this));
    }

    /**
     * @notice Solve multiple user requests to redeem Boring Vault shares and mint new Boring Vault shares.
     * @dev In order for this to work, the fromAccountant must have the toBoringVaults rate provider setup.
     */
    function boringRedeemMintSolve(
        BoringOnChainQueue.OnChainWithdraw[] calldata requests,
        address fromTeller,
        address toTeller,
        address intermediateAsset
    ) external requiresAuth {
        bytes memory solveData =
            abi.encode(SolveType.BORING_REDEEM_MINT, msg.sender, fromTeller, toTeller, intermediateAsset, true);

        queue.solveOnChainWithdraws(requests, solveData, address(this));
    }

    //============================== USER SOLVE FUNCTIONS ===============================

    /**
     * @notice Allows a user to solve their own request to redeem Boring Vault shares.
     */
    function boringRedeemSelfSolve(BoringOnChainQueue.OnChainWithdraw calldata request, address teller)
        external
        requiresAuth
    {
        if (request.user != msg.sender) revert BoringSolver___OnlySelf();

        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](1);
        requests[0] = request;

        bytes memory solveData = abi.encode(SolveType.BORING_REDEEM, msg.sender, teller, false);

        queue.solveOnChainWithdraws(requests, solveData, address(this));
    }

    /**
     * @notice Allows a user to solve their own request to redeem Boring Vault shares and mint new Boring Vault shares.
     * @dev In order for this to work, the fromAccountant must have the toBoringVaults rate provider setup.
     */
    function boringRedeemMintSelfSolve(
        BoringOnChainQueue.OnChainWithdraw calldata request,
        address fromTeller,
        address toTeller,
        address intermediateAsset
    ) external requiresAuth {
        if (request.user != msg.sender) revert BoringSolver___OnlySelf();

        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](1);
        requests[0] = request;

        bytes memory solveData =
            abi.encode(SolveType.BORING_REDEEM_MINT, msg.sender, fromTeller, toTeller, intermediateAsset, false);

        queue.solveOnChainWithdraws(requests, solveData, address(this));
    }

    //============================== IBORINGSOLVER FUNCTIONS ===============================

    /**
     * @notice Implementation of the IBoringSolver interface.
     */
    function boringSolve(
        address initiator,
        address boringVault,
        address solveAsset,
        uint256 totalShares,
        uint256 requiredAssets,
        bytes calldata solveData
    ) external requiresAuth {
        if (msg.sender != address(queue)) revert BoringSolver___OnlyQueue();
        if (initiator != address(this)) revert BoringSolver___WrongInitiator();

        SolveType solveType = abi.decode(solveData, (SolveType));

        if (solveType == SolveType.BORING_REDEEM) {
            _boringRedeemSolve(solveData, boringVault, solveAsset, totalShares, requiredAssets);
        } else if (solveType == SolveType.BORING_REDEEM_MINT) {
            _boringRedeemMintSolve(solveData, boringVault, solveAsset, totalShares, requiredAssets);
        } else {
            // Added for future protection, if another enum is added, txs with that enum will revert,
            // if no changes are made here.
            revert BoringSolver___FailedToSolve();
        }
    }

    //============================== INTERNAL SOLVE FUNCTIONS ===============================

    /**
     * @notice Internal helper function to solve multiple user requests to redeem Boring Vault shares.
     */
    function _boringRedeemSolve(
        bytes calldata solveData,
        address boringVault,
        address solveAsset,
        uint256 totalShares,
        uint256 requiredAssets
    ) internal {
        (, address solverOrigin, TellerWithMultiAssetSupport teller, bool excessToSolver) =
            abi.decode(solveData, (SolveType, address, TellerWithMultiAssetSupport, bool));

        if (boringVault != address(teller.vault())) {
            revert BoringSolver___BoringVaultTellerMismatch(boringVault, address(teller));
        }

        ERC20 asset = ERC20(solveAsset);
        // Redeem the Boring Vault shares for Solve Asset.
        uint256 assetsOut = teller.bulkWithdraw(asset, totalShares, requiredAssets, address(this));

        // Transfer excess assets to solver origin or Boring Vault.
        // Assets are sent to solver to cover gas fees.
        // But if users are self solving, then the excess assets go to the Boring Vault.
        if (excessToSolver) {
            asset.safeTransfer(solverOrigin, assetsOut - requiredAssets);
        } else {
            asset.safeTransfer(boringVault, assetsOut - requiredAssets);
        }

        // Approve Boring Queue to spend the required assets.
        asset.approve(address(queue), requiredAssets);
    }

    /**
     * @notice Internal helper function to solve multiple user requests to redeem Boring Vault shares and mint new Boring Vault shares.
     */
    function _boringRedeemMintSolve(
        bytes calldata solveData,
        address fromBoringVault,
        address toBoringVault,
        uint256 totalShares,
        uint256 requiredShares
    ) internal {
        (
            ,
            address solverOrigin,
            TellerWithMultiAssetSupport fromTeller,
            TellerWithMultiAssetSupport toTeller,
            ERC20 intermediateAsset,
            bool excessToSolver
        ) = abi.decode(
            solveData, (SolveType, address, TellerWithMultiAssetSupport, TellerWithMultiAssetSupport, ERC20, bool)
        );

        if (fromBoringVault != address(fromTeller.vault())) {
            revert BoringSolver___BoringVaultTellerMismatch(fromBoringVault, address(fromTeller));
        }

        if (toBoringVault != address(toTeller.vault())) {
            revert BoringSolver___BoringVaultTellerMismatch(toBoringVault, address(toTeller));
        }

        // Redeem the fromBoringVault shares for Intermediate Asset.
        uint256 excessAssets = fromTeller.bulkWithdraw(intermediateAsset, totalShares, 0, address(this));
        {
            // Determine how many assets are needed to mint requiredAssets worth of toBoringVault shares.
            // Note mulDivUp is used to ensure we always mint enough assets to cover the requiredShares.
            uint256 assetsToMintRequiredShares = requiredShares.mulDivUp(
                toTeller.accountant().getRateInQuoteSafe(intermediateAsset), BoringOnChainQueue(queue).ONE_SHARE()
            );

            // Remove assetsToMintRequiredShares from excessAssets.
            excessAssets = excessAssets - assetsToMintRequiredShares;

            // Approve toBoringVault to spend the Intermediate Asset.
            intermediateAsset.safeApprove(toBoringVault, assetsToMintRequiredShares);

            // Mint to BoringVault shares using Intermediate Asset.
            toTeller.bulkDeposit(intermediateAsset, assetsToMintRequiredShares, requiredShares, address(this));
        }

        // Transfer excess assets to solver origin or Boring Vault.
        // Assets are sent to solver to cover gas fees.
        // But if users are self solving, then the excess assets go to the from Boring Vault.
        if (excessToSolver) {
            intermediateAsset.safeTransfer(solverOrigin, excessAssets);
        } else {
            intermediateAsset.safeTransfer(fromBoringVault, excessAssets);
        }

        // Approve Boring Queue to spend the required assets.
        ERC20(toBoringVault).approve(address(queue), requiredShares);
    }
}
