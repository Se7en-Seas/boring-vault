// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {AccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {console} from "@forge-std/Test.sol";

contract ManagerWithMerkleVerification is AccessControlDefaultAdminRules {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;
    using Address for address;

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
        _grantRole(ROOT_MANAGER_ROLE, _root_manager);
    }

    // This could be sommelier to start, then the multisig of the BoringVault can change the depositor.
    function setAllowedTargetsRoot(bytes32 _allowed_targets_root) external onlyRole(ROOT_MANAGER_ROLE) {
        allowed_targets_root = _allowed_targets_root;
        // TODO event
    }

    // TODO could I handle falsh loans in a custom contract?
    // TODO so we would not allow list contracts and functions that accept bytes and bytes[] parameters where the bytes values are encoded with selectors.
    // Unless there is some way for this code to know, oh hey I am doing a flash loan with this data, remove the bytes selector
    function manageVaultWithMerkleVerification(
        bytes32[][] calldata target_proofs,
        address[] calldata targets,
        bytes[] calldata target_data,
        uint256[] calldata values
    ) public {
        if (!allow_manage_no_role_check) _checkRole(MERKLE_MANAGER_ROLE);

        uint256 targets_length = targets.length;
        require(targets_length == target_proofs.length, "Invalid proof length");
        require(targets_length == target_data.length, "Invalid data length");
        require(targets_length == values.length, "Invalid values length");

        for (uint256 i; i < targets_length; ++i) {
            bytes4 provided_selector = bytes4(target_data[i]);
            require(_verifyTargetsProof(target_proofs[i], targets[i], provided_selector), "Failed to verify target");
            vault.manage(targets[i], target_data[i], values[i]);
        }
    }

    bool internal in_flash_loan;

    function manageVaultWithBalancerFlashLoan(
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes calldata userData
    ) external onlyRole(MERKLE_MANAGER_ROLE) {
        // Allow the manager to make balancer flash loans without verifying input.
        in_flash_loan = true;
        balancer_vault.flashLoan(tokens, amounts, userData);
        in_flash_loan = false;
    }

    bool internal allow_manage_no_role_check;

    function receiveFlashLoan(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata userData
    ) external {
        require(msg.sender == address(balancer_vault), "Wrong caller");
        require(in_flash_loan, "Not in a flash loan");
        // Transfer tokens to vault.
        for (uint256 i = 0; i < amounts.length; ++i) {
            ERC20(tokens[i]).safeTransfer(address(vault), amounts[i]);
        }

        {
            (bytes32[][] memory targets_proofs, address[] memory targets, bytes[] memory data, uint256[] memory values)
            = abi.decode(userData, (bytes32[][], address[], bytes[], uint256[]));

            allow_manage_no_role_check = true;
            ManagerWithMerkleVerification(address(this)).manageVaultWithMerkleVerification(
                targets_proofs, targets, data, values
            );
            allow_manage_no_role_check = false;
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
}

interface BalancerVault {
    function flashLoan(address[] memory tokens, uint256[] memory amounts, bytes calldata userData) external;
}
