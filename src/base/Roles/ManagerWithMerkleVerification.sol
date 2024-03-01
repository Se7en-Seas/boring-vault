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
import {AddressDecoder} from "src/base/AddressDecoder.sol";
import {console} from "@forge-std/Test.sol";

contract ManagerWithMerkleVerification is AccessControlDefaultAdminRules {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;
    using Address for address;

    BoringVault public immutable vault;
    BalancerVault public immutable balancer_vault;

    // A tree where the leafs are the keccak256 hash of the target address, function selector.
    bytes32 public allowed_target_selector_root;
    bytes32 public allowed_address_argument_root;
    AddressDecoder public addressDecoder;

    bytes32 public constant MERKLE_MANAGER_ROLE = keccak256("MERKLE_MANAGER_ROLE");
    bytes32 public constant ROOT_MANAGER_ROLE = keccak256("ROOT_MANAGER_ROLE");

    constructor(address _owner, address _manager, address _root_manager, address _vault)
        AccessControlDefaultAdminRules(3 days, _owner)
    {
        vault = BoringVault(payable(_vault));
        _grantRole(MERKLE_MANAGER_ROLE, _manager);
        _grantRole(ROOT_MANAGER_ROLE, _root_manager);
    }

    // This could be sommelier to start, then the multisig of the BoringVault can change the depositor.
    function setAllowedTargetSelectorRoot(bytes32 _allowed_target_selector_root) external onlyRole(ROOT_MANAGER_ROLE) {
        allowed_target_selector_root = _allowed_target_selector_root;
        // TODO event
    }

    function setAllowedAddressArgumentRoot(bytes32 _allowed_address_argument_root)
        external
        onlyRole(ROOT_MANAGER_ROLE)
    {
        allowed_address_argument_root = _allowed_address_argument_root;
        // TODO event
    }

    function setAddressDecoder(address _address_decoder) external onlyRole(ROOT_MANAGER_ROLE) {
        addressDecoder = AddressDecoder(_address_decoder);
    }

    // TODO could I handle falsh loans in a custom contract?
    // TODO so we would not allow list contracts and functions that accept bytes and bytes[] parameters where the bytes values are encoded with selectors.
    // Unless there is some way for this code to know, oh hey I am doing a flash loan with this data, remove the bytes selector

    bool internal ongoing_manage;

    function manageVaultWithMerkleVerification(
        bytes32[][] calldata target_proofs,
        bytes32[][][] calldata arguments_proofs,
        string[] calldata function_signatures,
        address[] calldata targets,
        bytes[] calldata target_data,
        uint256[] calldata values
    ) public {
        if (!ongoing_manage) _checkRole(MERKLE_MANAGER_ROLE);

        ongoing_manage = true;

        uint256 targets_length = targets.length;
        require(targets_length == target_proofs.length, "Invalid proof length");
        require(targets_length == target_data.length, "Invalid data length");
        require(targets_length == values.length, "Invalid values length");

        for (uint256 i; i < targets_length; ++i) {
            uint256 gas = gasleft();
            _verifyCallData(target_proofs[i], arguments_proofs[i], function_signatures[i], targets[i], target_data[i]);
            console.log("Gas used for verify call", gas - gasleft());
            vault.manage(targets[i], target_data[i], values[i]);
        }

        ongoing_manage = false;
    }

    // TODO to save on gas I could probs make this a pure function, and remove the state reads.
    function _verifyCallData(
        bytes32[] calldata target_proof,
        bytes32[][] calldata arguments_proofs,
        string calldata function_signature,
        address target,
        bytes calldata target_data
    ) internal view {
        // Verify we can even call this target with selector, and that function_string is correct.
        {
            bytes4 provided_selector = bytes4(target_data);
            require(_verifyTargetsProof(target_proof, target, provided_selector), "Failed to verify target");

            // Derive the function selector to verify function_string is legitimate.
            bytes4 derived_selector = bytes4(keccak256(abi.encodePacked(function_signature)));

            // Verify provided and derived selectors match.
            require(provided_selector == derived_selector, "Function Selector Mismatch");
        }

        // Use address decoder to get addresses in call data.
        address[] memory decoded_addresses = addressDecoder.decode(function_signature, target_data[4:]); // Slice 4 bytes away to remove function selector.
        uint256 decoded_addresses_length = decoded_addresses.length;
        require(
            arguments_proofs.length == decoded_addresses_length,
            "Arguments proof length differs from found address length"
        );
        uint256 address_count;
        for (uint256 i; i < decoded_addresses_length; ++i) {
            require(
                _verifyArgumentsProof(arguments_proofs[address_count], decoded_addresses[i]), "Failed to verify address"
            );
            address_count += 1;
        }
    }

    function receiveFlashLoan(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata userData
    ) external {
        require(msg.sender == address(balancer_vault), "Wrong caller");
        require(ongoing_manage, "Not being managed");
        // Transfer tokens to vault.
        for (uint256 i = 0; i < amounts.length; ++i) {
            ERC20(tokens[i]).safeTransfer(address(vault), amounts[i]);
        }

        {
            (
                bytes32[][] memory targets_proofs,
                bytes32[][][] memory arguments_proofs,
                string[] memory function_signatures,
                address[] memory targets,
                bytes[] memory data,
                uint256[] memory values
            ) = abi.decode(userData, (bytes32[][], bytes32[][][], string[], address[], bytes[], uint256[]));

            ManagerWithMerkleVerification(address(this)).manageVaultWithMerkleVerification(
                targets_proofs, arguments_proofs, function_signatures, targets, data, values
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
        return MerkleProof.verifyCalldata(proof, allowed_target_selector_root, leaf);
    }

    function _verifyArgumentsProof(bytes32[] calldata proof, address argument) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(argument));
        return MerkleProof.verifyCalldata(proof, allowed_address_argument_root, leaf);
    }
}

interface BalancerVault {
    function flashLoan(address[] memory tokens, uint256[] memory amounts, bytes calldata userData) external;
}
