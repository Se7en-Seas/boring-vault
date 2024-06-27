// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract BaseDecoderAndSanitizer {
    using Address for address;

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
    }

    function claimFees(address feeAsset) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(feeAsset);
    }

    function withdrawNonBoringToken(address token, uint256 /*amount*/ )
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(token);
    }

    function manage(address target, bytes calldata data, uint256 value)
        external
        view
        returns (bytes memory addressesFound)
    {
        // TODO this is not quite perfect but a great start for the ability to reuse all the decoder and sanitizer logic.
        addressesFound = abi.decode(address(this).functionStaticCall(data), (bytes));

        addressesFound = abi.encodePacked(target, value > 0, bytes4(data), addressesFound);
    }
}
