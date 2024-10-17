// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {
    CrossChainTellerWithGenericBridge, ERC20
} from "src/base/Roles/CrossChain/CrossChainTellerWithGenericBridge.sol";
import {CCIPReceiver} from "@ccip/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {OApp} from "lib/LayerZero-v2/packages/layerzero-v2/evm/oapp/contracts/oapp/OApp.sol";

contract LayerZeroTeller is CrossChainTellerWithGenericBridge, CCIPReceiver {
    using SafeTransferLib for ERC20;

    // ========================================= STRUCTS =========================================

    /**
     * @notice Stores information about a chain.
     * @param allowMessagesFrom Whether to allow messages from this chain.
     * @param allowMessagesTo Whether to allow messages to this chain.
     * @param targetTeller The address of the target teller on the other chain.
     * @param messageGasLimit The gas limit for messages to this chain.
     */
    struct Chain {
        bool allowMessagesFrom;
        bool allowMessagesTo;
        address targetTeller;
        uint64 messageGasLimit;
    }
    // ========================================= STATE =========================================

    /**
     * @notice Maps chain selector to chain information.
     */
    mapping(uint64 => Chain) public selectorToChains;

    //============================== ERRORS ===============================

    error LayerZeroTeller__MessagesNotAllowedFrom(uint256 chainSelector);
    error LayerZeroTeller__MessagesNotAllowedFromSender(uint256 chainSelector, address sender);
    error LayerZeroTeller__MessagesNotAllowedTo(uint256 chainSelector);
    error LayerZeroTeller__FeeExceedsMax(uint256 chainSelector, uint256 fee, uint256 maxFee);
    error LayerZeroTeller__ZeroMessageGasLimit();

    //============================== EVENTS ===============================

    event ChainAdded(
        uint256 chainSelector,
        bool allowMessagesFrom,
        bool allowMessagesTo,
        address targetTeller,
        uint64 messageGasLimit
    );
    event ChainRemoved(uint256 chainSelector);
    event ChainAllowMessagesFrom(uint256 chainSelector, address targetTeller);
    event ChainAllowMessagesTo(uint256 chainSelector, address targetTeller);
    event ChainStopMessagesFrom(uint256 chainSelector);
    event ChainStopMessagesTo(uint256 chainSelector);
    event ChainSetGasLimit(uint256 chainSelector, uint64 messageGasLimit);

    //============================== IMMUTABLES ===============================

    constructor(address _owner, address _vault, address _accountant, address _weth, address _router)
        CrossChainTellerWithGenericBridge(_owner, _vault, _accountant, _weth)
        CCIPReceiver(_router)
    {}

    // ========================================= ADMIN FUNCTIONS =========================================
    /**
     * @notice Add a chain to the teller.
     * @dev Callable by OWNER_ROLE.
     * @param chainSelector The CCIP chain selector to add.
     * @param allowMessagesFrom Whether to allow messages from this chain.
     * @param allowMessagesTo Whether to allow messages to this chain.
     * @param targetTeller The address of the target teller on the other chain.
     * @param messageGasLimit The gas limit for messages to this chain.
     */
    function addChain(
        uint64 chainSelector,
        bool allowMessagesFrom,
        bool allowMessagesTo,
        address targetTeller,
        uint64 messageGasLimit
    ) external requiresAuth {
        if (allowMessagesTo && messageGasLimit == 0) {
            revert LayerZeroTeller__ZeroMessageGasLimit();
        }
        selectorToChains[chainSelector] = Chain(allowMessagesFrom, allowMessagesTo, targetTeller, messageGasLimit);

        emit ChainAdded(chainSelector, allowMessagesFrom, allowMessagesTo, targetTeller, messageGasLimit);
    }

    /**
     * @notice Remove a chain from the teller.
     * @dev Callable by MULTISIG_ROLE.
     */
    function removeChain(uint64 chainSelector) external requiresAuth {
        delete selectorToChains[chainSelector];

        emit ChainRemoved(chainSelector);
    }

    /**
     * @notice Allow messages from a chain.
     * @dev Callable by OWNER_ROLE.
     */
    function allowMessagesFromChain(uint64 chainSelector, address targetTeller) external requiresAuth {
        Chain storage chain = selectorToChains[chainSelector];
        chain.allowMessagesFrom = true;
        chain.targetTeller = targetTeller;

        emit ChainAllowMessagesFrom(chainSelector, targetTeller);
    }

    /**
     * @notice Allow messages to a chain.
     * @dev Callable by OWNER_ROLE.
     */
    function allowMessagesToChain(uint64 chainSelector, address targetTeller, uint64 messageGasLimit)
        external
        requiresAuth
    {
        if (messageGasLimit == 0) {
            revert LayerZeroTeller__ZeroMessageGasLimit();
        }
        Chain storage chain = selectorToChains[chainSelector];
        chain.allowMessagesTo = true;
        chain.targetTeller = targetTeller;
        chain.messageGasLimit = messageGasLimit;

        emit ChainAllowMessagesTo(chainSelector, targetTeller);
    }

    /**
     * @notice Stop messages from a chain.
     * @dev Callable by MULTISIG_ROLE.
     */
    function stopMessagesFromChain(uint64 chainSelector) external requiresAuth {
        Chain storage chain = selectorToChains[chainSelector];
        chain.allowMessagesFrom = false;

        emit ChainStopMessagesFrom(chainSelector);
    }

    /**
     * @notice Stop messages to a chain.
     * @dev Callable by MULTISIG_ROLE.
     */
    function stopMessagesToChain(uint64 chainSelector) external requiresAuth {
        Chain storage chain = selectorToChains[chainSelector];
        chain.allowMessagesTo = false;

        emit ChainStopMessagesTo(chainSelector);
    }

    /**
     * @notice Set the gas limit for messages to a chain.
     * @dev Callable by OWNER_ROLE.
     */
    function setChainGasLimit(uint64 chainSelector, uint64 messageGasLimit) external requiresAuth {
        if (messageGasLimit == 0) {
            revert LayerZeroTeller__ZeroMessageGasLimit();
        }
        Chain storage chain = selectorToChains[chainSelector];
        chain.messageGasLimit = messageGasLimit;

        emit ChainSetGasLimit(chainSelector, messageGasLimit);
    }
    // ========================================= CCIP RECEIVER =========================================

    /**
     * @notice Implement the CCIPReceiver interface to receive messages from the CCIP router.
     */
    function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal override {
        Chain memory source = selectorToChains[any2EvmMessage.sourceChainSelector];
        if (!source.allowMessagesFrom) {
            revert LayerZeroTeller__MessagesNotAllowedFrom(any2EvmMessage.sourceChainSelector);
        }
        address sender = abi.decode(any2EvmMessage.sender, (address));
        if (source.targetTeller != sender) {
            revert LayerZeroTeller__MessagesNotAllowedFromSender(any2EvmMessage.sourceChainSelector, sender);
        }
        uint256 message = abi.decode(any2EvmMessage.data, (uint256));

        _completeMessageReceive(any2EvmMessage.messageId, message);
    }

    // ========================================= INTERNAL BRIDGE FUNCTIONS =========================================

    /**
     * @notice Sends messages using CCIP router.
     * @dev This function does NOT revert if the `feeToken` is invalid,
     *      rather the CCIP bridge will revert.
     * @dev This function will revert if maxFee is exceeded.
     * @dev This function will revert if destination chain does not allow messages.
     * @param message The message to send.
     * @param bridgeWildCard An abi encoded uint64 containing the destination chain selector.
     * @param feeToken The token to pay the bridge fee in.
     * @param maxFee The maximum fee to pay the bridge.
     */
    function _sendMessage(uint256 message, bytes calldata bridgeWildCard, ERC20 feeToken, uint256 maxFee)
        internal
        override
        returns (bytes32 messageId)
    {
        uint64 destinationSelector = abi.decode(bridgeWildCard, (uint64));
        Chain memory chain = selectorToChains[destinationSelector];
        if (!chain.allowMessagesTo) {
            revert LayerZeroTeller__MessagesNotAllowedTo(destinationSelector);
        }

        // Build the message.
        Client.EVM2AnyMessage memory m =
            _buildMessage(message, chain.targetTeller, address(feeToken), chain.messageGasLimit);

        IRouterClient router = IRouterClient(this.getRouter());

        uint256 fee = router.getFee(destinationSelector, m);

        if (fee > maxFee) {
            revert LayerZeroTeller__FeeExceedsMax(destinationSelector, fee, maxFee);
        }

        feeToken.safeTransferFrom(msg.sender, address(this), fee);
        feeToken.safeApprove(address(router), fee);

        messageId = router.ccipSend(destinationSelector, m);
    }

    /**
     * @notice Preview fee required to bridge shares in a given feeToken.
     * @param message The message to send.
     * @param bridgeWildCard An abi encoded uint64 containing the destination chain selector.
     * @param feeToken The token to pay the bridge fee in.
     */
    function _previewFee(uint256 message, bytes calldata bridgeWildCard, ERC20 feeToken)
        internal
        view
        override
        returns (uint256 fee)
    {
        uint64 destinationSelector = abi.decode(bridgeWildCard, (uint64));
        Chain memory chain = selectorToChains[destinationSelector];
        Client.EVM2AnyMessage memory m =
            _buildMessage(message, chain.targetTeller, address(feeToken), chain.messageGasLimit);

        IRouterClient router = IRouterClient(this.getRouter());

        fee = router.getFee(destinationSelector, m);
    }

    /**
     * @notice Helper function to build a message.
     */
    function _buildMessage(uint256 message, address to, address feeToken, uint64 gasLimit)
        internal
        pure
        returns (Client.EVM2AnyMessage memory m)
    {
        m = Client.EVM2AnyMessage({
            receiver: abi.encode(to),
            data: abi.encode(message),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit and non-strict sequencing mode
                Client.EVMExtraArgsV1({gasLimit: gasLimit /*, strict: false*/ })
            ),
            feeToken: feeToken
        });
    }
}
