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
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {console} from "@forge-std/Test.sol"; //TODO remove

contract ManagerWithMerkleVerification is AccessControlDefaultAdminRules {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;
    using Address for address;

    struct VerifyData {
        bytes32 current_target_selector_root;
        bytes32 current_address_argument_root;
        AddressDecoder current_address_decoder;
    }

    BoringVault public immutable vault;
    BalancerVault public immutable balancer_vault;

    // A tree where the leafs are the keccak256 hash of the target address, function selector.
    bytes32 public allowed_target_selector_root;
    bytes32 public allowed_address_argument_root;
    AddressDecoder public address_decoder;
    bool internal ongoing_manage;

    bytes32 public constant MERKLE_MANAGER_ROLE = keccak256("MERKLE_MANAGER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    constructor(address _owner, address _manager, address _admin, address _vault, address _balancer_vault)
        AccessControlDefaultAdminRules(3 days, _owner)
    {
        vault = BoringVault(payable(_vault));
        _grantRole(MERKLE_MANAGER_ROLE, _manager);
        _grantRole(ADMIN_ROLE, _admin);
        balancer_vault = BalancerVault(_balancer_vault);
    }

    // This could be sommelier to start, then the multisig of the BoringVault can change the depositor.
    // TODO I could have the contents of the merkle tree passed in as call data, then we derive the merkle root on chain? That is more gas intensive, but allows people to easily verify what is in it.
    function setAllowedTargetSelectorRoot(bytes32 _allowed_target_selector_root) external onlyRole(ADMIN_ROLE) {
        allowed_target_selector_root = _allowed_target_selector_root;
        // TODO event
    }

    function setAllowedAddressArgumentRoot(bytes32 _allowed_address_argument_root) external onlyRole(ADMIN_ROLE) {
        allowed_address_argument_root = _allowed_address_argument_root;
        // TODO event
    }

    function setAddressDecoder(address _address_decoder) external onlyRole(ADMIN_ROLE) {
        address_decoder = AddressDecoder(_address_decoder);
    }

    function manageVaultWithMerkleVerification(
        bytes32[][] calldata target_proofs,
        bytes32[][][] calldata arguments_proofs,
        string[] calldata function_signatures,
        address[] calldata targets,
        bytes[] calldata target_data,
        uint256[] calldata values
    ) public {
        if (!ongoing_manage) _checkRole(MERKLE_MANAGER_ROLE);

        // TODO might be able to optimize further if targets.length is stored in mem.
        ongoing_manage = true;

        // uint256 targets_length = targets.length;
        require(targets.length == target_proofs.length, "Invalid target proof length");
        require(targets.length == arguments_proofs.length, "Invalid argument proof length");
        require(targets.length == function_signatures.length, "Invalid function signatures length");
        require(targets.length == target_data.length, "Invalid data length");
        require(targets.length == values.length, "Invalid values length");

        // Read state and save it in memory.
        VerifyData memory vd = VerifyData({
            current_target_selector_root: allowed_target_selector_root,
            current_address_argument_root: allowed_address_argument_root,
            current_address_decoder: address_decoder
        });

        for (uint256 i; i < targets.length; ++i) {
            _verifyCallData(
                vd, target_proofs[i], arguments_proofs[i], function_signatures[i], targets[i], target_data[i]
            );
            vault.manage(targets[i], target_data[i], values[i]);
        }

        ongoing_manage = false;
    }

    function receiveFlashLoan(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata userData
    ) external {
        // console.log("Here");
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

    // ========================================= INTERNAL HELPER FUNCTIONS =========================================

    function _verifyCallData(
        VerifyData memory vd,
        bytes32[] calldata target_proof,
        bytes32[][] calldata arguments_proofs,
        string calldata function_signature,
        address target,
        bytes calldata target_data
    ) internal pure {
        // Verify we can even call this target with selector, and that function_signature is correct.
        {
            bytes4 provided_selector = bytes4(target_data);
            require(
                _verifyTargetsProof(vd.current_target_selector_root, target_proof, target, provided_selector),
                "Failed to verify target"
            );

            // Derive the function selector to verify function_signature is legitimate.
            bytes4 derived_selector = bytes4(keccak256(abi.encodePacked(function_signature)));

            // Verify provided and derived selectors match.
            require(provided_selector == derived_selector, "Function Selector Mismatch");
        }

        // Use address decoder to get addresses in call data.
        address[] memory decoded_addresses = vd.current_address_decoder.decode(function_signature, target_data[4:]); // Slice 4 bytes away to remove function selector.
        uint256 decoded_addresses_length = decoded_addresses.length;
        require(
            arguments_proofs.length == decoded_addresses_length,
            "Arguments proof length differs from found address length"
        );
        uint256 address_count;
        for (uint256 i; i < decoded_addresses_length; ++i) {
            require(
                _verifyArgumentsProof(
                    vd.current_address_argument_root, arguments_proofs[address_count], decoded_addresses[i]
                ),
                "Failed to verify address"
            );
            address_count += 1;
        }
    }

    function _verifyTargetsProof(
        bytes32 _allowed_target_selector_root,
        bytes32[] calldata proof,
        address target,
        bytes4 selector
    ) internal pure returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(target, selector));
        return MerkleProof.verifyCalldata(proof, _allowed_target_selector_root, leaf);
    }

    function _verifyArgumentsProof(bytes32 _allowed_address_argument_root, bytes32[] calldata proof, address argument)
        internal
        pure
        returns (bool)
    {
        bytes32 leaf = keccak256(abi.encodePacked(argument));
        return MerkleProof.verifyCalldata(proof, _allowed_address_argument_root, leaf);
    }
}
