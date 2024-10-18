// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {
    CrossChainTellerWithGenericBridge, ERC20
} from "src/base/Roles/CrossChain/CrossChainTellerWithGenericBridge.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {OAppAuth, Origin, MessagingFee, MessagingReceipt} from "@opapp-auth/OAppAuth.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";

contract LayerZeroTeller is CrossChainTellerWithGenericBridge, OAppAuth {
    using SafeTransferLib for ERC20;
    using AddressToBytes32Lib for address;
    using AddressToBytes32Lib for bytes32;

    // ========================================= STRUCTS =========================================

    /**
     * @notice Stores information about a chain.
     * @dev Sender is stored in OAppAuthCore `peers` mapping.
     * @param allowMessagesFrom Whether to allow messages from this chain.
     * @param allowMessagesTo Whether to allow messages to this chain.
     * @param messageGasLimit The gas limit for messages to this chain.
     */
    struct Chain {
        bool allowMessagesFrom;
        bool allowMessagesTo;
        uint64 messageGasLimit;
    }
    // ========================================= STATE =========================================

    /**
     * @notice Maps chain selector to chain information.
     */
    mapping(uint32 => Chain) public idToChains;

    //============================== ERRORS ===============================

    error LayerZeroTeller__MessagesNotAllowedFrom(uint256 chainSelector);
    error LayerZeroTeller__MessagesNotAllowedFromSender(uint256 chainSelector, address sender);
    error LayerZeroTeller__MessagesNotAllowedTo(uint256 chainSelector);
    error LayerZeroTeller__FeeExceedsMax(uint256 chainSelector, uint256 fee, uint256 maxFee);
    error LayerZeroTeller__ZeroMessageGasLimit();
    error LayerZeroTeller__BadFeeToken();

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

    address internal immutable lzToken;

    constructor(
        address _owner,
        address _vault,
        address _accountant,
        address _weth,
        address _lzEndPoint,
        address _delegate,
        address _lzToken
    ) CrossChainTellerWithGenericBridge(_owner, _vault, _accountant, _weth) OAppAuth(_lzEndPoint, _delegate) {
        lzToken = _lzToken;
    }

    // ========================================= ADMIN FUNCTIONS =========================================
    /**
     * @notice Add a chain to the teller.
     * @dev Callable by OWNER_ROLE.
     * @param chainId The LayerZero chain id to add.
     * @param allowMessagesFrom Whether to allow messages from this chain.
     * @param allowMessagesTo Whether to allow messages to this chain.
     * @param targetTeller The address of the target teller on the other chain.
     * @param messageGasLimit The gas limit for messages to this chain.
     */
    function addChain(
        uint32 chainId,
        bool allowMessagesFrom,
        bool allowMessagesTo,
        address targetTeller,
        uint64 messageGasLimit
    ) external requiresAuth {
        if (allowMessagesTo && messageGasLimit == 0) {
            revert LayerZeroTeller__ZeroMessageGasLimit();
        }
        idToChains[chainId] = Chain(allowMessagesFrom, allowMessagesTo, messageGasLimit);
        _setPeer(chainId, targetTeller.toBytes32());

        emit ChainAdded(chainId, allowMessagesFrom, allowMessagesTo, targetTeller, messageGasLimit);
    }

    /**
     * @notice Remove a chain from the teller.
     * @dev Callable by MULTISIG_ROLE.
     */
    function removeChain(uint32 chainId) external requiresAuth {
        delete idToChains[chainId];
        _setPeer(chainId, bytes32(0));

        emit ChainRemoved(chainId);
    }

    /**
     * @notice Allow messages from a chain.
     * @dev Callable by OWNER_ROLE.
     */
    function allowMessagesFromChain(uint32 chainId, address targetTeller) external requiresAuth {
        Chain storage chain = idToChains[chainId];
        chain.allowMessagesFrom = true;
        _setPeer(chainId, targetTeller.toBytes32());

        emit ChainAllowMessagesFrom(chainId, targetTeller);
    }

    /**
     * @notice Allow messages to a chain.
     * @dev Callable by OWNER_ROLE.
     */
    function allowMessagesToChain(uint32 chainId, address targetTeller, uint64 messageGasLimit) external requiresAuth {
        if (messageGasLimit == 0) {
            revert LayerZeroTeller__ZeroMessageGasLimit();
        }
        Chain storage chain = idToChains[chainId];
        chain.allowMessagesTo = true;
        _setPeer(chainId, targetTeller.toBytes32());
        chain.messageGasLimit = messageGasLimit;

        emit ChainAllowMessagesTo(chainId, targetTeller);
    }

    /**
     * @notice Stop messages from a chain.
     * @dev Callable by MULTISIG_ROLE.
     */
    function stopMessagesFromChain(uint32 chainId) external requiresAuth {
        Chain storage chain = idToChains[chainId];
        chain.allowMessagesFrom = false;

        emit ChainStopMessagesFrom(chainId);
    }

    /**
     * @notice Stop messages to a chain.
     * @dev Callable by MULTISIG_ROLE.
     */
    function stopMessagesToChain(uint32 chainId) external requiresAuth {
        Chain storage chain = idToChains[chainId];
        chain.allowMessagesTo = false;

        emit ChainStopMessagesTo(chainId);
    }

    /**
     * @notice Set the gas limit for messages to a chain.
     * @dev Callable by OWNER_ROLE.
     */
    function setChainGasLimit(uint32 chainId, uint64 messageGasLimit) external requiresAuth {
        if (messageGasLimit == 0) {
            revert LayerZeroTeller__ZeroMessageGasLimit();
        }
        Chain storage chain = idToChains[chainId];
        chain.messageGasLimit = messageGasLimit;

        emit ChainSetGasLimit(chainId, messageGasLimit);
    }
    // ========================================= OAppAuthReceiver =========================================

    /**
     * @notice Receive messages from the LayerZero endpoint.
     * @dev `lzReceive` only sanitizes the message sender, but we also need to make sure we are allowing messages
     *      from the source chain.
     */
    function _lzReceive(
        Origin calldata, /*_origin*/
        bytes32 _guid,
        bytes calldata _message,
        address, /*_executor*/
        bytes calldata /*_extraData*/
    ) internal override {
        Chain memory source = idToChains[_origin.srcEid];
        if (!source.allowMessagesFrom) revert LayerZeroTeller__MessagesNotAllowedFrom(_origin.srcEid);
        uint256 message = abi.decode(_message, (uint256));
        _completeMessageReceive(_guid, message);
    }

    // ========================================= INTERNAL BRIDGE FUNCTIONS =========================================

    /**
     * @notice Sends messages using CCIP router.
     * @dev This function does NOT revert if the `feeToken` is invalid,
     *      rather the CCIP bridge will revert.
     * @dev This function will revert if maxFee is exceeded.
     * @dev This function will revert if destination chain does not allow messages.
     * @param message The message to send.
     * @param bridgeWildCard An abi encoded uint32 containing the destination chain id.
     * @param feeToken The token to pay the bridge fee in.
     * @param maxFee The maximum fee to pay the bridge.
     */
    function _sendMessage(uint256 message, bytes calldata bridgeWildCard, ERC20 feeToken, uint256 maxFee)
        internal
        override
        returns (bytes32 messageId)
    {
        uint32 destinationId = abi.decode(bridgeWildCard, (uint32));
        Chain memory chain = idToChains[destinationId];
        if (!chain.allowMessagesTo) {
            revert LayerZeroTeller__MessagesNotAllowedTo(destinationId);
        }
        bytes memory m = abi.encode(message);
        MessagingFee memory fee = _quote(destinationId, m, hex"", address(feeToken) != NATIVE);
        if (address(feeToken) == NATIVE) {
            if (fee.nativeFee > maxFee) {
                revert LayerZeroTeller__FeeExceedsMax(destinationId, fee.nativeFee, maxFee);
            }
        } else if (address(feeToken) == lzToken) {
            if (fee.lzTokenFee > maxFee) {
                revert LayerZeroTeller__FeeExceedsMax(destinationId, fee.lzTokenFee, maxFee);
            }
        } else {
            revert LayerZeroTeller__BadFeeToken();
        }
        MessagingReceipt memory receipt = _lzSend(destinationId, m, hex"", fee, msg.sender);

        messageId = receipt.guid;
    }

    /**
     * @notice Preview fee required to bridge shares in a given feeToken.
     * @param message The message to send.
     * @param bridgeWildCard An abi encoded uint32 containing the destination chain id.
     * @param feeToken The token to pay the bridge fee in.
     */
    function _previewFee(uint256 message, bytes calldata bridgeWildCard, ERC20 feeToken)
        internal
        view
        override
        returns (uint256 fee)
    {
        // Make sure feeToken is either NATIVE or lzToken.
        if (address(feeToken) != NATIVE && address(feeToken) != lzToken) {
            revert LayerZeroTeller__BadFeeToken();
        }
        uint32 destinationId = abi.decode(bridgeWildCard, (uint32));
        Chain memory chain = idToChains[destinationId];
        if (!chain.allowMessagesTo) {
            revert LayerZeroTeller__MessagesNotAllowedTo(destinationId);
        }
        bytes memory m = abi.encode(message);
        MessagingFee memory messageFee = _quote(destinationId, m, hex"", address(feeToken) != NATIVE);

        fee = address(feeToken) == NATIVE ? messageFee.nativeFee : messageFee.lzTokenFee;
    }
}
