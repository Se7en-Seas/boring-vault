// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

library AddressToBytes32Lib {
    function toBytes32(address addressValue) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addressValue)));
    }

    function toAddress(bytes32 bytes32Value) internal pure returns (address) {
        return address(bytes20(bytes32Value << 96));
    }
}
