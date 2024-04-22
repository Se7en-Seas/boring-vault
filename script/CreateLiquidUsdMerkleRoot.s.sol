// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
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

    address public itbAaveV3Usdc = address(65);
    address public itbAaveV3Dai = address(65);
    address public itbAaveV3Usdt = address(65);
    address public itbGearboxUsdc = address(65);
    address public itbGearboxDai = address(65);
    address public itbGearboxUsdt = address(65);
    address public itbCurveConvex_PyUsdUsdc = address(65);
    address public itbCurve_sDai_sUsde = address(65);
    address public itbCurveConvex_FraxUsdc = address(65);
    address public itbCurveConvex_UsdcCrvUsd = address(65);
    address public itbDecoderAndSanitizer = address(65);

    uint256 leafIndex = 0;

    mapping(address => mapping(address => bool)) public tokenToSpenderToApprovalInTree;
    mapping(address => mapping(address => bool)) public oneInchSellTokenToBuyTokenToInTree;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateLiquidUsdStrategistMerkleRoot();
    }

    function _addLidoLeafs(ManageLeaf[] memory leafs) internal {
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
            address(STETH), true, "submit(address)", new address[](1), "Stake ETH for stETH", rawDataDecoderAndSanitizer
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

    function _addEtherFiLeafs(ManageLeaf[] memory leafs) internal {
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
            EETH_LIQUIDITY_POOL, true, "deposit()", new address[](0), "Stake ETH for eETH", rawDataDecoderAndSanitizer
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

    function _addAaveV3Leafs(ManageLeaf[] memory leafs, ERC20[] memory supplyAssets, ERC20[] memory borrowAssets)
        internal
    {
        _addAaveV3ForkLeafs("Aave V3", v3Pool, leafs, supplyAssets, borrowAssets);
    }

    function _addSparkLendLeafs(ManageLeaf[] memory leafs, ERC20[] memory supplyAssets, ERC20[] memory borrowAssets)
        internal
    {
        _addAaveV3ForkLeafs("SparkLend", sparkLendPool, leafs, supplyAssets, borrowAssets);
    }

    function _addNativeLeafs(ManageLeaf[] memory leafs) internal {
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

    function _addAaveV3ForkLeafs(
        string memory protocolName,
        address protocolAddress,
        ManageLeaf[] memory leafs,
        ERC20[] memory supplyAssets,
        ERC20[] memory borrowAssets
    ) internal {
        // Approvals
        string memory baseApprovalString = string.concat("Approve ", protocolName, " Pool to spend ");
        for (uint256 i; i < supplyAssets.length; ++i) {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(supplyAssets[i]),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat(baseApprovalString, supplyAssets[i].symbol()),
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = protocolAddress;
        }
        for (uint256 i; i < borrowAssets.length; ++i) {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(borrowAssets[i]),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat(baseApprovalString, borrowAssets[i].symbol()),
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = protocolAddress;
        }
        // Lending
        for (uint256 i; i < supplyAssets.length; ++i) {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                protocolAddress,
                false,
                "supply(address,uint256,address,uint16)",
                new address[](2),
                string.concat("Supply ", supplyAssets[i].symbol(), " to ", protocolName),
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(supplyAssets[i]);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
        }
        // Withdrawing
        for (uint256 i; i < supplyAssets.length; ++i) {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                protocolAddress,
                false,
                "withdraw(address,uint256,address)",
                new address[](2),
                string.concat("Withdraw ", supplyAssets[i].symbol(), " from ", protocolName),
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(supplyAssets[i]);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
        }
        // Borrowing
        for (uint256 i; i < borrowAssets.length; ++i) {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                protocolAddress,
                false,
                "borrow(address,uint256,uint256,uint16,address)",
                new address[](2),
                string.concat("Borrow ", borrowAssets[i].symbol(), " from ", protocolName),
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(borrowAssets[i]);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
        }
        // Repaying
        for (uint256 i; i < borrowAssets.length; ++i) {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                protocolAddress,
                false,
                "repay(address,uint256,uint256,address)",
                new address[](2),
                string.concat("Repay ", borrowAssets[i].symbol(), " to ", protocolName),
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(borrowAssets[i]);
            leafs[leafIndex].argumentAddresses[1] = boringVault;
        }
        // Misc
        for (uint256 i; i < supplyAssets.length; ++i) {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                protocolAddress,
                false,
                "setUserUseReserveAsCollateral(address,bool)",
                new address[](1),
                string.concat("Toggle ", supplyAssets[i].symbol(), " as collateral in ", protocolName),
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(supplyAssets[i]);
        }
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            protocolAddress,
            false,
            "setUserEMode(uint8)",
            new address[](0),
            string.concat("Set user e-mode in ", protocolName),
            rawDataDecoderAndSanitizer
        );
    }

    function _addERC4626Leafs(ManageLeaf[] memory leafs, ERC4626 vault) internal {
        ERC20 asset = vault.asset();
        // Approvals
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            address(asset),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve ", vault.symbol(), " to spend ", asset.symbol()),
            rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = address(vault);
        // Depositing
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            address(vault),
            false,
            "deposit(uint256,address)",
            new address[](1),
            string.concat("Deposit ", asset.symbol(), " for ", vault.symbol()),
            rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = boringVault;
        // Withdrawing
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            address(vault),
            false,
            "withdraw(uint256,address,address)",
            new address[](2),
            string.concat("Withdraw ", asset.symbol(), " from ", vault.symbol()),
            rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = boringVault;
        leafs[leafIndex].argumentAddresses[1] = boringVault;
    }

    function _addGearboxLeafs(ManageLeaf[] memory leafs, ERC4626 dieselVault, address dieselStaking) internal {
        _addERC4626Leafs(leafs, dieselVault);
        string memory dieselVaultSymbol = dieselVault.symbol();
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            address(dieselVault),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve s", dieselVaultSymbol, " to spend ", dieselVaultSymbol),
            rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = dieselStaking;
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            dieselStaking,
            false,
            "deposit(uint256)",
            new address[](0),
            string.concat("Deposit ", dieselVaultSymbol, " for s", dieselVaultSymbol),
            rawDataDecoderAndSanitizer
        );
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            dieselStaking,
            false,
            "withdraw(uint256)",
            new address[](0),
            string.concat("Withdraw ", dieselVaultSymbol, " from s", dieselVaultSymbol),
            rawDataDecoderAndSanitizer
        );
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            dieselStaking,
            false,
            "claim()",
            new address[](0),
            string.concat("Claim rewards from s", dieselVaultSymbol),
            rawDataDecoderAndSanitizer
        );
    }

    function _addMorphoBlueSupplyLeafs(ManageLeaf[] memory leafs, bytes32 marketId) internal {
        IMB.MarketParams memory marketParams = IMB(morphoBlue).idToMarketParams(marketId);
        ERC20 loanToken = ERC20(marketParams.loanToken);
        ERC20 collateralToken = ERC20(marketParams.collateralToken);
        uint256 leftSideLLTV = marketParams.lltv / 1e16;
        uint256 rightSideLLTV = (marketParams.lltv / 1e14) % 100;
        string memory morphoBlueMarketName = string.concat(
            "MorphoBlue ",
            collateralToken.symbol(),
            "/",
            loanToken.symbol(),
            " ",
            vm.toString(leftSideLLTV),
            ".",
            vm.toString(rightSideLLTV),
            " LLTV market"
        );
        // Add approval leaf if not already added
        if (!tokenToSpenderToApprovalInTree[marketParams.loanToken][morphoBlue]) {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                marketParams.loanToken,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve MorhoBlue to spend ", loanToken.symbol()),
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = morphoBlue;
            tokenToSpenderToApprovalInTree[marketParams.loanToken][morphoBlue] = true;
        }
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            morphoBlue,
            false,
            "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            new address[](5),
            string.concat("Supply ", loanToken.symbol(), " to ", morphoBlueMarketName),
            rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
        leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
        leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
        leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
        leafs[leafIndex].argumentAddresses[4] = boringVault;
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            morphoBlue,
            false,
            "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
            new address[](6),
            string.concat("Withdraw ", loanToken.symbol(), " from ", morphoBlueMarketName),
            rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
        leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
        leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
        leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
        leafs[leafIndex].argumentAddresses[4] = boringVault;
        leafs[leafIndex].argumentAddresses[5] = boringVault;
    }

    function _addPendleMarketLeafs(ManageLeaf[] memory leafs, address marketAddress) internal {
        PendleMarket market = PendleMarket(marketAddress);
        (address sy, address pt, address yt) = market.readTokens();
        PendleSy SY = PendleSy(sy);
        address[] memory possibleTokensIn = SY.getTokensIn();
        address[] memory possibleTokensOut = SY.getTokensOut();
        (, ERC20 underlyingAsset,) = SY.assetInfo();
        // Approve router to spend all tokens in, skipping zero addresses.
        for (uint256 i; i < possibleTokensIn.length; ++i) {
            if (possibleTokensIn[i] != address(0) && !tokenToSpenderToApprovalInTree[possibleTokensIn[i]][pendleRouter])
            {
                ERC20 tokenIn = ERC20(possibleTokensIn[i]);
                leafIndex++;
                leafs[leafIndex] = ManageLeaf(
                    possibleTokensIn[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Pendle router to spend ", tokenIn.symbol()),
                    rawDataDecoderAndSanitizer
                );
                leafs[leafIndex].argumentAddresses[0] = pendleRouter;
                tokenToSpenderToApprovalInTree[possibleTokensIn[i]][pendleRouter] = true;
            }
        }
        // Approve router to spend LP, SY, PT, YT
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            marketAddress,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Pendle router to spend LP-", underlyingAsset.symbol()),
            rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = pendleRouter;
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            sy,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Pendle router to spend ", ERC20(sy).symbol()),
            rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = pendleRouter;
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            pt,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Pendle router to spend ", ERC20(pt).symbol()),
            rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = pendleRouter;
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            yt,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Pendle router to spend ", ERC20(yt).symbol()),
            rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = pendleRouter;
        // Mint SY using input token.
        for (uint256 i; i < possibleTokensIn.length; ++i) {
            if (possibleTokensIn[i] != address(0)) {
                leafIndex++;
                leafs[leafIndex] = ManageLeaf(
                    pendleRouter,
                    false,
                    "mintSyFromToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
                    new address[](6),
                    string.concat("Mint ", ERC20(sy).symbol(), " using ", ERC20(possibleTokensIn[i]).symbol()),
                    rawDataDecoderAndSanitizer
                );
                leafs[leafIndex].argumentAddresses[0] = boringVault;
                leafs[leafIndex].argumentAddresses[1] = sy;
                leafs[leafIndex].argumentAddresses[2] = possibleTokensIn[i];
                leafs[leafIndex].argumentAddresses[3] = possibleTokensIn[i];
                leafs[leafIndex].argumentAddresses[4] = address(0);
                leafs[leafIndex].argumentAddresses[5] = address(0);
            }
        }
        // Mint PT and YT using SY.
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            pendleRouter,
            false,
            "mintPyFromSy(address,address,uint256,uint256)",
            new address[](2),
            string.concat("Mint ", ERC20(pt).symbol(), " and ", ERC20(yt).symbol(), " from ", ERC20(sy).symbol()),
            rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = boringVault;
        leafs[leafIndex].argumentAddresses[1] = yt;
        // Swap between PT and YT.
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            pendleRouter,
            false,
            "swapExactYtForPt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            new address[](2),
            string.concat("Swap ", ERC20(yt).symbol(), " for ", ERC20(pt).symbol()),
            rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = boringVault;
        leafs[leafIndex].argumentAddresses[1] = marketAddress;
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            pendleRouter,
            false,
            "swapExactPtForYt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            new address[](2),
            string.concat("Swap ", ERC20(pt).symbol(), " for ", ERC20(yt).symbol()),
            rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = boringVault;
        leafs[leafIndex].argumentAddresses[1] = marketAddress;
        // Manage Liquidity.
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            pendleRouter,
            false,
            "addLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
            new address[](2),
            string.concat(
                "Mint LP-", underlyingAsset.symbol(), " using ", ERC20(sy).symbol(), " and ", ERC20(pt).symbol()
            ),
            rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = boringVault;
        leafs[leafIndex].argumentAddresses[1] = marketAddress;
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            pendleRouter,
            false,
            "removeLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
            new address[](2),
            string.concat(
                "Burn LP-", underlyingAsset.symbol(), " for ", ERC20(sy).symbol(), " and ", ERC20(pt).symbol()
            ),
            rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = boringVault;
        leafs[leafIndex].argumentAddresses[1] = marketAddress;
        // Burn PT and YT for SY.
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            pendleRouter,
            false,
            "redeemPyToSy(address,address,uint256,uint256)",
            new address[](2),
            string.concat("Burn ", ERC20(pt).symbol(), " and ", ERC20(yt).symbol(), " for ", ERC20(sy).symbol()),
            rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = boringVault;
        leafs[leafIndex].argumentAddresses[1] = yt;
        // Redeem SY for output token.
        for (uint256 i; i < possibleTokensOut.length; ++i) {
            if (possibleTokensOut[i] != address(0)) {
                leafIndex++;
                leafs[leafIndex] = ManageLeaf(
                    pendleRouter,
                    false,
                    "redeemSyToToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
                    new address[](6),
                    string.concat("Burn ", ERC20(sy).symbol(), " for ", ERC20(possibleTokensOut[i]).symbol()),
                    rawDataDecoderAndSanitizer
                );
                leafs[leafIndex].argumentAddresses[0] = address(boringVault);
                leafs[leafIndex].argumentAddresses[1] = sy;
                leafs[leafIndex].argumentAddresses[2] = possibleTokensOut[i];
                leafs[leafIndex].argumentAddresses[3] = possibleTokensOut[i];
                leafs[leafIndex].argumentAddresses[4] = address(0);
                leafs[leafIndex].argumentAddresses[5] = address(0);
            }
        }
        // Harvest rewards.
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            pendleRouter,
            false,
            "redeemDueInterestAndRewards(address,address[],address[],address[])",
            new address[](4),
            string.concat("Redeem due interest and rewards for ", underlyingAsset.symbol(), " Pendle"),
            rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = boringVault;
        leafs[leafIndex].argumentAddresses[1] = sy;
        leafs[leafIndex].argumentAddresses[2] = yt;
        leafs[leafIndex].argumentAddresses[3] = marketAddress;
    }

    function _addUniswapV3Leafs(ManageLeaf[] memory leafs, address[] memory token0, address[] memory token1) internal {
        require(token0.length == token1.length, "Token arrays must be of equal length");
        for (uint256 i; i < token0.length; ++i) {
            (token0[i], token1[i]) = token0[i] < token1[i] ? (token0[i], token1[i]) : (token1[i], token0[i]);
            // Approvals
            if (!tokenToSpenderToApprovalInTree[token0[i]][uniswapV3NonFungiblePositionManager]) {
                leafIndex++;
                leafs[leafIndex] = ManageLeaf(
                    token0[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve UniswapV3 NonFungible Position Manager to spend ", ERC20(token0[i]).symbol()),
                    rawDataDecoderAndSanitizer
                );
                leafs[leafIndex].argumentAddresses[0] = uniswapV3NonFungiblePositionManager;
                tokenToSpenderToApprovalInTree[token0[i]][uniswapV3NonFungiblePositionManager] = true;
            }
            if (!tokenToSpenderToApprovalInTree[token1[i]][uniswapV3NonFungiblePositionManager]) {
                leafIndex++;
                leafs[leafIndex] = ManageLeaf(
                    token1[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve UniswapV3 NonFungible Position Manager to spend ", ERC20(token1[i]).symbol()),
                    rawDataDecoderAndSanitizer
                );
                leafs[leafIndex].argumentAddresses[0] = uniswapV3NonFungiblePositionManager;
                tokenToSpenderToApprovalInTree[token1[i]][uniswapV3NonFungiblePositionManager] = true;
            }

            // Minting
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                uniswapV3NonFungiblePositionManager,
                false,
                "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
                new address[](3),
                string.concat("Mint UniswapV3 ", ERC20(token0[i]).symbol(), " ", ERC20(token1[i]).symbol(), " position"),
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = boringVault;
            // Increase liquidity
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                uniswapV3NonFungiblePositionManager,
                false,
                "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
                new address[](3),
                string.concat(
                    "Add liquidity to UniswapV3 ",
                    ERC20(token0[i]).symbol(),
                    " ",
                    ERC20(token1[i]).symbol(),
                    " position"
                ),
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(0);
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = token1[i];

            // Swapping to move tick in pool.
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                uniV3Router,
                false,
                "exactInput((bytes,address,uint256,uint256,uint256))",
                new address[](3),
                string.concat(
                    "Swap ", ERC20(token0[i]).symbol(), " for ", ERC20(token1[i]).symbol(), " using UniswapV3 router"
                ),
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = address(boringVault);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                uniV3Router,
                false,
                "exactInput((bytes,address,uint256,uint256,uint256))",
                new address[](3),
                string.concat(
                    "Swap ", ERC20(token1[i]).symbol(), " for ", ERC20(token0[i]).symbol(), " using UniswapV3 router"
                ),
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = token1[i];
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = address(boringVault);
        }
        // Decrease liquidity
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            new address[](0),
            "Remove liquidity from UniswapV3 position",
            rawDataDecoderAndSanitizer
        );
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "collect((uint256,address,uint128,uint128))",
            new address[](1),
            "Collect fees from UniswapV3 position",
            rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = boringVault;
    }

    function _addLeafsForFeeClaiming(ManageLeaf[] memory leafs, ERC20[] memory feeAssets) internal {
        // Approvals.
        for (uint256 i; i < feeAssets.length; ++i) {
            if (!tokenToSpenderToApprovalInTree[address(feeAssets[i])][accountantAddress]) {
                leafIndex++;
                leafs[leafIndex] = ManageLeaf(
                    address(feeAssets[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Accountant to spend ", feeAssets[i].symbol()),
                    rawDataDecoderAndSanitizer
                );
                leafs[leafIndex].argumentAddresses[0] = accountantAddress;
                tokenToSpenderToApprovalInTree[address(feeAssets[i])][accountantAddress] = true;
            }
        }
        // Claiming fees.
        for (uint256 i; i < feeAssets.length; ++i) {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                accountantAddress,
                false,
                "claimFees(address)",
                new address[](1),
                string.concat("Claim fees in ", feeAssets[i].symbol()),
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(feeAssets[i]);
        }
    }

    enum SwapKind {
        BuyAndSell,
        Sell
    }

    function _addLeafsFor1InchGeneralSwapping(
        ManageLeaf[] memory leafs,
        address[] memory assets,
        SwapKind[] memory kind
    ) internal {
        require(assets.length == kind.length, "Arrays must be of equal length");
        for (uint256 i; i < assets.length; ++i) {
            // Add approval leaf if not already added
            if (!tokenToSpenderToApprovalInTree[assets[i]][aggregationRouterV5]) {
                leafIndex++;
                leafs[leafIndex] = ManageLeaf(
                    assets[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve 1Inch router to spend ", ERC20(assets[i]).symbol()),
                    rawDataDecoderAndSanitizer
                );
                leafs[leafIndex].argumentAddresses[0] = aggregationRouterV5;
                tokenToSpenderToApprovalInTree[assets[i]][aggregationRouterV5] = true;
            }
            // Iterate through the list again.
            for (uint256 j; j < assets.length; ++j) {
                // Skip if we are on the same index
                if (i == j) {
                    continue;
                }
                if (!oneInchSellTokenToBuyTokenToInTree[assets[i]][assets[j]] && kind[j] != SwapKind.Sell) {
                    // Add sell swap.
                    leafIndex++;
                    leafs[leafIndex] = ManageLeaf(
                        aggregationRouterV5,
                        false,
                        "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                        new address[](5),
                        string.concat(
                            "Swap ",
                            ERC20(assets[i]).symbol(),
                            " for ",
                            ERC20(assets[j]).symbol(),
                            " using 1inch router"
                        ),
                        rawDataDecoderAndSanitizer
                    );
                    leafs[leafIndex].argumentAddresses[0] = oneInchExecutor;
                    leafs[leafIndex].argumentAddresses[1] = assets[i];
                    leafs[leafIndex].argumentAddresses[2] = assets[j];
                    leafs[leafIndex].argumentAddresses[3] = oneInchExecutor;
                    leafs[leafIndex].argumentAddresses[4] = boringVault;
                    oneInchSellTokenToBuyTokenToInTree[assets[i]][assets[j]] = true;
                }

                if (kind[i] == SwapKind.BuyAndSell && !oneInchSellTokenToBuyTokenToInTree[assets[j]][assets[i]]) {
                    // Add buy swap.
                    leafIndex++;
                    leafs[leafIndex] = ManageLeaf(
                        aggregationRouterV5,
                        false,
                        "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
                        new address[](5),
                        string.concat(
                            "Swap ",
                            ERC20(assets[j]).symbol(),
                            " for ",
                            ERC20(assets[i]).symbol(),
                            " using 1inch router"
                        ),
                        rawDataDecoderAndSanitizer
                    );
                    leafs[leafIndex].argumentAddresses[0] = oneInchExecutor;
                    leafs[leafIndex].argumentAddresses[1] = assets[j];
                    leafs[leafIndex].argumentAddresses[2] = assets[i];
                    leafs[leafIndex].argumentAddresses[3] = oneInchExecutor;
                    leafs[leafIndex].argumentAddresses[4] = boringVault;
                    oneInchSellTokenToBuyTokenToInTree[assets[j]][assets[i]] = true;
                }
            }
        }
    }

    function _addLeafsFor1InchUniswapV3Swapping(ManageLeaf[] memory leafs, address pool) internal {
        UniswapV3Pool uniswapV3Pool = UniswapV3Pool(pool);
        address token0 = uniswapV3Pool.token0();
        address token1 = uniswapV3Pool.token1();
        // Add approval leaf if not already added
        if (!tokenToSpenderToApprovalInTree[token0][aggregationRouterV5]) {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                token0,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve 1Inch router to spend ", ERC20(token0).symbol()),
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = aggregationRouterV5;
            tokenToSpenderToApprovalInTree[token0][aggregationRouterV5] = true;
        }
        if (!tokenToSpenderToApprovalInTree[token1][aggregationRouterV5]) {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                token1,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve 1Inch router to spend ", ERC20(token1).symbol()),
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = aggregationRouterV5;
            tokenToSpenderToApprovalInTree[token1][aggregationRouterV5] = true;
        }
        uint256 feeInBps = uniswapV3Pool.fee() / 100;
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            aggregationRouterV5,
            false,
            "uniswapV3Swap(uint256,uint256,uint256[])",
            new address[](1),
            string.concat(
                "Swap between ",
                ERC20(token0).symbol(),
                " and ",
                ERC20(token1).symbol(),
                " with ",
                vm.toString(feeInBps),
                " bps fee on UniswapV3 using 1inch router"
            ),
            rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = pool;
    }

    function generateLiquidUsdStrategistMerkleRoot() public {
        ManageLeaf[] memory leafs = new ManageLeaf[](1024);

        // ========================== Aave V3 ==========================
        /**
         * lend USDC, USDT, DAI, sDAI
         * borrow wETH, wstETH
         */
        ERC20[] memory supplyAssets = new ERC20[](4);
        supplyAssets[0] = USDC;
        supplyAssets[1] = USDT;
        supplyAssets[2] = DAI;
        supplyAssets[3] = ERC20(sDAI);
        ERC20[] memory borrowAssets = new ERC20[](2);
        borrowAssets[0] = WETH;
        borrowAssets[1] = WSTETH;
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== SparkLend ==========================
        /**
         * lend USDC, USDT, DAI, sDAI
         * borrow wETH, wstETH
         */
        _addSparkLendLeafs(leafs, supplyAssets, borrowAssets);

        // ========================== Lido ==========================
        _addLidoLeafs(leafs);

        // ========================== EtherFi ==========================
        /**
         * stake, unstake, wrap, unwrap
         */
        _addEtherFiLeafs(leafs);

        // ========================== Native ==========================
        /**
         * wrap, unwrap
         */
        _addNativeLeafs(leafs);

        // ========================== MakerDAO ==========================
        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(sDAI));

        // ========================== Gearbox ==========================
        /**
         * USDC, DAI, USDT deposit, withdraw,  dUSDCV3, dDAIV3 dUSDTV3 deposit, withdraw, claim
         */
        _addGearboxLeafs(leafs, ERC4626(dUSDCV3), sdUSDCV3);
        _addGearboxLeafs(leafs, ERC4626(dDAIV3), sdDAIV3);
        _addGearboxLeafs(leafs, ERC4626(dUSDTV3), sdUSDTV3);

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
        _addMorphoBlueSupplyLeafs(leafs, 0xdc5333039bcf15f1237133f74d5806675d83d9cf19cfd4cfdd9be674842651bf);
        _addMorphoBlueSupplyLeafs(leafs, 0xcec858380cba2d9ca710fce3ce864d74c3f620d53826f69d08508902e09be86f);
        _addMorphoBlueSupplyLeafs(leafs, 0x8e6aeb10c401de3279ac79b4b2ea15fc94b7d9cfc098d6c2a1ff7b2b26d9d02c);
        _addMorphoBlueSupplyLeafs(leafs, 0x1247f1c237eceae0602eab1470a5061a6dd8f734ba88c7cdc5d6109fb0026b28);
        _addMorphoBlueSupplyLeafs(leafs, 0xdb760246f6859780f6c1b272d47a8f64710777121118e56e0cdb4b8b744a3094);
        _addMorphoBlueSupplyLeafs(leafs, 0xc581c5f70bd1afa283eed57d1418c6432cbff1d862f94eaf58fdd4e46afbb67f);
        _addMorphoBlueSupplyLeafs(leafs, 0xfd8493f09eb6203615221378d89f53fcd92ff4f7d62cca87eece9a2fff59e86f);
        _addMorphoBlueSupplyLeafs(leafs, 0x7dde86a1e94561d9690ec678db673c1a6396365f7d1d65e129c5fff0990ff758);
        _addMorphoBlueSupplyLeafs(leafs, 0xf9acc677910cc17f650416a22e2a14d5da7ccb9626db18f1bf94efe64f92b372);
        _addMorphoBlueSupplyLeafs(leafs, 0x42dcfb38bb98767afb6e38ccf90d59d0d3f0aa216beb3a234f12850323d17536);
        _addMorphoBlueSupplyLeafs(leafs, 0x39d11026eae1c6ec02aa4c0910778664089cdd97c3fd23f68f7cd05e2e95af48);
        _addMorphoBlueSupplyLeafs(leafs, 0xe7e9694b754c4d4f7e21faf7223f6fa71abaeb10296a4c43a54a7977149687d2);
        _addMorphoBlueSupplyLeafs(leafs, 0xb323495f7e4148be5643a4ea4a8221eef163e4bccfdedc2a6f4696baacbc86cc);

        // ========================== Pendle ==========================
        /**
         * USDe, sUSDe LP, SY, PT, YT
         * eETH LP, SY, PT, YT
         */
        _addPendleMarketLeafs(leafs, pendleWeETHMarket);
        _addPendleMarketLeafs(leafs, pendleUSDeMarket);
        _addPendleMarketLeafs(leafs, pendleZircuitUSDeMarket);

        // ========================== Ethena ==========================
        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(address(SUSDE)));

        // ========================== UniswapV3 ==========================
        /**
         * Full position management for USDC, USDT, DAI, USDe, sUSDe.
         */
        address[] memory token0 = new address[](10);
        token0[0] = address(USDC);
        token0[1] = address(USDC);
        token0[2] = address(USDC);
        token0[3] = address(USDC);
        token0[4] = address(USDT);
        token0[5] = address(USDT);
        token0[6] = address(USDT);
        token0[7] = address(DAI);
        token0[8] = address(DAI);
        token0[9] = address(USDE);

        address[] memory token1 = new address[](10);
        token1[0] = address(USDT);
        token1[1] = address(DAI);
        token1[2] = address(USDE);
        token1[3] = address(SUSDE);
        token1[4] = address(DAI);
        token1[5] = address(USDE);
        token1[6] = address(SUSDE);
        token1[7] = address(USDE);
        token1[8] = address(SUSDE);
        token1[9] = address(SUSDE);

        _addUniswapV3Leafs(leafs, token0, token1);

        // ========================== Fee Claiming ==========================
        /**
         * Claim fees in USDC, DAI, USDT and USDE
         */
        ERC20[] memory feeAssets = new ERC20[](4);
        feeAssets[0] = USDC;
        feeAssets[1] = DAI;
        feeAssets[2] = USDT;
        feeAssets[3] = USDE;
        _addLeafsForFeeClaiming(leafs, feeAssets);

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
         * Swap crvUSD <-> USDC
         * Swap crvUSD <-> USDT
         * Swap crvUSD <-> USDe
         * Swap FRAX <-> USDC
         * Swap FRAX <-> USDT
         * Swap FRAX <-> DAI
         * Swap PYUSD <-> USDC
         * Swap PYUSD <-> FRAX
         * Swap PYUSD <-> crvUSD
         */
        address[] memory assets = new address[](16);
        SwapKind[] memory kind = new SwapKind[](16);
        assets[0] = address(USDC);
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = address(USDT);
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = address(DAI);
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = address(GHO);
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = address(USDE);
        kind[4] = SwapKind.BuyAndSell;
        assets[5] = address(CRVUSD);
        kind[5] = SwapKind.BuyAndSell;
        assets[6] = address(FRAX);
        kind[6] = SwapKind.BuyAndSell;
        assets[7] = address(PYUSD);
        kind[7] = SwapKind.BuyAndSell;
        assets[9] = address(WETH);
        kind[9] = SwapKind.BuyAndSell;
        assets[10] = address(WEETH);
        kind[10] = SwapKind.BuyAndSell;
        assets[11] = address(WSTETH);
        kind[11] = SwapKind.BuyAndSell;
        assets[8] = address(GEAR);
        kind[8] = SwapKind.Sell;
        assets[12] = address(CRV);
        kind[12] = SwapKind.Sell;
        assets[13] = address(CVX);
        kind[13] = SwapKind.Sell;
        assets[14] = address(AURA);
        kind[14] = SwapKind.Sell;
        assets[15] = address(BAL);
        kind[15] = SwapKind.Sell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        _addLeafsFor1InchUniswapV3Swapping(leafs, wstETH_wETH_01);
        _addLeafsFor1InchUniswapV3Swapping(leafs, rETH_wETH_01);
        _addLeafsFor1InchUniswapV3Swapping(leafs, rETH_wETH_05);
        _addLeafsFor1InchUniswapV3Swapping(leafs, wstETH_rETH_05);
        _addLeafsFor1InchUniswapV3Swapping(leafs, PENDLE_wETH_30);
        _addLeafsFor1InchUniswapV3Swapping(leafs, wETH_weETH_05);
        _addLeafsFor1InchUniswapV3Swapping(leafs, USDe_USDT_01);
        _addLeafsFor1InchUniswapV3Swapping(leafs, USDe_USDC_01);
        _addLeafsFor1InchUniswapV3Swapping(leafs, USDe_DAI_01);
        _addLeafsFor1InchUniswapV3Swapping(leafs, sUSDe_USDT_05);
        _addLeafsFor1InchUniswapV3Swapping(leafs, GEAR_wETH_100);
        _addLeafsFor1InchUniswapV3Swapping(leafs, GEAR_USDT_30);
        _addLeafsFor1InchUniswapV3Swapping(leafs, DAI_USDC_01);
        _addLeafsFor1InchUniswapV3Swapping(leafs, DAI_USDC_05);
        _addLeafsFor1InchUniswapV3Swapping(leafs, USDC_USDT_01);
        _addLeafsFor1InchUniswapV3Swapping(leafs, USDC_USDT_05);
        _addLeafsFor1InchUniswapV3Swapping(leafs, USDC_wETH_05);
        _addLeafsFor1InchUniswapV3Swapping(leafs, FRAX_USDC_05);
        _addLeafsFor1InchUniswapV3Swapping(leafs, FRAX_USDC_01);
        _addLeafsFor1InchUniswapV3Swapping(leafs, FRAX_USDT_05);
        _addLeafsFor1InchUniswapV3Swapping(leafs, DAI_FRAX_05);

        // ========================== Curve Swapping ==========================
        /**
         * USDe <-> USDC,
         * USDe <-> DAI,
         * sDAI <-> sUSDe,
         */
        {
            // Approvals
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(USDC),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Curve USDe USDC to spend USDC",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = USDe_USDC_Curve_Pool;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(USDE),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Curve USDe USDC to spend USDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = USDe_USDC_Curve_Pool;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(DAI),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Curve USDe DAI to spend DAI",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = USDe_DAI_Curve_Pool;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(USDE),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Curve USDe DAI to spend USDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = USDe_DAI_Curve_Pool;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(sDAI),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Curve sDAI sUSDe to spend sDAI",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = sDAI_sUSDe_Curve_Pool;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(SUSDE),
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve Curve sDAI sUSDe to spend sUSDe",
                rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = sDAI_sUSDe_Curve_Pool;
            // Swapping
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                USDe_USDC_Curve_Pool,
                false,
                "exchange(int128,int128,uint256,uint256)",
                new address[](0),
                "Swap using Curve USDe/USDC pool",
                rawDataDecoderAndSanitizer
            );
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                USDe_DAI_Curve_Pool,
                false,
                "exchange(int128,int128,uint256,uint256)",
                new address[](0),
                "Swap using Curve USDe/DAI pool",
                rawDataDecoderAndSanitizer
            );
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                sDAI_sUSDe_Curve_Pool,
                false,
                "exchange(int128,int128,uint256,uint256)",
                new address[](0),
                "Swap using Curve sDAI/sUSDe pool",
                rawDataDecoderAndSanitizer
            );
        }

        // ========================== ITB Aave V3 USDC ==========================
        /**
         * acceptOwnership() of itbAaveV3Usdc
         * transfer USDC to itbAaveV3Usdc
         * withdraw USDC from itbAaveV3Usdc
         * withdrawAll USDC from itbAaveV3Usdc
         * deposit USDC to itbAaveV3Usdc
         * withdraw USDC supply from itbAaveV3Usdc
         */
        {
            // acceptOwnership
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbAaveV3Usdc,
                false,
                "acceptOwnership()",
                new address[](0),
                "Accept ownership of the ITB Aave V3 USDC contract",
                itbDecoderAndSanitizer
            );
            // Transfer
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(USDC),
                false,
                "transfer(address,uint256)",
                new address[](1),
                "Transfer USDC to the ITB Aave V3 USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = itbAaveV3Usdc;
            // Withdraw
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbAaveV3Usdc,
                false,
                "withdraw(address,uint256)",
                new address[](1),
                "Withdraw USDC from the ITB Aave V3 USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDC);
            // WithdrawAll
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbAaveV3Usdc,
                false,
                "withdrawAll(address)",
                new address[](1),
                "Withdraw all USDC from the ITB Aave V3 USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDC);
            // Deposit
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbAaveV3Usdc,
                false,
                "deposit(address,uint256)",
                new address[](1),
                "Deposit USDC to the ITB Aave V3 USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDC);
            // Withdraw Supply
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbAaveV3Usdc,
                false,
                "withdrawSupply(address,uint256)",
                new address[](1),
                "Withdraw USDC supply from the ITB Aave V3 USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDC);
        }
        // ========================== ITB Aave V3 DAI ==========================
        /**
         * acceptOwnership() of itbAaveV3Dai
         * transfer DAI to itbAaveV3Dai
         * withdraw DAI from itbAaveV3Dai
         * withdrawAll DAI from itbAaveV3Dai
         * deposit DAI to itbAaveV3Dai
         * withdraw DAI supply from itbAaveV3Dai
         */
        {
            // acceptOwnership
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbAaveV3Dai,
                false,
                "acceptOwnership()",
                new address[](0),
                "Accept ownership of the ITB Aave V3 DAI contract",
                itbDecoderAndSanitizer
            );
            // Transfer
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(DAI),
                false,
                "transfer(address,uint256)",
                new address[](1),
                "Transfer DAI to the ITB Aave V3 DAI contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = itbAaveV3Dai;
            // Withdraw
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbAaveV3Dai,
                false,
                "withdraw(address,uint256)",
                new address[](1),
                "Withdraw DAI from the ITB Aave V3 DAI contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(DAI);
            // WithdrawAll
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbAaveV3Dai,
                false,
                "withdrawAll(address)",
                new address[](1),
                "Withdraw all DAI from the ITB Aave V3 DAI contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(DAI);
            // Deposit
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbAaveV3Dai,
                false,
                "deposit(address,uint256)",
                new address[](1),
                "Deposit DAI to the ITB Aave V3 DAI contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(DAI);
            // Withdraw Supply
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbAaveV3Dai,
                false,
                "withdrawSupply(address,uint256)",
                new address[](1),
                "Withdraw DAI supply from the ITB Aave V3 DAI contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(DAI);
        }
        // ========================== ITB Aave V3 USDT ==========================
        /**
         * acceptOwnership() of itbAaveV3Usdt
         * transfer USDT to itbAaveV3Usdt
         * withdraw USDT from itbAaveV3Usdt
         * withdrawAll USDT from itbAaveV3Usdt
         * deposit USDT to itbAaveV3Usdt
         * withdraw USDT supply from itbAaveV3Usdt
         */
        {
            // acceptOwnership
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbAaveV3Usdt,
                false,
                "acceptOwnership()",
                new address[](0),
                "Accept ownership of the ITB Aave V3 USDT contract",
                itbDecoderAndSanitizer
            );
            // Transfer
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(USDT),
                false,
                "transfer(address,uint256)",
                new address[](1),
                "Transfer USDT to the ITB Aave V3 USDT contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = itbAaveV3Usdt;
            // Withdraw
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbAaveV3Usdt,
                false,
                "withdraw(address,uint256)",
                new address[](1),
                "Withdraw USDT from the ITB Aave V3 USDT contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDT);
            // WithdrawAll
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbAaveV3Usdt,
                false,
                "withdrawAll(address)",
                new address[](1),
                "Withdraw all USDT from the ITB Aave V3 USDT contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDT);
            // Deposit
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbAaveV3Usdt,
                false,
                "deposit(address,uint256)",
                new address[](1),
                "Deposit USDT to the ITB Aave V3 USDT contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDT);
            // Withdraw Supply
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbAaveV3Usdt,
                false,
                "withdrawSupply(address,uint256)",
                new address[](1),
                "Withdraw USDT supply from the ITB Aave V3 USDT contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDT);
        }
        // ========================== ITB Gearbox USDC ==========================
        /**
         * acceptOwnership() of itbGearboxUsdc
         * transfer USDC to itbGearboxUsdc
         * withdraw USDC from itbGearboxUsdc
         * withdrawAll USDC from itbGearboxUsdc
         * deposit USDC to dUSDCV3
         * withdraw USDC from dUSDCV3
         * stake dUSDCV3 into sdUSDCV3
         * unstake dUSDCV3 from sdUSDCV3
         */
        {
            // acceptOwnership
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxUsdc,
                false,
                "acceptOwnership()",
                new address[](0),
                "Accept ownership of the ITB Gearbox USDC contract",
                itbDecoderAndSanitizer
            );
            // Transfer
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(USDC),
                false,
                "transfer(address,uint256)",
                new address[](1),
                "Transfer USDC to the ITB Gearbox USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = itbGearboxUsdc;
            // Approvals
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxUsdc,
                false,
                "approveToken(address,address,uint256)",
                new address[](2),
                "Approve Gearbox dUSDCV3 to spend USDC",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDC);
            leafs[leafIndex].argumentAddresses[1] = address(dUSDCV3);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxUsdc,
                false,
                "approveToken(address,address,uint256)",
                new address[](2),
                "Approve Gearbox sdUSDCV3 to spend dUSDCV3",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(dUSDCV3);
            leafs[leafIndex].argumentAddresses[1] = address(sdUSDCV3);
            // Withdraw
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxUsdc,
                false,
                "withdraw(address,uint256)",
                new address[](1),
                "Withdraw USDC from the ITB Gearbox USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDC);
            // WithdrawAll
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxUsdc,
                false,
                "withdrawAll(address)",
                new address[](1),
                "Withdraw all USDC from the ITB Gearbox USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDC);
            // Deposit
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxUsdc,
                false,
                "deposit(uint256,uint256)",
                new address[](0),
                "Deposit USDC into Gearbox dUSDCV3 contract",
                itbDecoderAndSanitizer
            );
            // Withdraw
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxUsdc,
                false,
                "withdrawSupply(uint256,uint256)",
                new address[](0),
                "Withdraw USDC from Gearbox dUSDCV3 contract",
                itbDecoderAndSanitizer
            );
            // Stake
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxUsdc,
                false,
                "stake(uint256)",
                new address[](0),
                "Stake dUSDCV3 into Gearbox sdUSDCV3 contract",
                itbDecoderAndSanitizer
            );
            // Unstake
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxUsdc,
                false,
                "unstake(uint256)",
                new address[](0),
                "Unstake dUSDCV3 from Gearbox sdUSDCV3 contract",
                itbDecoderAndSanitizer
            );
        }
        // ========================== ITB Gearbox DAI ==========================
        /**
         * acceptOwnership() of itbGearboxDai
         * transfer DAI to itbGearboxDai
         * withdraw DAI from itbGearboxDai
         * withdrawAll DAI from itbGearboxDai
         * deposit DAI to dDAIV3
         * withdraw DAI from dDAIV3
         * stake dDAIV3 into sdDAIV3
         * unstake dDAIV3 from sdDAIV3
         */
        {
            // acceptOwnership
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxDai,
                false,
                "acceptOwnership()",
                new address[](0),
                "Accept ownership of the ITB Gearbox DAI contract",
                itbDecoderAndSanitizer
            );
            // Transfer
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(DAI),
                false,
                "transfer(address,uint256)",
                new address[](1),
                "Transfer DAI to the ITB Gearbox DAI contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = itbGearboxDai;
            // Approvals
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxDai,
                false,
                "approveToken(address,address,uint256)",
                new address[](2),
                "Approve Gearbox dDAIV3 to spend DAI",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(DAI);
            leafs[leafIndex].argumentAddresses[1] = address(dDAIV3);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxDai,
                false,
                "approveToken(address,address,uint256)",
                new address[](2),
                "Approve Gearbox sdDAIV3 to spend dDAIV3",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(dDAIV3);
            leafs[leafIndex].argumentAddresses[1] = address(sdDAIV3);
            // Withdraw
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxDai,
                false,
                "withdraw(address,uint256)",
                new address[](1),
                "Withdraw DAI from the ITB Gearbox DAI contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(DAI);
            // WithdrawAll
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxDai,
                false,
                "withdrawAll(address)",
                new address[](1),
                "Withdraw all DAI from the ITB Gearbox DAI contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(DAI);
            // Deposit
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxDai,
                false,
                "deposit(uint256,uint256)",
                new address[](0),
                "Deposit DAI into Gearbox dDAIV3 contract",
                itbDecoderAndSanitizer
            );
            // Withdraw
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxDai,
                false,
                "withdrawSupply(uint256,uint256)",
                new address[](0),
                "Withdraw DAI from Gearbox dDAIV3 contract",
                itbDecoderAndSanitizer
            );
            // Stake
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxDai,
                false,
                "stake(uint256)",
                new address[](0),
                "Stake dDAIV3 into Gearbox sdDAIV3 contract",
                itbDecoderAndSanitizer
            );
            // Unstake
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxDai,
                false,
                "unstake(uint256)",
                new address[](0),
                "Unstake dDAIV3 from Gearbox sdDAIV3 contract",
                itbDecoderAndSanitizer
            );
        }
        // ========================== ITB Gearbox USDT ==========================
        /**
         * acceptOwnership() of itbGearboxUsdt
         * transfer USDT to itbGearboxUsdt
         * withdraw USDT from itbGearboxUsdt
         * withdrawAll USDT from itbGearboxUsdt
         * deposit USDT to dUSDTV3
         * withdraw USDT from dUSDTV3
         * stake dUSDTV3 into sdUSDTV3
         * unstake dUSDTV3 from sdUSDTV3
         */
        {
            // acceptOwnership
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxUsdt,
                false,
                "acceptOwnership()",
                new address[](0),
                "Accept ownership of the ITB Gearbox USDT contract",
                itbDecoderAndSanitizer
            );
            // Transfer
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(USDT),
                false,
                "transfer(address,uint256)",
                new address[](1),
                "Transfer USDT to the ITB Gearbox USDT contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = itbGearboxUsdt;
            // Approvals
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxUsdt,
                false,
                "approveToken(address,address,uint256)",
                new address[](2),
                "Approve Gearbox dUSDTV3 to spend USDT",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDT);
            leafs[leafIndex].argumentAddresses[1] = address(dUSDTV3);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxUsdt,
                false,
                "approveToken(address,address,uint256)",
                new address[](2),
                "Approve Gearbox sdUSDTV3 to spend dUSDTV3",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(dUSDTV3);
            leafs[leafIndex].argumentAddresses[1] = address(sdUSDTV3);
            // Withdraw
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxUsdt,
                false,
                "withdraw(address,uint256)",
                new address[](1),
                "Withdraw USDT from the ITB Gearbox USDT contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDT);
            // WithdrawAll
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxUsdt,
                false,
                "withdrawAll(address)",
                new address[](1),
                "Withdraw all USDT from the ITB Gearbox USDT contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDT);
            // Deposit
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxUsdt,
                false,
                "deposit(uint256,uint256)",
                new address[](0),
                "Deposit USDT into Gearbox dUSDTV3 contract",
                itbDecoderAndSanitizer
            );
            // Withdraw
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxUsdt,
                false,
                "withdrawSupply(uint256,uint256)",
                new address[](0),
                "Withdraw USDT from Gearbox dUSDTV3 contract",
                itbDecoderAndSanitizer
            );
            // Stake
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxUsdt,
                false,
                "stake(uint256)",
                new address[](0),
                "Stake dUSDTV3 into Gearbox sdUSDTV3 contract",
                itbDecoderAndSanitizer
            );
            // Unstake
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbGearboxUsdt,
                false,
                "unstake(uint256)",
                new address[](0),
                "Unstake dUSDTV3 from Gearbox sdUSDTV3 contract",
                itbDecoderAndSanitizer
            );
        }

        // ========================== ITB Curve/Convex PYUSD/USDC ==========================
        /**
         * itbCurveConvex_PyUsdUsdc
         * acceptOwnership() of itbCurveConvex_PyUsdUsdc
         * transfer both tokens to the pool
         * withdraw and withdraw all both tokens
         * addLiquidityAllCoinsAndStakeConvex
         * unstakeAndRemoveLiquidityAllCoinsConvex
         */
        {
            // acceptOwnership
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_PyUsdUsdc,
                false,
                "acceptOwnership()",
                new address[](0),
                "Accept ownership of the ITB Curve/Convex PYUSD/USDC contract",
                itbDecoderAndSanitizer
            );
            // Transfer both tokens to the pool
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(PYUSD),
                false,
                "transfer(address,uint256)",
                new address[](1),
                "Transfer PYUSD to the ITB Curve/Convex PYUSD/USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = itbCurveConvex_PyUsdUsdc;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(USDC),
                false,
                "transfer(address,uint256)",
                new address[](1),
                "Transfer USDC to the ITB Curve/Convex PYUSD/USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = itbCurveConvex_PyUsdUsdc;
            // Approvals
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_PyUsdUsdc,
                false,
                "approveToken(address,address,uint256)",
                new address[](2),
                "Approve Curve pool to spend PYUSD",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(PYUSD);
            leafs[leafIndex].argumentAddresses[1] = pyUsd_Usdc_Curve_Pool;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_PyUsdUsdc,
                false,
                "approveToken(address,address,uint256)",
                new address[](2),
                "Approve Curve pool to spend USDC",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDC);
            leafs[leafIndex].argumentAddresses[1] = pyUsd_Usdc_Curve_Pool;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_PyUsdUsdc,
                false,
                "approveToken(address,address,uint256)",
                new address[](2),
                "Approve Convex to spend Curve LP",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = pyUsd_Usdc_Curve_Pool;
            leafs[leafIndex].argumentAddresses[1] = convexCurveMainnetBooster;
            // Withdraw both tokens
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_PyUsdUsdc,
                false,
                "withdraw(address,uint256)",
                new address[](1),
                "Withdraw PYUSD from the ITB Curve/Convex PYUSD/USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(PYUSD);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_PyUsdUsdc,
                false,
                "withdraw(address,uint256)",
                new address[](1),
                "Withdraw USDC from the ITB Curve/Convex PYUSD/USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDC);
            // WithdrawAll both tokens
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_PyUsdUsdc,
                false,
                "withdrawAll(address)",
                new address[](1),
                "Withdraw all PYUSD from the ITB Curve/Convex PYUSD/USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(PYUSD);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_PyUsdUsdc,
                false,
                "withdrawAll(address)",
                new address[](1),
                "Withdraw all USDC from the ITB Curve/Convex PYUSD/USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDC);
            // Add liquidity and stake
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_PyUsdUsdc,
                false,
                "addLiquidityAllCoinsAndStakeConvex(address,uint256[],uint256,uint256)",
                new address[](2),
                "Add liquidity to the ITB Curve/Convex PYUSD/USDC contract and stake the convex tokens",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = pyUsd_Usdc_Curve_Pool;
            leafs[leafIndex].argumentAddresses[1] = pyUsd_Usdc_Convex_Id;
            // Unstake and remove liquidity
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_PyUsdUsdc,
                false,
                "unstakeAndRemoveLiquidityAllCoinsConvex(address,uint256,uint256,uint256[])",
                new address[](2),
                "Unstake the convex tokens and remove liquidity from the ITB Curve/Convex PYUSD/USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = pyUsd_Usdc_Curve_Pool;
            leafs[leafIndex].argumentAddresses[1] = pyUsd_Usdc_Convex_Id;
        }

        // ========================== ITB Curve/Convex FRAX/USDC ==========================
        /**
         * itbCurveConvex_FraxUsdc
         * acceptOwnership() of itbCurveConvex_FraxUsdc
         * transfer both tokens to the pool
         * withdraw and withdraw all both tokens
         * addLiquidityAllCoinsAndStakeConvex
         * unstakeAndRemoveLiquidityAllCoinsConvex
         */
        {
            // acceptOwnership
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_FraxUsdc,
                false,
                "acceptOwnership()",
                new address[](0),
                "Accept ownership of the ITB Curve/Convex FRAX/USDC contract",
                itbDecoderAndSanitizer
            );
            // Transfer both tokens to the pool
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(FRAX),
                false,
                "transfer(address,uint256)",
                new address[](1),
                "Transfer FRAX to the ITB Curve/Convex FRAX/USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = itbCurveConvex_FraxUsdc;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(USDC),
                false,
                "transfer(address,uint256)",
                new address[](1),
                "Transfer USDC to the ITB Curve/Convex FRAX/USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = itbCurveConvex_FraxUsdc;
            // Approvals
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_FraxUsdc,
                false,
                "approveToken(address,address,uint256)",
                new address[](2),
                "Approve Curve pool to spend FRAX",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(FRAX);
            leafs[leafIndex].argumentAddresses[1] = frax_Usdc_Curve_Pool;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_FraxUsdc,
                false,
                "approveToken(address,address,uint256)",
                new address[](2),
                "Approve Curve pool to spend USDC",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDC);
            leafs[leafIndex].argumentAddresses[1] = frax_Usdc_Curve_Pool;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_FraxUsdc,
                false,
                "approveToken(address,address,uint256)",
                new address[](2),
                "Approve Convex to spend Curve LP",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = frax_Usdc_Curve_Pool;
            leafs[leafIndex].argumentAddresses[1] = convexCurveMainnetBooster;
            // Withdraw both tokens
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_FraxUsdc,
                false,
                "withdraw(address,uint256)",
                new address[](1),
                "Withdraw FRAX from the ITB Curve/Convex FRAX/USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(FRAX);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_FraxUsdc,
                false,
                "withdraw(address,uint256)",
                new address[](1),
                "Withdraw USDC from the ITB Curve/Convex FRAX/USDC",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDC);
            // WithdrawAll both tokens
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_FraxUsdc,
                false,
                "withdrawAll(address)",
                new address[](1),
                "Withdraw all FRAX from the ITB Curve/Convex FRAX/USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(FRAX);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_FraxUsdc,
                false,
                "withdrawAll(address)",
                new address[](1),
                "Withdraw all USDC from the ITB Curve/Convex FRAX/USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDC);
            // Add liquidity and stake
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_FraxUsdc,
                false,
                "addLiquidityAllCoinsAndStakeConvex(address,uint256[],uint256,uint256)",
                new address[](2),
                "Add liquidity to the ITB Curve/Convex FRAX/USDC contract and stake the convex tokens",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = frax_Usdc_Curve_Pool;
            leafs[leafIndex].argumentAddresses[1] = frax_Usdc_Convex_Id;
            // Unstake and remove liquidity
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_FraxUsdc,
                false,
                "unstakeAndRemoveLiquidityAllCoinsConvex(address,uint256,uint256,uint256[])",
                new address[](2),
                "Unstake the convex tokens and remove liquidity from the ITB Curve/Convex FRAX/USDC contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = frax_Usdc_Curve_Pool;
            leafs[leafIndex].argumentAddresses[1] = frax_Usdc_Convex_Id;
        }

        // ========================== ITB Curve/Convex USDC/crvUSD ==========================
        /**
         * itbCurveConvex_UsdcCrvUsd
         * acceptOwnership() of itbCurveConvex_UsdcCrvUsd
         * transfer both tokens to the pool
         * withdraw and withdraw all both tokens
         * addLiquidityAllCoinsAndStakeConvex
         * unstakeAndRemoveLiquidityAllCoinsConvex
         */
        {
            // acceptOwnership
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_UsdcCrvUsd,
                false,
                "acceptOwnership()",
                new address[](0),
                "Accept ownership of the ITB Curve/Convex USDC/crvUSD contract",
                itbDecoderAndSanitizer
            );
            // Transfer both tokens to the pool
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(USDC),
                false,
                "transfer(address,uint256)",
                new address[](1),
                "Transfer USDC to the ITB Curve/Convex USDC/crvUSD contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = itbCurveConvex_UsdcCrvUsd;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(CRVUSD),
                false,
                "transfer(address,uint256)",
                new address[](1),
                "Transfer crvUSD to the ITB Curve/Convex USDC/crvUSD contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = itbCurveConvex_UsdcCrvUsd;
            // Approvals
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_UsdcCrvUsd,
                false,
                "approveToken(address,address,uint256)",
                new address[](2),
                "Approve Curve pool to spend USDC",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDC);
            leafs[leafIndex].argumentAddresses[1] = usdc_CrvUsd_Curve_Pool;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_UsdcCrvUsd,
                false,
                "approveToken(address,address,uint256)",
                new address[](2),
                "Approve Curve pool to spend crvUSD",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(CRVUSD);
            leafs[leafIndex].argumentAddresses[1] = usdc_CrvUsd_Curve_Pool;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_UsdcCrvUsd,
                false,
                "approveToken(address,address,uint256)",
                new address[](2),
                "Approve Convex to spend Curve LP",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = usdc_CrvUsd_Curve_Pool;
            leafs[leafIndex].argumentAddresses[1] = convexCurveMainnetBooster;
            // Withdraw both tokens
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_UsdcCrvUsd,
                false,
                "withdraw(address,uint256)",
                new address[](1),
                "Withdraw USDC from the ITB Curve/Convex USDC/crvUSD contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDC);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_UsdcCrvUsd,
                false,
                "withdraw(address,uint256)",
                new address[](1),
                "Withdraw crvUSD from the ITB Curve/Convex USDC/crvUSD contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(CRVUSD);
            // WithdrawAll both tokens
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_UsdcCrvUsd,
                false,
                "withdrawAll(address)",
                new address[](1),
                "Withdraw all USDC from the ITB Curve/Convex USDC/crvUSD contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(USDC);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_UsdcCrvUsd,
                false,
                "withdrawAll(address)",
                new address[](1),
                "Withdraw all crvUSD from the ITB Curve/Convex USDC/crvUSD contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(CRVUSD);
            // Add liquidity and stake
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_UsdcCrvUsd,
                false,
                "addLiquidityAllCoinsAndStakeConvex(address,uint256[],uint256,uint256)",
                new address[](2),
                "Add liquidity to the ITB Curve/Convex USDC/crvUSD contract and stake the convex tokens",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = usdc_CrvUsd_Curve_Pool;
            leafs[leafIndex].argumentAddresses[1] = usdc_CrvUsd_Convex_Id;
            // Unstake and remove liquidity
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurveConvex_UsdcCrvUsd,
                false,
                "unstakeAndRemoveLiquidityAllCoinsConvex(address,uint256,uint256,uint256[])",
                new address[](2),
                "Unstake the convex tokens and remove liquidity from the ITB Curve/Convex USDC/crvUSD contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = usdc_CrvUsd_Curve_Pool;
            leafs[leafIndex].argumentAddresses[1] = usdc_CrvUsd_Convex_Id;
        }

        // ========================== ITB Curve sDAI/sUSDe ==========================
        /**
         * acceptOwnership() of itbCurve_sDai_sUsde
         * transfer both tokens to the pool
         * withdraw and withdraw all both tokens
         * addLiquidityAllCoinsAndStake
         * unstakeAndRemoveLiquidityAllCoins
         */
        {
            // acceptOwnership
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurve_sDai_sUsde,
                false,
                "acceptOwnership()",
                new address[](0),
                "Accept ownership of the ITB Curve sDAI/sUSDe contract",
                itbDecoderAndSanitizer
            );
            // Transfer both tokens to the pool
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(sDAI),
                false,
                "transfer(address,uint256)",
                new address[](1),
                "Transfer sDAI to the ITB Curve sDAI/sUSDe contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = itbCurve_sDai_sUsde;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(SUSDE),
                false,
                "transfer(address,uint256)",
                new address[](1),
                "Transfer sUSDe to the ITB Curve sDAI/sUSDe contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = itbCurve_sDai_sUsde;
            // Approvals
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurve_sDai_sUsde,
                false,
                "approveToken(address,address,uint256)",
                new address[](2),
                "Approve Curve pool to spend sDAI",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(sDAI);
            leafs[leafIndex].argumentAddresses[1] = sDai_sUsde_Curve_Pool;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurve_sDai_sUsde,
                false,
                "approveToken(address,address,uint256)",
                new address[](2),
                "Approve Curve pool to spend sUSDe",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(SUSDE);
            leafs[leafIndex].argumentAddresses[1] = sDai_sUsde_Curve_Pool;
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurve_sDai_sUsde,
                false,
                "approveToken(address,address,uint256)",
                new address[](2),
                "Approve Curve gauge to spend Curve LP",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = sDai_sUsde_Curve_Pool;
            leafs[leafIndex].argumentAddresses[1] = sDai_sUsde_Curve_Gauge;
            // Withdraw both tokens
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurve_sDai_sUsde,
                false,
                "withdraw(address,uint256)",
                new address[](1),
                "Withdraw sDAI from the ITB Curve sDAI/sUSDe contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(sDAI);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurve_sDai_sUsde,
                false,
                "withdraw(address,uint256)",
                new address[](1),
                "Withdraw sUSDe from the ITB Curve sDAI/sUSDe contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(SUSDE);
            // WithdrawAll both tokens
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurve_sDai_sUsde,
                false,
                "withdrawAll(address)",
                new address[](1),
                "Withdraw all sDAI from the ITB Curve sDAI/sUSDe contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(sDAI);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurve_sDai_sUsde,
                false,
                "withdrawAll(address)",
                new address[](1),
                "Withdraw all sUSDe from the ITB Curve sDAI/sUSDe contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(SUSDE);
            // Add liquidity and stake
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurve_sDai_sUsde,
                false,
                "addLiquidityAllCoinsAndStake(address,uint256[],address,uint256)",
                new address[](2),
                "Add liquidity and stake to the ITB Curve sDAI/sUSDe contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = sDai_sUsde_Curve_Pool;
            leafs[leafIndex].argumentAddresses[1] = sDai_sUsde_Curve_Gauge;
            // Unstake and remove liquidity
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbCurve_sDai_sUsde,
                false,
                "unstakeAndRemoveLiquidityAllCoins(address,uint256,address,uint256[])",
                new address[](2),
                "Unstake and remove liquidity from the ITB Curve sDAI/sUSDe contract",
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = sDai_sUsde_Curve_Pool;
            leafs[leafIndex].argumentAddresses[1] = sDai_sUsde_Curve_Gauge;
        }

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

    function _generateMerkleTree(ManageLeaf[] memory manageLeafs) internal pure returns (bytes32[][] memory tree) {
        uint256 leafsLength = manageLeafs.length;
        bytes32[][] memory leafs = new bytes32[][](1);
        leafs[0] = new bytes32[](leafsLength);
        for (uint256 i; i < leafsLength; ++i) {
            bytes4 selector = bytes4(keccak256(abi.encodePacked(manageLeafs[i].signature)));
            bytes memory rawDigest = abi.encodePacked(
                manageLeafs[i].decoderAndSanitizer, manageLeafs[i].target, manageLeafs[i].canSendValue, selector
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

interface PendleMarket {
    function readTokens() external view returns (address, address, address);
}

interface PendleSy {
    function getTokensIn() external view returns (address[] memory);
    function getTokensOut() external view returns (address[] memory);
    function assetInfo() external view returns (uint8, ERC20, uint8);
}

interface UniswapV3Pool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
}
