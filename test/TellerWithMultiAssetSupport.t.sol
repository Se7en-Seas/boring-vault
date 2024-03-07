// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {ILiquidityPool} from "src/interfaces/IStaking.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

// TODO call functions from accounts without the roles.
contract TellerWithMultiAssetSupportTest is Test, MainnetAddresses {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    BoringVault public boring_vault;

    TellerWithMultiAssetSupport public teller;
    AccountantWithRateProviders public accountant;
    address public payout_address = vm.addr(7777777);
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    ERC20 internal constant NATIVE_ERC20 = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19363419;
        _startFork(rpcKey, blockNumber);

        boring_vault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        accountant = new AccountantWithRateProviders(
            address(this),
            address(this),
            address(this),
            address(boring_vault),
            payout_address,
            1e18,
            address(WETH),
            1.001e4,
            0.999e4,
            1,
            0
        );

        teller =
            new TellerWithMultiAssetSupport(address(this), address(boring_vault), address(accountant), address(WETH));

        boring_vault.grantRole(boring_vault.MINTER_ROLE(), address(teller));
        boring_vault.grantRole(boring_vault.BURNER_ROLE(), address(teller));

        teller.grantRole(teller.ADMIN_ROLE(), address(this));
        teller.grantRole(teller.ON_RAMP_ROLE(), address(this));
        teller.grantRole(teller.OFF_RAMP_ROLE(), address(this));

        teller.addAsset(WETH);
        teller.addAsset(ERC20(NATIVE));
        teller.addAsset(EETH);
        teller.addAsset(WEETH);

        accountant.setRateProviderData(EETH, true, address(0));
        accountant.setRateProviderData(WEETH, false, address(WEETH_RATE_PROVIDER));
    }

    function testUserDepositPeggedAssets(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);

        uint256 wETH_amount = amount;
        deal(address(WETH), address(this), wETH_amount);
        uint256 eETH_amount = amount;
        deal(address(this), eETH_amount + 1);
        ILiquidityPool(EETH_LIQUIDITY_POOL).deposit{value: eETH_amount + 1}();

        WETH.safeApprove(address(boring_vault), wETH_amount);
        EETH.safeApprove(address(boring_vault), eETH_amount);

        teller.deposit(WETH, wETH_amount, 0, address(this));
        teller.deposit(EETH, eETH_amount, 0, address(this));

        uint256 expected_shares = 2 * amount;

        assertEq(boring_vault.balanceOf(address(this)), expected_shares, "Should have received expected shares");
    }

    function testUserDepositNonPeggedAssets(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);

        uint256 weETH_amount = amount.mulDivDown(1e18, IRateProvider(WEETH_RATE_PROVIDER).getRate());
        deal(address(WEETH), address(this), weETH_amount);

        WEETH.safeApprove(address(boring_vault), weETH_amount);

        teller.deposit(WEETH, weETH_amount, 0, address(this));

        uint256 expected_shares = amount;

        assertApproxEqRel(
            boring_vault.balanceOf(address(this)), expected_shares, 0.000001e18, "Should have received expected shares"
        );
    }

    function testUserDepositNative(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);

        deal(address(this), 2 * amount);

        teller.deposit{value: amount}(ERC20(NATIVE), 0, 0, address(this));

        (bool ok,) = address(teller).call{value: amount}("");
        assertTrue(ok, "Failed to deposit with native");

        uint256 expected_shares = 2 * amount;

        assertEq(boring_vault.balanceOf(address(this)), expected_shares, "Should have received expected shares");
    }

    // TODO test bulk deposit and bulk withdraw.
    function testBulkDeposit(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);

        uint256 wETH_amount = amount;
        deal(address(WETH), address(this), wETH_amount);
        uint256 eETH_amount = amount;
        deal(address(this), eETH_amount + 1);
        ILiquidityPool(EETH_LIQUIDITY_POOL).deposit{value: eETH_amount + 1}();
        uint256 weETH_amount = amount.mulDivDown(1e18, IRateProvider(WEETH_RATE_PROVIDER).getRate());
        deal(address(WEETH), address(this), weETH_amount);

        WETH.safeApprove(address(boring_vault), wETH_amount);
        EETH.safeApprove(address(boring_vault), eETH_amount);
        WEETH.safeApprove(address(boring_vault), weETH_amount);

        teller.bulkDeposit(WETH, wETH_amount, 0, address(this));
        teller.bulkDeposit(EETH, eETH_amount, 0, address(this));
        teller.bulkDeposit(WEETH, weETH_amount, 0, address(this));

        uint256 expected_shares = 3 * amount;

        assertApproxEqRel(
            boring_vault.balanceOf(address(this)), expected_shares, 0.0001e18, "Should have received expected shares"
        );
    }

    function testBulkWithdraw(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);

        uint256 wETH_amount = amount;
        deal(address(WETH), address(this), wETH_amount);
        uint256 eETH_amount = amount;
        deal(address(this), eETH_amount + 1);
        ILiquidityPool(EETH_LIQUIDITY_POOL).deposit{value: eETH_amount + 1}();
        uint256 weETH_amount = amount.mulDivDown(1e18, IRateProvider(WEETH_RATE_PROVIDER).getRate());
        deal(address(WEETH), address(this), weETH_amount);

        WETH.safeApprove(address(boring_vault), wETH_amount);
        EETH.safeApprove(address(boring_vault), eETH_amount);
        WEETH.safeApprove(address(boring_vault), weETH_amount);

        uint256 shares_0 = teller.bulkDeposit(WETH, wETH_amount, 0, address(this));
        uint256 shares_1 = teller.bulkDeposit(EETH, eETH_amount, 0, address(this));
        uint256 shares_2 = teller.bulkDeposit(WEETH, weETH_amount, 0, address(this));

        uint256 assets_out_0 = teller.bulkWithdraw(WETH, shares_0, 0, address(this));
        uint256 assets_out_1 = teller.bulkWithdraw(EETH, shares_1, 0, address(this));
        uint256 assets_out_2 = teller.bulkWithdraw(WEETH, shares_2, 0, address(this));

        assertApproxEqAbs(assets_out_0, wETH_amount, 1, "Should have received expected wETH assets");
        assertApproxEqAbs(assets_out_1, eETH_amount, 1, "Should have received expected eETH assets");
        assertApproxEqAbs(assets_out_2, weETH_amount, 1, "Should have received expected weETH assets");
    }

    function testPausing() external {
        teller.pause();

        assertTrue(teller.isPaused() == true, "Teller should be paused");

        teller.unpause();

        assertTrue(teller.isPaused() == false, "Teller should be unpaused");
    }

    function testAssetIsSupported() external {
        assertTrue(teller.isSupported(WETH) == true, "WETH should be supported");

        teller.removeAsset(WETH);

        assertTrue(teller.isSupported(WETH) == false, "WETH should not be supported");

        teller.addAsset(WETH);

        assertTrue(teller.isSupported(WETH) == true, "WETH should be supported");
    }

    function testReverts() external {
        teller.pause();
        teller.removeAsset(WETH);

        // deposit reverts
        vm.expectRevert(bytes("paused"));
        teller.deposit(WETH, 0, 0, address(this));

        teller.unpause();

        vm.expectRevert(bytes("asset not supported"));
        teller.deposit(WETH, 0, 0, address(this));

        teller.addAsset(WETH);

        vm.expectRevert(bytes("zero deposit"));
        teller.deposit(WETH, 0, 0, address(this));

        vm.expectRevert(bytes("dual deposit"));
        teller.deposit{value: 1}(WETH, 1, 0, address(this));

        vm.expectRevert(bytes("minimumMint"));
        teller.deposit(WETH, 1, type(uint256).max, address(this));

        vm.expectRevert(bytes("zero deposit"));
        teller.deposit(NATIVE_ERC20, 0, 0, address(this));

        vm.expectRevert(bytes("minimumMint"));
        teller.deposit{value: 1}(NATIVE_ERC20, 1, type(uint256).max, address(this));

        // bulkDeposit reverts
        vm.expectRevert(bytes("zero deposit"));
        teller.bulkDeposit(WETH, 0, 0, address(this));

        vm.expectRevert(bytes("minimumMint"));
        teller.bulkDeposit(WETH, 1, type(uint256).max, address(this));

        // bulkWithdraw reverts
        vm.expectRevert(bytes("zero withdraw"));
        teller.bulkWithdraw(WETH, 0, 0, address(this));

        vm.expectRevert(bytes("minimumAssets"));
        teller.bulkWithdraw(WETH, 1, type(uint256).max, address(this));
    }

    // TODO test checking slippage check
    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
