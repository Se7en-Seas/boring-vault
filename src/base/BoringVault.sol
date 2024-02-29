// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {AccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";

contract BoringVault is ERC20, AccessControlDefaultAdminRules, ERC721Holder {
    using Address for address;
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    // Role needed to rebalance the vault.
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    // Role needed to deposit into vault.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Role needed to withdraw form vault.
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor(
        address _owner,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _manager,
        address _minter,
        address _burner
    ) ERC20(_name, _symbol, _decimals) AccessControlDefaultAdminRules(3 days, _owner) {
        _grantRole(MANAGER_ROLE, _manager);
        _grantRole(MINTER_ROLE, _minter);
        _grantRole(BURNER_ROLE, _burner);
    }

    function manage(address target, bytes calldata data, uint256 value) external onlyRole(MANAGER_ROLE) {
        target.functionCallWithValue(data, value);
    }

    function manage(address[] calldata targets, bytes[] calldata data, uint256[] calldata values)
        external
        onlyRole(MANAGER_ROLE)
    {
        uint256 targets_length = targets.length;
        for (uint256 i; i < targets_length; ++i) {
            targets[i].functionCallWithValue(data[i], values[i]);
        }
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        // Mint shares.
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        // Burn shares.
        _burn(from, amount);
    }

    // Add flash loan capability. Could use fallback functions to do it?
}
