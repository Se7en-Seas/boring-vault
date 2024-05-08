// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import "forge-std/Script.sol";

contract BaseMerkleRootGenerator is Script, MainnetAddresses {
    uint256 leafIndex = 0;

    address public _boringVault;
    address public _rawDataDecoderAndSanitizer;
    address public _managerAddress;
    address public _accountantAddress;

    mapping(address => mapping(address => bool)) public tokenToSpenderToApprovalInTree;
    mapping(address => mapping(address => bool)) public oneInchSellTokenToBuyTokenToInTree;

    function updateAddresses(
        address boringVault,
        address rawDataDecoderAndSanitizer,
        address managerAddress,
        address accountantAddress
    ) internal {
        _boringVault = boringVault;
        _rawDataDecoderAndSanitizer = rawDataDecoderAndSanitizer;
        _managerAddress = managerAddress;
        _accountantAddress = accountantAddress;
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
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = address(WSTETH);
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            address(STETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve unstETH to spend stETH",
            _rawDataDecoderAndSanitizer
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
            _rawDataDecoderAndSanitizer
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
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = _boringVault;
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            unstETH,
            false,
            "claimWithdrawal(uint256)",
            new address[](0),
            "Claim stETH withdrawal",
            _rawDataDecoderAndSanitizer
        );
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            unstETH,
            false,
            "claimWithdrawals(uint256[],uint256[])",
            new address[](0),
            "Claim stETH withdrawals",
            _rawDataDecoderAndSanitizer
        );
        // Wrapping
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            address(WSTETH), false, "wrap(uint256)", new address[](0), "Wrap stETH", _rawDataDecoderAndSanitizer
        );
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            address(WSTETH), false, "unwrap(uint256)", new address[](0), "Unwrap wstETH", _rawDataDecoderAndSanitizer
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
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = address(WEETH);
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            address(EETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve EtherFi Liquidity Pool to spend eETH",
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = EETH_LIQUIDITY_POOL;
        // Staking
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            EETH_LIQUIDITY_POOL, true, "deposit()", new address[](0), "Stake ETH for eETH", _rawDataDecoderAndSanitizer
        );
        // Unstaking
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            EETH_LIQUIDITY_POOL,
            false,
            "requestWithdraw(address,uint256)",
            new address[](1),
            "Request withdrawal from eETH",
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = _boringVault;
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            withdrawalRequestNft,
            false,
            "claimWithdraw(uint256)",
            new address[](0),
            "Claim eETH withdrawal",
            _rawDataDecoderAndSanitizer
        );
        // Wrapping
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            address(WEETH), false, "wrap(uint256)", new address[](0), "Wrap eETH", _rawDataDecoderAndSanitizer
        );
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            address(WEETH), false, "unwrap(uint256)", new address[](0), "Unwrap weETH", _rawDataDecoderAndSanitizer
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
            address(WETH), true, "deposit()", new address[](0), "Wrap ETH for wETH", _rawDataDecoderAndSanitizer
        );
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            address(WETH),
            false,
            "withdraw(uint256)",
            new address[](0),
            "Unwrap wETH for ETH",
            _rawDataDecoderAndSanitizer
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
                _rawDataDecoderAndSanitizer
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
                _rawDataDecoderAndSanitizer
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
                _rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(supplyAssets[i]);
            leafs[leafIndex].argumentAddresses[1] = _boringVault;
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
                _rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(supplyAssets[i]);
            leafs[leafIndex].argumentAddresses[1] = _boringVault;
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
                _rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(borrowAssets[i]);
            leafs[leafIndex].argumentAddresses[1] = _boringVault;
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
                _rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(borrowAssets[i]);
            leafs[leafIndex].argumentAddresses[1] = _boringVault;
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
                _rawDataDecoderAndSanitizer
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
            _rawDataDecoderAndSanitizer
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
            _rawDataDecoderAndSanitizer
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
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = _boringVault;
        // Withdrawing
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            address(vault),
            false,
            "withdraw(uint256,address,address)",
            new address[](2),
            string.concat("Withdraw ", asset.symbol(), " from ", vault.symbol()),
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = _boringVault;
        leafs[leafIndex].argumentAddresses[1] = _boringVault;
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
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = dieselStaking;
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            dieselStaking,
            false,
            "deposit(uint256)",
            new address[](0),
            string.concat("Deposit ", dieselVaultSymbol, " for s", dieselVaultSymbol),
            _rawDataDecoderAndSanitizer
        );
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            dieselStaking,
            false,
            "withdraw(uint256)",
            new address[](0),
            string.concat("Withdraw ", dieselVaultSymbol, " from s", dieselVaultSymbol),
            _rawDataDecoderAndSanitizer
        );
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            dieselStaking,
            false,
            "claim()",
            new address[](0),
            string.concat("Claim rewards from s", dieselVaultSymbol),
            _rawDataDecoderAndSanitizer
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
                _rawDataDecoderAndSanitizer
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
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
        leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
        leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
        leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
        leafs[leafIndex].argumentAddresses[4] = _boringVault;
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            morphoBlue,
            false,
            "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
            new address[](6),
            string.concat("Withdraw ", loanToken.symbol(), " from ", morphoBlueMarketName),
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
        leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
        leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
        leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
        leafs[leafIndex].argumentAddresses[4] = _boringVault;
        leafs[leafIndex].argumentAddresses[5] = _boringVault;
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
                    _rawDataDecoderAndSanitizer
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
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = pendleRouter;
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            sy,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Pendle router to spend ", ERC20(sy).symbol()),
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = pendleRouter;
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            pt,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Pendle router to spend ", ERC20(pt).symbol()),
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = pendleRouter;
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            yt,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Pendle router to spend ", ERC20(yt).symbol()),
            _rawDataDecoderAndSanitizer
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
                    _rawDataDecoderAndSanitizer
                );
                leafs[leafIndex].argumentAddresses[0] = _boringVault;
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
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = _boringVault;
        leafs[leafIndex].argumentAddresses[1] = yt;
        // Swap between PT and YT.
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            pendleRouter,
            false,
            "swapExactYtForPt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            new address[](2),
            string.concat("Swap ", ERC20(yt).symbol(), " for ", ERC20(pt).symbol()),
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = _boringVault;
        leafs[leafIndex].argumentAddresses[1] = marketAddress;
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            pendleRouter,
            false,
            "swapExactPtForYt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            new address[](2),
            string.concat("Swap ", ERC20(pt).symbol(), " for ", ERC20(yt).symbol()),
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = _boringVault;
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
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = _boringVault;
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
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = _boringVault;
        leafs[leafIndex].argumentAddresses[1] = marketAddress;
        // Burn PT and YT for SY.
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            pendleRouter,
            false,
            "redeemPyToSy(address,address,uint256,uint256)",
            new address[](2),
            string.concat("Burn ", ERC20(pt).symbol(), " and ", ERC20(yt).symbol(), " for ", ERC20(sy).symbol()),
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = _boringVault;
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
                    _rawDataDecoderAndSanitizer
                );
                leafs[leafIndex].argumentAddresses[0] = address(_boringVault);
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
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = _boringVault;
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
                    _rawDataDecoderAndSanitizer
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
                    _rawDataDecoderAndSanitizer
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
                _rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = _boringVault;
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
                _rawDataDecoderAndSanitizer
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
                _rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = address(_boringVault);
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                uniV3Router,
                false,
                "exactInput((bytes,address,uint256,uint256,uint256))",
                new address[](3),
                string.concat(
                    "Swap ", ERC20(token1[i]).symbol(), " for ", ERC20(token0[i]).symbol(), " using UniswapV3 router"
                ),
                _rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = token1[i];
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = address(_boringVault);
        }
        // Decrease liquidity
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            new address[](0),
            "Remove liquidity from UniswapV3 position",
            _rawDataDecoderAndSanitizer
        );
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            uniswapV3NonFungiblePositionManager,
            false,
            "collect((uint256,address,uint128,uint128))",
            new address[](1),
            "Collect fees from UniswapV3 position",
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = _boringVault;
    }

    function _addLeafsForFeeClaiming(ManageLeaf[] memory leafs, ERC20[] memory feeAssets) internal {
        // Approvals.
        for (uint256 i; i < feeAssets.length; ++i) {
            if (!tokenToSpenderToApprovalInTree[address(feeAssets[i])][_accountantAddress]) {
                leafIndex++;
                leafs[leafIndex] = ManageLeaf(
                    address(feeAssets[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Accountant to spend ", feeAssets[i].symbol()),
                    _rawDataDecoderAndSanitizer
                );
                leafs[leafIndex].argumentAddresses[0] = _accountantAddress;
                tokenToSpenderToApprovalInTree[address(feeAssets[i])][_accountantAddress] = true;
            }
        }
        // Claiming fees.
        for (uint256 i; i < feeAssets.length; ++i) {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                _accountantAddress,
                false,
                "claimFees(address)",
                new address[](1),
                string.concat("Claim fees in ", feeAssets[i].symbol()),
                _rawDataDecoderAndSanitizer
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
                    _rawDataDecoderAndSanitizer
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
                        _rawDataDecoderAndSanitizer
                    );
                    leafs[leafIndex].argumentAddresses[0] = oneInchExecutor;
                    leafs[leafIndex].argumentAddresses[1] = assets[i];
                    leafs[leafIndex].argumentAddresses[2] = assets[j];
                    leafs[leafIndex].argumentAddresses[3] = oneInchExecutor;
                    leafs[leafIndex].argumentAddresses[4] = _boringVault;
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
                        _rawDataDecoderAndSanitizer
                    );
                    leafs[leafIndex].argumentAddresses[0] = oneInchExecutor;
                    leafs[leafIndex].argumentAddresses[1] = assets[j];
                    leafs[leafIndex].argumentAddresses[2] = assets[i];
                    leafs[leafIndex].argumentAddresses[3] = oneInchExecutor;
                    leafs[leafIndex].argumentAddresses[4] = _boringVault;
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
                _rawDataDecoderAndSanitizer
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
                _rawDataDecoderAndSanitizer
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
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = pool;
    }

    function _addLeafsForCurveSwapping(ManageLeaf[] memory leafs, address curvePool) internal {
        CurvePool pool = CurvePool(curvePool);
        ERC20 coins0 = ERC20(pool.coins(0));
        ERC20 coins1 = ERC20(pool.coins(1));
        // Approvals.
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            address(coins0),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Curve ", coins0.symbol(), "/", coins1.symbol(), " pool to spend ", coins0.symbol()),
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = curvePool;
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            address(coins1),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Curve ", coins0.symbol(), "/", coins1.symbol(), " pool to spend ", coins1.symbol()),
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = curvePool;
        // Swapping.
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            curvePool,
            false,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            string.concat("Swap using Curve ", coins0.symbol(), "/", coins1.symbol(), " pool"),
            _rawDataDecoderAndSanitizer
        );
    }

    function _addLeafsForEigenLayerLST(
        ManageLeaf[] memory leafs,
        address lst,
        address strategy,
        address _strategyManager,
        address _delegationManager
    ) internal {
        // Approvals.
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            lst,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Eigen Layer Strategy Manager to spend ", ERC20(lst).symbol()),
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = _strategyManager;
        tokenToSpenderToApprovalInTree[lst][_strategyManager] = true;
        // Depositing.
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            _strategyManager,
            false,
            "depositIntoStrategy(address,address,uint256)",
            new address[](2),
            string.concat("Deposit ", ERC20(lst).symbol(), " into Eigen Layer Strategy Manager"),
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = strategy;
        leafs[leafIndex].argumentAddresses[1] = lst;
        // Request withdraw.
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            _delegationManager,
            false,
            "queueWithdrawals((address[],uint256[],address)[])",
            new address[](2),
            string.concat("Request withdraw of ", ERC20(lst).symbol(), " from Eigen Layer Delegation Manager"),
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = strategy;
        leafs[leafIndex].argumentAddresses[1] = _boringVault;
        // Complete withdraw.
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            _delegationManager,
            false,
            "completeQueuedWithdrawals((address,address,address,uint256,uint32,address[],uint256[])[],address[][],uint256[],bool[])",
            new address[](5),
            string.concat("Complete withdraw of ", ERC20(lst).symbol(), " from Eigen Layer Delegation Manager"),
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = _boringVault;
        leafs[leafIndex].argumentAddresses[1] = address(0);
        leafs[leafIndex].argumentAddresses[2] = _boringVault;
        leafs[leafIndex].argumentAddresses[3] = strategy;
        leafs[leafIndex].argumentAddresses[4] = lst;
    }

    function _addSwellLeafs(ManageLeaf[] memory leafs, address asset, address _swellSimpleStaking) internal {
        // Approval
        if (!tokenToSpenderToApprovalInTree[asset][_swellSimpleStaking]) {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                asset,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Swell Simple Staking to spend ", ERC20(asset).symbol()),
                _rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = _swellSimpleStaking;
            tokenToSpenderToApprovalInTree[asset][_swellSimpleStaking] = true;
        }
        // deposit
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            _swellSimpleStaking,
            false,
            "deposit(address,uint256,address)",
            new address[](2),
            string.concat("Deposit ", ERC20(asset).symbol(), " into Swell Simple Staking"),
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = asset;
        leafs[leafIndex].argumentAddresses[1] = _boringVault;
        // withdraw
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            _swellSimpleStaking,
            false,
            "withdraw(address,uint256,address)",
            new address[](2),
            string.concat("Withdraw ", ERC20(asset).symbol(), " from Swell Simple Staking"),
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = asset;
        leafs[leafIndex].argumentAddresses[1] = _boringVault;
    }

    function _addZircuitLeafs(ManageLeaf[] memory leafs, address asset, address _zircuitSimpleStaking) internal {
        // Approval
        if (!tokenToSpenderToApprovalInTree[asset][_zircuitSimpleStaking]) {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                asset,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Zircuit simple staking to spend ", ERC20(asset).symbol()),
                _rawDataDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = _zircuitSimpleStaking;
            tokenToSpenderToApprovalInTree[asset][_zircuitSimpleStaking] = true;
        }
        // deposit
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            _zircuitSimpleStaking,
            false,
            "depositFor(address,address,uint256)",
            new address[](2),
            string.concat("Deposit ", ERC20(asset).symbol(), " into Zircuit simple staking"),
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = asset;
        leafs[leafIndex].argumentAddresses[1] = _boringVault;
        // withdraw
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            _zircuitSimpleStaking,
            false,
            "withdraw(address,uint256)",
            new address[](1),
            string.concat("Withdraw ", ERC20(asset).symbol(), " from Zircuit simple staking"),
            _rawDataDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = asset;
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
        vm.serializeAddress(metadata, "BoringVaultAddress", _boringVault);
        vm.serializeAddress(metadata, "DecoderAndSanitizerAddress", _rawDataDecoderAndSanitizer);
        vm.serializeAddress(metadata, "ManagerAddress", _managerAddress);
        vm.serializeAddress(metadata, "AccountantAddress", _accountantAddress);
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

interface CurvePool {
    function coins(uint256 i) external view returns (address);
}
