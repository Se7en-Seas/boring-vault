// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {AccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";

contract ManagerWithMerkleVerification is AccessControlDefaultAdminRules {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    BoringVault public immutable vault;
    BalancerVault public immutable balancer_vault;

    // A tree where the leafs are the keccak256 hash of the target address, function selector.
    bytes32 public allowed_targets_root;
    bytes32 public allowed_address_arguments_root;

    bytes32 public constant MERKLE_MANAGER_ROLE = keccak256("MERKLE_MANAGER_ROLE");
    bytes32 public constant ROOT_MANAGER_ROLE = keccak256("ROOT_MANAGER_ROLE");

    constructor(address _owner, address _manager, address _root_manager, address _vault)
        AccessControlDefaultAdminRules(3 days, _owner)
    {
        vault = BoringVault(_vault);
        _grantRole(MERKLE_MANAGER_ROLE, _manager);
        _grantRole(MERKLE_MANAGER_ROLE, address(this)); // So that this contract can make a callback to itself during balancer flash loans.
        _grantRole(ROOT_MANAGER_ROLE, _root_manager);
    }

    // This could be sommelier to start, then the multisig of the BoringVault can change the depositor.
    function setAllowedTargetsRoot(bytes32 _allowed_targets_root) external onlyRole(ROOT_MANAGER_ROLE) {
        allowed_targets_root = _allowed_targets_root;
        // TODO event
    }

    function setAllowedAddressArgumentsRoot(bytes32 _allowed_address_arguments_root)
        external
        onlyRole(ROOT_MANAGER_ROLE)
    {
        allowed_address_arguments_root = _allowed_address_arguments_root;
        // TODO event
    }

    // TODO could I handle falsh loans in a custom contract?
    // TODO so we would not allow list contracts and functions that accept bytes and bytes[] parameters where the bytes values are encoded with selectors.
    // Unless there is some way for this code to know, oh hey I am doing a flash loan with this data, remove the bytes selector
    function manageVaultWithMerkleVerification(
        bytes32[][] calldata targets_proofs,
        bytes32[][] calldata address_arguments_proofs,
        address[] calldata targets,
        bytes[] calldata data,
        uint256[] calldata values
    ) public onlyRole(MERKLE_MANAGER_ROLE) {
        uint256 targets_length = targets.length;
        require(targets_length == targets_proofs.length, "Invalid proof length");
        require(targets_length == data.length, "Invalid data length");
        require(targets_length == values.length, "Invalid values length");

        for (uint256 i; i < targets_length; ++i) {
            require(_verifyTargetsProof(targets_proofs[i], targets[i], bytes4(data[i][0:4])), "Failed to verify target");
            require((data[i].length - 4) % 32 == 0, "Invalid data length");
            uint256 argument_count = (data[i].length - 4) / 32;
            require(argument_count == address_arguments_proofs[i].length, "Invalid proof length");

            for (uint256 j; j < argument_count; ++j) {
                uint256 starting_index = 4 + (j * 32);
                uint256 value_as_uint256 = abi.decode(data[i][starting_index:(starting_index + 32)], (uint256));
                if (value_as_uint256 < type(uint160).max && value_as_uint256 > 1e30) {
                    require(
                        _verifyArgumentsProof(address_arguments_proofs[i], address(uint160(value_as_uint256))),
                        "Failed to verify address"
                    );
                } // else this is more than likely not an address so we don't check it.
            }
            vault.manage(targets[i], data[i], values[i]);
        }
    }

    function manageVaultWithBalancerFlashLoan(
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes calldata userData
    ) external onlyRole(MERKLE_MANAGER_ROLE) {
        // Allow the manager to make balancer flash loans without verifying input.
        balancer_vault.flashLoan(tokens, amounts, userData);
    }

    function receiveFlashLoan(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata userData
    ) external {
        // TODO verify this is a legitimate flashloan.

        // Transfer tokens to vault.
        for (uint256 i = 0; i < amounts.length; ++i) {
            ERC20(tokens[i]).safeTransfer(address(vault), amounts[i]);
        }

        {
            (
                bytes32[][] memory targets_proofs,
                bytes32[][] memory address_arguments_proofs,
                address[] memory targets,
                bytes[] memory data,
                uint256[] memory values
            ) = abi.decode(userData, (bytes32[][], bytes32[][], address[], bytes[], uint256[]));

            ManagerWithMerkleVerification(address(this)).manageVaultWithMerkleVerification(
                targets_proofs, address_arguments_proofs, targets, data, values
            );
        }

        // Transfer tokens back to balancer.
        // Have vault transfer amount + fees back to balancer
        for (uint256 i; i < amounts.length; ++i) {
            bytes memory transfer_data =
                abi.encodeWithSelector(ERC20.transfer.selector, address(balancer_vault), (amounts[i] + feeAmounts[i]));
            vault.manage(tokens[i], transfer_data, 0);
        }
    }

    function _verifyTargetsProof(bytes32[] calldata proof, address target, bytes4 selector)
        internal
        view
        returns (bool)
    {
        bytes32 leaf = keccak256(abi.encodePacked(target, selector));
        return MerkleProof.verifyCalldata(proof, allowed_targets_root, leaf);
    }

    function _verifyArgumentsProof(bytes32[] calldata proof, address argument) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(argument));
        return MerkleProof.verifyCalldata(proof, allowed_address_arguments_root, leaf);
    }
}

interface BalancerVault {
    function flashLoan(address[] memory tokens, uint256[] memory amounts, bytes calldata userData) external;
}
