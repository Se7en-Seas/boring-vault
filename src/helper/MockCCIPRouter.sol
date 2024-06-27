// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

contract MockCCIPRouter {
    uint256 public messageCount;

    uint256 public currentFee = 1e18;
    mapping(ERC20 => uint256) public fees;

    mapping(bytes32 => Client.Any2EVMMessage) public messages;

    mapping(address => uint64) public senderToSelector;

    bytes32 public lastMessageId;

    function setFee(ERC20 feeToken, uint256 newFee) external {
        fees[feeToken] = newFee;
    }

    function setSenderToSelector(address sender, uint64 selector) external {
        senderToSelector[sender] = selector;
    }

    function getLastMessage() external view returns (Client.Any2EVMMessage memory) {
        return messages[lastMessageId];
    }

    function getFee(uint64, Client.EVM2AnyMessage memory message) external view returns (uint256) {
        return fees[ERC20(message.feeToken)];
    }

    function ccipSend(uint64, Client.EVM2AnyMessage memory message) external returns (bytes32 messageId) {
        ERC20(message.feeToken).transferFrom(msg.sender, address(this), fees[ERC20(message.feeToken)]);
        messageId = bytes32(messageCount);
        messageCount++;
        lastMessageId = messageId;
        messages[messageId].messageId = messageId;
        messages[messageId].sourceChainSelector = senderToSelector[msg.sender];
        messages[messageId].sender = abi.encode(msg.sender);
        messages[messageId].data = message.data;
    }
}
