pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {ChainValues} from "test/resources/ChainValues.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IComet} from "src/interfaces/IComet.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import "forge-std/Base.sol";

contract MerkleTreeHelper is CommonBase, ChainValues {
    using Address for address;

    string public sourceChain;
    uint256 leafIndex = type(uint256).max;

    mapping(address => mapping(address => bool)) public tokenToSpenderToApprovalInTree;
    mapping(address => mapping(address => bool)) public oneInchSellTokenToBuyTokenToInTree;

    function setSourceChainName(string memory _chain) internal {
        sourceChain = _chain;
    }

    // ========================================= 1Inch =========================================

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
            if (!tokenToSpenderToApprovalInTree[assets[i]][getAddress(sourceChain, "aggregationRouterV5")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    assets[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve 1Inch router to spend ", ERC20(assets[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "aggregationRouterV5");
                tokenToSpenderToApprovalInTree[assets[i]][getAddress(sourceChain, "aggregationRouterV5")] = true;
            }
            // Iterate through the list again.
            for (uint256 j; j < assets.length; ++j) {
                // Skip if we are on the same index
                if (i == j) {
                    continue;
                }
                if (!oneInchSellTokenToBuyTokenToInTree[assets[i]][assets[j]] && kind[j] != SwapKind.Sell) {
                    // Add sell swap.
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "aggregationRouterV5"),
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
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "oneInchExecutor");
                    leafs[leafIndex].argumentAddresses[1] = assets[i];
                    leafs[leafIndex].argumentAddresses[2] = assets[j];
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "oneInchExecutor");
                    leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");
                    oneInchSellTokenToBuyTokenToInTree[assets[i]][assets[j]] = true;
                }

                if (kind[i] == SwapKind.BuyAndSell && !oneInchSellTokenToBuyTokenToInTree[assets[j]][assets[i]]) {
                    // Add buy swap.
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        getAddress(sourceChain, "aggregationRouterV5"),
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
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "oneInchExecutor");
                    leafs[leafIndex].argumentAddresses[1] = assets[j];
                    leafs[leafIndex].argumentAddresses[2] = assets[i];
                    leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "oneInchExecutor");
                    leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");
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
        if (!tokenToSpenderToApprovalInTree[token0][getAddress(sourceChain, "aggregationRouterV5")]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                token0,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve 1Inch router to spend ", ERC20(token0).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "aggregationRouterV5");
            tokenToSpenderToApprovalInTree[token0][getAddress(sourceChain, "aggregationRouterV5")] = true;
        }
        if (!tokenToSpenderToApprovalInTree[token1][getAddress(sourceChain, "aggregationRouterV5")]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                token1,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve 1Inch router to spend ", ERC20(token1).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "aggregationRouterV5");
            tokenToSpenderToApprovalInTree[token1][getAddress(sourceChain, "aggregationRouterV5")] = true;
        }
        uint256 feeInBps = uniswapV3Pool.fee() / 100;
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "aggregationRouterV5"),
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
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = pool;
    }

    // ========================================= Curve/Convex =========================================
    // TODO need to use this in the test suite.
    function _addCurveLeafs(ManageLeaf[] memory leafs, address poolAddress, uint256 coinCount, address gauge)
        internal
    {
        CurvePool pool = CurvePool(poolAddress);
        ERC20[] memory coins = new ERC20[](coinCount);

        // Approve pool to spend tokens.
        for (uint256 i; i < coinCount; i++) {
            coins[i] = ERC20(pool.coins(i));
            // Approvals.
            if (!tokenToSpenderToApprovalInTree[address(coins[i])][poolAddress]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(coins[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Curve pool to spend ", coins[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = poolAddress;
                tokenToSpenderToApprovalInTree[address(coins[i])][poolAddress] = true;
            }
        }

        // Add liquidity.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            poolAddress,
            false,
            "add_liquidity(uint256[],uint256)",
            new address[](0),
            string.concat("Add liquidity to Curve pool"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Remove liquidity.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            poolAddress,
            false,
            "remove_liquidity(uint256,uint256[])",
            new address[](0),
            string.concat("Remove liquidity from Curve pool"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        if (gauge != address(0)) {
            // Deposit into gauge.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                gauge,
                false,
                "deposit(uint256,address)",
                new address[](1),
                string.concat("Deposit into Curve gauge"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            // Withdraw from gauge.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                gauge,
                false,
                "withdraw(uint256)",
                new address[](0),
                string.concat("Withdraw from Curve gauge"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );

            // Claim rewards.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                gauge,
                false,
                "claim_rewards(address)",
                new address[](1),
                string.concat("Claim rewards from Curve gauge"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        }
    }

    function _addConvexLeafs(ManageLeaf[] memory leafs, ERC20 token, address rewardsContract) internal {
        // Approve convexCurveMainnetBooster to spend lp tokens.
        if (!tokenToSpenderToApprovalInTree[address(token)][getAddress(sourceChain, "convexCurveMainnetBooster")]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(token),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Convex Curve Mainnet Booster to spend ", token.symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "convexCurveMainnetBooster");
            tokenToSpenderToApprovalInTree[address(token)][getAddress(sourceChain, "convexCurveMainnetBooster")] = true;
        }

        // Deposit into convexCurveMainnetBooster.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "convexCurveMainnetBooster"),
            false,
            "deposit(uint256,uint256,bool)",
            new address[](0),
            "Deposit into Convex Curve Mainnet Booster",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Withdraw from rewardsContract.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            rewardsContract,
            false,
            "withdrawAndUnwrap(uint256,bool)",
            new address[](0),
            "Withdraw and unwrap from Convex Curve Rewards Contract",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Get rewards from rewardsContract.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            rewardsContract,
            false,
            "getReward(address,bool)",
            new address[](1),
            "Get rewards from Convex Curve Rewards Contract",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    function _addLeafsForCurveSwapping(ManageLeaf[] memory leafs, address curvePool) internal {
        CurvePool pool = CurvePool(curvePool);
        ERC20 coins0 = ERC20(pool.coins(0));
        ERC20 coins1 = ERC20(pool.coins(1));
        // Approvals.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(coins0),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Curve ", coins0.symbol(), "/", coins1.symbol(), " pool to spend ", coins0.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = curvePool;
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(coins1),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Curve ", coins0.symbol(), "/", coins1.symbol(), " pool to spend ", coins1.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = curvePool;
        // Swapping.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            curvePool,
            false,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            string.concat("Swap using Curve ", coins0.symbol(), "/", coins1.symbol(), " pool"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    function _addLeafsForCurveSwapping3Pool(ManageLeaf[] memory leafs, address curvePool) internal {
        CurvePool pool = CurvePool(curvePool);
        ERC20 coins0 = ERC20(pool.coins(0));
        ERC20 coins1 = ERC20(pool.coins(1));
        ERC20 coins2 = ERC20(pool.coins(2));
        // Approvals.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(coins0),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat(
                "Approve Curve ",
                coins0.symbol(),
                "/",
                coins1.symbol(),
                "/",
                coins2.symbol(),
                " pool to spend ",
                coins0.symbol()
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = curvePool;
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(coins1),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat(
                "Approve Curve ",
                coins0.symbol(),
                "/",
                coins1.symbol(),
                "/",
                coins2.symbol(),
                " pool to spend ",
                coins1.symbol()
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = curvePool;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(coins2),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat(
                "Approve Curve ",
                coins0.symbol(),
                "/",
                coins1.symbol(),
                "/",
                coins2.symbol(),
                " pool to spend ",
                coins2.symbol()
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = curvePool;
        // Swapping.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            curvePool,
            false,
            "exchange(int128,int128,uint256,uint256)",
            new address[](0),
            string.concat("Swap using Curve ", coins0.symbol(), "/", coins1.symbol(), "/", coins2.symbol(), " pool"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= Usual Money =========================================

    function _addUsualMoneyLeafs(ManageLeaf[] memory leafs) internal {
        ERC20 Usd0 = getERC20(sourceChain, "USD0");
        ERC20 Usd0PP = getERC20(sourceChain, "USD0_plus");

        // Approve Usd0PP to spend Usd0.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(Usd0),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Usd0PP to spend ", Usd0.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = address(Usd0PP);

        // Call mint on Usd0PP.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(Usd0PP),
            false,
            "mint(uint256)",
            new address[](0),
            string.concat("Mint Usd0PP"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Call unwrap on Usd0PP.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(Usd0PP),
            false,
            "unwrap()",
            new address[](0),
            string.concat("Unwrap Usd0PP"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= Treehouse =========================================

    function _addTreehouseLeafs(
        ManageLeaf[] memory leafs,
        ERC20[] memory routerTokensIn,
        address router,
        address redemptionContract,
        ERC20 tAsset,
        address poolAddress,
        uint256 coinCount,
        address gauge
    ) internal {
        for (uint256 i; i < routerTokensIn.length; ++i) {
            // Approve Treehouse Router to spend tokens in.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(routerTokensIn[i]),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Treehouse Router to spend ", routerTokensIn[i].symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = router;

            // Deposit into Treehouse contract using router.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                router,
                false,
                "deposit(address,uint256)",
                new address[](1),
                string.concat("Deposit into Treehouse contract using router with ", routerTokensIn[i].symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(routerTokensIn[i]);
        }

        // Approve redemption contract to spend tAsset.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(tAsset),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve redemption contract to spend ", tAsset.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = redemptionContract;

        // Redeem tAsset.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            redemptionContract,
            false,
            "redeem(uint96)",
            new address[](0),
            string.concat("Redeem ", tAsset.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Finalize redeem.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            redemptionContract,
            false,
            "finalizeRedeem(uint256)",
            new address[](0),
            string.concat("Finalize redeem ", tAsset.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        _addCurveLeafs(leafs, poolAddress, coinCount, gauge);
    }

    // ========================================= StandardBridge =========================================

    error StandardBridge__LocalAndRemoteTokensLengthMismatch();

    function _addStandardBridgeLeafs(
        ManageLeaf[] memory leafs,
        string memory destination,
        address destinationCrossDomainMessenger,
        address sourceResolvedDelegate,
        address sourceStandardBridge,
        address sourcePortal,
        ERC20[] memory localTokens,
        ERC20[] memory remoteTokens
    ) internal virtual {
        if (localTokens.length != remoteTokens.length) {
            revert StandardBridge__LocalAndRemoteTokensLengthMismatch();
        }
        // Approvals
        for (uint256 i; i < localTokens.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(localTokens[i]),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve StandardBridge to spend ", localTokens[i].symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = sourceStandardBridge;
        }

        // ERC20 bridge leafs.
        for (uint256 i; i < localTokens.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                sourceStandardBridge,
                false,
                "bridgeERC20To(address,address,address,uint256,uint32,bytes)",
                new address[](3),
                string.concat("Bridge ", localTokens[i].symbol(), " from ", sourceChain, " to ", destination),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(localTokens[i]);
            leafs[leafIndex].argumentAddresses[1] = address(remoteTokens[i]);
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        }

        if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(mantle))) {
            // Mantle uses a nonstand `bridgeETHTo` function on their L2.
            // Bridge ETH.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                sourceStandardBridge,
                false,
                "bridgeETHTo(uint256,address,uint32,bytes)",
                new address[](1),
                string.concat("Bridge ETH from ", sourceChain, " to ", destination),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        } else {
            // Bridge ETH.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                sourceStandardBridge,
                true,
                "bridgeETHTo(address,uint32,bytes)",
                new address[](1),
                string.concat("Bridge ETH from ", sourceChain, " to ", destination),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        }

        // If we are generating leafs for some L2 back to mainnet, these leafs are not needed.
        if (keccak256(abi.encode(destination)) != keccak256(abi.encode(mainnet))) {
            if (keccak256(abi.encode(destination)) == keccak256(abi.encode(mantle))) {
                // Prove withdrawal transaction.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    sourcePortal,
                    false,
                    "proveWithdrawalTransaction((uint256,address,address,uint256,uint256,uint256,bytes),uint256,(bytes32,bytes32,bytes32,bytes32),bytes[])",
                    new address[](2),
                    string.concat("Prove withdrawal transaction from ", destination, " to ", sourceChain),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = destinationCrossDomainMessenger;
                leafs[leafIndex].argumentAddresses[1] = sourceResolvedDelegate;

                // Finalize withdrawal transaction.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    sourcePortal,
                    false,
                    "finalizeWithdrawalTransaction((uint256,address,address,uint256,uint256,uint256,bytes))",
                    new address[](2),
                    string.concat("Finalize withdrawal transaction from ", destination, " to ", sourceChain),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = destinationCrossDomainMessenger;
                leafs[leafIndex].argumentAddresses[1] = sourceResolvedDelegate;
            } else {
                // Prove withdrawal transaction.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    sourcePortal,
                    false,
                    "proveWithdrawalTransaction((uint256,address,address,uint256,uint256,bytes),uint256,(bytes32,bytes32,bytes32,bytes32),bytes[])",
                    new address[](2),
                    string.concat("Prove withdrawal transaction from ", destination, " to ", sourceChain),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = destinationCrossDomainMessenger;
                leafs[leafIndex].argumentAddresses[1] = sourceResolvedDelegate;

                // Finalize withdrawal transaction.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    sourcePortal,
                    false,
                    "finalizeWithdrawalTransaction((uint256,address,address,uint256,uint256,bytes))",
                    new address[](2),
                    string.concat("Finalize withdrawal transaction from ", destination, " to ", sourceChain),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = destinationCrossDomainMessenger;
                leafs[leafIndex].argumentAddresses[1] = sourceResolvedDelegate;
            }
        }
    }

    function _addLidoStandardBridgeLeafs(
        ManageLeaf[] memory leafs,
        string memory destination,
        address destinationCrossDomainMessenger,
        address sourceResolvedDelegate,
        address sourceStandardBridge,
        address sourcePortal
    ) internal virtual {
        ERC20 localToken = getERC20(sourceChain, "WSTETH");
        ERC20 remoteToken = getERC20(destination, "WSTETH");
        if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(mainnet))) {
            // Approvals
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(localToken),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve StandardBridge to spend ", localToken.symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = sourceStandardBridge;

            // ERC20 bridge leafs.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                sourceStandardBridge,
                false,
                "depositERC20To(address,address,address,uint256,uint32,bytes)",
                new address[](3),
                string.concat("Bridge ", localToken.symbol(), " from ", sourceChain, " to ", destination),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(localToken);
            leafs[leafIndex].argumentAddresses[1] = address(remoteToken);
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            // Prove withdrawal transaction.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                sourcePortal,
                false,
                "proveWithdrawalTransaction((uint256,address,address,uint256,uint256,bytes),uint256,(bytes32,bytes32,bytes32,bytes32),bytes[])",
                new address[](2),
                string.concat("Prove withdrawal transaction from ", destination, " to ", sourceChain),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = destinationCrossDomainMessenger;
            leafs[leafIndex].argumentAddresses[1] = sourceResolvedDelegate;

            // Finalize withdrawal transaction.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                sourcePortal,
                false,
                "finalizeWithdrawalTransaction((uint256,address,address,uint256,uint256,bytes))",
                new address[](2),
                string.concat("Finalize withdrawal transaction from ", destination, " to ", sourceChain),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = destinationCrossDomainMessenger;
            leafs[leafIndex].argumentAddresses[1] = sourceResolvedDelegate;
        } else if (keccak256(abi.encode(destination)) == keccak256(abi.encode(mainnet))) {
            // We are bridging back to mainnet.
            // Approve L2 ERC20 Token Bridge to spent wstETH.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(localToken),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve L2 ERC20 Token Bridge to spend ", localToken.symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = sourceStandardBridge;

            // call withdrawTo.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                sourceStandardBridge,
                false,
                "withdrawTo(address,address,uint256,uint32,bytes)",
                new address[](2),
                string.concat("Withdraw wstETH to ", destination),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(localToken);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }
    }

    // ========================================= Arbitrum Native Bridge =========================================

    /// @notice When sourceChain is arbitrum bridgeAssets MUST be mainnet addresses.
    function _addArbitrumNativeBridgeLeafs(ManageLeaf[] memory leafs, ERC20[] memory bridgeAssets) internal {
        if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(mainnet))) {
            // Bridge ERC20 Assets to Arbitrum
            for (uint256 i; i < bridgeAssets.length; i++) {
                address spender = address(bridgeAssets[i]) == getAddress(sourceChain, "WETH")
                    ? getAddress(sourceChain, "arbitrumWethGateway")
                    : getAddress(sourceChain, "arbitrumL1ERC20Gateway");
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(bridgeAssets[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Arbitrum L1 Gateway to spend ", bridgeAssets[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = spender;
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "arbitrumL1GatewayRouter"),
                    true,
                    "outboundTransfer(address,address,uint256,uint256,uint256,bytes)",
                    new address[](2),
                    string.concat("Bridge ", bridgeAssets[i].symbol(), " to Arbitrum"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = address(bridgeAssets[i]);
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "arbitrumL1GatewayRouter"),
                    true,
                    "outboundTransferCustomRefund(address,address,address,uint256,uint256,uint256,bytes)",
                    new address[](3),
                    string.concat("Bridge ", bridgeAssets[i].symbol(), " to Arbitrum"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = address(bridgeAssets[i]);
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
                leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            }
            // Create Retryable Ticket
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "arbitrumDelayedInbox"),
                false,
                "createRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,bytes)",
                new address[](3),
                "Create retryable ticket for Arbitrum",
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            // Unsafe Create Retryable Ticket
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "arbitrumDelayedInbox"),
                false,
                "unsafeCreateRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,bytes)",
                new address[](3),
                "Unsafe Create retryable ticket for Arbitrum",
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            // Create Retryable Ticket
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "arbitrumDelayedInbox"),
                true,
                "createRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,bytes)",
                new address[](3),
                "Create retryable ticket for Arbitrum",
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            // Unsafe Create Retryable Ticket
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "arbitrumDelayedInbox"),
                true,
                "unsafeCreateRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,bytes)",
                new address[](3),
                "Unsafe Create retryable ticket for Arbitrum",
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            // Execute Transaction For ERC20 claim.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "arbitrumOutbox"),
                false,
                "executeTransaction(bytes32[],uint256,address,address,uint256,uint256,uint256,uint256,bytes)",
                new address[](2),
                "Execute transaction to claim ERC20",
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(arbitrum, "arbitrumL2Sender");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "arbitrumL1ERC20Gateway");

            // Execute Transaction For ETH claim.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "arbitrumOutbox"),
                false,
                "executeTransaction(bytes32[],uint256,address,address,uint256,uint256,uint256,uint256,bytes)",
                new address[](2),
                "Execute transaction to claim ETH",
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        } else if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(arbitrum))) {
            // ERC20 bridge withdraws.
            for (uint256 i; i < bridgeAssets.length; ++i) {
                // outboundTransfer
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "arbitrumL2GatewayRouter"),
                    false,
                    "outboundTransfer(address,address,uint256,bytes)",
                    new address[](2),
                    string.concat("Withdraw ", vm.toString(address(bridgeAssets[i])), " from Arbitrum"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = address(bridgeAssets[i]);
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            }

            // WithdrawEth
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "arbitrumSys"),
                true,
                "withdrawEth(address)",
                new address[](1),
                "Withdraw ETH from Arbitrum",
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            // Redeem
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "arbitrumRetryableTx"),
                false,
                "redeem(bytes32)",
                new address[](0),
                "Redeem retryable ticket on Arbitrum",
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
        } else {
            revert("Unsupported chain for Arbitrum Native Bridge");
        }
    }

    // ========================================= Linea Native Bridge =========================================

    function _addLineaNativeBridgeLeafs(
        ManageLeaf[] memory leafs,
        string memory destination,
        ERC20[] memory localTokens
    ) internal {
        // Approve the source chains tokenBridge to spend local tokens.
        for (uint256 i; i < localTokens.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(localTokens[i]),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Linea ", sourceChain, " tokenBridge to spend ", localTokens[i].symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "tokenBridge");

            // Call bridgeToken to bridge the token.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "tokenBridge"),
                false,
                "bridgeToken(address,uint256,address)",
                new address[](2),
                string.concat("Bridge ", localTokens[i].symbol(), " from ", sourceChain, " to ", destination),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(localTokens[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "tokenBridge"),
                true,
                "bridgeToken(address,uint256,address)",
                new address[](2),
                string.concat("Bridge ", localTokens[i].symbol(), " from ", sourceChain, " to ", destination),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(localTokens[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }

        if (localTokens.length > 0) {
            if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(mainnet))) {
                // Call claimMessageWithProof to handle claiming ERC20s.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "lineaMessageService"),
                    false,
                    "claimMessageWithProof((bytes32[],uint256,uint32,address,address,uint256,uint256,address,bytes32,bytes))",
                    new address[](3),
                    string.concat("Claim ERC20s from ", destination, " Token Bridge to ", sourceChain, " Token Bridge"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(destination, "tokenBridge");
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "tokenBridge");
                leafs[leafIndex].argumentAddresses[2] = address(0);
            } else if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(linea))) {
                // Use claimMessage Leaf instead of claimMessageWithProof.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "lineaMessageService"),
                    false,
                    "claimMessage(address,address,uint256,uint256,address,bytes,uint256)",
                    new address[](3),
                    string.concat("Claim ERC20s from ", destination, " Token Bridge to ", sourceChain, " Token Bridge"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(destination, "tokenBridge");
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "tokenBridge");
                leafs[leafIndex].argumentAddresses[2] = address(0);
            }
        }

        // Call sendMessage to send ETH.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "lineaMessageService"),
            true,
            "sendMessage(address,uint256,bytes)",
            new address[](1),
            string.concat("Send ETH from ", sourceChain, " to ", destination),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Call claimMessage to handle claiming ETH.
        if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(mainnet))) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "lineaMessageService"),
                false,
                "claimMessageWithProof((bytes32[],uint256,uint32,address,address,uint256,uint256,address,bytes32,bytes))",
                new address[](3),
                string.concat("Claim ETH from ", destination, " Token Bridge to ", sourceChain, " Token Bridge"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[2] = address(0);
        } else if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(linea))) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "lineaMessageService"),
                false,
                "claimMessage(address,address,uint256,uint256,address,bytes,uint256)",
                new address[](3),
                string.concat("Claim ETH from ", destination, " Token Bridge to ", sourceChain, " Token Bridge"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[2] = address(0);
        }
    }

    // ========================================= Scroll Native Bridge =========================================

    function _addScrollNativeBridgeLeafs(
        ManageLeaf[] memory leafs,
        string memory destination,
        ERC20[] memory localTokens
    ) internal {
        if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(mainnet))) {
            // Add leaf for bridging ETH.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "scrollMessenger"),
                true,
                "sendMessage(address,uint256,bytes,uint256)",
                new address[](1),
                string.concat("Bridge ETH from ", sourceChain, " to ", mainnet),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            // Add leafs for bridging ERC20s.
            for (uint256 i; i < localTokens.length; ++i) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(localTokens[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Scroll Gateway Router to spend ", localTokens[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "scrollGatewayRouter");

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "scrollGatewayRouter"),
                    true,
                    "depositERC20(address,address,uint256,uint256)",
                    new address[](2),
                    string.concat("Bridge ", localTokens[i].symbol(), " from ", sourceChain, " to ", destination),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = address(localTokens[i]);
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            }

            // Add leaf for claiming ETH.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "scrollMessenger"),
                false,
                "relayMessageWithProof(address,address,uint256,uint256,bytes,(uint256,bytes))",
                new address[](2),
                string.concat("Claim ETH from ", destination, " to ", sourceChain),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            // Add leaf for ERC20 claiming.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "scrollMessenger"),
                false,
                "relayMessageWithProof(address,address,uint256,uint256,bytes,(uint256,bytes))",
                new address[](2),
                string.concat("Claim ERC20s from ", destination, " to ", sourceChain),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(destination, "scrollCustomERC20Gateway");
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "scrollCustomERC20Gateway");
        } else if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(scroll))) {
            // Add leafs for withdrawing ETH.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "scrollMessenger"),
                true,
                "sendMessage(address,uint256,bytes,uint256)",
                new address[](1),
                string.concat("Bridge ETH from ", sourceChain, " to ", destination),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            // Add leafs for withdrawing ERC20s.
            for (uint256 i; i < localTokens.length; ++i) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "scrollGatewayRouter"),
                    false,
                    "withdrawERC20(address,address,uint256,uint256)",
                    new address[](2),
                    string.concat("Withdraw ", localTokens[i].symbol(), " from ", sourceChain, " to ", destination),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = address(localTokens[i]);
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            }
        }
    }

    // ========================================= CCIP Send =========================================

    function _addCcipBridgeLeafs(
        ManageLeaf[] memory leafs,
        uint64 destinationChainId,
        ERC20[] memory bridgeAssets,
        ERC20[] memory feeTokens
    ) internal {
        // Bridge ERC20 Assets
        for (uint256 i; i < feeTokens.length; i++) {
            if (!tokenToSpenderToApprovalInTree[address(feeTokens[i])][getAddress(sourceChain, "ccipRouter")]) {
                // Add fee token approval.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(feeTokens[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve ", sourceChain, " CCIP Router to spend ", feeTokens[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "ccipRouter");
                tokenToSpenderToApprovalInTree[address(feeTokens[i])][getAddress(sourceChain, "ccipRouter")] = true;
            }
            for (uint256 j; j < bridgeAssets.length; j++) {
                if (!tokenToSpenderToApprovalInTree[address(bridgeAssets[j])][getAddress(sourceChain, "ccipRouter")]) {
                    // Add bridge asset approval.
                    unchecked {
                        leafIndex++;
                    }
                    leafs[leafIndex] = ManageLeaf(
                        address(bridgeAssets[j]),
                        false,
                        "approve(address,uint256)",
                        new address[](1),
                        string.concat("Approve ", sourceChain, " CCIP Router to spend ", bridgeAssets[j].symbol()),
                        getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                    );
                    leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "ccipRouter");
                    tokenToSpenderToApprovalInTree[address(bridgeAssets[j])][getAddress(sourceChain, "ccipRouter")] =
                        true;
                }
                // Add ccipSend leaf.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "ccipRouter"),
                    false,
                    "ccipSend(uint64,(bytes,bytes,(address,uint256)[],address,bytes))",
                    new address[](4),
                    string.concat(
                        "Bridge ",
                        bridgeAssets[j].symbol(),
                        " to chain ",
                        vm.toString(destinationChainId),
                        " using CCIP"
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = address(uint160(destinationChainId));
                leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
                leafs[leafIndex].argumentAddresses[2] = address(bridgeAssets[j]);
                leafs[leafIndex].argumentAddresses[3] = address(feeTokens[i]);
            }
        }
    }

    // ========================================= PancakeSwap V3 =========================================

    function _addPancakeSwapV3Leafs(ManageLeaf[] memory leafs, address[] memory token0, address[] memory token1)
        internal
    {
        require(token0.length == token1.length, "Token arrays must be of equal length");
        for (uint256 i; i < token0.length; ++i) {
            (token0[i], token1[i]) = token0[i] < token1[i] ? (token0[i], token1[i]) : (token1[i], token0[i]);
            // Approvals
            if (
                !tokenToSpenderToApprovalInTree[token0[i]][getAddress(
                    sourceChain, "pancakeSwapV3NonFungiblePositionManager"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token0[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat(
                        "Approve PancakeSwapV3 NonFungible Position Manager to spend ", ERC20(token0[i]).symbol()
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] =
                    getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager");
                tokenToSpenderToApprovalInTree[token0[i]][getAddress(
                    sourceChain, "pancakeSwapV3NonFungiblePositionManager"
                )] = true;
            }
            if (
                !tokenToSpenderToApprovalInTree[token1[i]][getAddress(
                    sourceChain, "pancakeSwapV3NonFungiblePositionManager"
                )]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token1[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat(
                        "Approve PancakeSwapV3 NonFungible Position Manager to spend ", ERC20(token1[i]).symbol()
                    ),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] =
                    getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager");
                tokenToSpenderToApprovalInTree[token1[i]][getAddress(
                    sourceChain, "pancakeSwapV3NonFungiblePositionManager"
                )] = true;
            }
            if (!tokenToSpenderToApprovalInTree[token0[i]][getAddress(sourceChain, "pancakeSwapV3MasterChefV3")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token0[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve PancakeSwapV3 Master Chef to spend ", ERC20(token0[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pancakeSwapV3MasterChefV3");
                tokenToSpenderToApprovalInTree[token0[i]][getAddress(sourceChain, "pancakeSwapV3MasterChefV3")] = true;
            }
            if (!tokenToSpenderToApprovalInTree[token1[i]][getAddress(sourceChain, "pancakeSwapV3MasterChefV3")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token1[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve PancakeSwapV3 Master Chef to spend ", ERC20(token1[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pancakeSwapV3MasterChefV3");
                tokenToSpenderToApprovalInTree[token1[i]][getAddress(sourceChain, "pancakeSwapV3MasterChefV3")] = true;
            }

            if (!tokenToSpenderToApprovalInTree[token0[i]][getAddress(sourceChain, "pancakeSwapV3Router")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token0[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve PancakeSwapV3 Router to spend ", ERC20(token0[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pancakeSwapV3Router");
                tokenToSpenderToApprovalInTree[token0[i]][getAddress(sourceChain, "pancakeSwapV3Router")] = true;
            }
            if (!tokenToSpenderToApprovalInTree[token1[i]][getAddress(sourceChain, "pancakeSwapV3Router")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token1[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve PancakeSwapV3 Router to spend ", ERC20(token1[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pancakeSwapV3Router");
                tokenToSpenderToApprovalInTree[token1[i]][getAddress(sourceChain, "pancakeSwapV3Router")] = true;
            }

            // Minting
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager"),
                false,
                "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
                new address[](3),
                string.concat(
                    "Mint PancakeSwapV3 ", ERC20(token0[i]).symbol(), " ", ERC20(token1[i]).symbol(), " position"
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            // Increase liquidity
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager"),
                false,
                "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
                new address[](3),
                string.concat(
                    "Add liquidity to PancakeSwapV3 ",
                    ERC20(token0[i]).symbol(),
                    " ",
                    ERC20(token1[i]).symbol(),
                    " position"
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(0);
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = token1[i];
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "pancakeSwapV3MasterChefV3"),
                false,
                "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
                new address[](3),
                string.concat(
                    "Add liquidity to PancakeSwapV3 ",
                    ERC20(token0[i]).symbol(),
                    " ",
                    ERC20(token1[i]).symbol(),
                    " staked position"
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(0);
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = token1[i];

            // Swapping to move tick in pool.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "pancakeSwapV3Router"),
                false,
                "exactInput((bytes,address,uint256,uint256))",
                new address[](3),
                string.concat(
                    "Swap ",
                    ERC20(token0[i]).symbol(),
                    " for ",
                    ERC20(token1[i]).symbol(),
                    " using PancakeSwapV3 router"
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "pancakeSwapV3Router"),
                false,
                "exactInput((bytes,address,uint256,uint256))",
                new address[](3),
                string.concat(
                    "Swap ",
                    ERC20(token1[i]).symbol(),
                    " for ",
                    ERC20(token0[i]).symbol(),
                    " using PancakeSwapV3 router"
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token1[i];
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        }
        // Decrease liquidity
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager"),
            false,
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            new address[](0),
            "Remove liquidity from PancakeSwapV3 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pancakeSwapV3MasterChefV3"),
            false,
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            new address[](0),
            "Remove liquidity from PancakeSwapV3 staked position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager"),
            false,
            "collect((uint256,address,uint128,uint128))",
            new address[](1),
            "Collect fees from PancakeSwapV3 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pancakeSwapV3MasterChefV3"),
            false,
            "collect((uint256,address,uint128,uint128))",
            new address[](1),
            "Collect fees from PancakeSwapV3 staked position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // burn
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager"),
            false,
            "burn(uint256)",
            new address[](0),
            "Burn PancakeSwapV3 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Staking
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pancakeSwapV3NonFungiblePositionManager"),
            false,
            "safeTransferFrom(address,address,uint256)",
            new address[](2),
            "Stake PancakeSwapV3 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "pancakeSwapV3MasterChefV3");

        // Staking harvest.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pancakeSwapV3MasterChefV3"),
            false,
            "harvest(uint256,address)",
            new address[](1),
            "Harvest rewards from PancakeSwapV3 staked postiion",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Unstaking
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pancakeSwapV3MasterChefV3"),
            false,
            "withdraw(uint256,address)",
            new address[](1),
            "Unstake PancakeSwapV3 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Native =========================================

    function _addNativeLeafs(ManageLeaf[] memory leafs) internal {
        // Wrapping
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "WETH"),
            true,
            "deposit()",
            new address[](0),
            "Wrap ETH for wETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "WETH"),
            false,
            "withdraw(uint256)",
            new address[](0),
            "Unwrap wETH for ETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= EtherFi =========================================

    function _addEtherFiLeafs(ManageLeaf[] memory leafs) internal {
        // Approvals
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "EETH"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve WEETH to spend eETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "WEETH");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "EETH"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve EtherFi Liquidity Pool to spend eETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "EETH_LIQUIDITY_POOL");
        // Staking
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "EETH_LIQUIDITY_POOL"),
            true,
            "deposit()",
            new address[](0),
            "Stake ETH for eETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        // Unstaking
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "EETH_LIQUIDITY_POOL"),
            false,
            "requestWithdraw(address,uint256)",
            new address[](1),
            "Request withdrawal from eETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "withdrawalRequestNft"),
            false,
            "claimWithdraw(uint256)",
            new address[](0),
            "Claim eETH withdrawal",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        // Wrapping
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "WEETH"),
            false,
            "wrap(uint256)",
            new address[](0),
            "Wrap eETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "WEETH"),
            false,
            "unwrap(uint256)",
            new address[](0),
            "Unwrap weETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= LIDO =========================================

    function _addLidoLeafs(ManageLeaf[] memory leafs) internal {
        // Approvals
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "STETH"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve WSTETH to spend stETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "WSTETH");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "STETH"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve unstETH to spend stETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "unstETH");
        // Staking
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "STETH"),
            true,
            "submit(address)",
            new address[](1),
            "Stake ETH for stETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = address(0);
        // Unstaking
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "unstETH"),
            false,
            "requestWithdrawals(uint256[],address)",
            new address[](1),
            "Request withdrawals from stETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "unstETH"),
            false,
            "claimWithdrawal(uint256)",
            new address[](0),
            "Claim stETH withdrawal",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "unstETH"),
            false,
            "claimWithdrawals(uint256[],uint256[])",
            new address[](0),
            "Claim stETH withdrawals",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        // Wrapping
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "WSTETH"),
            false,
            "wrap(uint256)",
            new address[](0),
            "Wrap stETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "WSTETH"),
            false,
            "unwrap(uint256)",
            new address[](0),
            "Unwrap wstETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= Frax =========================================

    function _addFraxLeafs(ManageLeaf[] memory leafs) internal {
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "SFRXETH")));
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "FRXETH"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve frxETH Redemption Ticket to spend frxETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "frxETHRedemptionTicket");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "SFRXETH"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve frxETH Redemption Ticket to spend sfrxETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "frxETHRedemptionTicket");

        // Staking
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "frxETHMinter"),
            true,
            "submit()",
            new address[](0),
            "Stake ETH for frxETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Unstaking
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "frxETHRedemptionTicket"),
            false,
            "enterRedemptionQueue(address,uint120)",
            new address[](1),
            "Request withdrawal from frxETH using frxETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "frxETHRedemptionTicket"),
            false,
            "enterRedemptionQueueViaSfrxEth(address,uint120)",
            new address[](1),
            "Request withdrawal from frxETH using sfrxETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Complete withdrawal
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "frxETHRedemptionTicket"),
            false,
            "burnRedemptionTicketNft(uint256,address)",
            new address[](1),
            "Claim frxETH withdrawal",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "frxETHRedemptionTicket"),
            false,
            "earlyBurnRedemptionTicketNft(address,uint256)",
            new address[](1),
            "Cancel frxETH withdrawal with penalty",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Swell Staking =========================================

    function _addSwellStakingLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "SWETH"),
            true,
            "deposit()",
            new address[](0),
            "Stake ETH for swETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "SWETH"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve swEXIT to spend swETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "swEXIT");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "swEXIT"),
            false,
            "createWithdrawRequest(uint256)",
            new address[](0),
            "Create a withdraw request from swETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "swEXIT"),
            false,
            "finalizeWithdrawal(uint256)",
            new address[](0),
            "Finalize a swETH withdraw request",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= Mantle Staking =========================================

    function _addMantleStakingLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "mantleLspStaking"),
            true,
            "stake(uint256)",
            new address[](0),
            "Stake ETH for mETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "METH"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Mantle LSP Staking to spend mETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "mantleLspStaking");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "mantleLspStaking"),
            false,
            "unstakeRequest(uint128,uint128)",
            new address[](0),
            "Request Unstake mETH for ETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "mantleLspStaking"),
            false,
            "claimUnstakeRequest(uint256)",
            new address[](0),
            "Claim Unstake Request for ETH",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= Aave V3 =========================================

    function _addAaveV3Leafs(ManageLeaf[] memory leafs, ERC20[] memory supplyAssets, ERC20[] memory borrowAssets)
        internal
    {
        _addAaveV3ForkLeafs("Aave V3", getAddress(sourceChain, "v3Pool"), leafs, supplyAssets, borrowAssets);
    }

    function _addAaveV3LidoLeafs(ManageLeaf[] memory leafs, ERC20[] memory supplyAssets, ERC20[] memory borrowAssets)
        internal
    {
        _addAaveV3ForkLeafs("Aave V3 Lido", getAddress(sourceChain, "v3LidoPool"), leafs, supplyAssets, borrowAssets);
    }

    function _addSparkLendLeafs(ManageLeaf[] memory leafs, ERC20[] memory supplyAssets, ERC20[] memory borrowAssets)
        internal
    {
        _addAaveV3ForkLeafs("SparkLend", getAddress(sourceChain, "sparkLendPool"), leafs, supplyAssets, borrowAssets);
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
            if (!tokenToSpenderToApprovalInTree[address(supplyAssets[i])][protocolAddress]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(supplyAssets[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat(baseApprovalString, supplyAssets[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = protocolAddress;
                tokenToSpenderToApprovalInTree[address(supplyAssets[i])][protocolAddress] = true;
            }
        }
        for (uint256 i; i < borrowAssets.length; ++i) {
            if (!tokenToSpenderToApprovalInTree[address(borrowAssets[i])][protocolAddress]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(borrowAssets[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat(baseApprovalString, borrowAssets[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = protocolAddress;
                tokenToSpenderToApprovalInTree[address(borrowAssets[i])][protocolAddress] = true;
            }
        }
        // Lending
        for (uint256 i; i < supplyAssets.length; ++i) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                protocolAddress,
                false,
                "supply(address,uint256,address,uint16)",
                new address[](2),
                string.concat("Supply ", supplyAssets[i].symbol(), " to ", protocolName),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(supplyAssets[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }
        // Withdrawing
        for (uint256 i; i < supplyAssets.length; ++i) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                protocolAddress,
                false,
                "withdraw(address,uint256,address)",
                new address[](2),
                string.concat("Withdraw ", supplyAssets[i].symbol(), " from ", protocolName),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(supplyAssets[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }
        // Borrowing
        for (uint256 i; i < borrowAssets.length; ++i) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                protocolAddress,
                false,
                "borrow(address,uint256,uint256,uint16,address)",
                new address[](2),
                string.concat("Borrow ", borrowAssets[i].symbol(), " from ", protocolName),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(borrowAssets[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }
        // Repaying
        for (uint256 i; i < borrowAssets.length; ++i) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                protocolAddress,
                false,
                "repay(address,uint256,uint256,address)",
                new address[](2),
                string.concat("Repay ", borrowAssets[i].symbol(), " to ", protocolName),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(borrowAssets[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }
        // Misc
        for (uint256 i; i < supplyAssets.length; ++i) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                protocolAddress,
                false,
                "setUserUseReserveAsCollateral(address,bool)",
                new address[](1),
                string.concat("Toggle ", supplyAssets[i].symbol(), " as collateral in ", protocolName),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(supplyAssets[i]);
        }
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            protocolAddress,
            false,
            "setUserEMode(uint8)",
            new address[](0),
            string.concat("Set user e-mode in ", protocolName),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= Uniswap V3 =========================================

    function _addUniswapV3Leafs(ManageLeaf[] memory leafs, address[] memory token0, address[] memory token1) internal {
        require(token0.length == token1.length, "Token arrays must be of equal length");
        for (uint256 i; i < token0.length; ++i) {
            (token0[i], token1[i]) = token0[i] < token1[i] ? (token0[i], token1[i]) : (token1[i], token0[i]);
            // Approvals
            if (
                !tokenToSpenderToApprovalInTree[token0[i]][getAddress(sourceChain, "uniswapV3NonFungiblePositionManager")]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token0[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve UniswapV3 NonFungible Position Manager to spend ", ERC20(token0[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniswapV3NonFungiblePositionManager");
                tokenToSpenderToApprovalInTree[token0[i]][getAddress(sourceChain, "uniswapV3NonFungiblePositionManager")]
                = true;
            }
            if (
                !tokenToSpenderToApprovalInTree[token1[i]][getAddress(sourceChain, "uniswapV3NonFungiblePositionManager")]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token1[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve UniswapV3 NonFungible Position Manager to spend ", ERC20(token1[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniswapV3NonFungiblePositionManager");
                tokenToSpenderToApprovalInTree[token1[i]][getAddress(sourceChain, "uniswapV3NonFungiblePositionManager")]
                = true;
            }

            if (!tokenToSpenderToApprovalInTree[token0[i]][getAddress(sourceChain, "uniV3Router")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token0[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve UniswapV3 Router to spend ", ERC20(token0[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniV3Router");
                tokenToSpenderToApprovalInTree[token0[i]][getAddress(sourceChain, "uniV3Router")] = true;
            }
            if (!tokenToSpenderToApprovalInTree[token1[i]][getAddress(sourceChain, "uniV3Router")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token1[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve UniswapV3 Router to spend ", ERC20(token1[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "uniV3Router");
                tokenToSpenderToApprovalInTree[token1[i]][getAddress(sourceChain, "uniV3Router")] = true;
            }

            // Minting
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"),
                false,
                "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
                new address[](3),
                string.concat("Mint UniswapV3 ", ERC20(token0[i]).symbol(), " ", ERC20(token1[i]).symbol(), " position"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            // Increase liquidity
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"),
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
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(0);
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = token1[i];

            // Swapping to move tick in pool.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "uniV3Router"),
                false,
                "exactInput((bytes,address,uint256,uint256,uint256))",
                new address[](3),
                string.concat(
                    "Swap ", ERC20(token0[i]).symbol(), " for ", ERC20(token1[i]).symbol(), " using UniswapV3 router"
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "uniV3Router"),
                false,
                "exactInput((bytes,address,uint256,uint256,uint256))",
                new address[](3),
                string.concat(
                    "Swap ", ERC20(token1[i]).symbol(), " for ", ERC20(token0[i]).symbol(), " using UniswapV3 router"
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token1[i];
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        }
        // Decrease liquidity
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"),
            false,
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            new address[](0),
            "Remove liquidity from UniswapV3 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"),
            false,
            "collect((uint256,address,uint128,uint128))",
            new address[](1),
            "Collect fees from UniswapV3 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // burn
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"),
            false,
            "burn(uint256)",
            new address[](0),
            "Burn UniswapV3 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= Camelot V3 =========================================

    function _addCamelotV3Leafs(ManageLeaf[] memory leafs, address[] memory token0, address[] memory token1) internal {
        require(token0.length == token1.length, "Token arrays must be of equal length");
        for (uint256 i; i < token0.length; ++i) {
            (token0[i], token1[i]) = token0[i] < token1[i] ? (token0[i], token1[i]) : (token1[i], token0[i]);
            // Approvals
            if (
                !tokenToSpenderToApprovalInTree[token0[i]][getAddress(sourceChain, "camelotNonFungiblePositionManager")]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token0[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve CamelotV3 NonFungible Position Manager to spend ", ERC20(token0[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "camelotNonFungiblePositionManager");
                tokenToSpenderToApprovalInTree[token0[i]][getAddress(sourceChain, "camelotNonFungiblePositionManager")]
                = true;
            }
            if (
                !tokenToSpenderToApprovalInTree[token1[i]][getAddress(sourceChain, "camelotNonFungiblePositionManager")]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token1[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve CamelotV3 NonFungible Position Manager to spend ", ERC20(token1[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "camelotNonFungiblePositionManager");
                tokenToSpenderToApprovalInTree[token1[i]][getAddress(sourceChain, "camelotNonFungiblePositionManager")]
                = true;
            }

            if (!tokenToSpenderToApprovalInTree[token0[i]][getAddress(sourceChain, "camelotRouterV3")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token0[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve CamelotV3 Router to spend ", ERC20(token0[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "camelotRouterV3");
                tokenToSpenderToApprovalInTree[token0[i]][getAddress(sourceChain, "camelotRouterV3")] = true;
            }
            if (!tokenToSpenderToApprovalInTree[token1[i]][getAddress(sourceChain, "camelotRouterV3")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token1[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve CamelotV3 Router to spend ", ERC20(token1[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "camelotRouterV3");
                tokenToSpenderToApprovalInTree[token1[i]][getAddress(sourceChain, "camelotRouterV3")] = true;
            }

            // Minting
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "camelotNonFungiblePositionManager"),
                false,
                "mint((address,address,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
                new address[](3),
                string.concat("Mint CamelotV3 ", ERC20(token0[i]).symbol(), " ", ERC20(token1[i]).symbol(), " position"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            // Increase liquidity
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "camelotNonFungiblePositionManager"),
                false,
                "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
                new address[](3),
                string.concat(
                    "Add liquidity to CamelotV3 ",
                    ERC20(token0[i]).symbol(),
                    " ",
                    ERC20(token1[i]).symbol(),
                    " position"
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(0);
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = token1[i];

            // Swapping to move tick in pool.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "camelotRouterV3"),
                false,
                "exactInput((bytes,address,uint256,uint256,uint256))",
                new address[](3),
                string.concat(
                    "Swap ", ERC20(token0[i]).symbol(), " for ", ERC20(token1[i]).symbol(), " using CamelotV3 router"
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "camelotRouterV3"),
                false,
                "exactInput((bytes,address,uint256,uint256,uint256))",
                new address[](3),
                string.concat(
                    "Swap ", ERC20(token1[i]).symbol(), " for ", ERC20(token0[i]).symbol(), " using CamelotV3 router"
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token1[i];
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        }
        // Decrease liquidity
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "camelotNonFungiblePositionManager"),
            false,
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            new address[](0),
            "Remove liquidity from CamelotV3 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "camelotNonFungiblePositionManager"),
            false,
            "collect((uint256,address,uint128,uint128))",
            new address[](1),
            "Collect fees from CamelotV3 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // burn
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "camelotNonFungiblePositionManager"),
            false,
            "burn(uint256)",
            new address[](0),
            "Burn CamelotV3 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= Balancer V2 Flashloans =========================================

    function _addBalancerFlashloanLeafs(ManageLeaf[] memory leafs, address tokenToFlashloan) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "managerAddress"),
            false,
            "flashLoan(address,address[],uint256[],bytes)",
            new address[](2),
            string.concat("Flashloan ", ERC20(tokenToFlashloan).symbol(), " from Balancer Vault"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "managerAddress");
        leafs[leafIndex].argumentAddresses[1] = tokenToFlashloan;
    }

    // ========================================= Pendle Router =========================================
    function _addPendleMarketLeafs(ManageLeaf[] memory leafs, address marketAddress, bool allowLimitOrderFills)
        internal
    {
        PendleMarket market = PendleMarket(marketAddress);
        (address sy, address pt, address yt) = market.readTokens();
        PendleSy SY = PendleSy(sy);
        address[] memory possibleTokensIn = SY.getTokensIn();
        address[] memory possibleTokensOut = SY.getTokensOut();
        string memory underlyingAssetDescriptor;
        {
            // Some pendle markets report underlying assets that are not actually on the source chain, so handle that edge case.
            (, ERC20 underlyingAsset,) = SY.assetInfo();
            if (keccak256(bytes(sourceChain)) == keccak256(bytes(mainnet))) {
                // Underlying asset is a contract on sourceChain.
                underlyingAssetDescriptor = underlyingAsset.symbol();
            } else {
                // Underlying asset is not a contract on targetChain.
                underlyingAssetDescriptor = ERC20(sy).symbol();
            }
        }
        // Approve router to spend all tokens in, skipping zero addresses.
        for (uint256 i; i < possibleTokensIn.length; ++i) {
            if (
                possibleTokensIn[i] != address(0)
                    && !tokenToSpenderToApprovalInTree[possibleTokensIn[i]][getAddress(sourceChain, "pendleRouter")]
            ) {
                ERC20 tokenIn = ERC20(possibleTokensIn[i]);
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    possibleTokensIn[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Pendle router to spend ", tokenIn.symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pendleRouter");
                tokenToSpenderToApprovalInTree[possibleTokensIn[i]][getAddress(sourceChain, "pendleRouter")] = true;
            }
        }
        // Approve router to spend LP, SY, PT, YT
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            marketAddress,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Pendle router to spend LP-", underlyingAssetDescriptor),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pendleRouter");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            sy,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Pendle router to spend ", ERC20(sy).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pendleRouter");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            pt,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Pendle router to spend ", ERC20(pt).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pendleRouter");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            yt,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Pendle router to spend ", ERC20(yt).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pendleRouter");
        // Mint SY using input token.
        for (uint256 i; i < possibleTokensIn.length; ++i) {
            if (possibleTokensIn[i] != address(0)) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "pendleRouter"),
                    false,
                    "mintSyFromToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
                    new address[](6),
                    string.concat("Mint ", ERC20(sy).symbol(), " using ", ERC20(possibleTokensIn[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
                leafs[leafIndex].argumentAddresses[1] = sy;
                leafs[leafIndex].argumentAddresses[2] = possibleTokensIn[i];
                leafs[leafIndex].argumentAddresses[3] = possibleTokensIn[i];
                leafs[leafIndex].argumentAddresses[4] = address(0);
                leafs[leafIndex].argumentAddresses[5] = address(0);
            }
        }
        // Mint PT and YT using SY.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pendleRouter"),
            false,
            "mintPyFromSy(address,address,uint256,uint256)",
            new address[](2),
            string.concat("Mint ", ERC20(pt).symbol(), " and ", ERC20(yt).symbol(), " from ", ERC20(sy).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = yt;
        // Swap between PT and YT.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pendleRouter"),
            false,
            "swapExactYtForPt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            new address[](2),
            string.concat("Swap ", ERC20(yt).symbol(), " for ", ERC20(pt).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = marketAddress;
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pendleRouter"),
            false,
            "swapExactPtForYt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256))",
            new address[](2),
            string.concat("Swap ", ERC20(pt).symbol(), " for ", ERC20(yt).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = marketAddress;
        // Manage Liquidity.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pendleRouter"),
            false,
            "addLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
            new address[](2),
            string.concat(
                "Mint LP-", underlyingAssetDescriptor, " using ", ERC20(sy).symbol(), " and ", ERC20(pt).symbol()
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = marketAddress;
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pendleRouter"),
            false,
            "removeLiquidityDualSyAndPt(address,address,uint256,uint256,uint256)",
            new address[](2),
            string.concat(
                "Burn LP-", underlyingAssetDescriptor, " for ", ERC20(sy).symbol(), " and ", ERC20(pt).symbol()
            ),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = marketAddress;
        // Burn PT and YT for SY.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pendleRouter"),
            false,
            "redeemPyToSy(address,address,uint256,uint256)",
            new address[](2),
            string.concat("Burn ", ERC20(pt).symbol(), " and ", ERC20(yt).symbol(), " for ", ERC20(sy).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = yt;
        // Redeem SY for output token.
        for (uint256 i; i < possibleTokensOut.length; ++i) {
            if (possibleTokensOut[i] != address(0)) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "pendleRouter"),
                    false,
                    "redeemSyToToken(address,address,uint256,(address,uint256,address,address,(uint8,address,bytes,bool)))",
                    new address[](6),
                    string.concat("Burn ", ERC20(sy).symbol(), " for ", ERC20(possibleTokensOut[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
                leafs[leafIndex].argumentAddresses[1] = sy;
                leafs[leafIndex].argumentAddresses[2] = possibleTokensOut[i];
                leafs[leafIndex].argumentAddresses[3] = possibleTokensOut[i];
                leafs[leafIndex].argumentAddresses[4] = address(0);
                leafs[leafIndex].argumentAddresses[5] = address(0);
            }
        }
        // Harvest rewards.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pendleRouter"),
            false,
            "redeemDueInterestAndRewards(address,address[],address[],address[])",
            new address[](4),
            string.concat("Redeem due interest and rewards for ", underlyingAssetDescriptor, " Pendle"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = sy;
        leafs[leafIndex].argumentAddresses[2] = yt;
        leafs[leafIndex].argumentAddresses[3] = marketAddress;

        // Swap between SY and PT
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pendleRouter"),
            false,
            "swapExactSyForPt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256),(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
            new address[](2),
            string.concat("Swap ", ERC20(sy).symbol(), " for ", ERC20(pt).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = marketAddress;
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pendleRouter"),
            false,
            "swapExactPtForSy(address,address,uint256,uint256,(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
            new address[](2),
            string.concat("Swap ", ERC20(pt).symbol(), " for ", ERC20(sy).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = marketAddress;

        // Swap between SY and YT
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pendleRouter"),
            false,
            "swapExactSyForYt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256),(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
            new address[](2),
            string.concat("Swap ", ERC20(sy).symbol(), " for ", ERC20(yt).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = marketAddress;
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pendleRouter"),
            false,
            "swapExactYtForSy(address,address,uint256,uint256,(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
            new address[](2),
            string.concat("Swap ", ERC20(yt).symbol(), " for ", ERC20(sy).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = marketAddress;

        if (allowLimitOrderFills) {
            // Re-add the swap between SY and PT and YT leaves, but add in the limit order router, and YT in the argumentAddresses.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "pendleRouter"),
                false,
                "swapExactSyForPt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256),(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
                new address[](4),
                string.concat("Swap ", ERC20(sy).symbol(), " for ", ERC20(pt).symbol(), " with limit orders"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = marketAddress;
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "pendleLimitOrderRouter");
            leafs[leafIndex].argumentAddresses[3] = yt;
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "pendleRouter"),
                false,
                "swapExactPtForSy(address,address,uint256,uint256,(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
                new address[](4),
                string.concat("Swap ", ERC20(pt).symbol(), " for ", ERC20(sy).symbol(), " with limit orders"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = marketAddress;
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "pendleLimitOrderRouter");
            leafs[leafIndex].argumentAddresses[3] = yt;

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "pendleRouter"),
                false,
                "swapExactSyForYt(address,address,uint256,uint256,(uint256,uint256,uint256,uint256,uint256),(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
                new address[](4),
                string.concat("Swap ", ERC20(sy).symbol(), " for ", ERC20(yt).symbol(), " with limit orders"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = marketAddress;
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "pendleLimitOrderRouter");
            leafs[leafIndex].argumentAddresses[3] = yt;
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "pendleRouter"),
                false,
                "swapExactYtForSy(address,address,uint256,uint256,(address,uint256,((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],bytes))",
                new address[](4),
                string.concat("Swap ", ERC20(yt).symbol(), " for ", ERC20(sy).symbol(), " with limit orders"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = marketAddress;
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "pendleLimitOrderRouter");
            leafs[leafIndex].argumentAddresses[3] = yt;

            _addPendleLimitOrderLeafs(leafs, marketAddress);
        }
    }

    // ========================================= Pendle Limit Order =========================================

    function _addPendleLimitOrderLeafs(ManageLeaf[] memory leafs, address marketAddress) internal {
        // Approve Limit Order Router to spend yt, pt and sy.
        PendleMarket market = PendleMarket(marketAddress);
        (address sy, address pt, address yt) = market.readTokens();

        if (!tokenToSpenderToApprovalInTree[yt][getAddress(sourceChain, "pendleLimitOrderRouter")]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                yt,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Pendle Limit Order Router to spend ", ERC20(yt).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pendleLimitOrderRouter");
            tokenToSpenderToApprovalInTree[yt][getAddress(sourceChain, "pendleLimitOrderRouter")] = true;
        }

        if (!tokenToSpenderToApprovalInTree[pt][getAddress(sourceChain, "pendleLimitOrderRouter")]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                pt,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Pendle Limit Order Router to spend ", ERC20(pt).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pendleLimitOrderRouter");
            tokenToSpenderToApprovalInTree[pt][getAddress(sourceChain, "pendleLimitOrderRouter")] = true;
        }

        if (!tokenToSpenderToApprovalInTree[sy][getAddress(sourceChain, "pendleLimitOrderRouter")]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                sy,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Pendle Limit Order Router to spend ", ERC20(sy).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pendleLimitOrderRouter");
            tokenToSpenderToApprovalInTree[sy][getAddress(sourceChain, "pendleLimitOrderRouter")] = true;
        }

        // Add fill leaf.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "pendleLimitOrderRouter"),
            false,
            "fill(((uint256,uint256,uint256,uint8,address,address,address,address,uint256,uint256,uint256,bytes),bytes,uint256)[],address,uint256,bytes,bytes)",
            new address[](2),
            string.concat("Fill Limit orders for ", ERC20(sy).symbol(), " Pendle market"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = yt;
    }

    // ========================================= Balancer =========================================

    function _addBalancerLeafs(ManageLeaf[] memory leafs, bytes32 poolId, address gauge) internal {
        BalancerVault bv = BalancerVault(getAddress(sourceChain, "balancerVault"));

        (ERC20[] memory tokens,,) = bv.getPoolTokens(poolId);
        address pool = _getPoolAddressFromPoolId(poolId);
        uint256 tokenCount;
        for (uint256 i; i < tokens.length; i++) {
            if (
                address(tokens[i]) != pool
                    && !tokenToSpenderToApprovalInTree[address(tokens[i])][getAddress(sourceChain, "balancerVault")]
            ) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(tokens[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Balancer Vault to spend ", tokens[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "balancerVault");
                tokenToSpenderToApprovalInTree[address(tokens[i])][getAddress(sourceChain, "balancerVault")] = true;
            }
            tokenCount++;
        }

        // Approve gauge.
        if (!tokenToSpenderToApprovalInTree[pool][gauge]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                pool,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Balancer gauge to spend ", ERC20(pool).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = gauge;
            tokenToSpenderToApprovalInTree[pool][gauge] = true;
        }

        address[] memory addressArguments = new address[](3 + tokenCount);
        addressArguments[0] = pool;
        addressArguments[1] = getAddress(sourceChain, "boringVault");
        addressArguments[2] = getAddress(sourceChain, "boringVault");
        // uint256 j;
        for (uint256 i; i < tokens.length; i++) {
            // if (address(tokens[i]) == pool) continue;
            addressArguments[3 + i] = address(tokens[i]);
            // j++;
        }

        // Join pool
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "balancerVault"),
            false,
            "joinPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
            new address[](addressArguments.length),
            string.concat("Join Balancer pool ", ERC20(pool).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        for (uint256 i; i < addressArguments.length; i++) {
            leafs[leafIndex].argumentAddresses[i] = addressArguments[i];
        }

        // Exit pool
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "balancerVault"),
            false,
            "exitPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
            new address[](addressArguments.length),
            string.concat("Exit Balancer pool ", ERC20(pool).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        for (uint256 i; i < addressArguments.length; i++) {
            leafs[leafIndex].argumentAddresses[i] = addressArguments[i];
        }

        // Deposit into gauge.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            gauge,
            false,
            "deposit(uint256,address)",
            new address[](1),
            string.concat("Deposit ", ERC20(pool).symbol(), " into Balancer gauge"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Withdraw from gauge.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            gauge,
            false,
            "withdraw(uint256)",
            new address[](0),
            string.concat("Withdraw ", ERC20(pool).symbol(), " from Balancer gauge"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        if (keccak256(abi.encode(sourceChain)) == keccak256(abi.encode(mainnet))) {
            // Mint rewards.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "minter"),
                false,
                "mint(address)",
                new address[](1),
                string.concat("Mint rewards from Balancer gauge"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = gauge;
        } else {
            // Call claim_rewards(address) on gauge.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                gauge,
                false,
                "claim_rewards(address)",
                new address[](1),
                string.concat("Claim rewards from Balancer gauge"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        }
    }

    // ========================================= Aura =========================================

    function _addAuraLeafs(ManageLeaf[] memory leafs, address auraDeposit) internal {
        ERC4626 auraVault = ERC4626(auraDeposit);
        ERC20 bpt = auraVault.asset();

        // Approve vault to spend BPT.
        if (!tokenToSpenderToApprovalInTree[address(bpt)][auraDeposit]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(bpt),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve ", auraVault.symbol(), " to spend ", bpt.symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = auraDeposit;
            tokenToSpenderToApprovalInTree[address(bpt)][auraDeposit] = true;
        }

        // Deposit BPT into Aura vault.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            auraDeposit,
            false,
            "deposit(uint256,address)",
            new address[](1),
            string.concat("Deposit ", bpt.symbol(), " into ", auraVault.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Withdraw BPT from Aura vault.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            auraDeposit,
            false,
            "withdraw(uint256,address,address)",
            new address[](2),
            string.concat("Withdraw ", bpt.symbol(), " from ", auraVault.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        // Call getReward.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            auraDeposit,
            false,
            "getReward(address,bool)",
            new address[](1),
            string.concat("Get rewards from ", auraVault.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= MorphoBlue =========================================

    function _addMorphoBlueSupplyLeafs(ManageLeaf[] memory leafs, bytes32 marketId) internal {
        IMB.MarketParams memory marketParams = IMB(getAddress(sourceChain, "morphoBlue")).idToMarketParams(marketId);
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
        if (!tokenToSpenderToApprovalInTree[marketParams.loanToken][getAddress(sourceChain, "morphoBlue")]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                marketParams.loanToken,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve MorhoBlue to spend ", loanToken.symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "morphoBlue");
            tokenToSpenderToApprovalInTree[marketParams.loanToken][getAddress(sourceChain, "morphoBlue")] = true;
        }
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "morphoBlue"),
            false,
            "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            new address[](5),
            string.concat("Supply ", loanToken.symbol(), " to ", morphoBlueMarketName),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
        leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
        leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
        leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
        leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "morphoBlue"),
            false,
            "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
            new address[](6),
            string.concat("Withdraw ", loanToken.symbol(), " from ", morphoBlueMarketName),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
        leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
        leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
        leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
        leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[5] = getAddress(sourceChain, "boringVault");
    }

    function _addMorphoBlueCollateralLeafs(ManageLeaf[] memory leafs, bytes32 marketId) internal {
        IMB.MarketParams memory marketParams = IMB(getAddress(sourceChain, "morphoBlue")).idToMarketParams(marketId);
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
        // Approve MorphoBlue to spend collateral.
        if (!tokenToSpenderToApprovalInTree[marketParams.collateralToken][getAddress(sourceChain, "morphoBlue")]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                marketParams.collateralToken,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve MorhoBlue to spend ", collateralToken.symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "morphoBlue");
            tokenToSpenderToApprovalInTree[marketParams.collateralToken][getAddress(sourceChain, "morphoBlue")] = true;
        }
        // Approve morpho blue to spend loan token.
        if (!tokenToSpenderToApprovalInTree[marketParams.collateralToken][getAddress(sourceChain, "morphoBlue")]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                marketParams.loanToken,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve MorhoBlue to spend ", loanToken.symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "morphoBlue");
            tokenToSpenderToApprovalInTree[marketParams.loanToken][getAddress(sourceChain, "morphoBlue")] = true;
        }
        // Supply collateral to MorphoBlue.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "morphoBlue"),
            false,
            "supplyCollateral((address,address,address,address,uint256),uint256,address,bytes)",
            new address[](5),
            string.concat("Supply ", collateralToken.symbol(), " to ", morphoBlueMarketName),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
        leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
        leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
        leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
        leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");

        // Borrow loan token from MorphoBlue.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "morphoBlue"),
            false,
            "borrow((address,address,address,address,uint256),uint256,uint256,address,address)",
            new address[](6),
            string.concat("Borrow ", loanToken.symbol(), " from ", morphoBlueMarketName),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
        leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
        leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
        leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
        leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[5] = getAddress(sourceChain, "boringVault");

        // Repay loan token to MorphoBlue.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "morphoBlue"),
            false,
            "repay((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            new address[](5),
            string.concat("Repay ", loanToken.symbol(), " to ", morphoBlueMarketName),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
        leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
        leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
        leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
        leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");

        // Withdraw collateral from MorphoBlue.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "morphoBlue"),
            false,
            "withdrawCollateral((address,address,address,address,uint256),uint256,address,address)",
            new address[](6),
            string.concat("Withdraw ", collateralToken.symbol(), " from ", morphoBlueMarketName),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = marketParams.loanToken;
        leafs[leafIndex].argumentAddresses[1] = marketParams.collateralToken;
        leafs[leafIndex].argumentAddresses[2] = marketParams.oracle;
        leafs[leafIndex].argumentAddresses[3] = marketParams.irm;
        leafs[leafIndex].argumentAddresses[4] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[5] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= ERC4626 =========================================

    function _addERC4626Leafs(ManageLeaf[] memory leafs, ERC4626 vault) internal {
        ERC20 asset = vault.asset();
        // Approvals
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(asset),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve ", vault.symbol(), " to spend ", asset.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = address(vault);
        // Depositing
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(vault),
            false,
            "deposit(uint256,address)",
            new address[](1),
            string.concat("Deposit ", asset.symbol(), " for ", vault.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        // Withdrawing
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(vault),
            false,
            "withdraw(uint256,address,address)",
            new address[](2),
            string.concat("Withdraw ", asset.symbol(), " from ", vault.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        // Minting
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(vault),
            false,
            "mint(uint256,address)",
            new address[](1),
            string.concat("Mint ", vault.symbol(), " using ", asset.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Redeeming
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(vault),
            false,
            "redeem(uint256,address,address)",
            new address[](2),
            string.concat("Redeem ", vault.symbol(), " for ", asset.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Vault Craft =========================================

    function _addVaultCraftLeafs(ManageLeaf[] memory leafs, ERC4626 vault, address gauge) internal {
        _addERC4626Leafs(leafs, vault);

        // Add leafs for gauge.
        // Approve gauge to spend vault share.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(vault),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve ", vault.symbol(), " gauge to spend", vault.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = gauge;

        // Deposit vault share into gauge.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            gauge,
            false,
            "deposit(uint256,address)",
            new address[](1),
            string.concat("Deposit ", vault.symbol(), " share into gauge"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Withdraw vault share from gauge.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            gauge,
            false,
            "withdraw(uint256)",
            new address[](0),
            string.concat("Withdraw ", vault.symbol(), " share from gauge"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Claim rewards from gauge.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            gauge,
            false,
            "claim_rewards(address)",
            new address[](1),
            string.concat("Claim rewards from gauge"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Gearbox =========================================

    function _addGearboxLeafs(ManageLeaf[] memory leafs, ERC4626 dieselVault, address dieselStaking) internal {
        _addERC4626Leafs(leafs, dieselVault);
        string memory dieselVaultSymbol = dieselVault.symbol();
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(dieselVault),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve s", dieselVaultSymbol, " to spend ", dieselVaultSymbol),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = dieselStaking;
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            dieselStaking,
            false,
            "deposit(uint256)",
            new address[](0),
            string.concat("Deposit ", dieselVaultSymbol, " for s", dieselVaultSymbol),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            dieselStaking,
            false,
            "withdraw(uint256)",
            new address[](0),
            string.concat("Withdraw ", dieselVaultSymbol, " from s", dieselVaultSymbol),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            dieselStaking,
            false,
            "claim()",
            new address[](0),
            string.concat("Claim rewards from s", dieselVaultSymbol),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= EIGEN LAYER LST =========================================

    function _addLeafsForEigenLayerLST(
        ManageLeaf[] memory leafs,
        address lst,
        address strategy,
        address _strategyManager,
        address _delegationManager,
        address operator,
        address rewardsContract,
        address claimerFor
    ) internal {
        // Approvals.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            lst,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Eigen Layer Strategy Manager to spend ", ERC20(lst).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = _strategyManager;
        tokenToSpenderToApprovalInTree[lst][_strategyManager] = true;
        // Depositing.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            _strategyManager,
            false,
            "depositIntoStrategy(address,address,uint256)",
            new address[](2),
            string.concat("Deposit ", ERC20(lst).symbol(), " into Eigen Layer Strategy Manager"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = strategy;
        leafs[leafIndex].argumentAddresses[1] = lst;
        // Request withdraw.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            _delegationManager,
            false,
            "queueWithdrawals((address[],uint256[],address)[])",
            new address[](2),
            string.concat("Request withdraw of ", ERC20(lst).symbol(), " from Eigen Layer Delegation Manager"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = strategy;
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        // Complete withdraw.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            _delegationManager,
            false,
            "completeQueuedWithdrawals((address,address,address,uint256,uint32,address[],uint256[])[],address[][],uint256[],bool[])",
            new address[](5),
            string.concat("Complete withdraw of ", ERC20(lst).symbol(), " from Eigen Layer Delegation Manager"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = address(0);
        leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[3] = strategy;
        leafs[leafIndex].argumentAddresses[4] = lst;

        // Delegation.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            _delegationManager,
            false,
            "delegateTo(address,(bytes,uint256),bytes32)",
            new address[](1),
            string.concat("Delegate to ", vm.toString(operator)),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = operator;

        // Undelegate
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            _delegationManager,
            false,
            "undelegate(address)",
            new address[](1),
            string.concat("Undelegate from ", vm.toString(operator)),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Handle reward claiming.
        if (claimerFor != address(0)) {
            // Add setClaimerFor leaf.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                rewardsContract,
                false,
                "setClaimerFor(address)",
                new address[](1),
                string.concat("Set rewards claimer to ", vm.toString(claimerFor)),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = claimerFor;
        }

        // Add processClaim leaf.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            rewardsContract,
            false,
            "processClaim((uint32,uint32,bytes,(address,bytes32),uint32[],bytes[],(address,uint256)[]),address)",
            new address[](1),
            string.concat("Process claim for ", ERC20(lst).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Swell Simple Staking =========================================

    function _addSwellSimpleStakingLeafs(ManageLeaf[] memory leafs, address asset, address _swellSimpleStaking)
        internal
    {
        // Approval
        if (!tokenToSpenderToApprovalInTree[asset][_swellSimpleStaking]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                asset,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Swell Simple Staking to spend ", ERC20(asset).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = _swellSimpleStaking;
            tokenToSpenderToApprovalInTree[asset][_swellSimpleStaking] = true;
        }
        // deposit
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            _swellSimpleStaking,
            false,
            "deposit(address,uint256,address)",
            new address[](2),
            string.concat("Deposit ", ERC20(asset).symbol(), " into Swell Simple Staking"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = asset;
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        // withdraw
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            _swellSimpleStaking,
            false,
            "withdraw(address,uint256,address)",
            new address[](2),
            string.concat("Withdraw ", ERC20(asset).symbol(), " from Swell Simple Staking"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = asset;
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Corn Staking =========================================

    function _addLeafsForCornStaking(ManageLeaf[] memory leafs, ERC20[] memory assets) internal {
        for (uint256 i; i < assets.length; ++i) {
            // Approve cornSilo to spend asset.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(assets[i]),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Corn Silo to spend ", assets[i].symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "cornSilo");

            if (address(assets[i]) == getAddress(sourceChain, "WBTC")) {
                // Need to add special bitcorn leafs.
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "cornSilo"),
                    false,
                    "mintAndDepositBitcorn(uint256)",
                    new address[](0),
                    string.concat("Deposit ", assets[i].symbol(), " into cornSilo for Bitcorn"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "cornSilo"),
                    false,
                    "redeemBitcorn(uint256)",
                    new address[](0),
                    string.concat("Burn Bitcorn from cornSilo for ", assets[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
            } else {
                // use generic deposit and withdraw
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "cornSilo"),
                    false,
                    "deposit(address,uint256)",
                    new address[](1),
                    string.concat("Deposit ", assets[i].symbol(), " into cornSilo"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = address(assets[i]);

                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    getAddress(sourceChain, "cornSilo"),
                    false,
                    "redeemToken(address,uint256)",
                    new address[](1),
                    string.concat("Withdraw ", assets[i].symbol(), " from cornSilo"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
            }
        }
    }

    // ========================================= Pump Staking =========================================

    function _addLeafsForPumpStaking(ManageLeaf[] memory leafs, address pumpStaking, ERC20 asset) internal {
        // Approve
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(asset),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Pump Staking to spend ", asset.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = pumpStaking;

        // Stake
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            pumpStaking,
            false,
            "stake(uint256)",
            new address[](0),
            string.concat("Stake ", asset.symbol(), " into Pump Staking"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Unstake Request
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            pumpStaking,
            false,
            "unstakeRequest(uint256)",
            new address[](0),
            string.concat("Request unstake of ", asset.symbol(), " from Pump Staking"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Claim Slot
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            pumpStaking,
            false,
            "claimSlot(uint8)",
            new address[](0),
            string.concat("Claim slot from Pump Staking"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Claim All
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            pumpStaking,
            false,
            "claimAll()",
            new address[](0),
            string.concat("Claim all withdraws from Pump Staking"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Unstake Instant
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            pumpStaking,
            false,
            "unstakeInstant(uint256)",
            new address[](0),
            string.concat("Unstake ", asset.symbol(), " instantly from Pump Staking"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    // ========================================= Satlayer Staking =========================================

    function _addSatlayerStakingLeafs(ManageLeaf[] memory leafs, ERC20[] memory assets) internal {
        address satlayerPool = getAddress(sourceChain, "satlayerPool");
        for (uint256 i; i < assets.length; ++i) {
            // Approval
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(assets[i]),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Satlayer Pool to spend ", ERC20(assets[i]).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = satlayerPool;
            // deposit
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                satlayerPool,
                false,
                "depositFor(address,address,uint256)",
                new address[](2),
                string.concat("Deposit ", ERC20(assets[i]).symbol(), " into Satlayer Pool"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
            // withdraw
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                satlayerPool,
                false,
                "withdraw(address,uint256)",
                new address[](1),
                string.concat("Withdraw ", ERC20(assets[i]).symbol(), " from Satlayer Pool"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
        }
    }

    // ========================================= Zircuit Staking =========================================

    function _addZircuitLeafs(ManageLeaf[] memory leafs, address asset, address _zircuitSimpleStaking) internal {
        // Approval
        if (!tokenToSpenderToApprovalInTree[asset][_zircuitSimpleStaking]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                asset,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Zircuit simple staking to spend ", ERC20(asset).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = _zircuitSimpleStaking;
            tokenToSpenderToApprovalInTree[asset][_zircuitSimpleStaking] = true;
        }
        // deposit
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            _zircuitSimpleStaking,
            false,
            "depositFor(address,address,uint256)",
            new address[](2),
            string.concat("Deposit ", ERC20(asset).symbol(), " into Zircuit simple staking"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = asset;
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        // withdraw
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            _zircuitSimpleStaking,
            false,
            "withdraw(address,uint256)",
            new address[](1),
            string.concat("Withdraw ", ERC20(asset).symbol(), " from Zircuit simple staking"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = asset;
    }

    // ========================================= Ethena Withdraws =========================================

    function _addEthenaSUSDeWithdrawLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "SUSDE"),
            false,
            "cooldownAssets(uint256)",
            new address[](0),
            "Withdraw from sUSDe specifying asset amount.",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "SUSDE"),
            false,
            "cooldownShares(uint256)",
            new address[](0),
            "Withdraw from sUSDe specifying share amount.",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "SUSDE"),
            false,
            "unstake(address)",
            new address[](1),
            "Complete withdraw from sUSDe.",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Elixir Withdraws =========================================

    function _addElixirSdeUSDWithdrawLeafs(ManageLeaf[] memory leafs) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "sdeUSD"),
            false,
            "cooldownAssets(uint256)",
            new address[](0),
            "Withdraw from sdeUSD specifying asset amount.",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "sdeUSD"),
            false,
            "cooldownShares(uint256)",
            new address[](0),
            "Withdraw from sdeUSD specifying share amount.",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "sdeUSD"),
            false,
            "unstake(address)",
            new address[](1),
            "Complete withdraw from sdeUSD.",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Fluid FToken =========================================

    function _addFluidFTokenLeafs(ManageLeaf[] memory leafs, address fToken) internal {
        ERC20 asset = ERC4626(fToken).asset();
        // Approval.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(asset),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Fluid ", ERC20(fToken).symbol(), " to spend ", asset.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = fToken;

        // Depositing
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            fToken,
            false,
            "deposit(uint256,address,uint256)",
            new address[](1),
            string.concat("Deposit ", asset.symbol(), " for ", ERC20(fToken).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        // Withdrawing
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            fToken,
            false,
            "withdraw(uint256,address,address,uint256)",
            new address[](2),
            string.concat("Withdraw ", asset.symbol(), " from ", ERC20(fToken).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        // Minting
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            fToken,
            false,
            "mint(uint256,address,uint256)",
            new address[](1),
            string.concat("Mint ", ERC20(fToken).symbol(), " using ", asset.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // Redeeming
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            fToken,
            false,
            "redeem(uint256,address,address,uint256)",
            new address[](2),
            string.concat("Redeem ", ERC20(fToken).symbol(), " for ", asset.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Symbiotic =========================================

    function _addSymbioticApproveAndDepositLeaf(ManageLeaf[] memory leafs, address defaultCollateral) internal {
        ERC4626 dc = ERC4626(defaultCollateral);
        ERC20 depositAsset = dc.asset();
        // Approve
        if (!tokenToSpenderToApprovalInTree[address(depositAsset)][defaultCollateral]) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(depositAsset),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Symbiotic ", dc.name(), " to spend ", depositAsset.symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = defaultCollateral;
            tokenToSpenderToApprovalInTree[address(depositAsset)][defaultCollateral] = true;
        }
        // Deposit
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            defaultCollateral,
            false,
            "deposit(address,uint256)",
            new address[](1),
            string.concat("Deposit ", depositAsset.symbol(), " into Symbiotic ", ERC20(defaultCollateral).name()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
    }

    function _addSymbioticLeafs(ManageLeaf[] memory leafs, address[] memory defaultCollaterals) internal {
        for (uint256 i; i < defaultCollaterals.length; i++) {
            _addSymbioticApproveAndDepositLeaf(leafs, defaultCollaterals[i]);
            // Withdraw
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                defaultCollaterals[i],
                false,
                "withdraw(address,uint256)",
                new address[](1),
                string.concat(
                    "Withdraw ",
                    ERC20(defaultCollaterals[i]).symbol(),
                    " from Symbiotic ",
                    ERC20(defaultCollaterals[i]).name()
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        }
    }

    function _addSymbioticVaultLeafs(ManageLeaf[] memory leafs, address[] memory vaults, ERC20[] memory assets)
        internal
    {
        for (uint256 i; i < assets.length; i++) {
            // Approve
            if (!tokenToSpenderToApprovalInTree[address(assets[i])][vaults[i]]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(assets[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Symbiotic Vault ", vm.toString(vaults[i]), " to spend ", assets[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = vaults[i];
                tokenToSpenderToApprovalInTree[address(assets[i])][vaults[i]] = true;
            }
            // Deposit
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                vaults[i],
                false,
                "deposit(address,uint256)",
                new address[](1),
                string.concat("Deposit ", assets[i].symbol(), " into Symbiotic Vault ", vm.toString(vaults[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            // Withdraw
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                vaults[i],
                false,
                "withdraw(address,uint256)",
                new address[](1),
                string.concat("Withdraw ", assets[i].symbol(), " from Symbiotic Vault ", vm.toString(vaults[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            // Claim
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                vaults[i],
                false,
                "claim(address,uint256)",
                new address[](1),
                string.concat("Claim withdraw from Symbiotic Vault ", vm.toString(vaults[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

            // ClaimBatch
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                vaults[i],
                false,
                "claimBatch(address,uint256[])",
                new address[](1),
                string.concat("Claim batch withdraw from Symbiotic Vault ", vm.toString(vaults[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        }
    }

    // ========================================= ITB Karak =========================================

    function _addLeafsForITBKarakPositionManager(
        ManageLeaf[] memory leafs,
        address itbDecoderAndSanitizer,
        address positionManager,
        address _karakVault,
        address _vaultSupervisor
    ) internal {
        ERC20 underlying = ERC4626(_karakVault).asset();
        // acceptOwnership
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "acceptOwnership()",
            new address[](0),
            string.concat("Accept ownership of the ITB Contract: ", vm.toString(positionManager)),
            itbDecoderAndSanitizer
        );
        // Transfer all tokens to the ITB contract.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(underlying),
            false,
            "transfer(address,uint256)",
            new address[](1),
            string.concat("Transfer ", underlying.symbol(), " to ITB Contract: ", vm.toString(positionManager)),
            itbDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = positionManager;
        // Approval Karak Vault to spend all tokens.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "approveToken(address,address,uint256)",
            new address[](2),
            string.concat("Approve ", ERC20(_karakVault).name(), " to spend ", underlying.symbol()),
            itbDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = address(underlying);
        leafs[leafIndex].argumentAddresses[1] = _karakVault;
        // Withdraw all tokens
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "withdraw(address,uint256)",
            new address[](1),
            string.concat("Withdraw ", underlying.symbol(), " from ITB Contract: ", vm.toString(positionManager)),
            itbDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = address(underlying);

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "withdrawAll(address)",
            new address[](1),
            string.concat(
                "Withdraw all ", underlying.symbol(), " from the ITB Contract: ", vm.toString(positionManager)
            ),
            itbDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = address(underlying);
        // Update Vault Supervisor.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "updateVaultSupervisor(address)",
            new address[](1),
            "Update the vault supervisor",
            itbDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = _vaultSupervisor;
        // Update position config.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "updatePositionConfig(address,address)",
            new address[](2),
            "Update the position config",
            itbDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = address(underlying);
        leafs[leafIndex].argumentAddresses[1] = _karakVault;
        // Deposit
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager, false, "deposit(uint256,uint256)", new address[](0), "Deposit", itbDecoderAndSanitizer
        );
        // Start Withdrawal
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "startWithdrawal(uint256)",
            new address[](0),
            "Start Withdrawal",
            itbDecoderAndSanitizer
        );
        // Complete Withdrawal
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "completeWithdrawal(uint256,uint256)",
            new address[](0),
            "Complete Withdrawal",
            itbDecoderAndSanitizer
        );
        // Complete Next Withdrawal
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "completeNextWithdrawal(uint256)",
            new address[](0),
            "Complete Next Withdrawal",
            itbDecoderAndSanitizer
        );
        // Complete Next Withdrawals
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "completeNextWithdrawals(uint256)",
            new address[](0),
            "Complete Next Withdrawals",
            itbDecoderAndSanitizer
        );
        // Override Withdrawal Indexes
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "overrideWithdrawalIndexes(uint256,uint256)",
            new address[](0),
            "Override Withdrawal Indexes",
            itbDecoderAndSanitizer
        );
        // Assemble
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager, false, "assemble(uint256)", new address[](0), "Assemble", itbDecoderAndSanitizer
        );
        // Disassemble
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "disassemble(uint256,uint256)",
            new address[](0),
            "Disassemble",
            itbDecoderAndSanitizer
        );
        // Full Disassemble
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "fullDisassemble(uint256)",
            new address[](0),
            "Full Disassemble",
            itbDecoderAndSanitizer
        );
    }

    // ========================================= Fee Claiming =========================================

    function _addLeafsForFeeClaiming(ManageLeaf[] memory leafs, ERC20[] memory feeAssets) internal {
        // Approvals.
        for (uint256 i; i < feeAssets.length; ++i) {
            if (!tokenToSpenderToApprovalInTree[address(feeAssets[i])][getAddress(sourceChain, "accountantAddress")]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    address(feeAssets[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Accountant to spend ", feeAssets[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "accountantAddress");
                tokenToSpenderToApprovalInTree[address(feeAssets[i])][getAddress(sourceChain, "accountantAddress")] =
                    true;
            }
        }
        // Claiming fees.
        for (uint256 i; i < feeAssets.length; ++i) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                getAddress(sourceChain, "accountantAddress"),
                false,
                "claimFees(address)",
                new address[](1),
                string.concat("Claim fees in ", feeAssets[i].symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(feeAssets[i]);
        }
    }

    // ========================================= LayerZero =========================================

    function _addLayerZeroLeafs(ManageLeaf[] memory leafs, ERC20 asset, address oftAdapter, uint32 endpoint) internal {
        if (address(asset) != oftAdapter) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(asset),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve LayerZero to spend ", asset.symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = oftAdapter;
        }
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            oftAdapter,
            true,
            "send((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),(uint256,uint256),address)",
            new address[](3),
            string.concat("Bridge ", asset.symbol(), " to LayerZero endpoint: ", vm.toString(endpoint)),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = address(uint160(endpoint));
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Compound V3 =========================================

    function _addCompoundV3Leafs(
        ManageLeaf[] memory leafs,
        ERC20[] memory collateralAssets,
        address cometAddress,
        address cometRewards
    ) internal {
        IComet comet = IComet(cometAddress);
        ERC20 baseToken = ERC20(comet.baseToken());
        // Handle base token
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(baseToken),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Comet to spend ", baseToken.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = cometAddress;

        // Supply base token
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            cometAddress,
            false,
            "supply(address,uint256)",
            new address[](1),
            string.concat("Supply ", baseToken.symbol(), " to Comet"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = address(baseToken);

        // Withdraw base token
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            cometAddress,
            false,
            "withdraw(address,uint256)",
            new address[](1),
            string.concat("Withdraw ", baseToken.symbol(), " from Comet"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = address(baseToken);

        // Handle collateral assets
        for (uint256 i; i < collateralAssets.length; ++i) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(collateralAssets[i]),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Comet to spend ", collateralAssets[i].symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = cometAddress;

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                cometAddress,
                false,
                "supply(address,uint256)",
                new address[](1),
                string.concat("Supply ", collateralAssets[i].symbol(), " to Comet"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(collateralAssets[i]);

            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                cometAddress,
                false,
                "withdraw(address,uint256)",
                new address[](1),
                string.concat("Withdraw ", collateralAssets[i].symbol(), " from Comet"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(collateralAssets[i]);
        }

        // Claim rewards.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            cometRewards,
            false,
            "claim(address,address,bool)",
            new address[](2),
            "Claim rewards from Comet",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = cometAddress;
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Merkl =========================================

    function _addMerklLeafs(
        ManageLeaf[] memory leafs,
        address merklDistributor,
        address operator,
        ERC20[] memory tokensToClaim
    ) internal {
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            merklDistributor,
            false,
            "toggleOperator(address,address)",
            new address[](2),
            string.concat("Allow ", vm.toString(operator), " to claim merkl rewards"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = operator;
        for (uint256 i; i < tokensToClaim.length; ++i) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                merklDistributor,
                false,
                "claim(address[],address[],uint256[],bytes32[][])",
                new address[](2),
                string.concat("Claim merkl", tokensToClaim[i].symbol(), " rewards"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = address(tokensToClaim[i]);
        }
    }

    // ========================================= VELODROME =========================================
    function _addVelodromeV3Leafs(
        ManageLeaf[] memory leafs,
        address[] memory token0,
        address[] memory token1,
        address nonfungiblePositionManager,
        address[] memory gauges
    ) internal {
        require(token0.length == token1.length && token0.length == gauges.length, "Arrays must be of equal length");
        for (uint256 i; i < token0.length; ++i) {
            (token0[i], token1[i]) = token0[i] < token1[i] ? (token0[i], token1[i]) : (token1[i], token0[i]);
            // Approvals
            if (!tokenToSpenderToApprovalInTree[token0[i]][nonfungiblePositionManager]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token0[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Velodrome NonFungible Position Manager to spend ", ERC20(token0[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = nonfungiblePositionManager;
                tokenToSpenderToApprovalInTree[token0[i]][nonfungiblePositionManager] = true;
            }
            if (!tokenToSpenderToApprovalInTree[token1[i]][nonfungiblePositionManager]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token1[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Velodrome NonFungible Position Manager to spend ", ERC20(token1[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = nonfungiblePositionManager;
                tokenToSpenderToApprovalInTree[token1[i]][nonfungiblePositionManager] = true;
            }

            // Minting
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                nonfungiblePositionManager,
                false,
                "mint((address,address,int24,int24,int24,uint256,uint256,uint256,uint256,address,uint256,uint160))",
                new address[](3),
                string.concat(
                    "Mint VelodromeV3 ", ERC20(token0[i]).symbol(), " ", ERC20(token1[i]).symbol(), " position"
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
            // Increase liquidity
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                nonfungiblePositionManager,
                false,
                "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
                new address[](3),
                string.concat(
                    "Add liquidity to VelodromeV3 ",
                    ERC20(token0[i]).symbol(),
                    " ",
                    ERC20(token1[i]).symbol(),
                    " position"
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(0);
            leafs[leafIndex].argumentAddresses[1] = token0[i];
            leafs[leafIndex].argumentAddresses[2] = token1[i];

            // Approve gauge to spend NFT.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                nonfungiblePositionManager,
                false,
                "approve(address,uint256)",
                new address[](1),
                "Approve gauge to spend VelodromeV3 position",
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = gauges[i];
        }

        // Decrease liquidity
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            nonfungiblePositionManager,
            false,
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
            new address[](0),
            "Remove liquidity from VelodromeV3 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            nonfungiblePositionManager,
            false,
            "collect((uint256,address,uint128,uint128))",
            new address[](1),
            "Collect fees from VelodromeV3 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // burn
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            nonfungiblePositionManager,
            false,
            "burn(uint256)",
            new address[](0),
            "Burn VelodromeV3 position",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        for (uint256 i; i < gauges.length; ++i) {
            // Deposit into Gauge
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                gauges[i],
                false,
                "deposit(uint256)",
                new address[](0),
                string.concat("Deposit into VelodromeV3 gauge ", vm.toString(gauges[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            // Withdraw from Gauge
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                gauges[i],
                false,
                "withdraw(uint256)",
                new address[](0),
                string.concat("Withdraw from VelodromeV3 gauge ", vm.toString(gauges[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            // Get reward
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                gauges[i],
                false,
                "getReward(uint256)",
                new address[](0),
                string.concat("Get reward from VelodromeV3 gauge ", vm.toString(gauges[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                gauges[i],
                false,
                "getReward(address)",
                new address[](1),
                string.concat("Get reward from VelodromeV3 gauge ", vm.toString(gauges[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        }
    }

    function _addVelodromeV2Leafs(
        ManageLeaf[] memory leafs,
        address[] memory token0,
        address[] memory token1,
        address router,
        address[] memory gauges
    ) internal {
        require(token0.length == token1.length && token0.length == gauges.length, "Arrays must be of equal length");

        for (uint256 i; i < token0.length; ++i) {
            (token0[i], token1[i]) = token0[i] < token1[i] ? (token0[i], token1[i]) : (token1[i], token0[i]);

            if (!tokenToSpenderToApprovalInTree[token0[i]][router]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token0[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Velodrome Router to spend ", ERC20(token0[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = router;
                tokenToSpenderToApprovalInTree[token0[i]][router] = true;
            }
            if (!tokenToSpenderToApprovalInTree[token1[i]][router]) {
                unchecked {
                    leafIndex++;
                }
                leafs[leafIndex] = ManageLeaf(
                    token1[i],
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Velodrome Router to spend ", ERC20(token1[i]).symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                leafs[leafIndex].argumentAddresses[0] = router;
                tokenToSpenderToApprovalInTree[token1[i]][router] = true;
            }

            // Add liquidity
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                router,
                false,
                "addLiquidity(address,address,bool,uint256,uint256,uint256,uint256,address,uint256)",
                new address[](3),
                string.concat(
                    "Add liquidity to VelodromeV2 ", ERC20(token0[i]).symbol(), "/", ERC20(token1[i]).symbol()
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");

            // Remove liquidity
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                router,
                false,
                "removeLiquidity(address,address,bool,uint256,uint256,uint256,address,uint256)",
                new address[](3),
                string.concat(
                    "Remove liquidity from VelodromeV2 ", ERC20(token0[i]).symbol(), "/", ERC20(token1[i]).symbol()
                ),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = token0[i];
            leafs[leafIndex].argumentAddresses[1] = token1[i];
            leafs[leafIndex].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        }

        for (uint256 i; i < gauges.length; ++i) {
            // Approve gauge to spend staking token.
            address stakingToken = VelodromV2Gauge(gauges[i]).stakingToken();
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                stakingToken,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve VelodromeV2 Gauge to spend ", ERC20(stakingToken).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = gauges[i];

            // Approve router to spend staking token.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                stakingToken,
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve Velodrome Router to spend ", ERC20(stakingToken).symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = router;

            // Deposit into Gauge
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                gauges[i],
                false,
                "deposit(uint256)",
                new address[](0),
                string.concat("Deposit into VelodromeV2 gauge ", vm.toString(gauges[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            // Withdraw from Gauge
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                gauges[i],
                false,
                "withdraw(uint256)",
                new address[](0),
                string.concat("Withdraw from VelodromeV2 gauge ", vm.toString(gauges[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            // Get reward
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                gauges[i],
                false,
                "getReward(address)",
                new address[](1),
                string.concat("Get reward from VelodromeV2 gauge ", vm.toString(gauges[i])),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        }
    }

    // ========================================= Karak =========================================

    function _addKarakLeafs(ManageLeaf[] memory leafs, address vaultSupervisor, address vault) internal {
        address delegationSupervisor = VaultSupervisor(vaultSupervisor).delegationSupervisor();
        ERC20 underlying = ERC4626(vault).asset();

        // Add leaf to approve karak vault to spend underlying.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            address(underlying),
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Karak Vault to spend ", underlying.symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = vault;

        // Approve vault supervisor to spend vault shares
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vault,
            false,
            "approve(address,uint256)",
            new address[](1),
            string.concat("Approve Vault Supervisor to spend ", ERC4626(vault).symbol(), " shares"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = vaultSupervisor;

        // Add deposit leafs
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vaultSupervisor,
            false,
            "deposit(address,uint256,uint256)",
            new address[](1),
            string.concat("Deposit ", underlying.symbol(), " into ", ERC4626(vault).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = vault;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vaultSupervisor,
            false,
            "gimmieShares(address,uint256)",
            new address[](1),
            string.concat("Gimmie shares into ", ERC4626(vault).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = vault;

        // Add withdraw leafs
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            vaultSupervisor,
            false,
            "returnShares(address,uint256)",
            new address[](1),
            string.concat("Return shares from ", ERC4626(vault).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = vault;

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            delegationSupervisor,
            false,
            "startWithdraw((address[],uint256[],address)[])",
            new address[](2),
            string.concat("Start withdraw of ", underlying.symbol(), " from ", ERC4626(vault).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = vault;
        leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            delegationSupervisor,
            false,
            "finishWithdraw((address,address,uint256,uint256,(address[],uint256[],address))[])",
            new address[](4),
            string.concat("Finish withdraw of ", underlying.symbol(), " from ", ERC4626(vault).symbol()),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        leafs[leafIndex].argumentAddresses[1] = address(0); // Delegation not implemented yet.
        leafs[leafIndex].argumentAddresses[2] = vault;
        leafs[leafIndex].argumentAddresses[3] = getAddress(sourceChain, "boringVault");
    }

    // ========================================= Puppet =========================================

    function _createPuppetLeafs(ManageLeaf[] memory leafs, address puppet)
        internal
        pure
        returns (ManageLeaf[] memory puppetLeafs)
    {
        puppetLeafs = new ManageLeaf[](leafs.length);

        // Iterate through every leaf, and
        // 1) Take the existing target and append it to the end of the argumentAddresses array.
        // 2) Change the target to the puppet contract.

        for (uint256 i; i < leafs.length; ++i) {
            puppetLeafs[i].argumentAddresses = new address[](leafs[i].argumentAddresses.length + 1);
            // Copy over argumentAddresses.
            for (uint256 j; j < leafs[i].argumentAddresses.length; ++j) {
                puppetLeafs[i].argumentAddresses[j] = leafs[i].argumentAddresses[j];
            }
            // Append the target to the end of the argumentAddresses array.
            puppetLeafs[i].argumentAddresses[leafs[i].argumentAddresses.length] = leafs[i].target;
            // Change the target to the puppet contract.
            puppetLeafs[i].target = puppet;
            // Copy over remaning values.
            puppetLeafs[i].canSendValue = leafs[i].canSendValue;
            puppetLeafs[i].signature = leafs[i].signature;
            puppetLeafs[i].description = leafs[i].description;
            puppetLeafs[i].decoderAndSanitizer = leafs[i].decoderAndSanitizer;
        }
    }

    // ========================================= Drone =========================================

    function _addLeafsForDroneTransfers(ManageLeaf[] memory leafs, address drone, ERC20[] memory assets) internal {
        for (uint256 i; i < assets.length; ++i) {
            // Add leaf for BoringVault to transfer to drone.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(assets[i]),
                false,
                "transfer(address,uint256)",
                new address[](1),
                string.concat("Transfer ", assets[i].symbol(), " to drone: ", vm.toString(drone)),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = drone;

            // Add leaf for drone to transfer to BoringVault.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                drone,
                false,
                "transfer(address,uint256)",
                new address[](2),
                string.concat("Transfer ", assets[i].symbol(), " to BoringVault"),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = address(assets[i]);
        }

        // Add leaf so boringVault can withdraw native from drone.
        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            drone,
            false,
            "withdrawNativeFromDrone()",
            new address[](0),
            string.concat("Withdraw native from drone: ", vm.toString(drone)),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
    }

    function _createDroneLeafs(ManageLeaf[] memory leafs, address drone, uint256 startIndex, uint256 endIndex)
        internal
    {
        address boringVault = getAddress(sourceChain, "boringVault");
        // Update boringVault address to be drone, so leafs work as expected.
        setAddress(true, sourceChain, "boringVault", drone);

        // Iterate through every leaf, and
        // 1) Take the existing target and append it to the end of the argumentAddresses array.
        // 2) Change the target to the drone contract.

        for (uint256 i = startIndex; i < endIndex; ++i) {
            uint256 newLength = leafs[i].argumentAddresses.length + 1;
            address[] memory temp = new address[](newLength);
            // Copy argumentAddresses into temporary array.
            for (uint256 j; j < leafs[i].argumentAddresses.length; ++j) {
                temp[j] = leafs[i].argumentAddresses[j];
            }

            // Expand argumentAddresses array by 1.
            leafs[i].argumentAddresses = new address[](newLength);

            // Copy over argumentAddresses into leaf address arguments array.
            for (uint256 j; j < leafs[i].argumentAddresses.length; ++j) {
                leafs[i].argumentAddresses[j] = temp[j];
            }

            // Append the target to the end of the argumentAddresses array.
            leafs[i].argumentAddresses[newLength - 1] = leafs[i].target;

            // Change the target to the puppet contract.
            leafs[i].target = drone;

            // Update Description.
            leafs[i].description = string.concat("(Drone: ", vm.toString(drone), ") ", leafs[i].description);
        }

        // Change boringVault address back to original.
        setAddress(true, sourceChain, "boringVault", boringVault);
    }

    // ========================================= Term Finance =========================================
    // TODO need to use this in the test suite.
    function _addTermFinanceLockOfferLeafs(ManageLeaf[] memory leafs, ERC20[] memory purchaseTokens, address[] memory termAuctionOfferLockerAddresses, address[] memory termRepoLockers)
        internal
    {
        for (uint256 i; i < purchaseTokens.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                    address(purchaseTokens[i]),
                    false,
                    "approve(address,uint256)",
                    new address[](1),
                    string.concat("Approve Term Repo Locker to spend ", purchaseTokens[i].symbol()),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
            leafs[leafIndex].argumentAddresses[0] = termRepoLockers[i];
            tokenToSpenderToApprovalInTree[address(purchaseTokens[i])][termRepoLockers[i]] = true;
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                    termAuctionOfferLockerAddresses[i],
                    false,
                    "lockOffers((bytes32,address,bytes32,uint256,address)[])",
                    new address[](2),
                    string.concat("Submit offer submission to offer locker ", vm.toString(termAuctionOfferLockerAddresses[i])),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
            leafs[leafIndex].argumentAddresses[1] = address(purchaseTokens[i]);
        }
    }

    // TODO need to use this in the test suite.
    function _addTermFinanceUnlockOfferLeafs(ManageLeaf[] memory leafs, address[] memory termAuctionOfferLockerAddresses)
        internal
    {
        for (uint256 i; i < termAuctionOfferLockerAddresses.length; i++) {
            unchecked {
                leafIndex++;
            }
        
            leafs[leafIndex] = ManageLeaf(
                    termAuctionOfferLockerAddresses[i],
                    false,
                    "unlockOffers(bytes32[])",
                    new address[](0),
                    string.concat("Unlock existing offer from offer locker ", vm.toString(termAuctionOfferLockerAddresses[i])),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
        }
    }

    // TODO need to use this in the test suite.
    function _addTermFinanceRevealOfferLeafs(ManageLeaf[] memory leafs, address[] memory termAuctionOfferLockerAddresses)
        internal
    {
        for (uint256 i; i < termAuctionOfferLockerAddresses.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                    termAuctionOfferLockerAddresses[i],
                    false,
                    "revealOffers(bytes32[],uint256[],uint256[])",
                    new address[](0),
                    string.concat("Unlock existing offer from offer locker ", vm.toString(termAuctionOfferLockerAddresses[i])),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
        }
    }

    // TODO need to use this in the test suite.
    function _addTermFinanceRedeemTermRepoTokensLeafs(ManageLeaf[] memory leafs, address[] memory termRepoServicers)
        internal
    {
        for (uint256 i; i < termRepoServicers.length; i++) {
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                    termRepoServicers[i],
                    false,
                    "redeemTermRepoTokens(address,uint256)",
                    new address[](1),
                    string.concat("Redeem TermRepo Tokens from servicer ", vm.toString(termRepoServicers[i])),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        }

    }

    // ========================================= BoringVault Teller =========================================

    function _addTellerLeafs(ManageLeaf[] memory leafs, address teller, ERC20[] memory assets) internal {
        ERC20 boringVault = TellerWithMultiAssetSupport(teller).vault();

        for (uint256 i; i < assets.length; ++i) {
            // Approve BoringVault to spend all assets.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                address(assets[i]),
                false,
                "approve(address,uint256)",
                new address[](1),
                string.concat("Approve ", boringVault.name(), ", to spend ", assets[i].symbol()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(boringVault);

            // BulkDeposit asset.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                teller,
                false,
                "bulkDeposit(address,uint256,uint256,address)",
                new address[](2),
                string.concat("Bulk deposit ", assets[i].symbol(), " into ", boringVault.name()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

            // BulkWithdraw asset.
            unchecked {
                leafIndex++;
            }
            leafs[leafIndex] = ManageLeaf(
                teller,
                false,
                "bulkWithdraw(address,uint256,uint256,address)",
                new address[](2),
                string.concat("Bulk withdraw ", assets[i].symbol(), " from ", boringVault.name()),
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = address(assets[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "boringVault");
        }
    }

    // ========================================= JSON FUNCTIONS =========================================
    // TODO this should pass in a bool or something to generate leafs indicating that we want leaf indexes printed.
    bool addLeafIndex = false;

    function _generateTestLeafs(ManageLeaf[] memory leafs, bytes32[][] memory manageTree) internal {
        string memory filePath = "./leafs/TemporaryLeafs.json";
        addLeafIndex = true;
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
        addLeafIndex = false;
    }
    // TODO look at how deployment json is made, and refactor this to work that way, so files dont need to be formatted.

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
        vm.serializeAddress(metadata, "BoringVaultAddress", getAddress(sourceChain, "boringVault"));
        vm.serializeAddress(
            metadata, "DecoderAndSanitizerAddress", getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        vm.serializeAddress(metadata, "ManagerAddress", getAddress(sourceChain, "managerAddress"));
        vm.serializeAddress(metadata, "AccountantAddress", getAddress(sourceChain, "accountantAddress"));
        string memory finalMetadata = vm.serializeBytes32(metadata, "ManageRoot", manageRoot);

        vm.writeLine(filePath, finalMetadata);
        vm.writeLine(filePath, ",");
        vm.writeLine(filePath, "\"leafs\": [");

        for (uint256 i; i < leafs.length; ++i) {
            string memory leaf = "leaf";
            if (addLeafIndex) vm.serializeUint(leaf, "LeafIndex", i);
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

    error MerkleTreeHelper__DecoderAndSanitizerMissingFunction(string signature);

    function _verifyDecoderImplementsLeafsFunctionSelectors(ManageLeaf[] memory leafs) internal view {
        for (uint256 i; i < leafs.length; ++i) {
            bytes4 selector = bytes4(keccak256(abi.encodePacked(leafs[i].signature)));
            // This is the "selector" for an empty leaf.
            if (selector == 0xc5d24601) continue;
            (bool success, bytes memory returndata) =
                leafs[i].decoderAndSanitizer.staticcall(abi.encodePacked(selector));
            if (!success && returndata.length > 0) {
                // Make sure we did not revert from the `BaseDecoderAndSanitizer__FunctionSelectorNotSupported()` error.
                if (
                    keccak256(returndata)
                        == keccak256(
                            abi.encodePacked(
                                BaseDecoderAndSanitizer.BaseDecoderAndSanitizer__FunctionSelectorNotSupported.selector
                            )
                        )
                ) {
                    revert MerkleTreeHelper__DecoderAndSanitizerMissingFunction(leafs[i].signature);
                }
            }
        }
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

    function _getPoolAddressFromPoolId(bytes32 poolId) internal pure returns (address) {
        return address(uint160(uint256(poolId >> 96)));
    }

    function _getProofsUsingTree(ManageLeaf[] memory manageLeafs, bytes32[][] memory tree)
        internal
        view
        returns (bytes32[][] memory proofs)
    {
        proofs = new bytes32[][](manageLeafs.length);
        for (uint256 i; i < manageLeafs.length; ++i) {
            // Generate manage proof.
            bytes4 selector = bytes4(keccak256(abi.encodePacked(manageLeafs[i].signature)));
            bytes memory rawDigest = abi.encodePacked(
                getAddress(sourceChain, "rawDataDecoderAndSanitizer"),
                manageLeafs[i].target,
                manageLeafs[i].canSendValue,
                selector
            );
            uint256 argumentAddressesLength = manageLeafs[i].argumentAddresses.length;
            for (uint256 j; j < argumentAddressesLength; ++j) {
                rawDigest = abi.encodePacked(rawDigest, manageLeafs[i].argumentAddresses[j]);
            }
            bytes32 leaf = keccak256(rawDigest);
            proofs[i] = _generateProof(leaf, tree);
        }
    }

    function _generateProof(bytes32 leaf, bytes32[][] memory tree) internal pure returns (bytes32[] memory proof) {
        // The length of each proof is the height of the tree - 1.
        uint256 tree_length = tree.length;
        proof = new bytes32[](tree_length - 1);

        // Build the proof
        for (uint256 i; i < tree_length - 1; ++i) {
            // For each layer we need to find the leaf.
            for (uint256 j; j < tree[i].length; ++j) {
                if (leaf == tree[i][j]) {
                    // We have found the leaf, so now figure out if the proof needs the next leaf or the previous one.
                    proof[i] = j % 2 == 0 ? tree[i][j + 1] : tree[i][j - 1];
                    leaf = _hashPair(leaf, proof[i]);
                    break;
                } else if (j == tree[i].length - 1) {
                    // We have reached the end of the layer and have not found the leaf.
                    revert("Leaf not found in tree");
                }
            }
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

interface BalancerVault {
    function getPoolTokens(bytes32) external view returns (ERC20[] memory, uint256[] memory, uint256);
}

interface VelodromV2Gauge {
    function stakingToken() external view returns (address);
}

interface VaultSupervisor {
    function delegationSupervisor() external view returns (address);
}
