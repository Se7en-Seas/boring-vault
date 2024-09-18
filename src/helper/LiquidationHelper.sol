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

    error LiquidationHelper__OnlyCallableByBalancerVault();
    error LiquidationHelper__OnlyCallableInFlashloan();
    error LiquidationHelper__OnlyBadFlashloanInputs();

    enum LiquidationType {
        AaveV3,
        Comet
    }

    IAaveV3Pool internal immutable aaveV3Pool;
    BalancerVault internal immutable balancerVault;
    TellerWithMultiAssetSupport internal immutable teller;
    AccountantWithRateProviders internal immutable accountant;
    ERC20 internal immutable boringVault;
    uint256 internal immutable ONE_SHARE;

    bool internal inLiquidation;

    constructor(address _owner, Authority _auth, address _aaveV3Pool, address _balancerVault, address _teller)
        Auth(_owner, _auth)
    {
        aaveV3Pool = IAaveV3Pool(_aaveV3Pool);
        balancerVault = BalancerVault(_balancerVault);
        teller = TellerWithMultiAssetSupport(_teller);
        accountant = AccountantWithRateProviders(teller.accountant());
        boringVault = ERC20(teller.vault());
        ONE_SHARE = 10 ** boringVault.decimals();
    }

    // ========================================= LIQUIDATION FUNCTIONS =========================================

    function liquidateUserOnAaveV3(ERC20 debt, address user, uint256 debtToCover, bool useFlashloan)
        external
        requiresAuth
    {
        if (useFlashloan) {
            address[] memory tokens = new address[](1);
            tokens[0] = address(debt);
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = debtToCover;
            bytes memory userData = abi.encode(LiquidationType.AaveV3, user, msg.sender);
            inLiquidation = true;
            balancerVault.flashLoan(address(this), tokens, amounts, userData);
            inLiquidation = false;
        } else {
            debt.safeTransferFrom(msg.sender, address(this), debtToCover);
            _liquidateUserOnAaveV3(debt, user, debtToCover, msg.sender);

            // Then transfer tokens back to liquidator.
            debt.safeTransfer(msg.sender, debtToCover);
        }
    }

    // Compound V3 liquidations
    function buyCollateralFromComet(
        IComet comet,
        address[] calldata users,
        uint256 minAmount,
        uint256 baseAmount,
        bool useFlashloan,
        bool absorb
    ) external requiresAuth {
        if (absorb) {
            comet.absorb(msg.sender, users);
        }

        ERC20 base = ERC20(comet.baseToken());

        if (useFlashloan) {
            address[] memory tokens = new address[](1);
            tokens[0] = address(base);
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = baseAmount;
            bytes memory userData = abi.encode(LiquidationType.Comet, comet, base, minAmount, baseAmount, msg.sender);
            inLiquidation = true;
            balancerVault.flashLoan(address(this), tokens, amounts, userData);
            inLiquidation = false;
        } else {
            base.safeTransferFrom(msg.sender, address(this), baseAmount);
            _buyCollateralFromComet(comet, base, minAmount, baseAmount, msg.sender);
        }
    }

    // ========================================= FLASHLOAN FUNCTIONS =========================================

    function receiveFlashLoan(
        ERC20[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata userData
    ) external {
        if (msg.sender != address(balancerVault)) revert LiquidationHelper__OnlyCallableByBalancerVault();
        if (!inLiquidation) revert LiquidationHelper__OnlyCallableInFlashloan();

        if (tokens.length != 1 || amounts.length != 1 || feeAmounts.length != 1 || feeAmounts[0] != 0) {
            revert LiquidationHelper__OnlyBadFlashloanInputs();
        }

        LiquidationType liquidationType = abi.decode(userData, (LiquidationType));

        if (liquidationType == LiquidationType.AaveV3) {
            (, address user, address liquidator) = abi.decode(userData, (LiquidationType, address, address));
            _liquidateUserOnAaveV3(tokens[0], user, amounts[0], liquidator);
        } else if (liquidationType == LiquidationType.Comet) {
            (, IComet comet, ERC20 base, uint256 minAmount, uint256 baseAmount, address liquidator) =
                abi.decode(userData, (LiquidationType, IComet, ERC20, uint256, uint256, address));
            _buyCollateralFromComet(comet, base, minAmount, baseAmount, liquidator);
        }

        // Then transfer tokens back to balancer
        tokens[0].safeTransfer(address(balancerVault), amounts[0] + feeAmounts[0]);
    }

    // ========================================= LIQUIDATION LOGIC FUNCTIONS =========================================

    function _liquidateUserOnAaveV3(ERC20 debt, address user, uint256 debtToCover, address liquidator) internal {
        // At this point this contract should have the debt asset to repay.
        debt.safeApprove(address(aaveV3Pool), debtToCover);
        uint256 boringVaultDelta = boringVault.balanceOf(address(this));
        aaveV3Pool.liquidationCall(address(boringVault), address(debt), user, debtToCover, false);
        boringVaultDelta = boringVault.balanceOf(address(this)) - boringVaultDelta;

        // Determine how many shares need to be withdrawn in order to cover the debt.
        uint256 sharesToWithdraw = debtToCover.mulDivDown(ONE_SHARE, accountant.getRateInQuoteSafe(debt)); // TODO might need to add 1 wei to account for rounding
        teller.bulkWithdraw(debt, sharesToWithdraw, debtToCover, address(this));

        // Send liquidator the excess shares.
        uint256 sharesToLiquidator = boringVaultDelta - sharesToWithdraw;
        boringVault.safeTransfer(liquidator, sharesToLiquidator);
    }

    function _buyCollateralFromComet(
        IComet comet,
        ERC20 base,
        uint256 minAmount,
        uint256 baseAmount,
        address liquidator
    ) internal {
        // At this point this contract should have the base asset to repay.
        base.safeApprove(address(comet), baseAmount);
        uint256 boringVaultDelta = boringVault.balanceOf(address(this));
        comet.buyCollateral(address(boringVault), minAmount, baseAmount, address(this));
        boringVaultDelta = boringVault.balanceOf(address(this)) - boringVaultDelta;

        // Determine how many shares need to be withdrawn in order to cover the base.
        uint256 sharesToWithdraw = baseAmount.mulDivDown(ONE_SHARE, accountant.getRateInQuoteSafe(base)); // TODO might need to add 1 wei to account for rounding
        teller.bulkWithdraw(base, sharesToWithdraw, baseAmount, address(this));

        // Send liquidator the excess shares.
        uint256 sharesToLiquidator = boringVaultDelta - sharesToWithdraw;
        boringVault.safeTransfer(liquidator, sharesToLiquidator);
    }
}
