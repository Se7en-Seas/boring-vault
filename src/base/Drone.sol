// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract Drone is ERC721Holder, ERC1155Holder {
    using Address for address;

    //============================== ERRORS ===============================

    error Drone__OnlyBoringVault();

    //============================== CONSTRUCTOR ===============================

    /**
     * @notice Address of the BoringVault contract.
     */
    address internal immutable boringVault;

    constructor(address _boringVault) {
        boringVault = _boringVault;
    }

    //============================== MANAGE ===============================

    /**
     * @notice Allows BoringVault to make an arbitrary function call from this contract.
     * @dev Callable by BoringVault.
     */
    function manage(address target, bytes calldata data, uint256 value) external returns (bytes memory result) {
        if (msg.sender != boringVault) {
            revert Drone__OnlyBoringVault();
        }
        result = target.functionCallWithValue(data, value);
    }

    //============================== RECEIVE ===============================

    receive() external payable {}
}
