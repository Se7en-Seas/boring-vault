// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract HyperlaneDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== HYPERLANE ===============================

    // For bridging ERC20s.
    // Example TX: https://etherscan.io/tx/0x36f60aa50950df168c28460f553b764c0a049b8992e3d41d4533c00aefbb6756
    function transferRemote(uint32 _destinationDomain, bytes32 _recipient, uint256 /*_amount*/ )
        external
        pure
        virtual
        returns (bytes memory sensitiveArguments)
    {
        // Merkle tree helper is designed to work with addresses, so cast destination domain to an address, then
        // split _recipient into 2 addresses.
        address recipient0 = address(bytes20(bytes16(_recipient)));
        address recipient1 = address(bytes20(bytes16(_recipient << 128)));
        sensitiveArguments = abi.encodePacked(address(uint160(_destinationDomain)), recipient0, recipient1);
    }
}
