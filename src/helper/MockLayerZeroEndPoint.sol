// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {OAppAuth, Origin, MessagingFee, MessagingReceipt} from "@opapp-auth/OAppAuth.sol";
import {MessagingParams} from "@opapp-auth/OAppAuthSender.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";

contract MockLayerZeroEndPoint {
    using AddressToBytes32Lib for address;
    using AddressToBytes32Lib for bytes32;

    struct Packet {
        Origin _origin;
        bytes32 _guid;
        bytes _message;
        address _executor;
        bytes _extraData;
        address to;
    }

    uint256 public messageCount;

    ERC20 public constant lzToken = ERC20(0x6985884C4392D348587B19cb9eAAf157F13271cd);
    ERC20 public constant NATIVE = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    uint256 public currentFee = 1e18;
    mapping(ERC20 => uint256) public fees;

    mapping(bytes32 => Packet) public messages;

    mapping(address => uint32) public senderToId;

    bytes32 public lastMessageId;

    function setFee(ERC20 feeToken, uint256 newFee) external {
        fees[feeToken] = newFee;
    }

    function setSenderToId(address sender, uint32 selector) external {
        senderToId[sender] = selector;
    }

    function getLastMessage() external view returns (Packet memory) {
        return messages[lastMessageId];
    }

    function quote(MessagingParams calldata _params, address) public view returns (MessagingFee memory fee) {
        if (_params.payInLzToken) {
            fee.lzTokenFee = fees[lzToken];
        } else {
            fee.nativeFee = fees[NATIVE];
        }
    }

    function send(MessagingParams calldata _params, address /*_refundAddress*/ )
        external
        payable
        returns (MessagingReceipt memory receipt)
    {
        uint256 suppliedNative = msg.value;
        uint256 suppliedLzToken = lzToken.balanceOf(address(this));

        if (suppliedNative < fees[NATIVE] || suppliedLzToken < fees[lzToken]) {
            revert("Insufficient funds");
        }

        bytes32 guid =
            keccak256(abi.encodePacked(senderToId[msg.sender], _params.dstEid, _params.message, _params.options));

        // Save packet
        Packet storage packet = messages[guid];
        packet._origin.srcEid = senderToId[msg.sender];
        packet._origin.sender = msg.sender.toBytes32();
        packet._origin.nonce = 0;
        packet._guid = guid;
        packet._message = _params.message;
        packet._executor = address(0);
        packet._extraData = _params.options;
        packet.to = _params.receiver.toAddress();

        // return receipt.
        receipt.guid = guid;
        receipt.nonce = 0;
        receipt.fee = quote(_params, msg.sender);
    }
}
