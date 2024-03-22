// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {MerkleProofLib} from "@solmate/utils/MerkleProofLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";

contract ManagerWithMerkleVerification is Auth {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;
    using Address for address;

    // ========================================= STATE =========================================

    /**
     * @notice A merkle tree root that restricts what data can be passed to the BoringVault.
     * @dev Maps a strategist address to their specific merkle root.
     * @dev Each leaf is composed of the keccak256 hash of abi.encodePacked {decodersAndSanitizer, target, valueIsNonZero, selector, argumentAddress_0, ...., argumentAddress_N}
     *      Where:
     *             - decodersAndSanitizer is the addres to call to extract packed address arguments from the calldata
     *             - target is the address to make the call to
     *             - valueIsNonZero is a bool indicating whether or not the value is non-zero
     *             - selector is the function selector on target
     *             - argumentAddress is each allowed address argument in that call
     */
    mapping(address => bytes32) public manageRoot;

    /**
     * @notice Bool indicating whether or not this contract is actively performing a flash loan.
     * @dev Used to block flash loans that are initiated outside a manage call.
     */
    bool internal performingFlashLoan;

    /**
     * @notice keccak256 hash of flash loan data.
     */
    bytes32 internal flashLoanIntentHash = bytes32(0);

    //============================== ERRORS ===============================

    error ManagerWithMerkleVerification__InvalidManageProofLength();
    error ManagerWithMerkleVerification__InvalidTargetDataLength();
    error ManagerWithMerkleVerification__InvalidValuesLength();
    error ManagerWithMerkleVerification__InvalidDecodersAndSanitizersLength();
    error ManagerWithMerkleVerification__FlashLoanNotExecuted();
    error ManagerWithMerkleVerification__FlashLoanNotInProgress();
    error ManagerWithMerkleVerification__BadFlashLoanIntentHash();
    error ManagerWithMerkleVerification__FailedToVerifyManageProof();

    //============================== EVENTS ===============================

    event ManageRootUpdated(address strategist, bytes32 oldRoot, bytes32 newRoot);
    event BoringVaultManaged(uint256 callsMade);

    //============================== IMMUTABLES ===============================

    /**
     * @notice The BoringVault this contract can manage.
     */
    BoringVault public immutable vault;

    /**
     * @notice The balancer vault this contract can use for flash loans.
     */
    BalancerVault public immutable balancerVault;

    constructor(address _owner, address _vault, address _balancerVault) Auth(_owner, Authority(address(0))) {
        vault = BoringVault(payable(_vault));
        balancerVault = BalancerVault(_balancerVault);
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Sets the manageRoot.
     */
    function setManageRoot(address strategist, bytes32 _manageRoot) external requiresAuth {
        bytes32 oldRoot = manageRoot[strategist];
        manageRoot[strategist] = _manageRoot;
        emit ManageRootUpdated(strategist, oldRoot, _manageRoot);
    }

    // ========================================= STRATEGIST FUNCTIONS =========================================

    /**
     * @notice Allows strategist to manage the BoringVault.
     * @dev The strategist must provide a merkle proof for every call that verifiees they are allowed to make that call.
     */
    function manageVaultWithMerkleVerification(
        bytes32[][] calldata manageProofs,
        address[] calldata decodersAndSanitizers,
        address[] calldata targets,
        bytes[] calldata targetData,
        uint256[] calldata values
    ) external requiresAuth {
        uint256 targetsLength = targets.length;
        if (targetsLength != manageProofs.length) revert ManagerWithMerkleVerification__InvalidManageProofLength();
        if (targetsLength != targetData.length) revert ManagerWithMerkleVerification__InvalidTargetDataLength();
        if (targetsLength != values.length) revert ManagerWithMerkleVerification__InvalidValuesLength();
        if (targetsLength != decodersAndSanitizers.length) {
            revert ManagerWithMerkleVerification__InvalidDecodersAndSanitizersLength();
        }

        // Read state and save it in memory.
        bytes32 strategistManageRoot = manageRoot[msg.sender];

        for (uint256 i; i < targetsLength; ++i) {
            _verifyCallData(
                strategistManageRoot, manageProofs[i], decodersAndSanitizers[i], targets[i], values[i], targetData[i]
            );
            vault.manage(targets[i], targetData[i], values[i]);
        }
        emit BoringVaultManaged(targetsLength);
    }

    // ========================================= FLASH LOAN FUNCTIONS =========================================

    /**
     * @notice In order to perform a flash loan,
     *         1) Merkle root must contain the leaf(address(this), this.flashLoan.selector, ARGUMENT_ADDRESSES ...)
     *         2) Strategist must initiate the flash loan using `manageVaultWithMerkleVerification`
     *         3) balancerVault MUST callback to this contract with the same userData
     */
    function flashLoan(
        address recipient,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes calldata userData
    ) external requiresAuth {
        flashLoanIntentHash = keccak256(userData);
        performingFlashLoan = true;
        balancerVault.flashLoan(recipient, tokens, amounts, userData);
        performingFlashLoan = false;
        if (flashLoanIntentHash != bytes32(0)) revert ManagerWithMerkleVerification__FlashLoanNotExecuted();
    }

    /**
     * @notice Add support for balancer flash loans.
     * @dev userData can optionally have salt encoded at the end of it, in order to change the intentHash,
     *      if a flash loan is exact userData is being repeated, and their is fear of 3rd parties
     *      front-running the rebalance.
     */
    function receiveFlashLoan(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata userData
    ) external requiresAuth {
        if (!performingFlashLoan) revert ManagerWithMerkleVerification__FlashLoanNotInProgress();

        // Validate userData using intentHash.
        bytes32 intentHash = keccak256(userData);
        if (intentHash != flashLoanIntentHash) revert ManagerWithMerkleVerification__BadFlashLoanIntentHash();
        // reset intent hash to prevent replays.
        flashLoanIntentHash = bytes32(0);

        // Transfer tokens to vault.
        for (uint256 i = 0; i < amounts.length; ++i) {
            ERC20(tokens[i]).safeTransfer(address(vault), amounts[i]);
        }
        {
            (
                bytes32[][] memory manageProofs,
                address[] memory decodersAndSanitizers,
                address[] memory targets,
                bytes[] memory data,
                uint256[] memory values
            ) = abi.decode(userData, (bytes32[][], address[], address[], bytes[], uint256[]));

            ManagerWithMerkleVerification(address(this)).manageVaultWithMerkleVerification(
                manageProofs, decodersAndSanitizers, targets, data, values
            );
        }

        // Transfer tokens back to balancer.
        // Have vault transfer amount + fees back to balancer
        bytes[] memory transferData = new bytes[](amounts.length);
        for (uint256 i; i < amounts.length; ++i) {
            transferData[i] =
                abi.encodeWithSelector(ERC20.transfer.selector, address(balancerVault), (amounts[i] + feeAmounts[i]));
        }
        // Values is always zero, just pass in an array of zeroes.
        vault.manage(tokens, transferData, new uint256[](amounts.length));
    }

    // ========================================= INTERNAL HELPER FUNCTIONS =========================================

    /**
     * @notice Helper function to decode, sanitize, and verify call data.
     */
    function _verifyCallData(
        bytes32 currentManageRoot,
        bytes32[] calldata manageProof,
        address decoderAndSanitizer,
        address target,
        uint256 value,
        bytes calldata targetData
    ) internal view {
        // Use address decoder to get addresses in call data.
        bytes memory packedArgumentAddresses = abi.decode(decoderAndSanitizer.functionStaticCall(targetData), (bytes));

        if (
            !_verifyManageProof(
                currentManageRoot,
                manageProof,
                target,
                decoderAndSanitizer,
                value,
                bytes4(targetData),
                packedArgumentAddresses
            )
        ) {
            revert ManagerWithMerkleVerification__FailedToVerifyManageProof();
        }
    }

    /**
     * @notice Helper function to verify a manageProof is valid.
     */
    function _verifyManageProof(
        bytes32 root,
        bytes32[] calldata proof,
        address target,
        address decoderAndSanitizer,
        uint256 value,
        bytes4 selector,
        bytes memory packedArgumentAddresses
    ) internal pure returns (bool) {
        bool valueNonZero = value > 0;
        bytes32 leaf =
            keccak256(abi.encodePacked(decoderAndSanitizer, target, valueNonZero, selector, packedArgumentAddresses));
        return MerkleProofLib.verify(proof, root, leaf);
    }
}
