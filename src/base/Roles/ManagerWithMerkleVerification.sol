// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {AccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {console} from "@forge-std/Test.sol"; // TODO remove

contract ManagerWithMerkleVerification is AccessControlDefaultAdminRules {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;
    using Address for address;

    // ========================================= STRUCTS =========================================

    /**
     * @param currentManageRoot current manage root
     * @param currentRawDataDecoderAndSanitizer current raw data decoder and sanitizer
     */
    struct VerifyData {
        bytes32 currentManageRoot;
        address currentRawDataDecoderAndSanitizer;
    }

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
     * @notice The RawDataDecoderAndSanitizer this contract uses to decode and sanitize call data.
     */
    address public rawDataDecoderAndSanitizer;

    /**
     * @notice Bool indicating whether or not this contract is actively being managed.
     * @dev Used to block flash loans that are initiated outside a manage call.
     */
    bool internal ongoingManage;

    /**
     * @notice keccak256 hash of flash loan data.
     */
    bytes32 internal flashLoanIntentHash = bytes32(0);

    //============================== EVENTS ===============================

    event ManageRootUpdated(bytes32 oldRoot, bytes32 newRoot);
    event RawDataDecoderAndSanitizerUpdated(
        address oldRawDataDecoderAndSanitizer, address newRawDataDecoderAndSanitizer
    );
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

    /**
     * @notice Sets the rawDataDecoderAndSanitizer.
     */
    function setRawDataDecoderAndSanitizer(address _rawDataDecoderAndSanitizer) external onlyRole(ADMIN_ROLE) {
        address oldRawDataDecoderAndSanitizer = rawDataDecoderAndSanitizer;
        rawDataDecoderAndSanitizer = _rawDataDecoderAndSanitizer;
        emit RawDataDecoderAndSanitizerUpdated(oldRawDataDecoderAndSanitizer, _rawDataDecoderAndSanitizer);
    }

    // ========================================= STRATEGIST FUNCTIONS =========================================

    /**
     * @notice Allows strategist to manage the BoringVault.
     * @dev The strategist must provide a merkle proof for every call that verifiees they are allowed to make that call.
     */
    function manageVaultWithMerkleVerification(
        bytes32[][] calldata manageProofs,
        address[] calldata targets,
        bytes[] calldata targetData,
        uint256[] calldata values
    ) external {
        // The only way ongoingManage is true is if we are already in a `manageVaultWithMerkleVerification`
        // call, so we only need to check role if it is false.
        if (!ongoingManage) _checkRole(STRATEGIST_ROLE);

        ongoingManage = true;

        uint256 targetsLength = targets.length;
        require(targetsLength == manageProofs.length, "Invalid target proof length");
        require(targetsLength == targetData.length, "Invalid data length");
        require(targetsLength == values.length, "Invalid values length");

        // Read state and save it in memory.
        VerifyData memory vd =
            VerifyData({currentManageRoot: manageRoot, currentRawDataDecoderAndSanitizer: rawDataDecoderAndSanitizer});

        for (uint256 i; i < targetsLength; ++i) {
            // Mem expansion cost seems to only add less than 1k gas to calls so not that big of a deal
            _verifyCallData(vd, manageProofs[i], targets[i], targetData[i]);
            vault.manage(targets[i], targetData[i], values[i]);
        }

        ongoingManage = false;

        emit BoringVaultManaged(targetsLength);
    }

    // ========================================= FLASH LOAN FUNCTIONS =========================================
    /**
     * @notice While managing vault, if strategist wants to execute a flash loan the first step is
     *         having the BoringVault call this function, passing in the `intentHash`.
     * @param intentHash the keccak256 hash of userData passed into `receiveFlashLoan`
     * @dev This function accepts the hash rather than the pre-image to keep userData private until it is being executed on chain.
     */
    function saveFlashLoanIntentHash(bytes32 intentHash) external onlyRole(STRATEGIST_ROLE) {
        flashLoanIntentHash = intentHash;
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
        require(msg.sender == address(balancerVault), "wrong caller");
        require(ongoingManage, "not being managed");

        // Validate userData using intentHash.
        bytes32 intentHash = keccak256(userData);
        require(intentHash == flashLoanIntentHash, "Intent hash mismatch");
        // reset intent hash to prevent replays.
        flashLoanIntentHash = bytes32(0);

        // Transfer tokens to vault.
        for (uint256 i = 0; i < amounts.length; ++i) {
            ERC20(tokens[i]).safeTransfer(address(vault), amounts[i]);
        }
        {
            (bytes32[][] memory manageProofs, address[] memory targets, bytes[] memory data, uint256[] memory values) =
                abi.decode(userData, (bytes32[][], address[], bytes[], uint256[]));

            ManagerWithMerkleVerification(address(this)).manageVaultWithMerkleVerification(
                manageProofs, targets, data, values
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
        VerifyData memory vd,
        bytes32[] calldata manageProof,
        address target,
        bytes calldata targetData
    ) internal view {
        bytes4 providedSelector = bytes4(targetData);

        // Use address decoder to get addresses in call data.
        address[] memory argumentAddresses =
            abi.decode(vd.currentRawDataDecoderAndSanitizer.functionStaticCall(targetData), (address[]));

        require(
            _verifyManageProof(vd.currentManageRoot, manageProof, target, providedSelector, argumentAddresses),
            "Failed to verify manage call"
        );
    }

    /**
     * @notice Helper function to verify a manageProof is valid.
     */
    function _verifyManageProof(
        bytes32 root,
        bytes32[] calldata proof,
        address target,
        bytes4 selector,
        address[] memory argumentAddresses
    ) internal pure returns (bool) {
        bytes memory rawDigest = abi.encodePacked(target, selector);
        uint256 argumentAddressesLength = argumentAddresses.length;
        for (uint256 i; i < argumentAddressesLength; ++i) {
            rawDigest = abi.encodePacked(rawDigest, argumentAddresses[i]);
        }
        bytes32 leaf = keccak256(rawDigest);
        return MerkleProof.verifyCalldata(proof, root, leaf);
    }
}
