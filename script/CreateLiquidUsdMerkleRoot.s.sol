// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "forge-std/Script.sol";

/**
 * forge script script/CreateLiquidUsdMerkleRoot.s.sol:CreateLiquidUsdMerkleRootScript
 */
contract CreateLiquidUsdMerkleRootScript is Script, MainnetAddresses {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xc79cC44DC8A91330872D7815aE9CFB04405952ea;
    address public rawDataDecoderAndSanitizer = 0xdADc9DE5d8C9E2a34875A2CEa0cd415751E1791b;
    address public managerAddress = 0x048a5002E57166a78Dd060B3B36DEd2f404D0a17;
    address public accountantAddress = 0xc6f89cc0551c944CEae872997A4060DC95622D8F;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateLiquidUsdStrategistMerkleRoot();
    }

    function generateLiquidUsdStrategistMerkleRoot() public {
        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== Aave V3 ==========================
        /**
         * lend USDC, USDT, DAI, sDAI
         * borrow wETH, wstETH
         */
        {
            // Approvals
            leafs[0] = ManageLeaf(
                address(USDC),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Aave V3 Pool to spend USDC",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = v3Pool;
            leafs[0] = ManageLeaf(
                address(USDT),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Aave V3 Pool to spend USDT",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = v3Pool;
            leafs[0] = ManageLeaf(
                address(DAI),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Aave V3 Pool to spend DAI",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = v3Pool;
            leafs[0] = ManageLeaf(
                address(sDAI),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Aave V3 Pool to spend sDAI",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = v3Pool;
            leafs[0] = ManageLeaf(
                address(WETH),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Aave V3 Pool to spend wETH",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = v3Pool;
            leafs[0] = ManageLeaf(
                address(WSTETH),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Aave V3 Pool to spend wstETH",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = v3Pool;
            // Lending
            leafs[0] = ManageLeaf(
                v3Pool,
                false,
                "supply(address,uint256,address,uint16)",
                new address[](2),
                "Supply USDC to Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(USDC);
            leafs[0].argumentAddresses[1] = boringVault;
            leafs[0] = ManageLeaf(
                v3Pool,
                false,
                "supply(address,uint256,address,uint16)",
                new address[](2),
                "Supply USDT to Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(USDT);
            leafs[0].argumentAddresses[1] = boringVault;
            leafs[0] = ManageLeaf(
                v3Pool,
                false,
                "supply(address,uint256,address,uint16)",
                new address[](2),
                "Supply DAI to Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(DAI);
            leafs[0].argumentAddresses[1] = boringVault;
            leafs[0] = ManageLeaf(
                v3Pool,
                false,
                "supply(address,uint256,address,uint16)",
                new address[](2),
                "Supply sDAI to Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(sDAI);
            leafs[0].argumentAddresses[1] = boringVault;
            // Withdrawing
            leafs[0] = ManageLeaf(
                v3Pool,
                false,
                "withdraw(address,uint256,address)",
                new address[](2),
                "Withdraw USDC from Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(USDC);
            leafs[0].argumentAddresses[1] = boringVault;
            leafs[0] = ManageLeaf(
                v3Pool,
                false,
                "withdraw(address,uint256,address)",
                new address[](2),
                "Withdraw USDT from Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(USDT);
            leafs[0].argumentAddresses[1] = boringVault;
            leafs[0] = ManageLeaf(
                v3Pool,
                false,
                "withdraw(address,uint256,address)",
                new address[](2),
                "Withdraw DAI from Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(DAI);
            leafs[0].argumentAddresses[1] = boringVault;
            leafs[0] = ManageLeaf(
                v3Pool,
                false,
                "withdraw(address,uint256,address)",
                new address[](2),
                "Withdraw sDAI from Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(sDAI);
            leafs[0].argumentAddresses[1] = boringVault;
            // Borrowing
            leafs[0] = ManageLeaf(
                v3Pool,
                false,
                "borrow(address,uint256,uint256,uint16,address)",
                new address[](2),
                "Borrow wETH from Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(WETH);
            leafs[0].argumentAddresses[1] = boringVault;
            leafs[0] = ManageLeaf(
                v3Pool,
                false,
                "borrow(address,uint256,uint256,uint16,address)",
                new address[](2),
                "Borrow wstETH from Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(WSTETH);
            leafs[0].argumentAddresses[1] = boringVault;
            // Repaying
            leafs[0] = ManageLeaf(
                v3Pool,
                false,
                "repay(address,uint256,uint256,address)",
                new address[](2),
                "Repay wETH to Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(WETH);
            leafs[0].argumentAddresses[1] = boringVault;
            leafs[0] = ManageLeaf(
                v3Pool,
                false,
                "repay(address,uint256,uint256,address)",
                new address[](2),
                "Repay wstETH to Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(WSTETH);
            leafs[0].argumentAddresses[1] = boringVault;
            // Misc
            leafs[0] = ManageLeaf(
                v3Pool,
                false,
                "setUserUseReserveAsCollateral(address,bool)",
                new address[](1),
                "Toggle USDC as collateral in Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(USDC);
            leafs[0] = ManageLeaf(
                v3Pool,
                false,
                "setUserUseReserveAsCollateral(address,bool)",
                new address[](1),
                "Toggle USDT as collateral in Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(USDT);
            leafs[0] = ManageLeaf(
                v3Pool,
                false,
                "setUserUseReserveAsCollateral(address,bool)",
                new address[](1),
                "Toggle DAI as collateral in Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(DAI);
            leafs[0] = ManageLeaf(
                v3Pool,
                false,
                "setUserUseReserveAsCollateral(address,bool)",
                new address[](1),
                "Toggle sDAI as collateral in Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(sDAI);
            leafs[0] = ManageLeaf(
                v3Pool,
                false,
                "setUserEMode(uint8)",
                new address[](0),
                "Set user e-mode in Aave V3",
                rawDataDecoderAndSanitizer
            );
        }

        // ========================== SparkLend ==========================
        /**
         * lend USDC, USDT, DAI, sDAI
         * borrow wETH, wstETH
         */
        {
            // Approvals
            leafs[0] = ManageLeaf(
                address(USDC),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve SparkLend Pool to spend USDC",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = sparkLendPool;
            leafs[0] = ManageLeaf(
                address(USDT),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve SparkLend Pool to spend USDT",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = sparkLendPool;
            leafs[0] = ManageLeaf(
                address(DAI),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve SparkLend Pool to spend DAI",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = sparkLendPool;
            leafs[0] = ManageLeaf(
                address(sDAI),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve SparkLend Pool to spend sDAI",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = sparkLendPool;
            leafs[0] = ManageLeaf(
                address(WETH),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve SparkLend Pool to spend wETH",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = sparkLendPool;
            leafs[0] = ManageLeaf(
                address(WSTETH),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve SparkLend Pool to spend wstETH",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = sparkLendPool;
            // Lending
            leafs[0] = ManageLeaf(
                sparkLendPool,
                false,
                "supply(address,uint256,address,uint16)",
                new address[](2),
                "Supply USDC to SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(USDC);
            leafs[0].argumentAddresses[1] = boringVault;
            leafs[0] = ManageLeaf(
                sparkLendPool,
                false,
                "supply(address,uint256,address,uint16)",
                new address[](2),
                "Supply USDT to SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(USDT);
            leafs[0].argumentAddresses[1] = boringVault;
            leafs[0] = ManageLeaf(
                sparkLendPool,
                false,
                "supply(address,uint256,address,uint16)",
                new address[](2),
                "Supply DAI to SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(DAI);
            leafs[0].argumentAddresses[1] = boringVault;
            leafs[0] = ManageLeaf(
                sparkLendPool,
                false,
                "supply(address,uint256,address,uint16)",
                new address[](2),
                "Supply sDAI to SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(sDAI);
            leafs[0].argumentAddresses[1] = boringVault;
            // Withdrawing
            leafs[0] = ManageLeaf(
                sparkLendPool,
                false,
                "withdraw(address,uint256,address)",
                new address[](2),
                "Withdraw USDC from SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(USDC);
            leafs[0].argumentAddresses[1] = boringVault;
            leafs[0] = ManageLeaf(
                sparkLendPool,
                false,
                "withdraw(address,uint256,address)",
                new address[](2),
                "Withdraw USDT from SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(USDT);
            leafs[0].argumentAddresses[1] = boringVault;
            leafs[0] = ManageLeaf(
                sparkLendPool,
                false,
                "withdraw(address,uint256,address)",
                new address[](2),
                "Withdraw DAI from SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(DAI);
            leafs[0].argumentAddresses[1] = boringVault;
            leafs[0] = ManageLeaf(
                sparkLendPool,
                false,
                "withdraw(address,uint256,address)",
                new address[](2),
                "Withdraw sDAI from SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(sDAI);
            leafs[0].argumentAddresses[1] = boringVault;
            // Borrowing
            leafs[0] = ManageLeaf(
                sparkLendPool,
                false,
                "borrow(address,uint256,uint256,uint16,address)",
                new address[](2),
                "Borrow wETH from SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(WETH);
            leafs[0].argumentAddresses[1] = boringVault;
            leafs[0] = ManageLeaf(
                sparkLendPool,
                false,
                "borrow(address,uint256,uint256,uint16,address)",
                new address[](2),
                "Borrow wstETH from SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(WSTETH);
            leafs[0].argumentAddresses[1] = boringVault;
            // Repaying
            leafs[0] = ManageLeaf(
                sparkLendPool,
                false,
                "repay(address,uint256,uint256,address)",
                new address[](2),
                "Repay wETH to SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(WETH);
            leafs[0].argumentAddresses[1] = boringVault;
            leafs[0] = ManageLeaf(
                sparkLendPool,
                false,
                "repay(address,uint256,uint256,address)",
                new address[](2),
                "Repay wstETH to SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(WSTETH);
            leafs[0].argumentAddresses[1] = boringVault;
            // Misc
            leafs[0] = ManageLeaf(
                sparkLendPool,
                false,
                "setUserUseReserveAsCollateral(address,bool)",
                new address[](1),
                "Toggle USDC as collateral in SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(USDC);
            leafs[0] = ManageLeaf(
                sparkLendPool,
                false,
                "setUserUseReserveAsCollateral(address,bool)",
                new address[](1),
                "Toggle USDT as collateral in SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(USDT);
            leafs[0] = ManageLeaf(
                sparkLendPool,
                false,
                "setUserUseReserveAsCollateral(address,bool)",
                new address[](1),
                "Toggle DAI as collateral in SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(DAI);
            leafs[0] = ManageLeaf(
                sparkLendPool,
                false,
                "setUserUseReserveAsCollateral(address,bool)",
                new address[](1),
                "Toggle sDAI as collateral in SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(sDAI);
            leafs[0] = ManageLeaf(
                sparkLendPool,
                false,
                "setUserEMode(uint8)",
                new address[](0),
                "Set user e-mode in SparkLend",
                rawDataDecoderAndSanitizer
            );
        }

        // ========================== Lido ==========================
        /**
         * stake, unstake, wrap, unwrap
         */
        {
            // Approvals
            leafs[0] = ManageLeaf(
                address(STETH),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve WSTETH to spend stETH",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(WSTETH);
            leafs[0] = ManageLeaf(
                address(STETH),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve unstETH to spend stETH",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = unstETH;
            // Staking
            leafs[0] = ManageLeaf(
                address(STETH),
                true,
                "submit(address)",
                new address[](1),
                "Stake ETH for stETH",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(0);
            // Unstaking
            leafs[0] = ManageLeaf(
                unstETH,
                false,
                "requestWithdrawals(uint256[],address)",
                new address[](1),
                "Request withdrawals from stETH",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = boringVault;
            leafs[0] = ManageLeaf(
                unstETH,
                false,
                "claimWithdrawal(uint256)",
                new address[](0),
                "Claim stETH withdrawal",
                rawDataDecoderAndSanitizer
            );
            leafs[0] = ManageLeaf(
                unstETH,
                false,
                "claimWithdrawals(uint256[],uint256[])",
                new address[](0),
                "Claim stETH withdrawals",
                rawDataDecoderAndSanitizer
            );
            // Wrapping
            leafs[0] = ManageLeaf(
                address(WSTETH), false, "wrap(uint256)", new address[](0), "Wrap stETH", rawDataDecoderAndSanitizer
            );
            leafs[0] = ManageLeaf(
                address(WSTETH), false, "unwrap(uint256)", new address[](0), "Unwrap wstETH", rawDataDecoderAndSanitizer
            );
        }

        // ========================== EtherFi ==========================
        /**
         * stake, unstake, wrap, unwrap
         */
        {
            // Approvals
            leafs[0] = ManageLeaf(
                address(EETH),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve WEETH to spend eETH",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(WEETH);
            leafs[0] = ManageLeaf(
                address(EETH),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve EtherFi Liquidity Pool to spend eETH",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = EETH_LIQUIDITY_POOL;
            // Staking
            leafs[0] = ManageLeaf(
                EETH_LIQUIDITY_POOL,
                true,
                "deposit()",
                new address[](0),
                "Stake ETH for eETH",
                rawDataDecoderAndSanitizer
            );
            // Unstaking
            leafs[0] = ManageLeaf(
                EETH_LIQUIDITY_POOL,
                false,
                "requestWithdraw(address,uint256)",
                new address[](1),
                "Request withdrawal from eETH",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = boringVault;
            leafs[0] = ManageLeaf(
                withdrawalRequestNft,
                false,
                "claimWithdraw(uint256)",
                new address[](0),
                "Claim eETH withdrawal",
                rawDataDecoderAndSanitizer
            );
            // Wrapping
            leafs[0] = ManageLeaf(
                address(WEETH), false, "wrap(uint256)", new address[](0), "Wrap eETH", rawDataDecoderAndSanitizer
            );
            leafs[0] = ManageLeaf(
                address(WEETH), false, "unwrap(uint256)", new address[](0), "Unwrap weETH", rawDataDecoderAndSanitizer
            );
        }

        // ========================== Native ==========================
        /**
         * wrap, unwrap
         */
        {
            // Wrapping
            leafs[0] = ManageLeaf(
                address(WETH), true, "deposit()", new address[](0), "Wrap ETH for wETH", rawDataDecoderAndSanitizer
            );
            leafs[0] = ManageLeaf(
                address(WETH),
                false,
                "withdraw(uint256)",
                new address[](0),
                "Unwrap wETH for ETH",
                rawDataDecoderAndSanitizer
            );
        }

        // ========================== MakerDAO ==========================
        /**
         * deposit, withdraw
         */
        {
            // Approvals
            leafs[0] = ManageLeaf(
                address(DAI),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve sDAI to spend DAI",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = address(sDAI);
            // Depositing
            leafs[0] = ManageLeaf(
                address(sDAI),
                false,
                "deposit(uint256,address)",
                new address[](1),
                "Deposit DAI for sDAI",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = boringVault;
            // Withdrawing
            leafs[0] = ManageLeaf(
                address(sDAI),
                false,
                "withdraw(uint256,address,address)",
                new address[](2),
                "Withdraw DAI from sDAI",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = boringVault;
            leafs[0].argumentAddresses[1] = boringVault;
        }

        // ========================== Gearbox ==========================
        /**
         * USDC, DAI, USDT deposit, withdraw,  dUSDCV3, dDAIV3 dUSDTV3 deposit, withdraw, claim
         */
        {
            // Approvals
            leafs[0] = ManageLeaf(
                address(USDC),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve dUSDCV3 to spend USDC",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = dUSDCV3;
            leafs[0] = ManageLeaf(
                address(DAI),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve dDAIV3 to spend DAI",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = dDAIV3;
            leafs[0] = ManageLeaf(
                address(USDT),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve dUSDTV3 to spend USDT",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = dUSDTV3;
            leafs[0] = ManageLeaf(
                dUSDCV3,
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve sdUSDCV3 to spend dUSDCV3",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = sdUSDCV3;
            leafs[0] = ManageLeaf(
                dDAIV3,
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve sdDAIV3 to spend dDAIV3",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = sdDAIV3;
            leafs[0] = ManageLeaf(
                dUSDTV3,
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve sdUSDTV3 to spend dUSDTV3",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = sdUSDTV3;
            // Depositing
            leafs[0] = ManageLeaf(
                dUSDCV3,
                false,
                "deposit(uint256,address)",
                new address[](1),
                "Deposit USDC for dUSDCV3",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = boringVault;
            leafs[0] = ManageLeaf(
                dDAIV3,
                false,
                "deposit(uint256,address)",
                new address[](1),
                "Deposit DAI for dDAIV3",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = boringVault;
            leafs[0] = ManageLeaf(
                dUSDTV3,
                false,
                "deposit(uint256,address)",
                new address[](1),
                "Deposit USDT for dUSDTV3",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = boringVault;
            leafs[0] = ManageLeaf(
                sdUSDCV3,
                false,
                "deposit(uint256)",
                new address[](0),
                "Deposit dUSDCV3 for sdUSDCV3",
                rawDataDecoderAndSanitizer
            );
            leafs[0] = ManageLeaf(
                sdDAIV3,
                false,
                "deposit(uint256)",
                new address[](0),
                "Deposit dDAIV3 for sdDAIV3",
                rawDataDecoderAndSanitizer
            );
            leafs[0] = ManageLeaf(
                sdUSDTV3,
                false,
                "deposit(uint256)",
                new address[](0),
                "Deposit dUSDTV3 for sdUSDTV3",
                rawDataDecoderAndSanitizer
            );
            // Withdrawing
            leafs[0] = ManageLeaf(
                address(sDAI),
                false,
                "withdraw(uint256,address,address)",
                new address[](2),
                "Withdraw DAI from sDAI",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = boringVault;
            leafs[0].argumentAddresses[1] = boringVault;
            leafs[0] = ManageLeaf(
                dUSDCV3,
                false,
                "withdraw(uint256,address,address)",
                new address[](2),
                "Withdraw USDC from dUSDCV3",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = boringVault;
            leafs[0].argumentAddresses[1] = boringVault;
            leafs[0] = ManageLeaf(
                dDAIV3,
                false,
                "withdraw(uint256,address,address)",
                new address[](2),
                "Withdraw DAI from dDAIV3",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = boringVault;
            leafs[0].argumentAddresses[1] = boringVault;
            leafs[0] = ManageLeaf(
                dUSDTV3,
                false,
                "withdraw(uint256,address,address)",
                new address[](2),
                "Withdraw USDT from dUSDTV3",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = boringVault;
            leafs[0].argumentAddresses[1] = boringVault;
            leafs[0] = ManageLeaf(
                sdUSDCV3,
                false,
                "withdraw(uint256)",
                new address[](0),
                "Withdraw dUSDCV3 from sdUSDCV3",
                rawDataDecoderAndSanitizer
            );
            leafs[0] = ManageLeaf(
                sdDAIV3,
                false,
                "withdraw(uint256)",
                new address[](0),
                "Withdraw dDAIV3 from sdDAIV3",
                rawDataDecoderAndSanitizer
            );
            leafs[0] = ManageLeaf(
                sdUSDTV3,
                false,
                "withdraw(uint256)",
                new address[](0),
                "Withdraw dUSDTV3 from sdUSDTV3",
                rawDataDecoderAndSanitizer
            );
            // Claiming
            leafs[0] = ManageLeaf(
                sdUSDCV3, false, "claim()", new address[](0), "Claim rewards from sdUSDCV3", rawDataDecoderAndSanitizer
            );
            leafs[0] = ManageLeaf(
                sdDAIV3, false, "claim()", new address[](0), "Claim rewards from sdDAIV3", rawDataDecoderAndSanitizer
            );
            leafs[0] = ManageLeaf(
                sdUSDTV3, false, "claim()", new address[](0), "Claim rewards from sdUSDTV3", rawDataDecoderAndSanitizer
            );
        }

        // ========================== MorphoBlue ==========================
        /**
         * Supply, Withdraw DAI, USDT, USDC to/from
         * sUSDe/USDT  91.50 LLTV market 0xdc5333039bcf15f1237133f74d5806675d83d9cf19cfd4cfdd9be674842651bf
         * USDe/USDT   91.50 LLTV market 0xcec858380cba2d9ca710fce3ce864d74c3f620d53826f69d08508902e09be86f
         * USDe/DAI    91.50 LLTV market 0x8e6aeb10c401de3279ac79b4b2ea15fc94b7d9cfc098d6c2a1ff7b2b26d9d02c
         * sUSDe/DAI   91.50 LLTV market 0x1247f1c237eceae0602eab1470a5061a6dd8f734ba88c7cdc5d6109fb0026b28
         * USDe/DAI    94.50 LLTV market 0xdb760246f6859780f6c1b272d47a8f64710777121118e56e0cdb4b8b744a3094
         * USDe/DAI    86.00 LLTV market 0xc581c5f70bd1afa283eed57d1418c6432cbff1d862f94eaf58fdd4e46afbb67f
         * USDe/DAI    77.00 LLTV market 0xfd8493f09eb6203615221378d89f53fcd92ff4f7d62cca87eece9a2fff59e86f
         * wETH/USDC   86.00 LLTV market 0x7dde86a1e94561d9690ec678db673c1a6396365f7d1d65e129c5fff0990ff758
         * wETH/USDC   91.50 LLTV market 0xf9acc677910cc17f650416a22e2a14d5da7ccb9626db18f1bf94efe64f92b372
         * sUSDe/DAI   77.00 LLTV market 0x42dcfb38bb98767afb6e38ccf90d59d0d3f0aa216beb3a234f12850323d17536
         * sUSDe/DAI   86.00 LLTV market 0x39d11026eae1c6ec02aa4c0910778664089cdd97c3fd23f68f7cd05e2e95af48
         * wstETH/USDT 86.00 LLTV market 0xe7e9694b754c4d4f7e21faf7223f6fa71abaeb10296a4c43a54a7977149687d2
         * wstETH/USDC 86.00 LLTV market 0xb323495f7e4148be5643a4ea4a8221eef163e4bccfdedc2a6f4696baacbc86cc
         */
        {
            // Approvals
            leafs[0] = ManageLeaf(
                address(USDC),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve MorhoBlue to spend USDC",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = morphoBlue;
            leafs[0] = ManageLeaf(
                address(DAI),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve MorhoBlue to spend DAI",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = morphoBlue;
            leafs[0] = ManageLeaf(
                address(USDT),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve MorhoBlue to spend USDT",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = morphoBlue;
            // Supplying
            IMB.MarketParams memory marketParams;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xdc5333039bcf15f1237133f74d5806675d83d9cf19cfd4cfdd9be674842651bf);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply USDT to MorphoBlue sUSDe/USDT 91.50 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xcec858380cba2d9ca710fce3ce864d74c3f620d53826f69d08508902e09be86f);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply USDT to MorphoBlue USDe/USDT 91.50 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0x8e6aeb10c401de3279ac79b4b2ea15fc94b7d9cfc098d6c2a1ff7b2b26d9d02c);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply DAI to MorphoBlue USDe/DAI 91.50 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0x1247f1c237eceae0602eab1470a5061a6dd8f734ba88c7cdc5d6109fb0026b28);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply DAI to MorphoBlue sUSDe/DAI 91.50 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xdb760246f6859780f6c1b272d47a8f64710777121118e56e0cdb4b8b744a3094);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply DAI to MorphoBlue USDe/DAI 94.50 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xc581c5f70bd1afa283eed57d1418c6432cbff1d862f94eaf58fdd4e46afbb67f);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply DAI to MorphoBlue USDe/DAI 86.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xfd8493f09eb6203615221378d89f53fcd92ff4f7d62cca87eece9a2fff59e86f);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply DAI to MorphoBlue USDe/DAI 77.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0x7dde86a1e94561d9690ec678db673c1a6396365f7d1d65e129c5fff0990ff758);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply USDC to MorphoBlue wETH/USDC 86.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xf9acc677910cc17f650416a22e2a14d5da7ccb9626db18f1bf94efe64f92b372);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply USDC to MorphoBlue wETH/USDC 91.50 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0x42dcfb38bb98767afb6e38ccf90d59d0d3f0aa216beb3a234f12850323d17536);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply DAI to MorphoBlue sUSDe/DAI 77.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0x39d11026eae1c6ec02aa4c0910778664089cdd97c3fd23f68f7cd05e2e95af48);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply DAI to MorphoBlue sUSDe/DAI 86.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xe7e9694b754c4d4f7e21faf7223f6fa71abaeb10296a4c43a54a7977149687d2);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply USDT to MorphoBlue wstETH/USDT 86.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xb323495f7e4148be5643a4ea4a8221eef163e4bccfdedc2a6f4696baacbc86cc);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply USDC to MorphoBlue wstETH/USDC 86.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            // Withdrawing
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xdc5333039bcf15f1237133f74d5806675d83d9cf19cfd4cfdd9be674842651bf);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw USDT from MorphoBlue sUSDe/USDT 91.50 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            leafs[0].argumentAddresses[5] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xcec858380cba2d9ca710fce3ce864d74c3f620d53826f69d08508902e09be86f);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw USDT from MorphoBlue USDe/USDT 91.50 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            leafs[0].argumentAddresses[5] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0x8e6aeb10c401de3279ac79b4b2ea15fc94b7d9cfc098d6c2a1ff7b2b26d9d02c);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw DAI from MorphoBlue USDe/DAI 91.50 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            leafs[0].argumentAddresses[5] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0x1247f1c237eceae0602eab1470a5061a6dd8f734ba88c7cdc5d6109fb0026b28);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw DAI from MorphoBlue sUSDe/DAI 91.50 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            leafs[0].argumentAddresses[5] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xdb760246f6859780f6c1b272d47a8f64710777121118e56e0cdb4b8b744a3094);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw DAI from MorphoBlue USDe/DAI 94.50 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            leafs[0].argumentAddresses[5] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xc581c5f70bd1afa283eed57d1418c6432cbff1d862f94eaf58fdd4e46afbb67f);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw DAI from MorphoBlue USDe/DAI 86.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            leafs[0].argumentAddresses[5] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xfd8493f09eb6203615221378d89f53fcd92ff4f7d62cca87eece9a2fff59e86f);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw DAI from MorphoBlue USDe/DAI 77.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            leafs[0].argumentAddresses[5] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0x7dde86a1e94561d9690ec678db673c1a6396365f7d1d65e129c5fff0990ff758);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw USDC from MorphoBlue wETH/USDC 86.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            leafs[0].argumentAddresses[5] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xf9acc677910cc17f650416a22e2a14d5da7ccb9626db18f1bf94efe64f92b372);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw USDC from MorphoBlue wETH/USDC 91.50 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            leafs[0].argumentAddresses[5] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0x42dcfb38bb98767afb6e38ccf90d59d0d3f0aa216beb3a234f12850323d17536);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw DAI from MorphoBlue sUSDe/DAI 77.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            leafs[0].argumentAddresses[5] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0x39d11026eae1c6ec02aa4c0910778664089cdd97c3fd23f68f7cd05e2e95af48);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw DAI from MorphoBlue sUSDe/DAI 86.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            leafs[0].argumentAddresses[5] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xe7e9694b754c4d4f7e21faf7223f6fa71abaeb10296a4c43a54a7977149687d2);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw USDT from MorphoBlue wstETH/USDT 86.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            leafs[0].argumentAddresses[5] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xb323495f7e4148be5643a4ea4a8221eef163e4bccfdedc2a6f4696baacbc86cc);
            leafs[0] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw USDC from MorphoBlue wstETH/USDC 86.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[0].argumentAddresses[0] = marketParams.loanToken;
            leafs[0].argumentAddresses[1] = marketParams.collateralToken;
            leafs[0].argumentAddresses[2] = marketParams.oracle;
            leafs[0].argumentAddresses[3] = marketParams.irm;
            leafs[0].argumentAddresses[4] = boringVault;
            leafs[0].argumentAddresses[5] = boringVault;
        }

        // Pendle
        // USDe, sUSDe LP, SY, PT, YT
        // eETH LP, SY, PT, YT

        // Swapping
        // 1inch swap
        // USDC <-> USDT,
        // USDC <-> DAI,
        // USDT <-> DAI,
        // GHO <-> USDC,
        // GHO <-> USDT,
        // GHO <-> DAI,
        // wETH -> USDC,
        // weETH -> USDC,
        // wstETH -> USDC,
        // wETH -> USDT,
        // weETH -> USDT,
        // wstETH -> USDT,
        // wETH -> DAI,
        // weETH -> DAI,
        // wstETH -> DAI,
        // wETH <-> wstETH,
        // weETH <-> wstETH,
        // weETH <-> wETH
        // Swap GEAR -> USDC?

        // uniswap v3
        leafs[0] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 NonFungible Position Manager to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[0].argumentAddresses[0] = uniswapV3NonFungiblePositionManager;
        leafs[1] = ManageLeaf(
            address(EZETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 NonFungible Position Manager to spend ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[1].argumentAddresses[0] = uniswapV3NonFungiblePositionManager;
        leafs[2] = ManageLeaf(
            address(WSTETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 NonFungible Position Manager to spend wstETH",
            rawDataDecoderAndSanitizer
        );
        leafs[2].argumentAddresses[0] = uniswapV3NonFungiblePositionManager;
        leafs[3] = ManageLeaf(
            address(RETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 NonFungible Position Manager to spend rETH",
            rawDataDecoderAndSanitizer
        );
        leafs[3].argumentAddresses[0] = uniswapV3NonFungiblePositionManager;
        leafs[4] = ManageLeaf(
            address(WEETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 NonFungible Position Manager to spend weETH",
            rawDataDecoderAndSanitizer
        );
        leafs[4].argumentAddresses[0] = uniswapV3NonFungiblePositionManager;
        leafs[5] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
            new address[](3),
            "Mint UniswapV3 ezETH wETH position",
            rawDataDecoderAndSanitizer
        );
        leafs[5].argumentAddresses[0] = address(EZETH);
        leafs[5].argumentAddresses[1] = address(WETH);
        leafs[5].argumentAddresses[2] = boringVault;
        leafs[6] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
            new address[](3),
            "Mint UniswapV3 wstETH ezETH position",
            rawDataDecoderAndSanitizer
        );
        leafs[6].argumentAddresses[0] = address(WSTETH);
        leafs[6].argumentAddresses[1] = address(EZETH);
        leafs[6].argumentAddresses[2] = boringVault;
        leafs[7] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
            new address[](3),
            "Mint UniswapV3 rETH ezETH position",
            rawDataDecoderAndSanitizer
        );
        leafs[7].argumentAddresses[0] = address(RETH);
        leafs[7].argumentAddresses[1] = address(EZETH);
        leafs[7].argumentAddresses[2] = boringVault;
        leafs[8] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
            new address[](3),
            "Mint UniswapV3 ezETH weETH position",
            rawDataDecoderAndSanitizer
        );
        leafs[8].argumentAddresses[0] = address(EZETH);
        leafs[8].argumentAddresses[1] = address(WEETH);
        leafs[8].argumentAddresses[2] = boringVault;
        leafs[9] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
            new address[](3),
            "Add liquidity to UniswapV3 ezETH wETH position",
            rawDataDecoderAndSanitizer
        );
        leafs[9].argumentAddresses[0] = address(0);
        leafs[9].argumentAddresses[1] = address(EZETH);
        leafs[9].argumentAddresses[2] = address(WETH);
        leafs[10] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            new address[](0),
            "Remove liquidity from UniswapV3 position",
            rawDataDecoderAndSanitizer
        );
        leafs[11] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "collect((uint256,address,uint128,uint128))",
            new address[](1),
            "Collect from UniswapV3 position",
            rawDataDecoderAndSanitizer
        );
        leafs[11].argumentAddresses[0] = boringVault;

        // morphoblue
        leafs[12] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve MorphoBlue to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[12].argumentAddresses[0] = morphoBlue;
        leafs[13] = ManageLeaf(
            morphoBlue,
            false,
            "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            new address[](5),
            "Supply wETH to ezETH MorphoBlue market",
            rawDataDecoderAndSanitizer
        );
        leafs[13].argumentAddresses[0] = address(WETH);
        leafs[13].argumentAddresses[1] = address(EZETH);
        leafs[13].argumentAddresses[2] = ezEthOracle;
        leafs[13].argumentAddresses[3] = ezEthIrm;
        leafs[13].argumentAddresses[4] = boringVault;
        leafs[14] = ManageLeaf(
            morphoBlue,
            false,
            "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
            new address[](6),
            "Withdraw wETH from ezETH MorphoBlue market",
            rawDataDecoderAndSanitizer
        );
        leafs[14].argumentAddresses[0] = address(WETH);
        leafs[14].argumentAddresses[1] = address(EZETH);
        leafs[14].argumentAddresses[2] = ezEthOracle;
        leafs[14].argumentAddresses[3] = ezEthIrm;
        leafs[14].argumentAddresses[4] = boringVault;
        leafs[14].argumentAddresses[5] = boringVault;

        // renzo staking
        leafs[15] =
            ManageLeaf(restakeManager, true, "depositETH()", new address[](0), "Mint ezETH", rawDataDecoderAndSanitizer);

        // lido support
        leafs[15] = ManageLeaf(
            address(STETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve wstETH to spend stETH",
            rawDataDecoderAndSanitizer
        );
        leafs[15].argumentAddresses[0] = address(WSTETH);
        leafs[16] = ManageLeaf(
            address(STETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve unstETH to spend stETH",
            rawDataDecoderAndSanitizer
        );
        leafs[16].argumentAddresses[0] = address(unstETH);
        leafs[17] = ManageLeaf(
            address(STETH), true, "submit(address)", new address[](1), "Mint stETH", rawDataDecoderAndSanitizer
        );
        leafs[17].argumentAddresses[0] = address(0);
        leafs[18] = ManageLeaf(
            address(WSTETH), false, "wrap(uint256)", new address[](0), "Wrap stETH", rawDataDecoderAndSanitizer
        );
        leafs[19] = ManageLeaf(
            address(WSTETH), false, "unwrap(uint256)", new address[](0), "Unwrap wstETH", rawDataDecoderAndSanitizer
        );
        leafs[20] = ManageLeaf(
            unstETH,
            false,
            "requestWithdrawals(uint256[],address)",
            new address[](1),
            "Request withdrawals from stETH",
            rawDataDecoderAndSanitizer
        );
        leafs[20].argumentAddresses[0] = boringVault;
        leafs[21] = ManageLeaf(
            unstETH,
            false,
            "claimWithdrawal(uint256)",
            new address[](0),
            "Claim stETH withdrawal",
            rawDataDecoderAndSanitizer
        );
        leafs[22] = ManageLeaf(
            unstETH,
            false,
            "claimWithdrawals(uint256[],uint256[])",
            new address[](0),
            "Claim stETH withdrawals",
            rawDataDecoderAndSanitizer
        );

        // balancer V2 and aura
        leafs[23] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer Vault to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[23].argumentAddresses[0] = vault;
        leafs[24] = ManageLeaf(
            address(EZETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer Vault to spend ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[24].argumentAddresses[0] = vault;
        leafs[25] = ManageLeaf(
            address(WSTETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer Vault to spend wstETH",
            rawDataDecoderAndSanitizer
        );
        leafs[25].argumentAddresses[0] = vault;
        leafs[25] = ManageLeaf(
            address(RETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer Vault to spend rETH",
            rawDataDecoderAndSanitizer
        );
        leafs[25].argumentAddresses[0] = vault;
        leafs[25] = ManageLeaf(
            address(WEETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer Vault to spend weETH",
            rawDataDecoderAndSanitizer
        );
        leafs[25].argumentAddresses[0] = vault;
        leafs[26] = ManageLeaf(
            address(RSWETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer Vault to spend rswETH",
            rawDataDecoderAndSanitizer
        );
        leafs[26].argumentAddresses[0] = vault;
        leafs[27] = ManageLeaf(
            address(ezETH_weETH_rswETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer ezETH-weETH-rswETH gauge to spend ezETH-weETH-rswETH bpts",
            rawDataDecoderAndSanitizer
        );
        leafs[27].argumentAddresses[0] = ezETH_weETH_rswETH_gauge;
        leafs[28] = ManageLeaf(
            address(ezETH_weETH_rswETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Aura ezETH-weETH-rswETH gauge to spend ezETH-weETH-rswETH bpts",
            rawDataDecoderAndSanitizer
        );
        leafs[28].argumentAddresses[0] = aura_ezETH_weETH_rswETH;
        leafs[29] = ManageLeaf(
            address(ezETH_wETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer ezETH-wETH gauge to spend ezETH-wETH bpts",
            rawDataDecoderAndSanitizer
        );
        leafs[29].argumentAddresses[0] = ezETH_wETH_gauge;
        leafs[30] = ManageLeaf(
            address(ezETH_wETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Aura ezETH-wETH gauge to spend ezETH-wETH bpts",
            rawDataDecoderAndSanitizer
        );
        leafs[30].argumentAddresses[0] = aura_ezETH_wETH;
        leafs[31] = ManageLeaf(
            vault,
            false,
            "joinPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
            new address[](6),
            "Join ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[31].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[31].argumentAddresses[1] = boringVault;
        leafs[31].argumentAddresses[2] = boringVault;
        leafs[31].argumentAddresses[3] = address(EZETH);
        leafs[31].argumentAddresses[4] = address(WEETH);
        leafs[31].argumentAddresses[5] = address(RSWETH);
        leafs[32] = ManageLeaf(
            ezETH_weETH_rswETH_gauge,
            false,
            "deposit(uint256,address)",
            new address[](1),
            "Deposit ezETH-weETH-rswETH bpts into Balancer gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[32].argumentAddresses[0] = boringVault;
        leafs[33] = ManageLeaf(
            ezETH_weETH_rswETH_gauge,
            false,
            "withdraw(uint256)",
            new address[](0),
            "Withdraw ezETH-weETH-rswETH bpts from Balancer gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[34] = ManageLeaf(
            aura_ezETH_wETH,
            false,
            "deposit(uint256,address)",
            new address[](1),
            "Deposit ezETH-weETH-rswETH bpts into Aura gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[34].argumentAddresses[0] = boringVault;
        leafs[35] = ManageLeaf(
            aura_ezETH_wETH,
            false,
            "withdraw(uint256,address,address)",
            new address[](2),
            "Withdraw ezETH-weETH-rswETH bpts from Aura gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[35].argumentAddresses[0] = boringVault;
        leafs[35].argumentAddresses[1] = boringVault;
        leafs[36] = ManageLeaf(
            vault,
            false,
            "exitPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
            new address[](6),
            "Exit ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[36].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[36].argumentAddresses[1] = boringVault;
        leafs[36].argumentAddresses[2] = boringVault;
        leafs[36].argumentAddresses[3] = address(EZETH);
        leafs[36].argumentAddresses[4] = address(WEETH);
        leafs[36].argumentAddresses[5] = address(RSWETH);
        leafs[37] = ManageLeaf(
            vault,
            false,
            "joinPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
            new address[](5),
            "Join ezETH-wETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[37].argumentAddresses[0] = address(ezETH_wETH);
        leafs[37].argumentAddresses[1] = boringVault;
        leafs[37].argumentAddresses[2] = boringVault;
        leafs[37].argumentAddresses[3] = address(EZETH);
        leafs[37].argumentAddresses[4] = address(WETH);
        leafs[38] = ManageLeaf(
            ezETH_wETH_gauge,
            false,
            "deposit(uint256,address)",
            new address[](1),
            "Deposit ezETH-wETH bpts into Balancer gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[38].argumentAddresses[0] = boringVault;
        leafs[39] = ManageLeaf(
            ezETH_wETH_gauge,
            false,
            "withdraw(uint256)",
            new address[](0),
            "Withdraw ezETH-wETH bpts from Balancer gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[40] = ManageLeaf(
            aura_ezETH_wETH,
            false,
            "deposit(uint256,address)",
            new address[](1),
            "Deposit ezETH-wETH bpts into Aura gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[40].argumentAddresses[0] = boringVault;
        leafs[41] = ManageLeaf(
            aura_ezETH_wETH,
            false,
            "withdraw(uint256,address,address)",
            new address[](2),
            "Withdraw ezETH-wETH bpts from Aura gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[41].argumentAddresses[0] = boringVault;
        leafs[41].argumentAddresses[1] = boringVault;
        leafs[42] = ManageLeaf(
            vault,
            false,
            "exitPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
            new address[](5),
            "Exit ezETH-wETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[42].argumentAddresses[0] = address(ezETH_wETH);
        leafs[42].argumentAddresses[1] = boringVault;
        leafs[42].argumentAddresses[2] = boringVault;
        leafs[42].argumentAddresses[3] = address(EZETH);
        leafs[42].argumentAddresses[4] = address(WETH);
        leafs[43] = ManageLeaf(
            minter,
            false,
            "mint(address)",
            new address[](1),
            "Claim $BAL rewards for ezETH-weETH-rswETH Balancer gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[43].argumentAddresses[0] = address(ezETH_weETH_rswETH_gauge);
        leafs[44] = ManageLeaf(
            minter,
            false,
            "mint(address)",
            new address[](1),
            "Claim $BAL rewards for ezETH-wETH Balancer gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[44].argumentAddresses[0] = address(ezETH_wETH_gauge);
        leafs[45] = ManageLeaf(
            aura_ezETH_weETH_rswETH,
            false,
            "getReward(address,bool)",
            new address[](1),
            "Claim rewards for ezETH-weETH-rswETH Aura gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[45].argumentAddresses[0] = boringVault;
        leafs[46] = ManageLeaf(
            aura_ezETH_wETH,
            false,
            "getReward(address,bool)",
            new address[](1),
            "Claim rewards for ezETH-wETH Aura gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[46].argumentAddresses[0] = boringVault;

        // gearbox
        leafs[47] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Gearbox dWETHV3 to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[47].argumentAddresses[0] = dWETHV3;
        leafs[48] = ManageLeaf(
            dWETHV3,
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Gearbox sdWETHV3 to spend dWETHV3",
            rawDataDecoderAndSanitizer
        );
        leafs[48].argumentAddresses[0] = sdWETHV3;
        leafs[49] = ManageLeaf(
            dWETHV3,
            false,
            "deposit(uint256,address)",
            new address[](1),
            "Deposit into Gearbox dWETHV3",
            rawDataDecoderAndSanitizer
        );
        leafs[49].argumentAddresses[0] = boringVault;
        leafs[50] = ManageLeaf(
            dWETHV3,
            false,
            "withdraw(uint256,address,address)",
            new address[](2),
            "Withdraw from Gearbox dWETHV3",
            rawDataDecoderAndSanitizer
        );
        leafs[50].argumentAddresses[0] = boringVault;
        leafs[50].argumentAddresses[1] = boringVault;
        leafs[51] = ManageLeaf(
            sdWETHV3,
            false,
            "deposit(uint256)",
            new address[](0),
            "Deposit into Gearbox sdWETHV3",
            rawDataDecoderAndSanitizer
        );
        leafs[52] = ManageLeaf(
            sdWETHV3,
            false,
            "withdraw(uint256)",
            new address[](0),
            "Withdraw from Gearbox sdWETHV3",
            rawDataDecoderAndSanitizer
        );
        leafs[53] = ManageLeaf(
            sdWETHV3,
            false,
            "claim()",
            new address[](0),
            "Claim rewards from Gearbox sdWETHV3",
            rawDataDecoderAndSanitizer
        );

        // native wrapper
        leafs[54] = ManageLeaf(
            address(WETH), true, "deposit()", new address[](0), "Wrap ETH for wETH", rawDataDecoderAndSanitizer
        );
        leafs[55] = ManageLeaf(
            address(WETH),
            false,
            "withdraw(uint256)",
            new address[](0),
            "Unwrap wETH for ETH",
            rawDataDecoderAndSanitizer
        );

        // pendle
        leafs[56] = ManageLeaf(
            address(EZETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Pendle router to spend ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[56].argumentAddresses[0] = pendleRouter;
        leafs[57] = ManageLeaf(
            pendleEzEthSy,
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Pendle router to spend SY-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[57].argumentAddresses[0] = pendleRouter;
        leafs[58] = ManageLeaf(
            pendleEzEthPt,
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Pendle router to spend PT-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[58].argumentAddresses[0] = pendleRouter;
        leafs[59] = ManageLeaf(
            pendleEzEthYt,
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Pendle router to spend YT-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[59].argumentAddresses[0] = pendleRouter;
        leafs[60] = ManageLeaf(
            pendleEzEthMarket,
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Pendle router to spend LP-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[60].argumentAddresses[0] = pendleRouter;
        leafs[61] = ManageLeaf(
            pendleRouter,
            false,
            "mintSyFromToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            new address[](6),
            "Mint SY-ezETH using ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[61].argumentAddresses[0] = boringVault;
        leafs[61].argumentAddresses[1] = pendleEzEthSy;
        leafs[61].argumentAddresses[2] = address(EZETH);
        leafs[61].argumentAddresses[3] = address(EZETH);
        leafs[61].argumentAddresses[4] = address(0);
        leafs[61].argumentAddresses[5] = address(0);
        leafs[62] = ManageLeaf(
            pendleRouter,
            false,
            "mintPyFromSy(address,address,uint256,uint256)",
            new address[](2),
            "Mint PT-ezETH and YT-ezETH from SY-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[62].argumentAddresses[0] = boringVault;
        leafs[62].argumentAddresses[1] = pendleEzEthYt;
        leafs[63] = ManageLeaf(
            pendleRouter,
            false,
            "swapExactYtForPt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            new address[](2),
            "Swap YT-ezETH for PT-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[63].argumentAddresses[0] = boringVault;
        leafs[63].argumentAddresses[1] = pendleEzEthMarket;
        leafs[64] = ManageLeaf(
            pendleRouter,
            false,
            "swapExactPtForYt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            new address[](2),
            "Swap PT-ezETH for YT-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[64].argumentAddresses[0] = boringVault;
        leafs[64].argumentAddresses[1] = pendleEzEthMarket;
        leafs[65] = ManageLeaf(
            pendleRouter,
            false,
            "addLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
            new address[](2),
            "Mint LP-ezETH using SY-ezETH and PT-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[65].argumentAddresses[0] = boringVault;
        leafs[65].argumentAddresses[1] = pendleEzEthMarket;
        leafs[66] = ManageLeaf(
            pendleRouter,
            false,
            "removeLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
            new address[](2),
            "Burn LP-ezETH for SY-ezETH and PT-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[66].argumentAddresses[0] = boringVault;
        leafs[66].argumentAddresses[1] = pendleEzEthMarket;
        leafs[67] = ManageLeaf(
            pendleRouter,
            false,
            "redeemPyToSy(address,address,uint256,uint256)",
            new address[](2),
            "Burn PT-ezETH and YT-ezETH for SY-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[67].argumentAddresses[0] = boringVault;
        leafs[67].argumentAddresses[1] = pendleEzEthYt;
        leafs[68] = ManageLeaf(
            pendleRouter,
            false,
            "redeemSyToToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            new address[](6),
            "Burn SY-ezETH for ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[68].argumentAddresses[0] = address(boringVault);
        leafs[68].argumentAddresses[1] = pendleEzEthSy;
        leafs[68].argumentAddresses[2] = address(EZETH);
        leafs[68].argumentAddresses[3] = address(EZETH);
        leafs[68].argumentAddresses[4] = address(0);
        leafs[68].argumentAddresses[5] = address(0);

        // flashloans
        leafs[69] = ManageLeaf(
            managerAddress,
            false,
            "flashLoan(address,address[],uint256[],bytes)",
            new address[](2),
            "Flash loan wETH from Balancer",
            rawDataDecoderAndSanitizer
        );
        leafs[69].argumentAddresses[0] = managerAddress;
        leafs[69].argumentAddresses[1] = address(WETH);

        // swap with balancer
        leafs[70] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap ezETH for weETH using ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[70].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[70].argumentAddresses[1] = address(EZETH);
        leafs[70].argumentAddresses[2] = address(WEETH);
        leafs[70].argumentAddresses[3] = address(boringVault);
        leafs[70].argumentAddresses[4] = address(boringVault);
        leafs[71] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap ezETH for rswETH using ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[71].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[71].argumentAddresses[1] = address(EZETH);
        leafs[71].argumentAddresses[2] = address(RSWETH);
        leafs[71].argumentAddresses[3] = address(boringVault);
        leafs[71].argumentAddresses[4] = address(boringVault);
        leafs[72] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap weETH for ezETH using ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[72].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[72].argumentAddresses[1] = address(WEETH);
        leafs[72].argumentAddresses[2] = address(EZETH);
        leafs[72].argumentAddresses[3] = address(boringVault);
        leafs[72].argumentAddresses[4] = address(boringVault);
        leafs[73] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap rswETH for ezETH using ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[73].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[73].argumentAddresses[1] = address(RSWETH);
        leafs[73].argumentAddresses[2] = address(EZETH);
        leafs[73].argumentAddresses[3] = address(boringVault);
        leafs[73].argumentAddresses[4] = address(boringVault);
        leafs[74] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap weETH for rswETH using ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[74].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[74].argumentAddresses[1] = address(WEETH);
        leafs[74].argumentAddresses[2] = address(RSWETH);
        leafs[74].argumentAddresses[3] = address(boringVault);
        leafs[74].argumentAddresses[4] = address(boringVault);
        leafs[75] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap rswETH for weETH using ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[75].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[75].argumentAddresses[1] = address(RSWETH);
        leafs[75].argumentAddresses[2] = address(WEETH);
        leafs[75].argumentAddresses[3] = address(boringVault);
        leafs[75].argumentAddresses[4] = address(boringVault);
        leafs[76] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap ezETH for wETH using ezETH-wETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[76].argumentAddresses[0] = address(ezETH_wETH);
        leafs[76].argumentAddresses[1] = address(EZETH);
        leafs[76].argumentAddresses[2] = address(WETH);
        leafs[76].argumentAddresses[3] = address(boringVault);
        leafs[76].argumentAddresses[4] = address(boringVault);
        leafs[77] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap wETH for ezETH using ezETH-wETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[77].argumentAddresses[0] = address(ezETH_wETH);
        leafs[77].argumentAddresses[1] = address(WETH);
        leafs[77].argumentAddresses[2] = address(EZETH);
        leafs[77].argumentAddresses[3] = address(boringVault);
        leafs[77].argumentAddresses[4] = address(boringVault);

        // swap with curve
        leafs[78] = ManageLeaf(
            address(EZETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve ezETH/wETH pool to spend ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[78].argumentAddresses[0] = ezETH_wETH_Curve_Pool;
        leafs[79] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve ezETH/wETH pool to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[79].argumentAddresses[0] = ezETH_wETH_Curve_Pool;
        leafs[80] = ManageLeaf(
            ezETH_wETH_Curve_Pool,
            false,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            "Swap using Curve ezETH/wETH pool",
            rawDataDecoderAndSanitizer
        );
        leafs[81] = ManageLeaf(
            address(WEETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve weETH/rswETH pool to spend weETH",
            rawDataDecoderAndSanitizer
        );
        leafs[81].argumentAddresses[0] = weETH_rswETH_Curve_Pool;
        leafs[82] = ManageLeaf(
            address(RSWETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve weETH/rswETH pool to spend rswETH",
            rawDataDecoderAndSanitizer
        );
        leafs[82].argumentAddresses[0] = weETH_rswETH_Curve_Pool;
        leafs[83] = ManageLeaf(
            weETH_rswETH_Curve_Pool,
            false,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            "Swap using Curve weETH/rswETH pool",
            rawDataDecoderAndSanitizer
        );
        leafs[84] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve rswETH/wETH pool to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[84].argumentAddresses[0] = rswETH_wETH_Curve_Pool;
        leafs[85] = ManageLeaf(
            address(RSWETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve rswETH/wETH pool to spend rswETH",
            rawDataDecoderAndSanitizer
        );
        leafs[85].argumentAddresses[0] = rswETH_wETH_Curve_Pool;
        leafs[86] = ManageLeaf(
            rswETH_wETH_Curve_Pool,
            false,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            "Swap using Curve rswETH/wETH pool",
            rawDataDecoderAndSanitizer
        );
        leafs[87] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve weETH/wETH pool to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[87].argumentAddresses[0] = weETH_wETH_Curve_LP;
        leafs[88] = ManageLeaf(
            address(WEETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve weETH/wETH pool to spend weETH",
            rawDataDecoderAndSanitizer
        );
        leafs[88].argumentAddresses[0] = weETH_wETH_Curve_LP;
        leafs[89] = ManageLeaf(
            weETH_wETH_Curve_LP,
            false,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            "Swap using Curve weETH/wETH pool",
            rawDataDecoderAndSanitizer
        );
        leafs[90] = ManageLeaf(
            address(STETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve ETH/stETH pool to spend stETH",
            rawDataDecoderAndSanitizer
        );
        leafs[90].argumentAddresses[0] = EthStethPool;
        leafs[91] = ManageLeaf(
            EthStethPool,
            true,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            "Swap using Curve ETH/stETH pool",
            rawDataDecoderAndSanitizer
        );

        // swap with uniV3 -> move to other root
        leafs[92] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 router to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[92].argumentAddresses[0] = uniV3Router;
        leafs[93] = ManageLeaf(
            address(RETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 router to spend rETH",
            rawDataDecoderAndSanitizer
        );
        leafs[93].argumentAddresses[0] = uniV3Router;
        leafs[94] = ManageLeaf(
            address(WSTETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 router to spend wstETH",
            rawDataDecoderAndSanitizer
        );
        leafs[94].argumentAddresses[0] = uniV3Router;
        leafs[95] = ManageLeaf(
            address(WEETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 router to spend weETH",
            rawDataDecoderAndSanitizer
        );
        leafs[95].argumentAddresses[0] = uniV3Router;
        leafs[96] = ManageLeaf(
            address(RSWETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 router to spend rswETH",
            rawDataDecoderAndSanitizer
        );
        leafs[96].argumentAddresses[0] = uniV3Router;
        leafs[97] = ManageLeaf(
            address(EZETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 router to spend ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[97].argumentAddresses[0] = uniV3Router;
        leafs[98] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap wETH for wstETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[98].argumentAddresses[0] = address(WETH);
        leafs[98].argumentAddresses[1] = address(WSTETH);
        leafs[98].argumentAddresses[2] = address(boringVault);
        leafs[99] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap wETH for rETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[99].argumentAddresses[0] = address(WETH);
        leafs[99].argumentAddresses[1] = address(RETH);
        leafs[99].argumentAddresses[2] = address(boringVault);
        leafs[100] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap wETH for ezETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[100].argumentAddresses[0] = address(WETH);
        leafs[100].argumentAddresses[1] = address(EZETH);
        leafs[100].argumentAddresses[2] = address(boringVault);
        leafs[101] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap wETH for weETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[101].argumentAddresses[0] = address(WETH);
        leafs[101].argumentAddresses[1] = address(WEETH);
        leafs[101].argumentAddresses[2] = address(boringVault);
        leafs[102] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap wETH for rswETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[102].argumentAddresses[0] = address(WETH);
        leafs[102].argumentAddresses[1] = address(RSWETH);
        leafs[102].argumentAddresses[2] = address(boringVault);
        leafs[103] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap wstETH for wETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[103].argumentAddresses[0] = address(WSTETH);
        leafs[103].argumentAddresses[1] = address(WETH);
        leafs[103].argumentAddresses[2] = address(boringVault);
        leafs[104] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap rETH for wETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[104].argumentAddresses[0] = address(RETH);
        leafs[104].argumentAddresses[1] = address(WETH);
        leafs[104].argumentAddresses[2] = address(boringVault);
        leafs[105] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap ezETH for wETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[105].argumentAddresses[0] = address(EZETH);
        leafs[105].argumentAddresses[1] = address(WETH);
        leafs[105].argumentAddresses[2] = address(boringVault);
        leafs[106] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap weETH for wETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[106].argumentAddresses[0] = address(WEETH);
        leafs[106].argumentAddresses[1] = address(WETH);
        leafs[106].argumentAddresses[2] = address(boringVault);
        leafs[107] = ManageLeaf(
            uniV3Router,
            false,
            "exactInput((bytes,address,uint256,uint256,uint256))",
            new address[](3),
            "Swap rswETH for wETH using UniswapV3 router",
            rawDataDecoderAndSanitizer
        );
        leafs[107].argumentAddresses[0] = address(RSWETH);
        leafs[107].argumentAddresses[1] = address(WETH);
        leafs[107].argumentAddresses[2] = address(boringVault);

        // swap with 1inch -> move to other root
        leafs[108] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve 1inch router to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[108].argumentAddresses[0] = aggregationRouterV5;
        leafs[109] = ManageLeaf(
            address(RETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve 1inch router to spend rETH",
            rawDataDecoderAndSanitizer
        );
        leafs[109].argumentAddresses[0] = aggregationRouterV5;
        leafs[110] = ManageLeaf(
            address(WSTETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve 1inch router to spend wstETH",
            rawDataDecoderAndSanitizer
        );
        leafs[110].argumentAddresses[0] = aggregationRouterV5;
        leafs[111] = ManageLeaf(
            address(WEETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve 1inch router to spend weETH",
            rawDataDecoderAndSanitizer
        );
        leafs[111].argumentAddresses[0] = aggregationRouterV5;
        leafs[112] = ManageLeaf(
            address(RSWETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve 1inch router to spend rswETH",
            rawDataDecoderAndSanitizer
        );
        leafs[112].argumentAddresses[0] = aggregationRouterV5;
        leafs[113] = ManageLeaf(
            address(EZETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve 1inch router to spend ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[113].argumentAddresses[0] = aggregationRouterV5;
        leafs[114] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap wETH for ezETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[114].argumentAddresses[0] = oneInchExecutor;
        leafs[114].argumentAddresses[1] = address(WETH);
        leafs[114].argumentAddresses[2] = address(EZETH);
        leafs[114].argumentAddresses[3] = oneInchExecutor;
        leafs[114].argumentAddresses[4] = boringVault;
        leafs[115] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap wETH for weETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[115].argumentAddresses[0] = oneInchExecutor;
        leafs[115].argumentAddresses[1] = address(WETH);
        leafs[115].argumentAddresses[2] = address(WEETH);
        leafs[115].argumentAddresses[3] = oneInchExecutor;
        leafs[115].argumentAddresses[4] = boringVault;
        leafs[116] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap wETH for wstETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[116].argumentAddresses[0] = oneInchExecutor;
        leafs[116].argumentAddresses[1] = address(WETH);
        leafs[116].argumentAddresses[2] = address(WSTETH);
        leafs[116].argumentAddresses[3] = oneInchExecutor;
        leafs[116].argumentAddresses[4] = boringVault;
        leafs[117] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap wETH for rETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[117].argumentAddresses[0] = oneInchExecutor;
        leafs[117].argumentAddresses[1] = address(WETH);
        leafs[117].argumentAddresses[2] = address(RETH);
        leafs[117].argumentAddresses[3] = oneInchExecutor;
        leafs[117].argumentAddresses[4] = boringVault;
        leafs[118] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap wETH for rswETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[118].argumentAddresses[0] = oneInchExecutor;
        leafs[118].argumentAddresses[1] = address(WETH);
        leafs[118].argumentAddresses[2] = address(RSWETH);
        leafs[118].argumentAddresses[3] = oneInchExecutor;
        leafs[118].argumentAddresses[4] = boringVault;
        leafs[119] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap ezETH for wETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[119].argumentAddresses[0] = oneInchExecutor;
        leafs[119].argumentAddresses[1] = address(EZETH);
        leafs[119].argumentAddresses[2] = address(WETH);
        leafs[119].argumentAddresses[3] = oneInchExecutor;
        leafs[119].argumentAddresses[4] = boringVault;
        leafs[120] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap wstETH for wETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[120].argumentAddresses[0] = oneInchExecutor;
        leafs[120].argumentAddresses[1] = address(WSTETH);
        leafs[120].argumentAddresses[2] = address(WETH);
        leafs[120].argumentAddresses[3] = oneInchExecutor;
        leafs[120].argumentAddresses[4] = boringVault;
        leafs[121] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap rETH for wETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[121].argumentAddresses[0] = oneInchExecutor;
        leafs[121].argumentAddresses[1] = address(RETH);
        leafs[121].argumentAddresses[2] = address(WETH);
        leafs[121].argumentAddresses[3] = oneInchExecutor;
        leafs[121].argumentAddresses[4] = boringVault;
        leafs[122] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap weETH for wETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[122].argumentAddresses[0] = oneInchExecutor;
        leafs[122].argumentAddresses[1] = address(WEETH);
        leafs[122].argumentAddresses[2] = address(WETH);
        leafs[122].argumentAddresses[3] = oneInchExecutor;
        leafs[122].argumentAddresses[4] = boringVault;
        leafs[123] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap rswETH for wETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[123].argumentAddresses[0] = oneInchExecutor;
        leafs[123].argumentAddresses[1] = address(RSWETH);
        leafs[123].argumentAddresses[2] = address(WETH);
        leafs[123].argumentAddresses[3] = oneInchExecutor;
        leafs[123].argumentAddresses[4] = boringVault;
        leafs[124] = ManageLeaf(
            aggregationRouterV5,
            false,
            "uniswapV3Swap(uint256,uint256,uint256[])",
            new address[](1),
            "Swap between wETH and wstETH on UniswapV3 using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[124].argumentAddresses[0] = wETH_weETH_05;

        leafs[125] = ManageLeaf(
            aggregationRouterV5,
            false,
            "uniswapV3Swap(uint256,uint256,uint256[])",
            new address[](1),
            "Swap between wstETH and wETH on UniswapV3 using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[125].argumentAddresses[0] = wstETH_wETH_01;

        leafs[126] = ManageLeaf(
            aggregationRouterV5,
            false,
            "uniswapV3Swap(uint256,uint256,uint256[])",
            new address[](1),
            "Swap between rETH and wETH on UniswapV3 using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[126].argumentAddresses[0] = rETH_wETH_01;

        leafs[127] = ManageLeaf(
            aggregationRouterV5,
            false,
            "uniswapV3Swap(uint256,uint256,uint256[])",
            new address[](1),
            "Swap between rETH and wETH on UniswapV3 using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[127].argumentAddresses[0] = rETH_wETH_05;

        leafs[128] = ManageLeaf(
            aggregationRouterV5,
            false,
            "uniswapV3Swap(uint256,uint256,uint256[])",
            new address[](1),
            "Swap between wstETH and rETH on UniswapV3 using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[128].argumentAddresses[0] = wstETH_rETH_05;

        leafs[129] = ManageLeaf(
            aggregationRouterV5,
            false,
            "uniswapV3Swap(uint256,uint256,uint256[])",
            new address[](1),
            "Swap between wETH and rswETH on UniswapV3 using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[129].argumentAddresses[0] = wETH_rswETH_05;

        leafs[130] = ManageLeaf(
            aggregationRouterV5,
            false,
            "uniswapV3Swap(uint256,uint256,uint256[])",
            new address[](1),
            "Swap between wETH and rswETH on UniswapV3 using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[130].argumentAddresses[0] = wETH_rswETH_30;

        leafs[131] = ManageLeaf(
            aggregationRouterV5,
            false,
            "uniswapV3Swap(uint256,uint256,uint256[])",
            new address[](1),
            "Swap between ezETH and wETH on UniswapV3 using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[131].argumentAddresses[0] = ezETH_wETH_01;

        // Swap BAL using balancer
        leafs[132] = ManageLeaf(
            address(BAL),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer Vault to spend BAL",
            rawDataDecoderAndSanitizer
        );
        leafs[132].argumentAddresses[0] = vault;

        leafs[133] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap BAL for wETH using BAL-wETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[133].argumentAddresses[0] = address(BAL_wETH);
        leafs[133].argumentAddresses[1] = address(BAL);
        leafs[133].argumentAddresses[2] = address(WETH);
        leafs[133].argumentAddresses[3] = address(boringVault);
        leafs[133].argumentAddresses[4] = address(boringVault);

        // Swap BAL using 1inch
        leafs[134] = ManageLeaf(
            address(BAL),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve 1inch router to spend BAL",
            rawDataDecoderAndSanitizer
        );
        leafs[134].argumentAddresses[0] = aggregationRouterV5;
        leafs[135] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap BAL for wETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[135].argumentAddresses[0] = oneInchExecutor;
        leafs[135].argumentAddresses[1] = address(BAL);
        leafs[135].argumentAddresses[2] = address(WETH);
        leafs[135].argumentAddresses[3] = oneInchExecutor;
        leafs[135].argumentAddresses[4] = boringVault;

        // Swap PENDLE using 1inch
        leafs[136] = ManageLeaf(
            address(PENDLE),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve 1inch router to spend PENDLE",
            rawDataDecoderAndSanitizer
        );
        leafs[136].argumentAddresses[0] = aggregationRouterV5;
        leafs[137] = ManageLeaf(
            aggregationRouterV5,
            false,
            "uniswapV3Swap(uint256,uint256,uint256[])",
            new address[](1),
            "Swap between PENDLE and wETH on UniswapV3 using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[137].argumentAddresses[0] = PENDLE_wETH_30;

        leafs[138] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap PENDLE for wETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[138].argumentAddresses[0] = oneInchExecutor;
        leafs[138].argumentAddresses[1] = address(PENDLE);
        leafs[138].argumentAddresses[2] = address(WETH);
        leafs[138].argumentAddresses[3] = oneInchExecutor;
        leafs[138].argumentAddresses[4] = boringVault;

        // Swap PENDLE using balancer
        leafs[139] = ManageLeaf(
            address(PENDLE),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer Vault to spend PENDLE",
            rawDataDecoderAndSanitizer
        );
        leafs[139].argumentAddresses[0] = vault;

        leafs[140] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap PENDLE for wETH using PENDLE-wETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[140].argumentAddresses[0] = address(PENDLE_wETH);
        leafs[140].argumentAddresses[1] = address(PENDLE);
        leafs[140].argumentAddresses[2] = address(WETH);
        leafs[140].argumentAddresses[3] = address(boringVault);
        leafs[140].argumentAddresses[4] = address(boringVault);

        // Swap AURA using balancer
        leafs[141] = ManageLeaf(
            address(AURA),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer Vault to spend AURA",
            rawDataDecoderAndSanitizer
        );
        leafs[141].argumentAddresses[0] = vault;

        leafs[142] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap AURA for wETH using wETH-AURA Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[142].argumentAddresses[0] = address(wETH_AURA);
        leafs[142].argumentAddresses[1] = address(AURA);
        leafs[142].argumentAddresses[2] = address(WETH);
        leafs[142].argumentAddresses[3] = address(boringVault);
        leafs[142].argumentAddresses[4] = address(boringVault);

        // Swap Aura using 1inch
        leafs[143] = ManageLeaf(
            address(AURA),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve 1inch router to spend AURA",
            rawDataDecoderAndSanitizer
        );
        leafs[143].argumentAddresses[0] = aggregationRouterV5;

        leafs[144] = ManageLeaf(
            aggregationRouterV5,
            false,
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            new address[](5),
            "Swap AURA for wETH using 1inch router",
            rawDataDecoderAndSanitizer
        );
        leafs[144].argumentAddresses[0] = oneInchExecutor;
        leafs[144].argumentAddresses[1] = address(AURA);
        leafs[144].argumentAddresses[2] = address(WETH);
        leafs[144].argumentAddresses[3] = oneInchExecutor;
        leafs[144].argumentAddresses[4] = boringVault;

        // Setup leafs to claim fees.
        leafs[145] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve AccountantWithRateProviders to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[145].argumentAddresses[0] = accountantAddress;

        // Approve AccountantWithRateProviders to spend eETH
        leafs[146] = ManageLeaf(
            address(EETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve AccountantWithRateProviders to spend eETH",
            rawDataDecoderAndSanitizer
        );
        leafs[146].argumentAddresses[0] = accountantAddress;

        // Approve AccountantWithRateProviders to spend weETH
        leafs[147] = ManageLeaf(
            address(WEETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve AccountantWithRateProviders to spend weETH",
            rawDataDecoderAndSanitizer
        );
        leafs[147].argumentAddresses[0] = accountantAddress;

        leafs[148] = ManageLeaf(
            accountantAddress,
            false,
            "claimFees(address)",
            new address[](1),
            "Claim Fees with wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[148].argumentAddresses[0] = address(WETH);

        leafs[149] = ManageLeaf(
            accountantAddress,
            false,
            "claimFees(address)",
            new address[](1),
            "Claim Fees with eETH",
            rawDataDecoderAndSanitizer
        );
        leafs[149].argumentAddresses[0] = address(EETH);

        leafs[150] = ManageLeaf(
            accountantAddress,
            false,
            "claimFees(address)",
            new address[](1),
            "Claim Fees with weETH",
            rawDataDecoderAndSanitizer
        );
        leafs[150].argumentAddresses[0] = address(WEETH);

        leafs[151] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
            new address[](3),
            "Add liquidity to UniswapV3 wstETH ezETH position",
            rawDataDecoderAndSanitizer
        );
        leafs[151].argumentAddresses[0] = address(0);
        leafs[151].argumentAddresses[1] = address(WSTETH);
        leafs[151].argumentAddresses[2] = address(EZETH);

        leafs[152] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
            new address[](3),
            "Add liquidity to UniswapV3 rETH ezETH position",
            rawDataDecoderAndSanitizer
        );
        leafs[152].argumentAddresses[0] = address(0);
        leafs[152].argumentAddresses[1] = address(RETH);
        leafs[152].argumentAddresses[2] = address(EZETH);

        leafs[153] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
            new address[](3),
            "Add liquidity to UniswapV3 ezETH weETH position",
            rawDataDecoderAndSanitizer
        );
        leafs[153].argumentAddresses[0] = address(0);
        leafs[153].argumentAddresses[1] = address(EZETH);
        leafs[153].argumentAddresses[2] = address(WEETH);

        leafs[154] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "redeemDueInterestAndRewards(address,address[],address[],address[])",
            new address[](4),
            "Redeem due interest and rewards for ezETH Pendle.",
            rawDataDecoderAndSanitizer
        );
        leafs[154].argumentAddresses[0] = boringVault;
        leafs[154].argumentAddresses[1] = pendleEzEthSy;
        leafs[154].argumentAddresses[2] = pendleEzEthYt;
        leafs[154].argumentAddresses[3] = pendleEzEthMarket;

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/AdminStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function generateProductionRenzoStrategistMerkleRoot() public {
        ManageLeaf[] memory leafs = new ManageLeaf[](128);

        // uniswap v3
        leafs[0] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 NonFungible Position Manager to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[0].argumentAddresses[0] = uniswapV3NonFungiblePositionManager;
        leafs[1] = ManageLeaf(
            address(EZETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 NonFungible Position Manager to spend ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[1].argumentAddresses[0] = uniswapV3NonFungiblePositionManager;
        leafs[2] = ManageLeaf(
            address(WSTETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 NonFungible Position Manager to spend wstETH",
            rawDataDecoderAndSanitizer
        );
        leafs[2].argumentAddresses[0] = uniswapV3NonFungiblePositionManager;
        leafs[3] = ManageLeaf(
            address(RETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 NonFungible Position Manager to spend rETH",
            rawDataDecoderAndSanitizer
        );
        leafs[3].argumentAddresses[0] = uniswapV3NonFungiblePositionManager;
        leafs[4] = ManageLeaf(
            address(WEETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve UniswapV3 NonFungible Position Manager to spend weETH",
            rawDataDecoderAndSanitizer
        );
        leafs[4].argumentAddresses[0] = uniswapV3NonFungiblePositionManager;
        leafs[5] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
            new address[](3),
            "Mint UniswapV3 ezETH wETH position",
            rawDataDecoderAndSanitizer
        );
        leafs[5].argumentAddresses[0] = address(EZETH);
        leafs[5].argumentAddresses[1] = address(WETH);
        leafs[5].argumentAddresses[2] = boringVault;
        leafs[6] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
            new address[](3),
            "Mint UniswapV3 wstETH ezETH position",
            rawDataDecoderAndSanitizer
        );
        leafs[6].argumentAddresses[0] = address(WSTETH);
        leafs[6].argumentAddresses[1] = address(EZETH);
        leafs[6].argumentAddresses[2] = boringVault;
        leafs[7] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
            new address[](3),
            "Mint UniswapV3 rETH ezETH position",
            rawDataDecoderAndSanitizer
        );
        leafs[7].argumentAddresses[0] = address(RETH);
        leafs[7].argumentAddresses[1] = address(EZETH);
        leafs[7].argumentAddresses[2] = boringVault;
        leafs[8] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
            new address[](3),
            "Mint UniswapV3 ezETH weETH position",
            rawDataDecoderAndSanitizer
        );
        leafs[8].argumentAddresses[0] = address(EZETH);
        leafs[8].argumentAddresses[1] = address(WEETH);
        leafs[8].argumentAddresses[2] = boringVault;
        leafs[9] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
            new address[](0),
            "Add liquidity to UniswapV3 position",
            rawDataDecoderAndSanitizer
        );
        leafs[10] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            new address[](0),
            "Remove liquidity from UniswapV3 position",
            rawDataDecoderAndSanitizer
        );
        leafs[11] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "collect((uint256,address,uint128,uint128))",
            new address[](1),
            "Collect from UniswapV3 position",
            rawDataDecoderAndSanitizer
        );
        leafs[11].argumentAddresses[0] = boringVault;

        // morphoblue
        leafs[12] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve MorphoBlue to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[12].argumentAddresses[0] = morphoBlue;
        leafs[13] = ManageLeaf(
            morphoBlue,
            false,
            "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            new address[](5),
            "Supply wETH to ezETH MorphoBlue market",
            rawDataDecoderAndSanitizer
        );
        leafs[13].argumentAddresses[0] = address(WETH);
        leafs[13].argumentAddresses[1] = address(EZETH);
        leafs[13].argumentAddresses[2] = ezEthOracle;
        leafs[13].argumentAddresses[3] = ezEthIrm;
        leafs[13].argumentAddresses[4] = boringVault;
        leafs[14] = ManageLeaf(
            morphoBlue,
            false,
            "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
            new address[](6),
            "Withdraw wETH from ezETH MorphoBlue market",
            rawDataDecoderAndSanitizer
        );
        leafs[14].argumentAddresses[0] = address(WETH);
        leafs[14].argumentAddresses[1] = address(EZETH);
        leafs[14].argumentAddresses[2] = ezEthOracle;
        leafs[14].argumentAddresses[3] = ezEthIrm;
        leafs[14].argumentAddresses[4] = boringVault;
        leafs[14].argumentAddresses[5] = boringVault;

        // renzo staking
        leafs[15] =
            ManageLeaf(restakeManager, true, "depositETH()", new address[](0), "Mint ezETH", rawDataDecoderAndSanitizer);

        // lido support
        leafs[15] = ManageLeaf(
            address(STETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve wstETH to spend stETH",
            rawDataDecoderAndSanitizer
        );
        leafs[15].argumentAddresses[0] = address(WSTETH);
        leafs[16] = ManageLeaf(
            address(STETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve unstETH to spend stETH",
            rawDataDecoderAndSanitizer
        );
        leafs[16].argumentAddresses[0] = address(unstETH);
        leafs[17] = ManageLeaf(
            address(STETH), true, "submit(address)", new address[](1), "Mint stETH", rawDataDecoderAndSanitizer
        );
        leafs[17].argumentAddresses[0] = address(0);
        leafs[18] = ManageLeaf(
            address(WSTETH), false, "wrap(uint256)", new address[](0), "Wrap stETH", rawDataDecoderAndSanitizer
        );
        leafs[19] = ManageLeaf(
            address(WSTETH), false, "unwrap(uint256)", new address[](0), "Unwrap wstETH", rawDataDecoderAndSanitizer
        );
        leafs[20] = ManageLeaf(
            unstETH,
            false,
            "requestWithdrawals(uint256[],address)",
            new address[](1),
            "Request withdrawals from stETH",
            rawDataDecoderAndSanitizer
        );
        leafs[20].argumentAddresses[0] = boringVault;
        leafs[21] = ManageLeaf(
            unstETH,
            false,
            "claimWithdrawal(uint256)",
            new address[](0),
            "Claim stETH withdrawal",
            rawDataDecoderAndSanitizer
        );
        leafs[22] = ManageLeaf(
            unstETH,
            false,
            "claimWithdrawals(uint256[],uint256[])",
            new address[](0),
            "Claim stETH withdrawals",
            rawDataDecoderAndSanitizer
        );

        // balancer V2 and aura
        leafs[23] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer Vault to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[23].argumentAddresses[0] = vault;
        leafs[24] = ManageLeaf(
            address(EZETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer Vault to spend ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[24].argumentAddresses[0] = vault;
        leafs[25] = ManageLeaf(
            address(WSTETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer Vault to spend wstETH",
            rawDataDecoderAndSanitizer
        );
        leafs[25].argumentAddresses[0] = vault;
        leafs[25] = ManageLeaf(
            address(RETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer Vault to spend rETH",
            rawDataDecoderAndSanitizer
        );
        leafs[25].argumentAddresses[0] = vault;
        leafs[25] = ManageLeaf(
            address(WEETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer Vault to spend weETH",
            rawDataDecoderAndSanitizer
        );
        leafs[25].argumentAddresses[0] = vault;
        leafs[26] = ManageLeaf(
            address(RSWETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer Vault to spend rswETH",
            rawDataDecoderAndSanitizer
        );
        leafs[26].argumentAddresses[0] = vault;
        leafs[27] = ManageLeaf(
            address(ezETH_weETH_rswETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer ezETH-weETH-rswETH gauge to spend ezETH-weETH-rswETH bpts",
            rawDataDecoderAndSanitizer
        );
        leafs[27].argumentAddresses[0] = ezETH_weETH_rswETH_gauge;
        leafs[28] = ManageLeaf(
            address(ezETH_weETH_rswETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Aura ezETH-weETH-rswETH gauge to spend ezETH-weETH-rswETH bpts",
            rawDataDecoderAndSanitizer
        );
        leafs[28].argumentAddresses[0] = aura_ezETH_weETH_rswETH;
        leafs[29] = ManageLeaf(
            address(ezETH_wETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer ezETH-wETH gauge to spend ezETH-wETH bpts",
            rawDataDecoderAndSanitizer
        );
        leafs[29].argumentAddresses[0] = ezETH_wETH_gauge;
        leafs[30] = ManageLeaf(
            address(ezETH_wETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Aura ezETH-wETH gauge to spend ezETH-wETH bpts",
            rawDataDecoderAndSanitizer
        );
        leafs[30].argumentAddresses[0] = aura_ezETH_wETH;
        leafs[31] = ManageLeaf(
            vault,
            false,
            "joinPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
            new address[](6),
            "Join ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[31].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[31].argumentAddresses[1] = boringVault;
        leafs[31].argumentAddresses[2] = boringVault;
        leafs[31].argumentAddresses[3] = address(EZETH);
        leafs[31].argumentAddresses[4] = address(WEETH);
        leafs[31].argumentAddresses[5] = address(RSWETH);
        leafs[32] = ManageLeaf(
            ezETH_weETH_rswETH_gauge,
            false,
            "deposit(uint256,address)",
            new address[](1),
            "Deposit ezETH-weETH-rswETH bpts into Balancer gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[32].argumentAddresses[0] = boringVault;
        leafs[33] = ManageLeaf(
            ezETH_weETH_rswETH_gauge,
            false,
            "withdraw(uint256)",
            new address[](0),
            "Withdraw ezETH-weETH-rswETH bpts from Balancer gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[34] = ManageLeaf(
            aura_ezETH_wETH,
            false,
            "deposit(uint256,address)",
            new address[](1),
            "Deposit ezETH-weETH-rswETH bpts into Aura gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[34].argumentAddresses[0] = boringVault;
        leafs[35] = ManageLeaf(
            aura_ezETH_wETH,
            false,
            "withdraw(uint256,address,address)",
            new address[](2),
            "Withdraw ezETH-weETH-rswETH bpts from Aura gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[35].argumentAddresses[0] = boringVault;
        leafs[35].argumentAddresses[1] = boringVault;
        leafs[36] = ManageLeaf(
            vault,
            false,
            "exitPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
            new address[](6),
            "Exit ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[36].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[36].argumentAddresses[1] = boringVault;
        leafs[36].argumentAddresses[2] = boringVault;
        leafs[36].argumentAddresses[3] = address(EZETH);
        leafs[36].argumentAddresses[4] = address(WEETH);
        leafs[36].argumentAddresses[5] = address(RSWETH);
        leafs[37] = ManageLeaf(
            vault,
            false,
            "joinPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
            new address[](5),
            "Join ezETH-wETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[37].argumentAddresses[0] = address(ezETH_wETH);
        leafs[37].argumentAddresses[1] = boringVault;
        leafs[37].argumentAddresses[2] = boringVault;
        leafs[37].argumentAddresses[3] = address(EZETH);
        leafs[37].argumentAddresses[4] = address(WETH);
        leafs[38] = ManageLeaf(
            ezETH_wETH_gauge,
            false,
            "deposit(uint256,address)",
            new address[](1),
            "Deposit ezETH-wETH bpts into Balancer gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[38].argumentAddresses[0] = boringVault;
        leafs[39] = ManageLeaf(
            ezETH_wETH_gauge,
            false,
            "withdraw(uint256)",
            new address[](0),
            "Withdraw ezETH-wETH bpts from Balancer gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[40] = ManageLeaf(
            aura_ezETH_wETH,
            false,
            "deposit(uint256,address)",
            new address[](1),
            "Deposit ezETH-wETH bpts into Aura gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[40].argumentAddresses[0] = boringVault;
        leafs[41] = ManageLeaf(
            aura_ezETH_wETH,
            false,
            "withdraw(uint256,address,address)",
            new address[](2),
            "Withdraw ezETH-wETH bpts from Aura gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[41].argumentAddresses[0] = boringVault;
        leafs[41].argumentAddresses[1] = boringVault;
        leafs[42] = ManageLeaf(
            vault,
            false,
            "exitPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
            new address[](5),
            "Exit ezETH-wETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[42].argumentAddresses[0] = address(ezETH_wETH);
        leafs[42].argumentAddresses[1] = boringVault;
        leafs[42].argumentAddresses[2] = boringVault;
        leafs[42].argumentAddresses[3] = address(EZETH);
        leafs[42].argumentAddresses[4] = address(WETH);
        leafs[43] = ManageLeaf(
            minter,
            false,
            "mint(address)",
            new address[](1),
            "Claim $BAL rewards for ezETH-weETH-rswETH Balancer gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[43].argumentAddresses[0] = address(ezETH_weETH_rswETH_gauge);
        leafs[44] = ManageLeaf(
            minter,
            false,
            "mint(address)",
            new address[](1),
            "Claim $BAL rewards for ezETH-wETH Balancer gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[44].argumentAddresses[0] = address(ezETH_wETH_gauge);
        leafs[45] = ManageLeaf(
            aura_ezETH_weETH_rswETH,
            false,
            "getReward(address,bool)",
            new address[](1),
            "Claim rewards for ezETH-weETH-rswETH Aura gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[45].argumentAddresses[0] = boringVault;
        leafs[46] = ManageLeaf(
            aura_ezETH_wETH,
            false,
            "getReward(address,bool)",
            new address[](1),
            "Claim rewards for ezETH-wETH Aura gauge",
            rawDataDecoderAndSanitizer
        );
        leafs[46].argumentAddresses[0] = boringVault;

        // gearbox
        leafs[47] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Gearbox dWETHV3 to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[47].argumentAddresses[0] = dWETHV3;
        leafs[48] = ManageLeaf(
            dWETHV3,
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Gearbox sdWETHV3 to spend dWETHV3",
            rawDataDecoderAndSanitizer
        );
        leafs[48].argumentAddresses[0] = sdWETHV3;
        leafs[49] = ManageLeaf(
            dWETHV3,
            false,
            "deposit(uint256,address)",
            new address[](1),
            "Deposit into Gearbox dWETHV3",
            rawDataDecoderAndSanitizer
        );
        leafs[49].argumentAddresses[0] = boringVault;
        leafs[50] = ManageLeaf(
            dWETHV3,
            false,
            "withdraw(uint256,address,address)",
            new address[](2),
            "Withdraw from Gearbox dWETHV3",
            rawDataDecoderAndSanitizer
        );
        leafs[50].argumentAddresses[0] = boringVault;
        leafs[50].argumentAddresses[1] = boringVault;
        leafs[51] = ManageLeaf(
            sdWETHV3,
            false,
            "deposit(uint256)",
            new address[](0),
            "Deposit into Gearbox sdWETHV3",
            rawDataDecoderAndSanitizer
        );
        leafs[52] = ManageLeaf(
            sdWETHV3,
            false,
            "withdraw(uint256)",
            new address[](0),
            "Withdraw from Gearbox sdWETHV3",
            rawDataDecoderAndSanitizer
        );
        leafs[53] = ManageLeaf(
            sdWETHV3,
            false,
            "claim()",
            new address[](0),
            "Claim rewards from Gearbox sdWETHV3",
            rawDataDecoderAndSanitizer
        );

        // native wrapper
        leafs[54] = ManageLeaf(
            address(WETH), true, "deposit()", new address[](0), "Wrap ETH for wETH", rawDataDecoderAndSanitizer
        );
        leafs[55] = ManageLeaf(
            address(WETH),
            false,
            "withdraw(uint256)",
            new address[](0),
            "Unwrap wETH for ETH",
            rawDataDecoderAndSanitizer
        );

        // pendle
        leafs[56] = ManageLeaf(
            address(EZETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Pendle router to spend ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[56].argumentAddresses[0] = pendleRouter;
        leafs[57] = ManageLeaf(
            pendleEzEthSy,
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Pendle router to spend SY-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[57].argumentAddresses[0] = pendleRouter;
        leafs[58] = ManageLeaf(
            pendleEzEthPt,
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Pendle router to spend PT-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[58].argumentAddresses[0] = pendleRouter;
        leafs[59] = ManageLeaf(
            pendleEzEthYt,
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Pendle router to spend YT-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[59].argumentAddresses[0] = pendleRouter;
        leafs[60] = ManageLeaf(
            pendleEzEthMarket,
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Pendle router to spend LP-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[60].argumentAddresses[0] = pendleRouter;
        leafs[61] = ManageLeaf(
            pendleRouter,
            false,
            "mintSyFromToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            new address[](6),
            "Mint SY-ezETH using ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[61].argumentAddresses[0] = boringVault;
        leafs[61].argumentAddresses[1] = pendleEzEthSy;
        leafs[61].argumentAddresses[2] = address(EZETH);
        leafs[61].argumentAddresses[3] = address(EZETH);
        leafs[61].argumentAddresses[4] = address(0);
        leafs[61].argumentAddresses[5] = address(0);
        leafs[62] = ManageLeaf(
            pendleRouter,
            false,
            "mintPyFromSy(address,address,uint256,uint256)",
            new address[](2),
            "Mint PT-ezETH and YT-ezETH from SY-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[62].argumentAddresses[0] = boringVault;
        leafs[62].argumentAddresses[1] = pendleEzEthYt;
        leafs[63] = ManageLeaf(
            pendleRouter,
            false,
            "swapExactYtForPt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            new address[](2),
            "Swap YT-ezETH for PT-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[63].argumentAddresses[0] = boringVault;
        leafs[63].argumentAddresses[1] = pendleEzEthMarket;
        leafs[64] = ManageLeaf(
            pendleRouter,
            false,
            "swapExactPtForYt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            new address[](2),
            "Swap PT-ezETH for YT-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[64].argumentAddresses[0] = boringVault;
        leafs[64].argumentAddresses[1] = pendleEzEthMarket;
        leafs[65] = ManageLeaf(
            pendleRouter,
            false,
            "addLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
            new address[](2),
            "Mint LP-ezETH using SY-ezETH and PT-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[65].argumentAddresses[0] = boringVault;
        leafs[65].argumentAddresses[1] = pendleEzEthMarket;
        leafs[66] = ManageLeaf(
            pendleRouter,
            false,
            "removeLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
            new address[](2),
            "Burn LP-ezETH for SY-ezETH and PT-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[66].argumentAddresses[0] = boringVault;
        leafs[66].argumentAddresses[1] = pendleEzEthMarket;
        leafs[67] = ManageLeaf(
            pendleRouter,
            false,
            "redeemPyToSy(address,address,uint256,uint256)",
            new address[](2),
            "Burn PT-ezETH and YT-ezETH for SY-ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[67].argumentAddresses[0] = boringVault;
        leafs[67].argumentAddresses[1] = pendleEzEthYt;
        leafs[68] = ManageLeaf(
            pendleRouter,
            false,
            "redeemSyToToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
            new address[](6),
            "Burn SY-ezETH for ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[68].argumentAddresses[0] = address(boringVault);
        leafs[68].argumentAddresses[1] = pendleEzEthSy;
        leafs[68].argumentAddresses[2] = address(EZETH);
        leafs[68].argumentAddresses[3] = address(EZETH);
        leafs[68].argumentAddresses[4] = address(0);
        leafs[68].argumentAddresses[5] = address(0);

        // flashloans
        leafs[69] = ManageLeaf(
            managerAddress,
            false,
            "flashLoan(address,address[],uint256[],bytes)",
            new address[](2),
            "Flash loan wETH from Balancer",
            rawDataDecoderAndSanitizer
        );
        leafs[69].argumentAddresses[0] = managerAddress;
        leafs[69].argumentAddresses[1] = address(WETH);

        // swap with balancer
        leafs[70] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap ezETH for weETH using ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[70].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[70].argumentAddresses[1] = address(EZETH);
        leafs[70].argumentAddresses[2] = address(WEETH);
        leafs[70].argumentAddresses[3] = address(boringVault);
        leafs[70].argumentAddresses[4] = address(boringVault);
        leafs[71] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap ezETH for rswETH using ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[71].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[71].argumentAddresses[1] = address(EZETH);
        leafs[71].argumentAddresses[2] = address(RSWETH);
        leafs[71].argumentAddresses[3] = address(boringVault);
        leafs[71].argumentAddresses[4] = address(boringVault);
        leafs[72] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap weETH for ezETH using ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[72].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[72].argumentAddresses[1] = address(WEETH);
        leafs[72].argumentAddresses[2] = address(EZETH);
        leafs[72].argumentAddresses[3] = address(boringVault);
        leafs[72].argumentAddresses[4] = address(boringVault);
        leafs[73] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap rswETH for ezETH using ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[73].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[73].argumentAddresses[1] = address(RSWETH);
        leafs[73].argumentAddresses[2] = address(EZETH);
        leafs[73].argumentAddresses[3] = address(boringVault);
        leafs[73].argumentAddresses[4] = address(boringVault);
        leafs[74] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap weETH for rswETH using ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[74].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[74].argumentAddresses[1] = address(WEETH);
        leafs[74].argumentAddresses[2] = address(RSWETH);
        leafs[74].argumentAddresses[3] = address(boringVault);
        leafs[74].argumentAddresses[4] = address(boringVault);
        leafs[75] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap rswETH for weETH using ezETH-weETH-rswETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[75].argumentAddresses[0] = address(ezETH_weETH_rswETH);
        leafs[75].argumentAddresses[1] = address(RSWETH);
        leafs[75].argumentAddresses[2] = address(WEETH);
        leafs[75].argumentAddresses[3] = address(boringVault);
        leafs[75].argumentAddresses[4] = address(boringVault);
        leafs[76] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap ezETH for wETH using ezETH-wETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[76].argumentAddresses[0] = address(ezETH_wETH);
        leafs[76].argumentAddresses[1] = address(EZETH);
        leafs[76].argumentAddresses[2] = address(WETH);
        leafs[76].argumentAddresses[3] = address(boringVault);
        leafs[76].argumentAddresses[4] = address(boringVault);
        leafs[77] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap wETH for ezETH using ezETH-wETH Balancer pool",
            rawDataDecoderAndSanitizer
        );
        leafs[77].argumentAddresses[0] = address(ezETH_wETH);
        leafs[77].argumentAddresses[1] = address(WETH);
        leafs[77].argumentAddresses[2] = address(EZETH);
        leafs[77].argumentAddresses[3] = address(boringVault);
        leafs[77].argumentAddresses[4] = address(boringVault);

        // swap with curve
        leafs[78] = ManageLeaf(
            address(EZETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve ezETH/wETH pool to spend ezETH",
            rawDataDecoderAndSanitizer
        );
        leafs[78].argumentAddresses[0] = ezETH_wETH_Curve_Pool;
        leafs[79] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve ezETH/wETH pool to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[79].argumentAddresses[0] = ezETH_wETH_Curve_Pool;
        leafs[80] = ManageLeaf(
            ezETH_wETH_Curve_Pool,
            false,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            "Swap using Curve ezETH/wETH pool",
            rawDataDecoderAndSanitizer
        );
        leafs[81] = ManageLeaf(
            address(WEETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve weETH/rswETH pool to spend weETH",
            rawDataDecoderAndSanitizer
        );
        leafs[81].argumentAddresses[0] = weETH_rswETH_Curve_Pool;
        leafs[82] = ManageLeaf(
            address(RSWETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve weETH/rswETH pool to spend rswETH",
            rawDataDecoderAndSanitizer
        );
        leafs[82].argumentAddresses[0] = weETH_rswETH_Curve_Pool;
        leafs[83] = ManageLeaf(
            weETH_rswETH_Curve_Pool,
            false,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            "Swap using Curve weETH/rswETH pool",
            rawDataDecoderAndSanitizer
        );
        leafs[84] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve rswETH/wETH pool to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[84].argumentAddresses[0] = rswETH_wETH_Curve_Pool;
        leafs[85] = ManageLeaf(
            address(RSWETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve rswETH/wETH pool to spend rswETH",
            rawDataDecoderAndSanitizer
        );
        leafs[85].argumentAddresses[0] = rswETH_wETH_Curve_Pool;
        leafs[86] = ManageLeaf(
            rswETH_wETH_Curve_Pool,
            false,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            "Swap using Curve rswETH/wETH pool",
            rawDataDecoderAndSanitizer
        );
        leafs[87] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve weETH/wETH pool to spend wETH",
            rawDataDecoderAndSanitizer
        );
        leafs[87].argumentAddresses[0] = weETH_wETH_Curve_LP;
        leafs[88] = ManageLeaf(
            address(WEETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve weETH/wETH pool to spend weETH",
            rawDataDecoderAndSanitizer
        );
        leafs[88].argumentAddresses[0] = weETH_wETH_Curve_LP;
        leafs[89] = ManageLeaf(
            weETH_wETH_Curve_LP,
            false,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            "Swap using Curve weETH/wETH pool",
            rawDataDecoderAndSanitizer
        );
        leafs[90] = ManageLeaf(
            address(STETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Curve ETH/stETH pool to spend stETH",
            rawDataDecoderAndSanitizer
        );
        leafs[90].argumentAddresses[0] = EthStethPool;
        leafs[91] = ManageLeaf(
            EthStethPool,
            true,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            "Swap using Curve ETH/stETH pool",
            rawDataDecoderAndSanitizer
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/RenzoStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function _generateLeafs(
        string memory filePath,
        ManageLeaf[] memory leafs,
        bytes32 manageRoot,
        bytes32[][] memory manageTree
    ) internal {
        if (vm.exists(filePath)) {
            // Need to delete it
            vm.removeFile(filePath);
        }
        vm.writeLine(filePath, "{ \"metadata\": ");
        string[] memory composition = new string[](5);
        composition[0] = "Bytes20(DECODER_AND_SANITIZER_ADDRESS)";
        composition[1] = "Bytes20(TARGET_ADDRESS)";
        composition[2] = "Bytes1(CAN_SEND_VALUE)";
        composition[3] = "Bytes4(TARGET_FUNCTION_SELECTOR)";
        composition[4] = "Bytes{N*20}(ADDRESS_ARGUMENT_0,...,ADDRESS_ARGUMENT_N)";
        string memory metadata = "ManageRoot";
        {
            // Determine how many leafs are used.
            uint256 usedLeafCount;
            for (uint256 i; i < leafs.length; ++i) {
                if (leafs[i].target != address(0)) {
                    usedLeafCount++;
                }
            }
            vm.serializeUint(metadata, "LeafCount", usedLeafCount);
        }
        vm.serializeUint(metadata, "TreeCapacity", leafs.length);
        vm.serializeString(metadata, "DigestComposition", composition);
        vm.serializeAddress(metadata, "BoringVaultAddress", boringVault);
        vm.serializeAddress(metadata, "DecoderAndSanitizerAddress", rawDataDecoderAndSanitizer);
        vm.serializeAddress(metadata, "ManagerAddress", managerAddress);
        vm.serializeAddress(metadata, "AccountantAddress", accountantAddress);
        string memory finalMetadata = vm.serializeBytes32(metadata, "ManageRoot", manageRoot);

        vm.writeLine(filePath, finalMetadata);
        vm.writeLine(filePath, ",");
        vm.writeLine(filePath, "\"leafs\": [");

        for (uint256 i; i < leafs.length; ++i) {
            string memory leaf = "leaf";
            vm.serializeAddress(leaf, "TargetAddress", leafs[i].target);
            vm.serializeAddress(leaf, "DecoderAndSanitizerAddress", leafs[i].decoderAndSanitizer);
            vm.serializeBool(leaf, "CanSendValue", leafs[i].canSendValue);
            vm.serializeString(leaf, "FunctionSignature", leafs[i].signature);
            bytes4 sel = bytes4(keccak256(abi.encodePacked(leafs[i].signature)));
            string memory selector = Strings.toHexString(uint32(sel), 4);
            vm.serializeString(leaf, "FunctionSelector", selector);
            bytes memory packedData;
            for (uint256 j; j < leafs[i].argumentAddresses.length; ++j) {
                packedData = abi.encodePacked(packedData, leafs[i].argumentAddresses[j]);
            }
            vm.serializeBytes(leaf, "PackedArgumentAddresses", packedData);
            vm.serializeAddress(leaf, "AddressArguments", leafs[i].argumentAddresses);
            bytes32 digest = keccak256(
                abi.encodePacked(leafs[i].decoderAndSanitizer, leafs[i].target, leafs[i].canSendValue, sel, packedData)
            );
            vm.serializeBytes32(leaf, "LeafDigest", digest);

            string memory finalJson = vm.serializeString(leaf, "Description", leafs[i].description);

            // vm.writeJson(finalJson, filePath);
            vm.writeLine(filePath, finalJson);
            if (i != leafs.length - 1) {
                vm.writeLine(filePath, ",");
            }
        }
        vm.writeLine(filePath, "],");

        string memory merkleTreeName = "MerkleTree";
        string[][] memory merkleTree = new string[][](manageTree.length);
        for (uint256 k; k < manageTree.length; ++k) {
            merkleTree[k] = new string[](manageTree[k].length);
        }

        for (uint256 i; i < manageTree.length; ++i) {
            for (uint256 j; j < manageTree[i].length; ++j) {
                merkleTree[i][j] = vm.toString(manageTree[i][j]);
            }
        }

        string memory finalMerkleTree;
        for (uint256 i; i < merkleTree.length; ++i) {
            string memory layer = Strings.toString(merkleTree.length - (i + 1));
            finalMerkleTree = vm.serializeString(merkleTreeName, layer, merkleTree[i]);
        }
        vm.writeLine(filePath, "\"MerkleTree\": ");
        vm.writeLine(filePath, finalMerkleTree);
        vm.writeLine(filePath, "}");
    }

    // ========================================= HELPER FUNCTIONS =========================================
    struct ManageLeaf {
        address target;
        bool canSendValue;
        string signature;
        address[] argumentAddresses;
        string description;
        address decoderAndSanitizer;
    }

    function _buildTrees(bytes32[][] memory merkleTreeIn) internal pure returns (bytes32[][] memory merkleTreeOut) {
        // We are adding another row to the merkle tree, so make merkleTreeOut be 1 longer.
        uint256 merkleTreeIn_length = merkleTreeIn.length;
        merkleTreeOut = new bytes32[][](merkleTreeIn_length + 1);
        uint256 layer_length;
        // Iterate through merkleTreeIn to copy over data.
        for (uint256 i; i < merkleTreeIn_length; ++i) {
            layer_length = merkleTreeIn[i].length;
            merkleTreeOut[i] = new bytes32[](layer_length);
            for (uint256 j; j < layer_length; ++j) {
                merkleTreeOut[i][j] = merkleTreeIn[i][j];
            }
        }

        uint256 next_layer_length;
        if (layer_length % 2 != 0) {
            next_layer_length = (layer_length + 1) / 2;
        } else {
            next_layer_length = layer_length / 2;
        }
        merkleTreeOut[merkleTreeIn_length] = new bytes32[](next_layer_length);
        uint256 count;
        for (uint256 i; i < layer_length; i += 2) {
            merkleTreeOut[merkleTreeIn_length][count] =
                _hashPair(merkleTreeIn[merkleTreeIn_length - 1][i], merkleTreeIn[merkleTreeIn_length - 1][i + 1]);
            count++;
        }

        if (next_layer_length > 1) {
            // We need to process the next layer of leaves.
            merkleTreeOut = _buildTrees(merkleTreeOut);
        }
    }

    function _generateMerkleTree(ManageLeaf[] memory manageLeafs) internal view returns (bytes32[][] memory tree) {
        uint256 leafsLength = manageLeafs.length;
        bytes32[][] memory leafs = new bytes32[][](1);
        leafs[0] = new bytes32[](leafsLength);
        for (uint256 i; i < leafsLength; ++i) {
            bytes4 selector = bytes4(keccak256(abi.encodePacked(manageLeafs[i].signature)));
            bytes memory rawDigest = abi.encodePacked(
                rawDataDecoderAndSanitizer, manageLeafs[i].target, manageLeafs[i].canSendValue, selector
            );
            uint256 argumentAddressesLength = manageLeafs[i].argumentAddresses.length;
            for (uint256 j; j < argumentAddressesLength; ++j) {
                rawDigest = abi.encodePacked(rawDigest, manageLeafs[i].argumentAddresses[j]);
            }
            leafs[0][i] = keccak256(rawDigest);
        }
        tree = _buildTrees(leafs);
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}

interface IMB {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function idToMarketParams(bytes32 id) external view returns (MarketParams memory);
}
