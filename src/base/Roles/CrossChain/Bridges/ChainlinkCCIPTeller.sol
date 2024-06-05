// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {
    CrossChainTellerWithGenericBridge, ERC20
} from "src/base/Roles/CrossChain/CrossChainTellerWithGenericBridge.sol";
import {CCIPReceiver} from "@ccip/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";

abstract contract ChainlinkCCIPTeller is CrossChainTellerWithGenericBridge, CCIPReceiver {
    using SafeTransferLib for ERC20;

    // ========================================= STRUCTS =========================================

    struct Chain {
        bool allowMessagesFrom;
        address fromAddress;
        bool allowMessagesTo;
        address toAddress;
    }
    // ========================================= CONSTANTS =========================================
    // ========================================= STATE =========================================

    mapping(uint256 => Chain) public idToChains;
    //============================== ERRORS ===============================

    error ChainlinkCCIPTeller__MessagesNotAllowedFrom(uint256 chainId);
    error ChainlinkCCIPTeller__MessagesNotAllowedFromSender(uint256 chainId, address sender);
    error ChainlinkCCIPTeller__MessagesNotAllowedTo(uint256 chainId);
    error ChainlinkCCIPTeller__FeeExceedsMax(uint256 chainId, uint256 fee, uint256 maxFee);
    //============================== EVENTS ===============================

    event ChainAdded(
        uint256 chainId, bool allowMessagesFrom, address fromAddress, bool allowMessagesTo, address toAddress
    );
    //============================== IMMUTABLES ===============================
    /**
     * @notice The message gas limit to use for CCIP messages.
     */

    uint256 public immutable messageGasLimit;

    constructor(
        address _owner,
        address _vault,
        address _accountant,
        address _weth,
        address _router,
        uint256 _messageGasLimit
    ) CrossChainTellerWithGenericBridge(_owner, _vault, _accountant, _weth) CCIPReceiver(_router) {
        messageGasLimit = _messageGasLimit;
    }

    // ========================================= ADMIN FUNCTIONS =========================================
    // TODO methods to change params of a chain.
    function addChain(
        uint256 chainId,
        bool allowMessagesFrom,
        address fromAddress,
        bool allowMessagesTo,
        address toAddress
    ) external requiresAuth {
        idToChains[chainId] = Chain(allowMessagesFrom, fromAddress, allowMessagesTo, toAddress);

        emit ChainAdded(chainId, allowMessagesFrom, fromAddress, allowMessagesTo, toAddress);
    }
    // ========================================= CCIP RECEIVER =========================================

    function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal override {
        Chain memory source = idToChains[any2EvmMessage.sourceChainSelector];
        if (!source.allowMessagesFrom) {
            revert ChainlinkCCIPTeller__MessagesNotAllowedFrom(any2EvmMessage.sourceChainSelector);
        }
        address sender = abi.decode(any2EvmMessage.sender, (address));
        if (source.fromAddress != sender) {
            revert ChainlinkCCIPTeller__MessagesNotAllowedFromSender(any2EvmMessage.sourceChainSelector, sender);
        }
        uint256 message = abi.decode(any2EvmMessage.data, (uint256));

        _completeMessageReceive(any2EvmMessage.messageId, message);
    }

    // ========================================= VIEW FUNCTIONS =========================================
    // /**
    //  * @notice Preview fee required to bridge shares back to source.
    //  * @param amount Specified amount of `share` tokens to bridge to source network.
    //  * @param to Specified address to receive bridged shares on source network.
    //  * @return fee required to bridge shares.
    //  */

    // ========================================= INTERNAL BRIDGE FUNCTIONS =========================================
    function _sendMessage(uint256 message, bytes calldata bridgeWildCard, ERC20 feeToken, uint256 maxFee)
        internal
        override
        returns (bytes32 messageId)
    {
        uint64 destinationId = abi.decode(bridgeWildCard, (uint64));
        Chain memory chain = idToChains[destinationId];
        if (!chain.allowMessagesTo) {
            revert ChainlinkCCIPTeller__MessagesNotAllowedTo(destinationId);
        }

        // Build the message.
        Client.EVM2AnyMessage memory m = _buildMessage(message, chain.toAddress, address(feeToken));

        IRouterClient router = IRouterClient(this.getRouter());

        uint256 fee = router.getFee(destinationId, m);

        if (fee > maxFee) {
            revert ChainlinkCCIPTeller__FeeExceedsMax(destinationId, fee, maxFee);
        }

        feeToken.safeTransferFrom(msg.sender, address(this), fee);
        feeToken.safeApprove(address(router), fee);

        messageId = router.ccipSend(destinationId, m);
    }

    function _previewFee(uint256 message, bytes calldata bridgeWildCard, ERC20 feeToken)
        internal
        view
        override
        returns (uint256 fee)
    {
        uint64 destinationId = abi.decode(bridgeWildCard, (uint64));
        Chain memory chain = idToChains[destinationId];
        Client.EVM2AnyMessage memory m = _buildMessage(message, chain.toAddress, address(feeToken));

        IRouterClient router = IRouterClient(this.getRouter());

        fee = router.getFee(destinationId, m);
    }

    function _buildMessage(uint256 message, address to, address feeToken)
        internal
        view
        returns (Client.EVM2AnyMessage memory m)
    {
        m = Client.EVM2AnyMessage({
            receiver: abi.encode(to),
            data: abi.encode(message),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit and non-strict sequencing mode
                Client.EVMExtraArgsV1({gasLimit: messageGasLimit /*, strict: false*/ })
            ),
            feeToken: feeToken
        });
    }
}
