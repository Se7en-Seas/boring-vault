// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/CreateLiquidUsdMerkleRoot.s.sol:CreateLiquidUsdMerkleRootScript --rpc-url $MAINNET_RPC_URL
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

        uint256 leafIndex = 0;

        // ========================== Aave V3 ==========================
        /**
         * lend USDC, USDT, DAI, sDAI
         * borrow wETH, wstETH
         */
        {
            // Approvals
            leafs[leafIndex] = ManageLeaf(
                address(USDC),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Aave V3 Pool to spend USDC",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = v3Pool;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(USDT),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Aave V3 Pool to spend USDT",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = v3Pool;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(DAI),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Aave V3 Pool to spend DAI",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = v3Pool;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(sDAI),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Aave V3 Pool to spend sDAI",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = v3Pool;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(WETH),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Aave V3 Pool to spend wETH",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = v3Pool;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(WSTETH),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Aave V3 Pool to spend wstETH",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = v3Pool;
            // Lending
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                v3Pool,
                false,
                "supply(address,uint256,address,uint16)",
                new address[](2),
                "Supply USDC to Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDC);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                v3Pool,
                false,
                "supply(address,uint256,address,uint16)",
                new address[](2),
                "Supply USDT to Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDT);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                v3Pool,
                false,
                "supply(address,uint256,address,uint16)",
                new address[](2),
                "Supply DAI to Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(DAI);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                v3Pool,
                false,
                "supply(address,uint256,address,uint16)",
                new address[](2),
                "Supply sDAI to Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(sDAI);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            // Withdrawing
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                v3Pool,
                false,
                "withdraw(address,uint256,address)",
                new address[](2),
                "Withdraw USDC from Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDC);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                v3Pool,
                false,
                "withdraw(address,uint256,address)",
                new address[](2),
                "Withdraw USDT from Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDT);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                v3Pool,
                false,
                "withdraw(address,uint256,address)",
                new address[](2),
                "Withdraw DAI from Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(DAI);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                v3Pool,
                false,
                "withdraw(address,uint256,address)",
                new address[](2),
                "Withdraw sDAI from Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(sDAI);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            // Borrowing
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                v3Pool,
                false,
                "borrow(address,uint256,uint256,uint16,address)",
                new address[](2),
                "Borrow wETH from Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(WETH);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                v3Pool,
                false,
                "borrow(address,uint256,uint256,uint16,address)",
                new address[](2),
                "Borrow wstETH from Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(WSTETH);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            // Repaying
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                v3Pool,
                false,
                "repay(address,uint256,uint256,address)",
                new address[](2),
                "Repay wETH to Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(WETH);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                v3Pool,
                false,
                "repay(address,uint256,uint256,address)",
                new address[](2),
                "Repay wstETH to Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(WSTETH);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            // Misc
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                v3Pool,
                false,
                "setUserUseReserveAsCollateral(address,bool)",
                new address[](1),
                "Toggle USDC as collateral in Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDC);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                v3Pool,
                false,
                "setUserUseReserveAsCollateral(address,bool)",
                new address[](1),
                "Toggle USDT as collateral in Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDT);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                v3Pool,
                false,
                "setUserUseReserveAsCollateral(address,bool)",
                new address[](1),
                "Toggle DAI as collateral in Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(DAI);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                v3Pool,
                false,
                "setUserUseReserveAsCollateral(address,bool)",
                new address[](1),
                "Toggle sDAI as collateral in Aave V3",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(sDAI);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
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
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(USDC),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve SparkLend Pool to spend USDC",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = sparkLendPool;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(USDT),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve SparkLend Pool to spend USDT",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = sparkLendPool;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(DAI),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve SparkLend Pool to spend DAI",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = sparkLendPool;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(sDAI),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve SparkLend Pool to spend sDAI",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = sparkLendPool;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(WETH),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve SparkLend Pool to spend wETH",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = sparkLendPool;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(WSTETH),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve SparkLend Pool to spend wstETH",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = sparkLendPool;
            // Lending
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                sparkLendPool,
                false,
                "supply(address,uint256,address,uint16)",
                new address[](2),
                "Supply USDC to SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDC);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                sparkLendPool,
                false,
                "supply(address,uint256,address,uint16)",
                new address[](2),
                "Supply USDT to SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDT);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                sparkLendPool,
                false,
                "supply(address,uint256,address,uint16)",
                new address[](2),
                "Supply DAI to SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(DAI);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                sparkLendPool,
                false,
                "supply(address,uint256,address,uint16)",
                new address[](2),
                "Supply sDAI to SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(sDAI);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            // Withdrawing
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                sparkLendPool,
                false,
                "withdraw(address,uint256,address)",
                new address[](2),
                "Withdraw USDC from SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDC);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                sparkLendPool,
                false,
                "withdraw(address,uint256,address)",
                new address[](2),
                "Withdraw USDT from SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDT);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                sparkLendPool,
                false,
                "withdraw(address,uint256,address)",
                new address[](2),
                "Withdraw DAI from SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(DAI);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                sparkLendPool,
                false,
                "withdraw(address,uint256,address)",
                new address[](2),
                "Withdraw sDAI from SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(sDAI);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            // Borrowing
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                sparkLendPool,
                false,
                "borrow(address,uint256,uint256,uint16,address)",
                new address[](2),
                "Borrow wETH from SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(WETH);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                sparkLendPool,
                false,
                "borrow(address,uint256,uint256,uint16,address)",
                new address[](2),
                "Borrow wstETH from SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(WSTETH);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            // Repaying
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                sparkLendPool,
                false,
                "repay(address,uint256,uint256,address)",
                new address[](2),
                "Repay wETH to SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(WETH);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                sparkLendPool,
                false,
                "repay(address,uint256,uint256,address)",
                new address[](2),
                "Repay wstETH to SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(WSTETH);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            // Misc
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                sparkLendPool,
                false,
                "setUserUseReserveAsCollateral(address,bool)",
                new address[](1),
                "Toggle USDC as collateral in SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDC);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                sparkLendPool,
                false,
                "setUserUseReserveAsCollateral(address,bool)",
                new address[](1),
                "Toggle USDT as collateral in SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDT);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                sparkLendPool,
                false,
                "setUserUseReserveAsCollateral(address,bool)",
                new address[](1),
                "Toggle DAI as collateral in SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(DAI);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                sparkLendPool,
                false,
                "setUserUseReserveAsCollateral(address,bool)",
                new address[](1),
                "Toggle sDAI as collateral in SparkLend",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(sDAI);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
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
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(STETH),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve WSTETH to spend stETH",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(WSTETH);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(STETH),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve unstETH to spend stETH",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = unstETH;
            // Staking
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(STETH),
                true,
                "submit(address)",
                new address[](1),
                "Stake ETH for stETH",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(0);
            // Unstaking
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                unstETH,
                false,
                "requestWithdrawals(uint256[],address)",
                new address[](1),
                "Request withdrawals from stETH",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                unstETH,
                false,
                "claimWithdrawal(uint256)",
                new address[](0),
                "Claim stETH withdrawal",
                rawDataDecoderAndSanitizer
            );
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                unstETH,
                false,
                "claimWithdrawals(uint256[],uint256[])",
                new address[](0),
                "Claim stETH withdrawals",
                rawDataDecoderAndSanitizer
            );
            // Wrapping
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(WSTETH), false, "wrap(uint256)", new address[](0), "Wrap stETH", rawDataDecoderAndSanitizer
            );
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(WSTETH), false, "unwrap(uint256)", new address[](0), "Unwrap wstETH", rawDataDecoderAndSanitizer
            );
        }

        // ========================== EtherFi ==========================
        /**
         * stake, unstake, wrap, unwrap
         */
        {
            // Approvals
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(EETH),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve WEETH to spend eETH",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(WEETH);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(EETH),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve EtherFi Liquidity Pool to spend eETH",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = EETH_LIQUIDITY_POOL;
            // Staking
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                EETH_LIQUIDITY_POOL,
                true,
                "deposit()",
                new address[](0),
                "Stake ETH for eETH",
                rawDataDecoderAndSanitizer
            );
            // Unstaking
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                EETH_LIQUIDITY_POOL,
                false,
                "requestWithdraw(address,uint256)",
                new address[](1),
                "Request withdrawal from eETH",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                withdrawalRequestNft,
                false,
                "claimWithdraw(uint256)",
                new address[](0),
                "Claim eETH withdrawal",
                rawDataDecoderAndSanitizer
            );
            // Wrapping
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(WEETH), false, "wrap(uint256)", new address[](0), "Wrap eETH", rawDataDecoderAndSanitizer
            );
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(WEETH), false, "unwrap(uint256)", new address[](0), "Unwrap weETH", rawDataDecoderAndSanitizer
            );
        }

        // ========================== Native ==========================
        /**
         * wrap, unwrap
         */
        {
            // Wrapping
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(WETH), true, "deposit()", new address[](0), "Wrap ETH for wETH", rawDataDecoderAndSanitizer
            );
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
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
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(DAI),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve sDAI to spend DAI",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(sDAI);
            // Depositing
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(sDAI),
                false,
                "deposit(uint256,address)",
                new address[](1),
                "Deposit DAI for sDAI",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            // Withdrawing
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(sDAI),
                false,
                "withdraw(uint256,address,address)",
                new address[](2),
                "Withdraw DAI from sDAI",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafs[leafIndex].argumentAddresses[1] = boringVault;
        }

        // ========================== Gearbox ==========================
        /**
         * USDC, DAI, USDT deposit, withdraw,  dUSDCV3, dDAIV3 dUSDTV3 deposit, withdraw, claim
         */
        {
            // Approvals
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(USDC),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve dUSDCV3 to spend USDC",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = dUSDCV3;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(DAI),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve dDAIV3 to spend DAI",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = dDAIV3;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(USDT),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve dUSDTV3 to spend USDT",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = dUSDTV3;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                dUSDCV3,
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve sdUSDCV3 to spend dUSDCV3",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = sdUSDCV3;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                dDAIV3,
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve sdDAIV3 to spend dDAIV3",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = sdDAIV3;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                dUSDTV3,
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve sdUSDTV3 to spend dUSDTV3",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = sdUSDTV3;
            // Depositing
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                dUSDCV3,
                false,
                "deposit(uint256,address)",
                new address[](1),
                "Deposit USDC for dUSDCV3",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                dDAIV3,
                false,
                "deposit(uint256,address)",
                new address[](1),
                "Deposit DAI for dDAIV3",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                dUSDTV3,
                false,
                "deposit(uint256,address)",
                new address[](1),
                "Deposit USDT for dUSDTV3",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                sdUSDCV3,
                false,
                "deposit(uint256)",
                new address[](0),
                "Deposit dUSDCV3 for sdUSDCV3",
                rawDataDecoderAndSanitizer
            );
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                sdDAIV3,
                false,
                "deposit(uint256)",
                new address[](0),
                "Deposit dDAIV3 for sdDAIV3",
                rawDataDecoderAndSanitizer
            );
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                sdUSDTV3,
                false,
                "deposit(uint256)",
                new address[](0),
                "Deposit dUSDTV3 for sdUSDTV3",
                rawDataDecoderAndSanitizer
            );
            // Withdrawing
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(sDAI),
                false,
                "withdraw(uint256,address,address)",
                new address[](2),
                "Withdraw DAI from sDAI",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                dUSDCV3,
                false,
                "withdraw(uint256,address,address)",
                new address[](2),
                "Withdraw USDC from dUSDCV3",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                dDAIV3,
                false,
                "withdraw(uint256,address,address)",
                new address[](2),
                "Withdraw DAI from dDAIV3",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                dUSDTV3,
                false,
                "withdraw(uint256,address,address)",
                new address[](2),
                "Withdraw USDT from dUSDTV3",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafs[leafIndex].argumentAddresses[1] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                sdUSDCV3,
                false,
                "withdraw(uint256)",
                new address[](0),
                "Withdraw dUSDCV3 from sdUSDCV3",
                rawDataDecoderAndSanitizer
            );
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                sdDAIV3,
                false,
                "withdraw(uint256)",
                new address[](0),
                "Withdraw dDAIV3 from sdDAIV3",
                rawDataDecoderAndSanitizer
            );
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                sdUSDTV3,
                false,
                "withdraw(uint256)",
                new address[](0),
                "Withdraw dUSDTV3 from sdUSDTV3",
                rawDataDecoderAndSanitizer
            );
            // Claiming
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                sdUSDCV3, false, "claim()", new address[](0), "Claim rewards from sdUSDCV3", rawDataDecoderAndSanitizer
            );
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                sdDAIV3, false, "claim()", new address[](0), "Claim rewards from sdDAIV3", rawDataDecoderAndSanitizer
            );
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
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
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(USDC),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve MorhoBlue to spend USDC",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = morphoBlue;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(DAI),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve MorhoBlue to spend DAI",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = morphoBlue;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(USDT),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve MorhoBlue to spend USDT",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = morphoBlue;
            // Supplying
            IMB.MarketParams memory marketParams;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xdc5333039bcf15f1237133f74d5806675d83d9cf19cfd4cfdd9be674842651bf);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply USDT to MorphoBlue sUSDe/USDT 91.50 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xcec858380cba2d9ca710fce3ce864d74c3f620d53826f69d08508902e09be86f);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply USDT to MorphoBlue USDe/USDT 91.50 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0x8e6aeb10c401de3279ac79b4b2ea15fc94b7d9cfc098d6c2a1ff7b2b26d9d02c);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply DAI to MorphoBlue USDe/DAI 91.50 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0x1247f1c237eceae0602eab1470a5061a6dd8f734ba88c7cdc5d6109fb0026b28);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply DAI to MorphoBlue sUSDe/DAI 91.50 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xdb760246f6859780f6c1b272d47a8f64710777121118e56e0cdb4b8b744a3094);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply DAI to MorphoBlue USDe/DAI 94.50 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xc581c5f70bd1afa283eed57d1418c6432cbff1d862f94eaf58fdd4e46afbb67f);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply DAI to MorphoBlue USDe/DAI 86.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xfd8493f09eb6203615221378d89f53fcd92ff4f7d62cca87eece9a2fff59e86f);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply DAI to MorphoBlue USDe/DAI 77.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0x7dde86a1e94561d9690ec678db673c1a6396365f7d1d65e129c5fff0990ff758);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply USDC to MorphoBlue wETH/USDC 86.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xf9acc677910cc17f650416a22e2a14d5da7ccb9626db18f1bf94efe64f92b372);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply USDC to MorphoBlue wETH/USDC 91.50 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0x42dcfb38bb98767afb6e38ccf90d59d0d3f0aa216beb3a234f12850323d17536);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply DAI to MorphoBlue sUSDe/DAI 77.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0x39d11026eae1c6ec02aa4c0910778664089cdd97c3fd23f68f7cd05e2e95af48);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply DAI to MorphoBlue sUSDe/DAI 86.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xe7e9694b754c4d4f7e21faf7223f6fa71abaeb10296a4c43a54a7977149687d2);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply USDT to MorphoBlue wstETH/USDT 86.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xb323495f7e4148be5643a4ea4a8221eef163e4bccfdedc2a6f4696baacbc86cc);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
                new address[](5),
                "Supply USDC to MorphoBlue wstETH/USDC 86.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            // Withdrawing
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xdc5333039bcf15f1237133f74d5806675d83d9cf19cfd4cfdd9be674842651bf);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw USDT from MorphoBlue sUSDe/USDT 91.50 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafs[leafIndex].argumentAddresses[5] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xcec858380cba2d9ca710fce3ce864d74c3f620d53826f69d08508902e09be86f);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw USDT from MorphoBlue USDe/USDT 91.50 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafs[leafIndex].argumentAddresses[5] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0x8e6aeb10c401de3279ac79b4b2ea15fc94b7d9cfc098d6c2a1ff7b2b26d9d02c);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw DAI from MorphoBlue USDe/DAI 91.50 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafs[leafIndex].argumentAddresses[5] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0x1247f1c237eceae0602eab1470a5061a6dd8f734ba88c7cdc5d6109fb0026b28);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw DAI from MorphoBlue sUSDe/DAI 91.50 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafs[leafIndex].argumentAddresses[5] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xdb760246f6859780f6c1b272d47a8f64710777121118e56e0cdb4b8b744a3094);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw DAI from MorphoBlue USDe/DAI 94.50 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafs[leafIndex].argumentAddresses[5] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xc581c5f70bd1afa283eed57d1418c6432cbff1d862f94eaf58fdd4e46afbb67f);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw DAI from MorphoBlue USDe/DAI 86.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafs[leafIndex].argumentAddresses[5] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xfd8493f09eb6203615221378d89f53fcd92ff4f7d62cca87eece9a2fff59e86f);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw DAI from MorphoBlue USDe/DAI 77.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafs[leafIndex].argumentAddresses[5] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0x7dde86a1e94561d9690ec678db673c1a6396365f7d1d65e129c5fff0990ff758);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw USDC from MorphoBlue wETH/USDC 86.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafs[leafIndex].argumentAddresses[5] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xf9acc677910cc17f650416a22e2a14d5da7ccb9626db18f1bf94efe64f92b372);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw USDC from MorphoBlue wETH/USDC 91.50 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafs[leafIndex].argumentAddresses[5] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0x42dcfb38bb98767afb6e38ccf90d59d0d3f0aa216beb3a234f12850323d17536);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw DAI from MorphoBlue sUSDe/DAI 77.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafs[leafIndex].argumentAddresses[5] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0x39d11026eae1c6ec02aa4c0910778664089cdd97c3fd23f68f7cd05e2e95af48);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw DAI from MorphoBlue sUSDe/DAI 86.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafs[leafIndex].argumentAddresses[5] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xe7e9694b754c4d4f7e21faf7223f6fa71abaeb10296a4c43a54a7977149687d2);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw USDT from MorphoBlue wstETH/USDT 86.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafs[leafIndex].argumentAddresses[5] = boringVault;
            marketParams =
                IMB(morphoBlue).idToMarketParams(0xb323495f7e4148be5643a4ea4a8221eef163e4bccfdedc2a6f4696baacbc86cc);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                morphoBlue,
                false,
                "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
                new address[](6),
                "Withdraw USDC from MorphoBlue wstETH/USDC 86.00 LLTV market",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
            leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
            leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
            leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafs[leafIndex].argumentAddresses[5] = boringVault;
        }

        // ========================== Pendle ==========================
        /**
         * USDe, sUSDe LP, SY, PT, YT
         * eETH LP, SY, PT, YT
         */
        {
            // Approvals
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(USDE),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Pendle router to spend USDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = pendleRouter;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(SUSDE),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Pendle router to spend sUSDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = pendleRouter;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                pendleUSDeSy,
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Pendle router to spend SY-USDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = pendleRouter;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                pendleSUSDeSy,
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Pendle router to spend SY-sUSDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = pendleRouter;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                pendleUSDePt,
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Pendle router to spend PT-USDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = pendleRouter;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                pendleSUSDePt,
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Pendle router to spend PT-sUSDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = pendleRouter;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                pendleUSDeYt,
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Pendle router to spend YT-USDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = pendleRouter;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                pendleSUSDeYt,
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Pendle router to spend YT-sUSDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = pendleRouter;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                pendleUSDeMarket,
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Pendle router to spend LP-USDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = pendleRouter;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                pendleSUSDeMarket,
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Pendle router to spend LP-sUSDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = pendleRouter;
            // Mint SY using Token
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                pendleRouter,
                false,
                "mintSyFromToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
                new address[](6),
                "Mint SY-USDe using USDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafs[leafIndex].argumentAddresses[1] = pendleUSDeSy;
            leafs[leafIndex].argumentAddresses[2] = address(USDE);
            leafs[leafIndex].argumentAddresses[3] = address(USDE);
            leafs[leafIndex].argumentAddresses[4] = address(0);
            leafs[leafIndex].argumentAddresses[5] = address(0);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                pendleRouter,
                false,
                "mintSyFromToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
                new address[](6),
                "Mint SY-sUSDe using USDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafs[leafIndex].argumentAddresses[1] = pendleSUSDeSy;
            leafs[leafIndex].argumentAddresses[2] = address(USDE);
            leafs[leafIndex].argumentAddresses[3] = address(USDE);
            leafs[leafIndex].argumentAddresses[4] = address(0);
            leafs[leafIndex].argumentAddresses[5] = address(0);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                pendleRouter,
                false,
                "mintSyFromToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
                new address[](6),
                "Mint SY-sUSDe using sUSDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafs[leafIndex].argumentAddresses[1] = pendleSUSDeSy;
            leafs[leafIndex].argumentAddresses[2] = address(SUSDE);
            leafs[leafIndex].argumentAddresses[3] = address(SUSDE);
            leafs[leafIndex].argumentAddresses[4] = address(0);
            leafs[leafIndex].argumentAddresses[5] = address(0);
            // Mint PT and YT using SY
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                pendleRouter,
                false,
                "mintPyFromSy(address,address,uint256,uint256)",
                new address[](2),
                "Mint PT-USDe and YT-USDe from SY-USDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafs[leafIndex].argumentAddresses[1] = pendleUSDeYt;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                pendleRouter,
                false,
                "mintPyFromSy(address,address,uint256,uint256)",
                new address[](2),
                "Mint PT-sUSDe and YT-sUSDe from SY-sUSDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafs[leafIndex].argumentAddresses[1] = pendleSUSDeYt;
            // Swap between PT and YT
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                pendleRouter,
                false,
                "swapExactYtForPt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
                new address[](2),
                "Swap YT-USDe for PT-USDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafs[leafIndex].argumentAddresses[1] = pendleUSDeMarket;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                pendleRouter,
                false,
                "swapExactPtForYt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
                new address[](2),
                "Swap PT-USDe for YT-USDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafs[leafIndex].argumentAddresses[1] = pendleUSDeMarket;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                pendleRouter,
                false,
                "swapExactYtForPt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
                new address[](2),
                "Swap YT-sUSDe for PT-sUSDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafs[leafIndex].argumentAddresses[1] = pendleSUSDeMarket;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                pendleRouter,
                false,
                "swapExactPtForYt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
                new address[](2),
                "Swap PT-sUSDe for YT-sUSDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafs[leafIndex].argumentAddresses[1] = pendleSUSDeMarket;
            // Manage Liquidity
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                pendleRouter,
                false,
                "addLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
                new address[](2),
                "Mint LP-USDe using SY-USDe and PT-USDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafs[leafIndex].argumentAddresses[1] = pendleUSDeMarket;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                pendleRouter,
                false,
                "removeLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
                new address[](2),
                "Burn LP-USDe for SY-USDe and PT-USDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafs[leafIndex].argumentAddresses[1] = pendleUSDeMarket;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                pendleRouter,
                false,
                "addLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
                new address[](2),
                "Mint LP-sUSDe using SY-sUSDe and PT-sUSDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafs[leafIndex].argumentAddresses[1] = pendleSUSDeMarket;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                pendleRouter,
                false,
                "removeLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
                new address[](2),
                "Burn LP-sUSDe for SY-sUSDe and PT-sUSDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafs[leafIndex].argumentAddresses[1] = pendleSUSDeMarket;
            // Burn PT and YT for SY
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                pendleRouter,
                false,
                "redeemPyToSy(address,address,uint256,uint256)",
                new address[](2),
                "Burn PT-USDe and YT-USDe for SY-USDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafs[leafIndex].argumentAddresses[1] = pendleUSDeYt;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                pendleRouter,
                false,
                "redeemPyToSy(address,address,uint256,uint256)",
                new address[](2),
                "Burn PT-sUSDe and YT-sUSDe for SY-sUSDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafs[leafIndex].argumentAddresses[1] = pendleSUSDeYt;
            // Burn SY for Token
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                pendleRouter,
                false,
                "redeemSyToToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
                new address[](6),
                "Burn SY-USDe for USDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(boringVault);
            leafs[leafIndex].argumentAddresses[1] = pendleUSDeSy;
            leafs[leafIndex].argumentAddresses[2] = address(USDE);
            leafs[leafIndex].argumentAddresses[3] = address(USDE);
            leafs[leafIndex].argumentAddresses[4] = address(0);
            leafs[leafIndex].argumentAddresses[5] = address(0);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                pendleRouter,
                false,
                "redeemSyToToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
                new address[](6),
                "Burn SY-sUSDe for sUSDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(boringVault);
            leafs[leafIndex].argumentAddresses[1] = pendleSUSDeSy;
            leafs[leafIndex].argumentAddresses[2] = address(SUSDE);
            leafs[leafIndex].argumentAddresses[3] = address(SUSDE);
            leafs[leafIndex].argumentAddresses[4] = address(0);
            leafs[leafIndex].argumentAddresses[5] = address(0);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                uniswapV3NonFungiblePositionManager,
                false,
                "redeemDueInterestAndRewards(address,address[],address[],address[])",
                new address[](4),
                "Redeem due interest and rewards for USDe Pendle.",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafs[leafIndex].argumentAddresses[1] = pendleUSDeSy;
            leafs[leafIndex].argumentAddresses[2] = pendleUSDeYt;
            leafs[leafIndex].argumentAddresses[3] = pendleUSDeMarket;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                uniswapV3NonFungiblePositionManager,
                false,
                "redeemDueInterestAndRewards(address,address[],address[],address[])",
                new address[](4),
                "Redeem due interest and rewards for sUSDe Pendle.",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafs[leafIndex].argumentAddresses[1] = pendleSUSDeSy;
            leafs[leafIndex].argumentAddresses[2] = pendleSUSDeYt;
            leafs[leafIndex].argumentAddresses[3] = pendleSUSDeMarket;

            // TODO add weETH pendle market
        }

        // ========================== Ethena ==========================
        /**
         * deposit, withdraw
         */
        {
            // Approvals
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(USDE),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve sUSDe to spend USDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(SUSDE);
            // Depositing
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(SUSDE),
                false,
                "deposit(uint256,address)",
                new address[](1),
                "Deposit USDe for sUSDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            // Withdrawing
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(SUSDE),
                false,
                "withdraw(uint256,address,address)",
                new address[](2),
                "Withdraw USDe from sUSDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = boringVault;
            leafs[leafIndex].argumentAddresses[1] = boringVault;
        }

        // ========================== 1inch ==========================
        /**
         * USDC <-> USDT,
         * USDC <-> DAI,
         * USDT <-> DAI,
         * GHO <-> USDC,
         * GHO <-> USDT,
         * GHO <-> DAI,
         * wETH -> USDC,
         * weETH -> USDC,
         * wstETH -> USDC,
         * wETH -> USDT,
         * weETH -> USDT,
         * wstETH -> USDT,
         * wETH -> DAI,
         * weETH -> DAI,
         * wstETH -> DAI,
         * wETH <-> wstETH,
         * weETH <-> wstETH,
         * weETH <-> wETH
         * Swap GEAR -> USDC
         */
        {
            // Approvals
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(USDC),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve 1inch router to spend USDC",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = aggregationRouterV5;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(USDT),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve 1inch router to spend USDT",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = aggregationRouterV5;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(DAI),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve 1inch router to spend DAI",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = aggregationRouterV5;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(GHO),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve 1inch router to spend GHO",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = aggregationRouterV5;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(WETH),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve 1inch router to spend wETH",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = aggregationRouterV5;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(WEETH),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve 1inch router to spend weETH",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = aggregationRouterV5;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(WSTETH),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve 1inch router to spend wstETH",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = aggregationRouterV5;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(GEAR),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve 1inch router to spend GEAR",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = aggregationRouterV5;
            // Swapping
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                aggregationRouterV5,
                false,
                "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                new address[](5),
                "Swap USDC for USDT using 1inch router",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[1] = address(USDC);
            leafs[leafIndex].argumentAddresses[2] = address(USDT);
            leafs[leafIndex].argumentAddresses[3] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                aggregationRouterV5,
                false,
                "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                new address[](5),
                "Swap USDC for DAI using 1inch router",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[1] = address(USDC);
            leafs[leafIndex].argumentAddresses[2] = address(DAI);
            leafs[leafIndex].argumentAddresses[3] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                aggregationRouterV5,
                false,
                "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                new address[](5),
                "Swap USDT for DAI using 1inch router",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[1] = address(USDT);
            leafs[leafIndex].argumentAddresses[2] = address(DAI);
            leafs[leafIndex].argumentAddresses[3] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                aggregationRouterV5,
                false,
                "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                new address[](5),
                "Swap GHO for USDC using 1inch router",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[1] = address(GHO);
            leafs[leafIndex].argumentAddresses[2] = address(USDC);
            leafs[leafIndex].argumentAddresses[3] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                aggregationRouterV5,
                false,
                "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                new address[](5),
                "Swap GHO for USDT using 1inch router",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[1] = address(GHO);
            leafs[leafIndex].argumentAddresses[2] = address(USDT);
            leafs[leafIndex].argumentAddresses[3] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                aggregationRouterV5,
                false,
                "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                new address[](5),
                "Swap GHO for DAI using 1inch router",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[1] = address(GHO);
            leafs[leafIndex].argumentAddresses[2] = address(DAI);
            leafs[leafIndex].argumentAddresses[3] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                aggregationRouterV5,
                false,
                "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                new address[](5),
                "Swap wETH for USDC using 1inch router",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[1] = address(WETH);
            leafs[leafIndex].argumentAddresses[2] = address(USDC);
            leafs[leafIndex].argumentAddresses[3] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                aggregationRouterV5,
                false,
                "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                new address[](5),
                "Swap weETH for USDC using 1inch router",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[1] = address(WEETH);
            leafs[leafIndex].argumentAddresses[2] = address(USDC);
            leafs[leafIndex].argumentAddresses[3] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                aggregationRouterV5,
                false,
                "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                new address[](5),
                "Swap wstETH for USDC using 1inch router",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[1] = address(WSTETH);
            leafs[leafIndex].argumentAddresses[2] = address(USDC);
            leafs[leafIndex].argumentAddresses[3] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                aggregationRouterV5,
                false,
                "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                new address[](5),
                "Swap USDT for USDC using 1inch router",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[1] = address(USDT);
            leafs[leafIndex].argumentAddresses[2] = address(USDC);
            leafs[leafIndex].argumentAddresses[3] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                aggregationRouterV5,
                false,
                "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                new address[](5),
                "Swap DAI for USDC using 1inch router",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[1] = address(DAI);
            leafs[leafIndex].argumentAddresses[2] = address(USDC);
            leafs[leafIndex].argumentAddresses[3] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                aggregationRouterV5,
                false,
                "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                new address[](5),
                "Swap wETH for weETH using 1inch router",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[1] = address(WETH);
            leafs[leafIndex].argumentAddresses[2] = address(WEETH);
            leafs[leafIndex].argumentAddresses[3] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                aggregationRouterV5,
                false,
                "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                new address[](5),
                "Swap wETH for wstETH using 1inch router",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[1] = address(WETH);
            leafs[leafIndex].argumentAddresses[2] = address(WSTETH);
            leafs[leafIndex].argumentAddresses[3] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                aggregationRouterV5,
                false,
                "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                new address[](5),
                "Swap weETH for wstETH using 1inch router",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[1] = address(WEETH);
            leafs[leafIndex].argumentAddresses[2] = address(WSTETH);
            leafs[leafIndex].argumentAddresses[3] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                aggregationRouterV5,
                false,
                "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                new address[](5),
                "Swap GEAR for USDC using 1inch router",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[1] = address(GEAR);
            leafs[leafIndex].argumentAddresses[2] = address(USDC);
            leafs[leafIndex].argumentAddresses[3] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                aggregationRouterV5,
                false,
                "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                new address[](5),
                "Swap wstETH for wETH using 1inch router",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[1] = address(WSTETH);
            leafs[leafIndex].argumentAddresses[2] = address(WETH);
            leafs[leafIndex].argumentAddresses[3] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[4] = boringVault;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                aggregationRouterV5,
                false,
                "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                new address[](5),
                "Swap weETH for wstETH using 1inch router",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[1] = address(WEETH);
            leafs[leafIndex].argumentAddresses[2] = address(WSTETH);
            leafs[leafIndex].argumentAddresses[3] = oneInchExecutor;
            leafs[leafIndex].argumentAddresses[4] = boringVault;

            // TODO swapping using the other function for valid uniswap V3 pools
        }

        // TODO curve swapping for USDe and sUSDe
        // TODO uniswapV3 swapping for USDe
        // TODO 1inch swapping for USDe

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/LiquidUsdStrategistLeafs.json";

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