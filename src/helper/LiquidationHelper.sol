// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {IAaveV3Pool} from "src/interfaces/IAaveV3Pool.sol";
import {IComet} from "src/interfaces/IComet.sol";

contract LiquidationHelper is Auth {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    error LiquidationHelper__PreferredWithdrawOrderInputMustHaveMaxAmounts();

    struct WithdrawOrder {
        ERC20 asset;
        uint96 amount; // if type(uint96).max is used, we try to withdraw as much as possible from the BoringVault for that asset
    }

    WithdrawOrder[] public preferredWithdrawOrder;

    IAaveV3Pool internal immutable aaveV3Pool;
    TellerWithMultiAssetSupport internal immutable teller;
    AccountantWithRateProviders internal immutable accountant;
    ERC20 internal immutable boringVault;
    uint256 internal immutable ONE_SHARE;

    bool internal inLiquidation;

    constructor(
        address _owner,
        Authority _auth,
        address _aaveV3Pool,
        address _teller,
        WithdrawOrder[] memory _preferredWithdrawOrder
    ) Auth(_owner, _auth) {
        aaveV3Pool = IAaveV3Pool(_aaveV3Pool);
        teller = TellerWithMultiAssetSupport(_teller);
        accountant = AccountantWithRateProviders(teller.accountant());
        boringVault = ERC20(teller.vault());
        ONE_SHARE = 10 ** boringVault.decimals();
        // Okay for this to be empty.
        for (uint256 i; i < _preferredWithdrawOrder.length; ++i) {
            if (_preferredWithdrawOrder[i].amount != type(uint96).max) {
                revert LiquidationHelper__PreferredWithdrawOrderInputMustHaveMaxAmounts();
            }
            preferredWithdrawOrder.push(_preferredWithdrawOrder[i]);
        }
    }

    // ============================================ ADMIN FUNCTIONS ============================================
    function setPreferredWithdrawOrder(WithdrawOrder[] calldata _preferredWithdrawOrder) external requiresAuth {
        delete preferredWithdrawOrder;
        for (uint256 i; i < _preferredWithdrawOrder.length; ++i) {
            if (_preferredWithdrawOrder[i].amount != type(uint96).max) {
                revert LiquidationHelper__PreferredWithdrawOrderInputMustHaveMaxAmounts();
            }
            preferredWithdrawOrder.push(_preferredWithdrawOrder[i]);
        }
    }

    // ========================================= LIQUIDATION FUNCTIONS =========================================

    function liquidateUserOnAaveV3AndWithdrawInPreferredOrder(ERC20 debt, address user, uint256 debtToCover)
        external
        requiresAuth
    {
        debt.safeTransferFrom(msg.sender, address(this), debtToCover);
        WithdrawOrder[] memory withdrawOrder = preferredWithdrawOrder;
        uint256 totalShares = _liquidateUserOnAaveV3(debt, user, debtToCover);
        _withdrawFromBoringVaultInOrder(totalShares, withdrawOrder, msg.sender);
    }

    function liquidateUserOnAaveV3AndWithdrawInCustomOrder(
        ERC20 debt,
        address user,
        uint256 debtToCover,
        WithdrawOrder[] calldata withdrawOrder
    ) external requiresAuth {
        debt.safeTransferFrom(msg.sender, address(this), debtToCover);
        uint256 totalShares = _liquidateUserOnAaveV3(debt, user, debtToCover);
        _withdrawFromBoringVaultInOrder(totalShares, withdrawOrder, msg.sender);
    }

    function buyCollateralFromCometAndWithdrawInPreferredOrder(IComet comet, uint256 minAmount, uint256 baseAmount)
        external
        requiresAuth
    {
        WithdrawOrder[] memory withdrawOrder = preferredWithdrawOrder;

        ERC20 base = ERC20(comet.baseToken());

        base.safeTransferFrom(msg.sender, address(this), baseAmount);
        uint256 totalShares = _buyCollateralFromComet(comet, base, minAmount, baseAmount);
        _withdrawFromBoringVaultInOrder(totalShares, withdrawOrder, msg.sender);
    }

    function buyCollateralFromCometAndWithdrawInCustomOrder(
        IComet comet,
        uint256 minAmount,
        uint256 baseAmount,
        WithdrawOrder[] calldata withdrawOrder
    ) external requiresAuth {
        ERC20 base = ERC20(comet.baseToken());

        base.safeTransferFrom(msg.sender, address(this), baseAmount);
        uint256 totalShares = _buyCollateralFromComet(comet, base, minAmount, baseAmount);
        _withdrawFromBoringVaultInOrder(totalShares, withdrawOrder, msg.sender);
    }

    // ========================================= INTERNAL FUNCTIONS =========================================

    function _liquidateUserOnAaveV3(ERC20 debt, address user, uint256 debtToCover)
        internal
        returns (uint256 boringVaultDelta)
    {
        // At this point this contract should have the debt asset to repay.
        debt.safeApprove(address(aaveV3Pool), debtToCover);
        boringVaultDelta = boringVault.balanceOf(address(this));
        aaveV3Pool.liquidationCall(address(boringVault), address(debt), user, debtToCover, false);
        boringVaultDelta = boringVault.balanceOf(address(this)) - boringVaultDelta;
    }

    function _buyCollateralFromComet(IComet comet, ERC20 base, uint256 minAmount, uint256 baseAmount)
        internal
        returns (uint256 boringVaultDelta)
    {
        // At this point this contract should have the base asset to repay.
        base.safeApprove(address(comet), baseAmount);
        boringVaultDelta = boringVault.balanceOf(address(this));
        comet.buyCollateral(address(boringVault), minAmount, baseAmount, address(this));
        boringVaultDelta = boringVault.balanceOf(address(this)) - boringVaultDelta;
    }

    /**
     * @notice We allow liquidations to work when the Teller is paused because the end state of sending the
     *         BoringVault shares to the liquidator is the same end state as if the liquidator interacted directly
     *         with the AaveV3 pool to perform the liquidation.
     * @notice Lending platforms should price Boring Vault assets using getRateSafe() as opposed to the normal getRate.
     */
    function _withdrawFromBoringVaultInOrder(
        uint256 totalShares,
        WithdrawOrder[] memory withdrawOrder,
        address liquidator
    ) internal {
        // Only attempt withdraws if Teller is not paused.
        if (!teller.isPaused()) {
            for (uint256 i; i < withdrawOrder.length; ++i) {
                if (totalShares == 0) break;
                uint256 amountInShares;
                uint256 amountInAsset = uint256(withdrawOrder[i].amount);
                if (amountInAsset == type(uint96).max) {
                    uint256 boringVaultBalance = withdrawOrder[i].asset.balanceOf(address(boringVault));
                    if (boringVaultBalance == 0) {
                        continue;
                    }
                    amountInShares =
                        boringVaultBalance.mulDivDown(ONE_SHARE, accountant.getRateInQuoteSafe(withdrawOrder[i].asset));
                } else {
                    amountInShares =
                        amountInAsset.mulDivDown(ONE_SHARE, accountant.getRateInQuoteSafe(withdrawOrder[i].asset));
                }
                // Limit amountInShares, so that we don't revert from subtraction underflow.
                amountInShares = amountInShares > totalShares ? totalShares : amountInShares;
                // Skip withdraw if calculated `amountInShares` is zero.
                if (amountInShares == 0) continue;
                totalShares -= amountInShares;
                teller.bulkWithdraw(withdrawOrder[i].asset, amountInShares, 0, liquidator);
            }
        }

        // Transfer remaining shares to liquidator.
        if (totalShares > 0) {
            boringVault.safeTransfer(liquidator, totalShares);
        }
    }
}
