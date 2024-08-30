// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

library DroneLib {
    bytes32 internal constant TARGET_FLAG = keccak256(bytes("DroneLib.target"));

    function extractTargetFromCalldata() internal pure returns (address target) {
        target = extractTargetFromInput(msg.data);
    }

    function extractTargetFromInput(bytes calldata data) internal pure returns (address target) {
        // Look at the last 32 bytes of calldata and see if the TARGET_FLAG is there.
        uint256 length = data.length;
        if (length >= 68) {
            bytes32 flag = bytes32(data[length - 32:]);

            if (flag == TARGET_FLAG) {
                // If the flag is there, extract the target from the calldata.
                target = address(bytes20(data[length - 52:length - 32]));
            }
        }

        // else no target present, so target is address(0).
    }
}
