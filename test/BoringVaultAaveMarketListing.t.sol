// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper, ERC20} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {LiquidationHelper} from "src/helper/LiquidationHelper.sol";
import {AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/src/20240902_AaveV3EthereumEtherFi_EtherFiEthereumActivation/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902.sol";
import {MockAaveOracle} from "src/helper/MockAaveOracle.sol";
import {IAaveV3Pool} from "src/interfaces/IAaveV3Pool.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract BoringDroneTest is Test, MerkleTreeHelper {
    using Address for address;

    address public aavePayloadController = 0xdAbad81aF85554E9ae636395611C58F7eC1aAEc5;
    address public aaveCreatePayloadCaller = 0x020E4359255f907DF480EbFfc8a7b7beac0c0216;
    address public aaveExecutePayloadCaller = 0x3Cbded22F878aFC8d39dCD744d3Fe62086B76193;
    address public aaveQueuePayloadCaller = 0xEd42a7D8559a463722Ca4beD50E0Cc05a386b0e1;
    address public aaveExecutor = 0x5300A1a15135EA4dc7aD5a167152C01EFc9b192A;

    address usdcWhale = 0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341;
    address public aaveMarketSetup;
    address public mockOracle;
    LiquidationHelper public liquidationHelper;
    IAaveV3Pool public aaveV3Pool;
    AaveOracle public oracle;

    address public constant weETHs = 0x917ceE801a67f933F2e6b33fC0cD1ED2d5909D88;
    address public constant weETHs_accountant = 0xbe16605B22a7faCEf247363312121670DFe5afBE;
    address public constant weETHs_teller = 0x99dE9e5a3eC2750a6983C8732E6e795A35e7B861;
    address public constant eth_usd_feed = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    AccountantWithRateProviders public accountant = AccountantWithRateProviders(weETHs_accountant);
    TellerWithMultiAssetSupport public teller = TellerWithMultiAssetSupport(weETHs_teller);
    address public exchangeRateUpdater = 0x41DFc53B13932a2690C9790527C1967d8579a6ae;
    address public boringVaultOwner = 0xCEA8039076E35a825854c5C2f85659430b06ec96;

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 20676058; // The block number before create payload was called

        // Then this is the tx where the payload was created.
        // https://etherscan.io/tx/0x025defc34c08bbe6c0fe56213cd11ec5d5dad8f66c817155a09de33d4f06e431
        // When the payload was executed.
        // https://etherscan.io/tx/0x8dce3e22688d50eaba48fbd1805623e7b7b9cb8910c96e609f279906c3d6ef67
        _startFork(rpcKey, blockNumber);
        setSourceChainName("mainnet");

        // Give executor enough assets to execute the payload.
        deal(getAddress(sourceChain, "WEETH"), aaveExecutor, 1e18);
        vm.startPrank(usdcWhale);
        getERC20(sourceChain, "USDC").transfer(aaveExecutor, 1_000_000e6);
        getERC20(sourceChain, "USDC").transfer(address(this), 1_000_000e6);
        vm.stopPrank();
        deal(getAddress(sourceChain, "PYUSD"), aaveExecutor, 1_000_000e6);
        deal(getAddress(sourceChain, "FRAX"), aaveExecutor, 1_000_000e18);
        deal(weETHs, aaveExecutor, 1e18);

        mockOracle = address(new MockAaveOracle(weETHs_accountant, eth_usd_feed));

        assertTrue(mockOracle == 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f, "Update oracle in aave setup contract");

        oracle = AaveOracle(getAddress(sourceChain, "v3Oracle"));

        LiquidationHelper.WithdrawOrder[] memory preferredWithdrawOrder = new LiquidationHelper.WithdrawOrder[](3);
        preferredWithdrawOrder[0] =
            LiquidationHelper.WithdrawOrder({asset: getERC20(sourceChain, "WEETH"), amount: type(uint96).max});
        preferredWithdrawOrder[1] =
            LiquidationHelper.WithdrawOrder({asset: getERC20(sourceChain, "WETH"), amount: type(uint96).max});
        preferredWithdrawOrder[2] =
            LiquidationHelper.WithdrawOrder({asset: getERC20(sourceChain, "WSTETH"), amount: type(uint96).max});

        liquidationHelper = new LiquidationHelper(
            address(this),
            Authority(address(0)),
            getAddress(sourceChain, "v3EtherFiPool"),
            weETHs_teller,
            preferredWithdrawOrder
        );

        // give liquidation helper SOLVER_ROLE so it can call bulkWithdraw
        RolesAuthority auth = RolesAuthority(address(accountant.authority()));

        vm.prank(boringVaultOwner);
        auth.setUserRole(address(liquidationHelper), 12, true);

        aaveV3Pool = IAaveV3Pool(getAddress(sourceChain, "v3EtherFiPool"));

        aaveMarketSetup = address(new AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902());

        Action[] memory actions = new Action[](1);
        actions[0] = Action({
            target: aaveMarketSetup,
            withDelegateCall: true,
            accessLevel: 1,
            value: 0,
            signature: "execute()",
            callData: hex""
        });

        bytes memory payload =
            abi.encodeWithSignature("createPayload((address,bool,uint8,uint256,string,bytes)[])", actions);

        // Create payload
        vm.prank(aaveCreatePayloadCaller);
        (bool success,) = aavePayloadController.call(payload);
        require(success, "Failed to create payload");

        // Queue payload
        bytes memory queuePayload =
            hex"15034cba0000000000000000000000009aee0b04504cef83a65ac3f0e838d0593bcb2bc700000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a600000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000066d9c2d7";
        vm.prank(aaveQueuePayloadCaller);
        (success,) = aavePayloadController.call(queuePayload);

        skip(5 days);
        payload = abi.encodeWithSignature("executePayload(uint40)", 166);
        vm.prank(aaveExecutePayloadCaller);
        (success,) = aavePayloadController.call(payload);
        require(success, "Failed to execute payload");

        deal(getAddress(sourceChain, "WETH"), address(this), 0);
    }

    function testSupplyingweETHsAndBorrowing() public {
        address user = vm.addr(1);
        deal(weETHs, user, 1_000e18);

        vm.startPrank(user);
        // Approve pool to spend weETHs.
        ERC20(weETHs).approve(address(aaveV3Pool), 1_000e18);

        // Supply weETHs to the pool.
        aaveV3Pool.supply(weETHs, 1_000e18, user, 0);

        address debt = getAddress(sourceChain, "USDC");
        uint256 debtToCover = 1_000e6;

        // Borrow USDC from pool.
        aaveV3Pool.borrow(debt, debtToCover, 2, 0, user);

        vm.stopPrank();

        // Check if we have borrowed USDC.
        assertEq(getERC20(sourceChain, "USDC").balanceOf(user), 1_000e6, "User should have borrowed 1_000 USDC");
    }

    function testLiquidatingOneWithdraw0() public {
        address userToLiquidate = vm.addr(1);
        ERC20 debt = getERC20(sourceChain, "USDC");
        uint256 collateralAmount = 10e18;
        uint256 targetLTV = 0.8e6; // This should have the same decimals as the debt asset.
        // Zero out all but once balance.
        deal(getAddress(sourceChain, "WEETH"), weETHs, collateralAmount);
        deal(getAddress(sourceChain, "WETH"), weETHs, 0);
        deal(getAddress(sourceChain, "WSTETH"), weETHs, 0);
        uint256 currentRate = accountant.getRate();
        uint256 borrowAmount = _setUserUpForLiquidation(
            userToLiquidate, debt, collateralAmount, targetLTV, uint96(currentRate * 0.9999e4 / 1e4)
        );

        // Try to liquidate the user.
        debt.approve(address(liquidationHelper), borrowAmount);
        liquidationHelper.liquidateUserOnAaveV3AndWithdrawInPreferredOrder(debt, userToLiquidate, borrowAmount);

        assertGt(
            getERC20(sourceChain, "WEETH").balanceOf(address(this)),
            0,
            "This address should have got weETH from liquidation"
        );
    }

    function testLiquidatingOneWithdraw1() public {
        address userToLiquidate = vm.addr(1);
        ERC20 debt = getERC20(sourceChain, "USDC");
        uint256 collateralAmount = 10e18;
        uint256 targetLTV = 0.8e6; // This should have the same decimals as the debt asset.
        // Zero out all but once balance.
        deal(getAddress(sourceChain, "WEETH"), weETHs, 0);
        deal(getAddress(sourceChain, "WETH"), weETHs, collateralAmount);
        deal(getAddress(sourceChain, "WSTETH"), weETHs, 0);
        uint256 currentRate = accountant.getRate();
        uint256 borrowAmount = _setUserUpForLiquidation(
            userToLiquidate, debt, collateralAmount, targetLTV, uint96(currentRate * 0.9999e4 / 1e4)
        );

        // Try to liquidate the user.
        debt.approve(address(liquidationHelper), borrowAmount);
        liquidationHelper.liquidateUserOnAaveV3AndWithdrawInPreferredOrder(debt, userToLiquidate, borrowAmount);

        assertGt(
            getERC20(sourceChain, "WETH").balanceOf(address(this)),
            0,
            "This address should have got wETH from liquidation"
        );
    }

    function testLiquidatingOneWithdraw2() public {
        address userToLiquidate = vm.addr(1);
        ERC20 debt = getERC20(sourceChain, "USDC");
        uint256 collateralAmount = 10e18;
        uint256 targetLTV = 0.8e6; // This should have the same decimals as the debt asset.
        // Zero out all but once balance.
        deal(getAddress(sourceChain, "WEETH"), weETHs, 0);
        deal(getAddress(sourceChain, "WETH"), weETHs, 0);
        deal(getAddress(sourceChain, "WSTETH"), weETHs, collateralAmount);
        uint256 currentRate = accountant.getRate();
        uint256 borrowAmount = _setUserUpForLiquidation(
            userToLiquidate, debt, collateralAmount, targetLTV, uint96(currentRate * 0.9999e4 / 1e4)
        );

        // Try to liquidate the user.
        debt.approve(address(liquidationHelper), borrowAmount);
        liquidationHelper.liquidateUserOnAaveV3AndWithdrawInPreferredOrder(debt, userToLiquidate, borrowAmount);

        assertGt(
            getERC20(sourceChain, "WSTETH").balanceOf(address(this)),
            0,
            "This address should have got wstETH from liquidation"
        );
    }

    function testLiquidatingMultipleWithdraw0() public {
        address userToLiquidate = vm.addr(1);
        ERC20 debt = getERC20(sourceChain, "USDC");
        uint256 collateralAmount = 10e18;
        uint256 targetLTV = 0.8e6; // This should have the same decimals as the debt asset.
        // Zero out all but once balance.
        deal(getAddress(sourceChain, "WEETH"), weETHs, 0.001e18);
        deal(getAddress(sourceChain, "WETH"), weETHs, collateralAmount);
        deal(getAddress(sourceChain, "WSTETH"), weETHs, 0);
        uint256 currentRate = accountant.getRate();
        uint256 borrowAmount = _setUserUpForLiquidation(
            userToLiquidate, debt, collateralAmount, targetLTV, uint96(currentRate * 0.9999e4 / 1e4)
        );

        // Try to liquidate the user.
        debt.approve(address(liquidationHelper), borrowAmount);
        liquidationHelper.liquidateUserOnAaveV3AndWithdrawInPreferredOrder(debt, userToLiquidate, borrowAmount);

        assertGt(
            getERC20(sourceChain, "WEETH").balanceOf(address(this)),
            0,
            "This address should have got weETH from liquidation"
        );
        assertGt(
            getERC20(sourceChain, "WETH").balanceOf(address(this)),
            0,
            "This address should have got wETH from liquidation"
        );
    }

    function testLiquidatingMultipleWithdraw1() public {
        address userToLiquidate = vm.addr(1);
        ERC20 debt = getERC20(sourceChain, "USDC");
        uint256 collateralAmount = 10e18;
        uint256 targetLTV = 0.8e6; // This should have the same decimals as the debt asset.
        // Zero out all but once balance.
        deal(getAddress(sourceChain, "WEETH"), weETHs, 0.001e18);
        deal(getAddress(sourceChain, "WETH"), weETHs, 0.001e18);
        deal(getAddress(sourceChain, "WSTETH"), weETHs, collateralAmount);
        uint256 currentRate = accountant.getRate();
        uint256 borrowAmount = _setUserUpForLiquidation(
            userToLiquidate, debt, collateralAmount, targetLTV, uint96(currentRate * 0.9999e4 / 1e4)
        );

        // Try to liquidate the user.
        debt.approve(address(liquidationHelper), borrowAmount);
        liquidationHelper.liquidateUserOnAaveV3AndWithdrawInPreferredOrder(debt, userToLiquidate, borrowAmount);

        assertGt(
            getERC20(sourceChain, "WEETH").balanceOf(address(this)),
            0,
            "This address should have got weETH from liquidation"
        );
        assertGt(
            getERC20(sourceChain, "WETH").balanceOf(address(this)),
            0,
            "This address should have got wETH from liquidation"
        );
        assertGt(
            getERC20(sourceChain, "WSTETH").balanceOf(address(this)),
            0,
            "This address should have got wstETH from liquidation"
        );
    }

    function testLiquidatingMultipleWithdraw2() public {
        address userToLiquidate = vm.addr(1);
        ERC20 debt = getERC20(sourceChain, "USDC");
        uint256 collateralAmount = 10e18;
        uint256 targetLTV = 0.8e6; // This should have the same decimals as the debt asset.
        // Zero out all but once balance.
        deal(getAddress(sourceChain, "WEETH"), weETHs, 0.001e18);
        deal(getAddress(sourceChain, "WETH"), weETHs, 0.001e18);
        deal(getAddress(sourceChain, "WSTETH"), weETHs, 0.001e18);
        uint256 currentRate = accountant.getRate();
        uint256 borrowAmount = _setUserUpForLiquidation(
            userToLiquidate, debt, collateralAmount, targetLTV, uint96(currentRate * 0.9999e4 / 1e4)
        );

        // Try to liquidate the user.
        debt.approve(address(liquidationHelper), borrowAmount);
        liquidationHelper.liquidateUserOnAaveV3AndWithdrawInPreferredOrder(debt, userToLiquidate, borrowAmount);

        assertGt(
            getERC20(sourceChain, "WEETH").balanceOf(address(this)),
            0,
            "This address should have got weETH from liquidation"
        );
        assertGt(
            getERC20(sourceChain, "WETH").balanceOf(address(this)),
            0,
            "This address should have got wETH from liquidation"
        );
        assertGt(
            getERC20(sourceChain, "WSTETH").balanceOf(address(this)),
            0,
            "This address should have got wstETH from liquidation"
        );

        assertGt(ERC20(weETHs).balanceOf(address(this)), 0, "This address should have got weETHs from liquidation");
        assertEq(
            ERC20(weETHs).balanceOf(address(liquidationHelper)),
            0,
            "Liquidation Helper should have zero weETHs from liquidation"
        );
    }

    function testLiquidatingWhenTellerPaused() public {
        address userToLiquidate = vm.addr(1);
        ERC20 debt = getERC20(sourceChain, "USDC");
        uint256 collateralAmount = 10e18;
        uint256 targetLTV = 0.8e6; // This should have the same decimals as the debt asset.
        // Zero out all but once balance.
        deal(getAddress(sourceChain, "WEETH"), weETHs, 0.001e18);
        deal(getAddress(sourceChain, "WETH"), weETHs, 0.001e18);
        deal(getAddress(sourceChain, "WSTETH"), weETHs, 0.001e18);
        uint256 currentRate = accountant.getRate();
        uint256 borrowAmount = _setUserUpForLiquidation(
            userToLiquidate, debt, collateralAmount, targetLTV, uint96(currentRate * 0.9999e4 / 1e4)
        );

        // Pause Teller.
        vm.prank(boringVaultOwner);
        teller.pause();

        // Try to liquidate the user.
        debt.approve(address(liquidationHelper), borrowAmount);
        liquidationHelper.liquidateUserOnAaveV3AndWithdrawInPreferredOrder(debt, userToLiquidate, borrowAmount);

        assertEq(
            getERC20(sourceChain, "WEETH").balanceOf(address(this)),
            0,
            "This address should get zero weETH from liquidation"
        );
        assertEq(
            getERC20(sourceChain, "WETH").balanceOf(address(this)),
            0,
            "This address should get zero wETH from liquidation"
        );
        assertEq(
            getERC20(sourceChain, "WSTETH").balanceOf(address(this)),
            0,
            "This address should get zero wstETH from liquidation"
        );

        assertGt(ERC20(weETHs).balanceOf(address(this)), 0, "This address should have got weETHs from liquidation");
        assertEq(
            ERC20(weETHs).balanceOf(address(liquidationHelper)),
            0,
            "Liquidation Helper should have zero weETHs from liquidation"
        );
    }

    function testLiquidatingWhenAccountantPaused() public {
        address userToLiquidate = vm.addr(1);
        ERC20 debt = getERC20(sourceChain, "USDC");
        uint256 collateralAmount = 10e18;
        uint256 targetLTV = 0.8e6; // This should have the same decimals as the debt asset.
        // Zero out all but once balance.
        deal(getAddress(sourceChain, "WEETH"), weETHs, 0.001e18);
        deal(getAddress(sourceChain, "WETH"), weETHs, 0.001e18);
        deal(getAddress(sourceChain, "WSTETH"), weETHs, 0.001e18);
        uint256 currentRate = accountant.getRate();
        uint256 borrowAmount = _setUserUpForLiquidation(
            userToLiquidate, debt, collateralAmount, targetLTV, uint96(currentRate * 0.9999e4 / 1e4)
        );

        // Pause Accountant.
        vm.prank(boringVaultOwner);
        accountant.pause();

        // Try to liquidate the user.
        debt.approve(address(liquidationHelper), borrowAmount);
        vm.expectRevert(
            bytes(abi.encodeWithSelector(AccountantWithRateProviders.AccountantWithRateProviders__Paused.selector))
        );
        liquidationHelper.liquidateUserOnAaveV3AndWithdrawInPreferredOrder(debt, userToLiquidate, borrowAmount);
    }

    function testLiquidatingInCustomOrder() public {
        address userToLiquidate = vm.addr(1);
        ERC20 debt = getERC20(sourceChain, "USDC");
        uint256 collateralAmount = 10e18;
        uint256 targetLTV = 0.8e6; // This should have the same decimals as the debt asset.
        // Zero out all but once balance.
        deal(getAddress(sourceChain, "WEETH"), weETHs, 777);
        deal(getAddress(sourceChain, "WETH"), weETHs, collateralAmount);
        deal(getAddress(sourceChain, "WSTETH"), weETHs, 0);
        uint256 currentRate = accountant.getRate();
        uint256 borrowAmount = _setUserUpForLiquidation(
            userToLiquidate, debt, collateralAmount, targetLTV, uint96(currentRate * 0.9999e4 / 1e4)
        );

        LiquidationHelper.WithdrawOrder[] memory customWithdrawOrder = new LiquidationHelper.WithdrawOrder[](2);
        customWithdrawOrder[0] = LiquidationHelper.WithdrawOrder({asset: getERC20(sourceChain, "WEETH"), amount: 777});
        customWithdrawOrder[1] =
            LiquidationHelper.WithdrawOrder({asset: getERC20(sourceChain, "WETH"), amount: type(uint96).max});
        // Try to liquidate the user.
        debt.approve(address(liquidationHelper), borrowAmount);
        liquidationHelper.liquidateUserOnAaveV3AndWithdrawInCustomOrder(
            debt, userToLiquidate, borrowAmount, customWithdrawOrder
        );

        assertApproxEqAbs(
            getERC20(sourceChain, "WEETH").balanceOf(address(this)),
            777,
            1,
            "This address should have got 777 weETH from liquidation"
        );

        assertGt(
            getERC20(sourceChain, "WETH").balanceOf(address(this)),
            0,
            "This address should have got wETH from liquidation"
        );
    }

    function testLiquidatingInCustomOrderWithHugeAmount() public {
        address userToLiquidate = vm.addr(1);
        ERC20 debt = getERC20(sourceChain, "USDC");
        uint256 collateralAmount = 10e18;
        uint256 targetLTV = 0.8e6; // This should have the same decimals as the debt asset.
        // Zero out all but once balance.
        deal(getAddress(sourceChain, "WEETH"), weETHs, collateralAmount);
        deal(getAddress(sourceChain, "WETH"), weETHs, 0);
        deal(getAddress(sourceChain, "WSTETH"), weETHs, 0);
        uint256 currentRate = accountant.getRate();
        uint256 borrowAmount = _setUserUpForLiquidation(
            userToLiquidate, debt, collateralAmount, targetLTV, uint96(currentRate * 0.9999e4 / 1e4)
        );

        LiquidationHelper.WithdrawOrder[] memory customWithdrawOrder = new LiquidationHelper.WithdrawOrder[](1);
        customWithdrawOrder[0] =
            LiquidationHelper.WithdrawOrder({asset: getERC20(sourceChain, "WEETH"), amount: type(uint96).max - 1});
        // Try to liquidate the user.
        debt.approve(address(liquidationHelper), borrowAmount);
        liquidationHelper.liquidateUserOnAaveV3AndWithdrawInCustomOrder(
            debt, userToLiquidate, borrowAmount, customWithdrawOrder
        );

        assertGt(
            getERC20(sourceChain, "WEETH").balanceOf(address(this)),
            0,
            "This address should have got weETH from liquidation"
        );
    }

    function testLiquidatingInCustomOrderDuplicateAssets() public {
        address userToLiquidate = vm.addr(1);
        ERC20 debt = getERC20(sourceChain, "USDC");
        uint256 collateralAmount = 10e18;
        uint256 targetLTV = 0.8e6; // This should have the same decimals as the debt asset.
        // Zero out all but once balance.
        deal(getAddress(sourceChain, "WEETH"), weETHs, collateralAmount);
        deal(getAddress(sourceChain, "WETH"), weETHs, 0);
        deal(getAddress(sourceChain, "WSTETH"), weETHs, 0);
        uint256 currentRate = accountant.getRate();
        uint256 borrowAmount = _setUserUpForLiquidation(
            userToLiquidate, debt, collateralAmount, targetLTV, uint96(currentRate * 0.9999e4 / 1e4)
        );

        LiquidationHelper.WithdrawOrder[] memory customWithdrawOrder = new LiquidationHelper.WithdrawOrder[](2);
        customWithdrawOrder[0] = LiquidationHelper.WithdrawOrder({asset: getERC20(sourceChain, "WEETH"), amount: 777});
        customWithdrawOrder[1] =
            LiquidationHelper.WithdrawOrder({asset: getERC20(sourceChain, "WEETH"), amount: type(uint96).max});
        // Try to liquidate the user.
        debt.approve(address(liquidationHelper), borrowAmount);
        liquidationHelper.liquidateUserOnAaveV3AndWithdrawInCustomOrder(
            debt, userToLiquidate, borrowAmount, customWithdrawOrder
        );

        assertGt(
            getERC20(sourceChain, "WEETH").balanceOf(address(this)),
            0,
            "This address should have got weETH from liquidation"
        );
    }

    function testLiquidatingInCustomOrderUnsupportedAsset() public {
        address userToLiquidate = vm.addr(1);
        ERC20 debt = getERC20(sourceChain, "USDC");
        uint256 collateralAmount = 10e18;
        uint256 targetLTV = 0.8e6; // This should have the same decimals as the debt asset.
        // Zero out all but once balance.
        deal(getAddress(sourceChain, "WEETH"), weETHs, collateralAmount);
        deal(getAddress(sourceChain, "WETH"), weETHs, 0);
        deal(getAddress(sourceChain, "WSTETH"), weETHs, 0);
        uint256 currentRate = accountant.getRate();
        uint256 borrowAmount = _setUserUpForLiquidation(
            userToLiquidate, debt, collateralAmount, targetLTV, uint96(currentRate * 0.9999e4 / 1e4)
        );

        LiquidationHelper.WithdrawOrder[] memory customWithdrawOrder = new LiquidationHelper.WithdrawOrder[](2);
        customWithdrawOrder[0] = LiquidationHelper.WithdrawOrder({asset: getERC20(sourceChain, "WEETH"), amount: 777});
        customWithdrawOrder[1] =
            LiquidationHelper.WithdrawOrder({asset: getERC20(sourceChain, "USDC"), amount: type(uint96).max - 1});
        // Try to liquidate the user.
        debt.approve(address(liquidationHelper), borrowAmount);

        /// NOTE this call can still work if the unsupported asset has amount of type(uint96).max, and BoringVault has
        /// a zero balance of it.
        // USDC is not supported, so call reverts
        vm.expectRevert();
        liquidationHelper.liquidateUserOnAaveV3AndWithdrawInCustomOrder(
            debt, userToLiquidate, borrowAmount, customWithdrawOrder
        );
    }

    function testChangingPreferredWithdrawOrder() external {
        LiquidationHelper.WithdrawOrder[] memory preferredWithdrawOrder = new LiquidationHelper.WithdrawOrder[](2);
        preferredWithdrawOrder[0] =
            LiquidationHelper.WithdrawOrder({asset: getERC20(sourceChain, "WETH"), amount: type(uint96).max});
        preferredWithdrawOrder[1] =
            LiquidationHelper.WithdrawOrder({asset: getERC20(sourceChain, "EETH"), amount: type(uint96).max});

        liquidationHelper.setPreferredWithdrawOrder(preferredWithdrawOrder);

        (ERC20 asset0,) = liquidationHelper.preferredWithdrawOrder(0);
        (ERC20 asset1,) = liquidationHelper.preferredWithdrawOrder(1);

        // Querying for index 2 should revert.
        vm.expectRevert();
        liquidationHelper.preferredWithdrawOrder(2);

        assertTrue(asset0 == getERC20(sourceChain, "WETH"), "First asset should be wETH");
        assertTrue(asset1 == getERC20(sourceChain, "EETH"), "Second asset should be eETH");

        // Trying to set a preferred withdraw order with a non type uint96 amount should revert with error.
        preferredWithdrawOrder[0] =
            LiquidationHelper.WithdrawOrder({asset: getERC20(sourceChain, "WETH"), amount: type(uint96).max});
        preferredWithdrawOrder[1] =
            LiquidationHelper.WithdrawOrder({asset: getERC20(sourceChain, "EETH"), amount: type(uint96).max - 1});

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    LiquidationHelper.LiquidationHelper__PreferredWithdrawOrderInputMustHaveMaxAmounts.selector
                )
            )
        );
        liquidationHelper.setPreferredWithdrawOrder(preferredWithdrawOrder);
    }
    // ========================================= HELPER FUNCTIONS =========================================

    struct Action {
        address target;
        bool withDelegateCall;
        uint8 accessLevel;
        uint256 value;
        string signature;
        bytes callData;
    }

    receive() external payable {}

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }

    function _setUserUpForLiquidation(
        address userToLiquidate,
        ERC20 debt,
        uint256 collateralAmount,
        uint256 targetLTV,
        uint96 newExchangeRate
    ) internal returns (uint256 borrowAmount) {
        uint256 collateralPrice = uint256(MockAaveOracle(mockOracle).latestAnswer());
        uint256 debtPrice = oracle.getAssetPrice(address(debt));
        uint256 collateralValue = collateralPrice * collateralAmount / 1e18;
        borrowAmount = targetLTV * collateralValue / debtPrice;
        deal(weETHs, userToLiquidate, collateralAmount);

        vm.startPrank(userToLiquidate);
        // Approve pool to spend weETHs.
        ERC20(weETHs).approve(address(aaveV3Pool), collateralAmount);

        // Supply weETHs to the pool.
        aaveV3Pool.supply(weETHs, collateralAmount, userToLiquidate, 0);

        // Borrow from pool.
        aaveV3Pool.borrow(address(debt), borrowAmount, 2, 0, userToLiquidate);

        vm.stopPrank();

        // Update exchange rate to a very low value.
        vm.prank(exchangeRateUpdater);
        accountant.updateExchangeRate(newExchangeRate);

        vm.prank(boringVaultOwner);
        accountant.unpause();
    }
}

interface AaveOracle {
    function getAssetPrice(address asset) external view returns (uint256);
}
