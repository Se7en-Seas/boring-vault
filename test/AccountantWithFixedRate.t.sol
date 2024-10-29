// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithFixedRate} from "src/base/Roles/AccountantWithFixedRate.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {GenericRateProvider} from "src/helper/GenericRateProvider.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract AccountantWithFixedRateTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    BoringVault public boringVault;
    AccountantWithFixedRate public accountant;
    address public payout_address = vm.addr(7777777);
    RolesAuthority public rolesAuthority;
    GenericRateProvider public mETHRateProvider;
    GenericRateProvider public ptRateProvider;

    uint8 public constant MINTER_ROLE = 1;
    uint8 public constant ADMIN_ROLE = 2;
    uint8 public constant UPDATE_EXCHANGE_RATE_ROLE = 3;
    uint8 public constant BORING_VAULT_ROLE = 4;

    ERC20 internal WETH;
    ERC20 internal EETH;
    ERC20 internal WEETH;
    ERC20 internal ETHX;
    address internal liquidV1PriceRouter;
    address internal pendleEethPt;
    ERC20 internal METH;
    address internal mantleLspStaking;
    address internal WEETH_RATE_PROVIDER;

    uint16 managementFee = 0.01e4;
    uint16 performanceFee = 0.2e4;
    address yieldDistributor = vm.addr(3);

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19827152;
        _startFork(rpcKey, blockNumber);

        WETH = getERC20(sourceChain, "WETH");
        EETH = getERC20(sourceChain, "EETH");
        WEETH = getERC20(sourceChain, "WEETH");
        ETHX = getERC20(sourceChain, "ETHX");
        liquidV1PriceRouter = getAddress(sourceChain, "liquidV1PriceRouter");
        pendleEethPt = getAddress(sourceChain, "pendleEethPt");
        METH = getERC20(sourceChain, "METH");
        mantleLspStaking = getAddress(sourceChain, "mantleLspStaking");
        WEETH_RATE_PROVIDER = getAddress(sourceChain, "WEETH_RATE_PROVIDER");

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        accountant = new AccountantWithFixedRate(
            address(this),
            address(boringVault),
            payout_address,
            1e18,
            address(WETH),
            1.05e4,
            0.95e4,
            1,
            managementFee,
            performanceFee
        );

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        accountant.setAuthority(rolesAuthority);
        boringVault.setAuthority(rolesAuthority);

        // Setup roles authority.
        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
        // rolesAuthority.setRoleCapability(
        //     ADMIN_ROLE, address(accountant), AccountantWithRateProviders.pause.selector, true
        // );
        // rolesAuthority.setRoleCapability(
        //     ADMIN_ROLE, address(accountant), AccountantWithRateProviders.unpause.selector, true
        // );
        // rolesAuthority.setRoleCapability(
        //     ADMIN_ROLE, address(accountant), AccountantWithRateProviders.updateDelay.selector, true
        // );
        // rolesAuthority.setRoleCapability(
        //     ADMIN_ROLE, address(accountant), AccountantWithRateProviders.updateUpper.selector, true
        // );
        // rolesAuthority.setRoleCapability(
        //     ADMIN_ROLE, address(accountant), AccountantWithRateProviders.updateLower.selector, true
        // );
        // rolesAuthority.setRoleCapability(
        //     ADMIN_ROLE, address(accountant), AccountantWithRateProviders.updateManagementFee.selector, true
        // );
        // rolesAuthority.setRoleCapability(
        //     ADMIN_ROLE, address(accountant), AccountantWithRateProviders.updatePayoutAddress.selector, true
        // );
        // rolesAuthority.setRoleCapability(
        //     ADMIN_ROLE, address(accountant), AccountantWithRateProviders.setRateProviderData.selector, true
        // );
        // rolesAuthority.setRoleCapability(
        //     UPDATE_EXCHANGE_RATE_ROLE,
        //     address(accountant),
        //     AccountantWithRateProviders.updateExchangeRate.selector,
        //     true
        // );
        // rolesAuthority.setRoleCapability(
        //     BORING_VAULT_ROLE, address(accountant), AccountantWithRateProviders.claimFees.selector, true
        // );

        // Allow the boring vault to receive ETH.
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);

        rolesAuthority.setUserRole(address(this), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(this), UPDATE_EXCHANGE_RATE_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        deal(address(WETH), address(this), 1_000e18);
        WETH.safeApprove(address(boringVault), 1_000e18);
        boringVault.enter(address(this), WETH, 1_000e18, address(address(this)), 1_000e18);

        accountant.setRateProviderData(EETH, true, address(0));
        accountant.setRateProviderData(WEETH, false, address(WEETH_RATE_PROVIDER));

        accountant.setYieldDistributor(yieldDistributor);

        skip(1 days);
        // Perform first update so totalSupply saved is correct.
        accountant.updateExchangeRate(1e18);
    }

    function testUpdateExchangeRateLogic(
        uint96 firstUpdate,
        uint96 secondUpdate,
        uint256 firstDelay,
        uint256 secondDelay
    ) external {
        firstUpdate = uint96(bound(firstUpdate, 1.001e18, 1.01e18));
        secondUpdate = uint96(bound(secondUpdate, 0.99e18, 1e18));
        firstDelay = bound(firstDelay, 1 days, 7 days);
        secondDelay = bound(secondDelay, 1 days, 7 days);

        (uint96 startingYield,) = accountant.fixedRateAccountantState();

        assertEq(startingYield, 0, "Starting yield should be 0");

        skip(firstDelay);
        accountant.updateExchangeRate(firstUpdate);

        (uint96 firstYield,) = accountant.fixedRateAccountantState();

        uint256 totalSupply = boringVault.totalSupply(); // Also equal to min assets since exchange rate started at 1e18.
        uint256 grossYield = uint256(firstUpdate - 1e18).mulDivDown(totalSupply, 1e18);
        // Calculate management fee.
        uint256 expectedFee = totalSupply.mulDivDown(managementFee, 1e4);
        expectedFee = expectedFee.mulDivDown(firstDelay, 365 days);

        // Calculate performance fee.
        expectedFee += grossYield.mulDivDown(performanceFee, 1e4);

        assertEq(firstYield, uint96(grossYield - expectedFee), "First yield should be correct");

        skip(secondDelay);
        accountant.updateExchangeRate(secondUpdate);

        (uint96 secondYield,) = accountant.fixedRateAccountantState();

        // Update was not above fixed rate, so no yield should be earned.
        assertEq(secondYield, firstYield, "Second yield should be the same as first yield");
    }

    function testClaimYield() external {
        skip(1 days);
        accountant.updateExchangeRate(1.01e18);

        (uint96 yieldEarned, address distributor) = accountant.fixedRateAccountantState();
        assertGt(yieldEarned, 0, "Yield earned should be greater than 0");

        // Boring Vault approves accountant to spend wETH.
        vm.prank(address(boringVault));
        WETH.approve(address(accountant), yieldEarned);

        uint256 boringVaultBalance = WETH.balanceOf(address(boringVault));

        // Distributor calls claimYield.
        vm.prank(distributor);
        accountant.claimYield(WETH);

        assertEq(
            WETH.balanceOf(address(boringVault)),
            boringVaultBalance - yieldEarned,
            "Boring Vault balance should decrease"
        );
        assertEq(WETH.balanceOf(yieldDistributor), yieldEarned, "Yield distributor balance should increase");

        (yieldEarned,) = accountant.fixedRateAccountantState();

        assertEq(yieldEarned, 0, "Yield earned should be zero after claim");
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

interface MantleLspStaking {
    function mETHToETH(uint256) external view returns (uint256);
}

interface PriceRouter {
    function getValue(address, uint256, address) external view returns (uint256);
}
