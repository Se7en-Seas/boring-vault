// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";

contract DexAggregatorSwapper {
    struct SwapDescription {
        address srcToken;
        address dstToken;
        address payable srcReceiver;
        address payable dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
    }

    ManagerWithMerkleVerification internal manager;

    // Before calling this manager should call approve in normal manage call
    function swapWithDex(
        bytes32[] calldata manageProof,
        address decodersAndSanitizers,
        address target,
        SwapDescription calldata desc,
        uint256 value
    ) external {
        // Could potentially have this call approve
        // save srcToken balance
        // derive targetData from desc
        // call manager.manageVaultWithMerkleVerification to perform the swap
        // save dstToken balance
        // compare value out to value in
        // then could call revoke approve.
    }
}
