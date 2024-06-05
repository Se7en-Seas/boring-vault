// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

library MessageLib {
    error MessageLib__ShareAmountOverflow();
    /**
     * @notice Messages are transferred between chains as uint256
     *         The first 96 bits are the share amount.
     *         The remaining 160 bits are the address to send the shares to.
     * @dev Using a uint256 was chosen because most bridging protocols charge based off the number of
     *      bytes sent, and packing a uint256 in this way caps it at 32 bytes.
     */

    struct Message {
        uint256 shareAmount; // The amount of shares to bridge.
        address to;
    }

    function uint256ToMessage(uint256 b) internal pure returns (Message memory m) {
        m.shareAmount = uint96(b >> 160);
        m.to = address(uint160(b));
    }

    function messageToUint256(Message memory m) internal pure returns (uint256 b) {
        if (m.shareAmount >= 1 << 96) revert MessageLib__ShareAmountOverflow();

        b |= m.shareAmount << 160;
        b |= uint160(m.to);
    }
}
