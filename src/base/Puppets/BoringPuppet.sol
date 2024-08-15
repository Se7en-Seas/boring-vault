// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {PuppetLib} from "src/base/Puppets/PuppetLib.sol";

contract BoringPuppet is ERC721Holder, ERC1155Holder {
    using Address for address;

    //============================== MODIFIERS ===============================

    modifier onlyBoringVault() {
        if (msg.sender != boringVault) revert BoringPuppet__OnlyBoringVault();
        _;
    }

    //============================== ERRORS ===============================

    error BoringPuppet__OnlyBoringVault();

    //============================== CONSTRUCTOR ===============================

    /**
     * @notice The address of the BoringVault that can control this puppet.
     */
    address internal immutable boringVault;

    constructor(address _boringVault) {
        boringVault = _boringVault;
    }

    //============================== FALLBACK ===============================

    /**
     * @notice This contract in its current state can only be interacted with by the BoringVault.
     * @notice The real target is extracted from the call data using `extractTargetFromCalldata()`.
     * @notice The puppet then forwards
     */
    fallback() external payable onlyBoringVault {
        // Exctract real target from end of calldata
        address target = PuppetLib.extractTargetFromCalldata();

        // Forward call to real target.
        // TODO we could do some verification of `target`, but if it is wrong then it should just revert when it tries to make the call.
        target.functionCallWithValue(msg.data, msg.value);
    }

    //============================== RECEIVE ===============================

    receive() external payable {}
}
