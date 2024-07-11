pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {ChainValues} from "test/resources/ChainValues.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "forge-std/Base.sol";

contract MerkleTreeHelper is CommonBase, ChainValues {
    string public sourceChain;
    address public _boringVault;
    address public _rawDataDecoderAndSanitizer;
    address public _managerAddress;
    address public _accountantAddress;
    uint256 leafIndex = type(uint256).max;

    mapping(address => mapping(address => bool)) public tokenToSpenderToApprovalInTree;
    mapping(address => mapping(address => bool)) public oneInchSellTokenToBuyTokenToInTree;

    function setSourceChainName(string memory _chain) internal {
        sourceChain = _chain;
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

        // If we are generating leafs for some L2 back to mainnet, these leafs are not needed.
        if (keccak256(abi.encode(destination)) != keccak256(abi.encode(mainnet))) {
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

    // ========================================= JSON FUNCTIONS =========================================
    function _generateTestLeafs(ManageLeaf[] memory leafs, bytes32[][] memory manageTree) internal {
        string memory filePath = "./leafs/TemporaryLeafs.json";
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function _generateLeafs(
        string memory filePath,
        ManageLeaf[] memory leafs,
        bytes32 manageRoot,
        bytes32[][] memory manageTree
    ) internal {
        _boringVault = getAddress(sourceChain, "boringVault");
        _rawDataDecoderAndSanitizer = getAddress(sourceChain, "rawDataDecoderAndSanitizer");
        _managerAddress = getAddress(sourceChain, "managerAddress");
        _accountantAddress = getAddress(sourceChain, "accountantAddress");

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
            vm.serializeUint(leaf, "LeafIndex", i);
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
