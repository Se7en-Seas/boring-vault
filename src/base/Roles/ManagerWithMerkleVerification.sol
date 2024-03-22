// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {AccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import {MerkleProofLib} from "@solmate/utils/MerkleProofLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {console} from "@forge-std/Test.sol";

contract ManagerWithMerkleVerification is AccessControlDefaultAdminRules {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;
    using Address for address;

    // ========================================= CONSTANTS =========================================

    /**
     * @notice Accounts with this role are allowed to call `manageVaultWithMerkleVerification`.
     */
    bytes32 public constant STRATEGIST_ROLE = keccak256("STRATEGIST_ROLE");

    /**
     * @notice Accounts with this role are able to set the manageRoot, and the RawDataDecoderAndSanitizer.
     */
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // ========================================= STATE =========================================

    // A tree where the leafs are the keccak256 hash of the target address, function selector.
    /**
     * @notice A merkle tree root that restricts what data can be passed to the BoringVault.
     * @dev Each leaf is composed of the keccak256 hash of abi.encodePacked {target, selector, argumentAddress_0, ...., argumentAddress_N}
     *      Where:
     *             - target is the address to make the call to
     *             - selector is the function selector on target
     *             - argumentAddress is each allowed address argument in that call
     */
    bytes32 public manageRoot;

    /**
     * @notice Bool indicating whether or not this contract is actively performing a flash loan.
     * @dev Used to block flash loans that are initiated outside a manage call.
     */
    bool internal performingFlashLoan;

    /**
     * @notice keccak256 hash of flash loan data.
     */
    bytes32 internal flashLoanIntentHash = bytes32(0);

    //============================== EVENTS ===============================

    event ManageRootUpdated(bytes32 oldRoot, bytes32 newRoot);
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

    constructor(address _owner, address _manager, address _admin, address _vault, address _balancerVault)
        AccessControlDefaultAdminRules(3 days, _owner)
    {
        vault = BoringVault(payable(_vault));
        _grantRole(STRATEGIST_ROLE, _manager);
        _grantRole(STRATEGIST_ROLE, address(this));
        _grantRole(ADMIN_ROLE, _admin);
        balancerVault = BalancerVault(_balancerVault);
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    // TODO I could have the contents of the merkle tree passed in as call data, then we derive the merkle root on chain? That is more gas intensive, but allows people to easily verify what is in it.
    /**
     * @notice Sets the manageRoot.
     */
    function setManageRoot(bytes32 _manageRoot) external onlyRole(ADMIN_ROLE) {
        bytes32 oldRoot = manageRoot;
        manageRoot = _manageRoot;
        emit ManageRootUpdated(oldRoot, _manageRoot);
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
    ) external onlyRole(STRATEGIST_ROLE) {
        uint256 targetsLength = targets.length;
        if (targetsLength != manageProofs.length) revert("Invalid target proof length");
        if (targetsLength != targetData.length) revert("Invalid data length");
        if (targetsLength != values.length) revert("Invalid values length");
        if (targetsLength != decodersAndSanitizers.length) revert("Invalid decodersAndSanitizers length");

        // Read state and save it in memory.
        bytes32 currentManageRoot = manageRoot;

        for (uint256 i; i < targetsLength; ++i) {
            _verifyCallData(
                currentManageRoot, manageProofs[i], decodersAndSanitizers[i], targets[i], values[i], targetData[i]
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
    ) external {
        if (msg.sender != address(vault)) revert("wrong caller");
        flashLoanIntentHash = keccak256(userData);
        performingFlashLoan = true;
        balancerVault.flashLoan(recipient, tokens, amounts, userData);
        performingFlashLoan = false;
        if (flashLoanIntentHash != bytes32(0)) revert("flash loan not executed");
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
    ) external {
        if (msg.sender != address(balancerVault)) revert("wrong caller");
        if (!performingFlashLoan) revert("no flash loan");

        // Validate userData using intentHash.
        bytes32 intentHash = keccak256(userData);
        if (intentHash != flashLoanIntentHash) revert("Intent hash mismatch");
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
        address[] memory argumentAddresses = abi.decode(decoderAndSanitizer.functionStaticCall(targetData), (address[]));

        if (
            !_verifyManageProof(
                currentManageRoot,
                manageProof,
                target,
                decoderAndSanitizer,
                value,
                bytes4(targetData),
                argumentAddresses
            )
        ) {
            revert("Failed to verify manage call");
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
        address[] memory argumentAddresses
    ) internal pure returns (bool) {
        bool valueNonZero = value > 0;
        bytes memory rawDigest = abi.encodePacked(decoderAndSanitizer, target, valueNonZero, selector);
        uint256 argumentAddressesLength = argumentAddresses.length;
        for (uint256 i; i < argumentAddressesLength; ++i) {
            rawDigest = abi.encodePacked(rawDigest, argumentAddresses[i]);
        }
        bytes32 leaf = keccak256(rawDigest);
        return MerkleProofLib.verify(proof, root, leaf);
    }
}
