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
        bytes32[][] calldata target_proofs,
        bytes32[][][] calldata address_arguments_proofs,
        string[][] calldata function_strings,
        address[] calldata targets,
        bytes[] calldata target_data,
        uint256[] calldata values
    ) public {
        if (!in_flash_loan) _checkRole(MERKLE_MANAGER_ROLE);

        uint256 targets_length = targets.length;
        require(targets_length == target_proofs.length, "Invalid proof length");
        require(targets_length == function_strings.length, "Invalid function string length");
        require(targets_length == target_data.length, "Invalid data length");
        require(targets_length == values.length, "Invalid values length");

        for (uint256 i; i < targets_length; ++i) {
            _verifyCallData(
                target_proofs[i],
                address_arguments_proofs[i],
                function_strings[i],
                targets[i],
                target_data[i],
                values[i]
            );
            vault.manage(targets[i], target_data[i], values[i]);
        }
    }

    function _verifyCallData(
        bytes32[] calldata target_proof,
        bytes32[][] calldata argument_proofs, // Must be as long as the number of addresses in target_data
        string[] calldata function_string,
        address target,
        bytes calldata target_data,
        uint256 value
    ) internal view returns (bool) {
        // Verify we can even call this target with selector, and that function_string is correct.
        {
            bytes4 provided_selector = bytes4(target_data);
            require(_verifyTargetsProof(target_proof, target, provided_selector), "Failed to verify target");

            // Derive the function selector to verify function_string is legitimate.
            bytes memory packed_function_string;
            for (uint256 i; i < function_string.length; ++i) {
                packed_function_string = abi.encodePacked(packed_function_string, function_string[i]);
            }
            bytes4 derived_selector = bytes4(keccak256(packed_function_string));

            // Verify provided and derived selectors match.
            require(provided_selector == derived_selector, "Function Selector Mismatch");
        }

        // We now know that the provided function string has the proper arguments in it.
        // Iterate through function_string, and target_data, looking for addresses.
        uint256 address_count;
        uint256 slice_index = 4; // Start at 4 so that we don't include the function selector.
        // Start at 1, since first string is function name.
        for (uint256 i = 1; i < function_string.length; ++i) {
            (address[] memory decoded_addresses, uint256 unknown_encoded_length) =
                _process_unknown_type(function_string[i], target_data[slice_index:]);
            // Iterate through the decoded addresses, and verify everyone.
            for (uint256 j; j < decoded_addresses.length; ++j) {
                console.log("Address found:", decoded_addresses[j]);
                require(
                    _verifyArgumentsProof(argument_proofs[address_count], decoded_addresses[j]),
                    "Failed to verify address"
                );
                address_count += 1;
            }
            slice_index += unknown_encoded_length;
        }

        // require((data[i].length - 4) % 32 == 0, "Invalid data length");
    }

    bytes32 internal constant HASHED_TYPES_ADDRESS_DYNAMIC_ARRAY = keccak256("address[]");
    bytes32 internal constant HASHED_TYPES_BYTES_DYNAMIC_ARRAY = keccak256("bytes[]");
    bytes32 internal constant HASHED_TYPES_STRING_DYNAMIC_ARRAY = keccak256("string[]");
    bytes32 internal constant HASHED_TYPES_ADDRESS = keccak256("address");
    bytes32 internal constant HASHED_TYPES_BYTES = keccak256("bytes");
    bytes32 internal constant HASHED_TYPES_STRING = keccak256("string");
    bytes32 internal constant HASHED_TYPES_NO_TYPE_0 = keccak256("(");
    bytes32 internal constant HASHED_TYPES_NO_TYPE_1 = keccak256(",");
    bytes32 internal constant HASHED_TYPES_NO_TYPE_2 = keccak256(")");
    bytes32 internal constant HASHED_ERROR_0 = keccak256("[]"); // This would happen if the string array was misconfigured.

    /**
     * @notice The solidity docs refer to both dynamic and fixed type values.
     *         Dyanmic values are ones that have a dynamic length when encoding them.
     *         Static values are ones that always have the same length when encoding(32 bytes).
     */
    function _process_unknown_type(string calldata value_type, bytes calldata raw_data)
        internal
        view
        returns (address[] memory decoded_addresses, uint256 unknown_encoded_length)
    {
        // console.log("Value type", value_type);
        bytes32 hashed_value_type = keccak256(bytes(value_type));

        // Start by handling no types.
        if (
            hashed_value_type == HASHED_TYPES_NO_TYPE_0 || hashed_value_type == HASHED_TYPES_NO_TYPE_1
                || hashed_value_type == HASHED_TYPES_NO_TYPE_2
        ) {
            // There is nothing to decode from the data, so decoded_addresses should be zero, and unknown_encoded_length should be zero.
            return (decoded_addresses, unknown_encoded_length);
        }

        // Check for errors in string input.
        // TODO are there any other ways the string data could be messed up?
        if (hashed_value_type == HASHED_ERROR_0) revert("Value Type string error");

        // Iterate through the string, and look for "[" character, if found that means we have an array.
        bool is_array;
        uint8 array_length;
        bool is_dynamic;
        bytes32 hashed_fixed_array_type;
        {
            bytes1 open_char = bytes1("[");
            bytes1 close_char = bytes1("]");
            bytes memory value_type_bytes = bytes(value_type);
            uint256 value_type_bytes_length = value_type_bytes.length;
            for (uint256 i; i < value_type_bytes_length; ++i) {
                if (value_type_bytes[i] == open_char) {
                    is_array = true;
                    // Look at the next character, if close_char, then it is a dynamic array.
                    if (value_type_bytes[i + 1] == close_char) {
                        is_dynamic = true;
                    } else {
                        // Try converting the next character to a uint8.
                        array_length = _string_byte_to_uint8(value_type_bytes[i + 1]);
                        // Then confirm the next character is the close_char, if not revert.
                        if (value_type_bytes[i + 2] != close_char) revert("Multi-digit fixed arrays not supported");
                        // Save the base type of the fixed array.
                        hashed_fixed_array_type = keccak256(bytes(value_type[0:value_type_bytes_length - 3]));
                    }
                    break;
                }
            }
        }

        if (is_array) {
            // See if it is dynamic or static.
            if (is_dynamic) {
                if (hashed_value_type == HASHED_TYPES_ADDRESS_DYNAMIC_ARRAY) {
                    // Save addresses and length of encoded data.
                    decoded_addresses = abi.decode(raw_data, (address[]));
                    bytes memory encoded_addresses = abi.encode(decoded_addresses);
                    unknown_encoded_length = encoded_addresses.length;
                    return (decoded_addresses, unknown_encoded_length);
                }
                if (hashed_value_type == HASHED_TYPES_BYTES_DYNAMIC_ARRAY) {
                    // Only save the length of encoded data.
                    bytes[] memory decoded_bytes = abi.decode(raw_data, (bytes[]));
                    bytes memory encoded_bytes = abi.encode(decoded_bytes);
                    unknown_encoded_length = encoded_bytes.length;
                    return (decoded_addresses, unknown_encoded_length);
                }
                if (hashed_value_type == HASHED_TYPES_STRING_DYNAMIC_ARRAY) {
                    // Only save the length of encoded data.
                    string[] memory decoded_strings = abi.decode(raw_data, (string[]));
                    bytes memory encoded_strings = abi.encode(decoded_strings);
                    unknown_encoded_length = encoded_strings.length;
                    return (decoded_addresses, unknown_encoded_length);
                }
                // If we made it this far, then we have a dynamic array of static types, that is NOT of type address, so we can treat them all as decoding a uint256[].
                uint256[] memory unknown_fixed_types = abi.decode(raw_data, (uint256[]));
                bytes memory encoded_fixed_types = abi.encode(unknown_fixed_types);
                unknown_encoded_length = encoded_fixed_types.length;
                return (decoded_addresses, unknown_encoded_length);
            } else {
                // We have a fixed array.
                // Fixed arrays with static types are encoded with 32 bytes per element.
                if (hashed_fixed_array_type == HASHED_TYPES_ADDRESS) {
                    decoded_addresses = new address[](array_length);
                    for (uint256 i; i < array_length; ++i) {
                        decoded_addresses[i] = abi.decode(raw_data[i * 32:((i + 1) * 32)], (address));
                    }
                    unknown_encoded_length = array_length * 32;
                    return (decoded_addresses, unknown_encoded_length);
                }
                if (hashed_fixed_array_type == HASHED_TYPES_BYTES || hashed_fixed_array_type == HASHED_TYPES_STRING) {
                    revert("Fixed arrays of dynamic types are not supported.");
                }
                // If we made it this far, then we have a fixed array of static types, that is NOT of type address so we can simple update unknown_encoded_length.
                unknown_encoded_length = array_length * 32;
                return (decoded_addresses, unknown_encoded_length);
            }
        } else {
            if (hashed_value_type == HASHED_TYPES_ADDRESS) {
                // We found an address, so decode it and return it.
                decoded_addresses = new address[](1);
                decoded_addresses[0] = abi.decode(raw_data, (address));
                unknown_encoded_length = 32;
                return (decoded_addresses, unknown_encoded_length);
            }
            if (hashed_value_type == HASHED_TYPES_BYTES) {
                // bytes have a dynamic length, so we need to decode it, then re-encode it to get the length.
                bytes memory bytes_value = abi.decode(raw_data, (bytes));
                bytes memory encoded_bytes_value = abi.encode(bytes_value);
                unknown_encoded_length = encoded_bytes_value.length;
                return (decoded_addresses, unknown_encoded_length);
            }
            if (hashed_value_type == HASHED_TYPES_STRING) {
                // bytes have a dynamic length, so we need to decode it, then re-encode it to get the length.
                string memory string_value = abi.decode(raw_data, (string));
                bytes memory encoded_string_value = abi.encode(string_value);
                unknown_encoded_length = encoded_string_value.length;
                return (decoded_addresses, unknown_encoded_length);
            }
            // If we made it here we are dealing with a static type, that is not of type address, which is always encoded with 32 bytes.
            unknown_encoded_length = 32;
            return (decoded_addresses, unknown_encoded_length);
        }

        revert("How did we get here.");
    }

    function _string_byte_to_uint8(bytes1 str_byte) internal pure returns (uint8) {
        uint8 res = uint8(str_byte) - uint8(0x30);
        if (res > 9) revert("Error getting uint8 from string.");
        return res;
    }

    function manageVaultWithBalancerFlashLoan(
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes calldata userData
    ) external onlyRole(MERKLE_MANAGER_ROLE) {
        // Allow the manager to make balancer flash loans without verifying input.
        balancer_vault.flashLoan(tokens, amounts, userData);
    }

    bool internal in_flash_loan;

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
                bytes32[][][] memory address_arguments_proofs,
                string[][] memory function_strings,
                address[] memory targets,
                bytes[] memory data,
                uint256[] memory values
            ) = abi.decode(userData, (bytes32[][], bytes32[][][], string[][], address[], bytes[], uint256[]));

            in_flash_loan = true;
            ManagerWithMerkleVerification(address(this)).manageVaultWithMerkleVerification(
                targets_proofs, address_arguments_proofs, function_strings, targets, data, values
            );
            in_flash_loan = false;
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
