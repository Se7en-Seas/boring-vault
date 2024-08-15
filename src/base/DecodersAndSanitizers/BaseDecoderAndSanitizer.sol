// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {PuppetLib} from "src/base/Puppets/PuppetLib.sol";

contract BaseDecoderAndSanitizer {
    function appendPuppetTargetIfPresent(bytes memory addressesFound) internal pure returns (bytes memory) {
        address puppetTarget = PuppetLib.extractTargetFromCalldata();
        if (puppetTarget != address(0)) {
            return abi.encodePacked(addressesFound, puppetTarget);
        } else {
            return addressesFound;
        }
    }

    //============================== IMMUTABLES ===============================

    /**
     * @notice The BoringVault contract address.
     */
    address internal immutable boringVault;

    constructor(address _boringVault) {
        boringVault = _boringVault;
    }

    function approve(address spender, uint256) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(spender);
        addressesFound = appendPuppetTargetIfPresent(addressesFound);
    }

    function claimFees(address feeAsset) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(feeAsset);
        addressesFound = appendPuppetTargetIfPresent(addressesFound);
    }

    function withdrawNonBoringToken(address token, uint256 /*amount*/ )
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(token);
        addressesFound = appendPuppetTargetIfPresent(addressesFound);
    }
}
