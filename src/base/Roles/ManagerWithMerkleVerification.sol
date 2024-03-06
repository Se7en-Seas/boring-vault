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
import {RawDataDecoderAndSanitizer} from "src/base/RawDataDecoderAndSanitizer.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {console} from "@forge-std/Test.sol"; //TODO remove

contract ManagerWithMerkleVerification is AccessControlDefaultAdminRules {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;
    using Address for address;

    struct VerifyData {
        bytes32 currentTargetSelectorRoot;
        RawDataDecoderAndSanitizer currentRawDataDecoderAndSanitizer;
    }

    BoringVault public immutable vault;
    BalancerVault public immutable balancerVault;

    // A tree where the leafs are the keccak256 hash of the target address, function selector.
    bytes32 public manageRoot;
    RawDataDecoderAndSanitizer public rawDataDecoderAndSanitizer;
    bool internal ongoingManage;

    bytes32 public constant MERKLE_MANAGER_ROLE = keccak256("MERKLE_MANAGER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    constructor(address _owner, address _manager, address _admin, address _vault, address _balancerVault)
        AccessControlDefaultAdminRules(3 days, _owner)
    {
        vault = BoringVault(payable(_vault));
        _grantRole(MERKLE_MANAGER_ROLE, _manager);
        _grantRole(ADMIN_ROLE, _admin);
        balancerVault = BalancerVault(_balancerVault);
    }

    // This could be sommelier to start, then the multisig of the BoringVault can change the depositor.
    // TODO I could have the contents of the merkle tree passed in as call data, then we derive the merkle root on chain? That is more gas intensive, but allows people to easily verify what is in it.
    function setManageRoot(bytes32 _manageRoot) external onlyRole(ADMIN_ROLE) {
        manageRoot = _manageRoot;
        // TODO event
    }

    function setRawDataDecoderAndSanitizer(address _rawDataDecoderAndSanitizer) external onlyRole(ADMIN_ROLE) {
        rawDataDecoderAndSanitizer = RawDataDecoderAndSanitizer(_rawDataDecoderAndSanitizer);
    }

    function manageVaultWithMerkleVerification(
        bytes32[][] calldata manageProofs,
        string[] calldata functionSignatures,
        address[] calldata targets,
        bytes[] calldata targetData,
        uint256[] calldata values
    ) public {
        if (!ongoingManage) _checkRole(MERKLE_MANAGER_ROLE);

        ongoingManage = true;

        uint256 targetsLength = targets.length;
        require(targetsLength == manageProofs.length, "Invalid target proof length");
        require(targetsLength == functionSignatures.length, "Invalid function signatures length");
        require(targetsLength == targetData.length, "Invalid data length");
        require(targetsLength == values.length, "Invalid values length");

        // Read state and save it in memory.
        VerifyData memory vd = VerifyData({
            currentTargetSelectorRoot: manageRoot,
            currentRawDataDecoderAndSanitizer: rawDataDecoderAndSanitizer
        });

        for (uint256 i; i < targetsLength; ++i) {
            _verifyCallData(vd, manageProofs[i], functionSignatures[i], targets[i], targetData[i]);
            vault.manage(targets[i], targetData[i], values[i]);
        }

        ongoingManage = false;
    }

    function receiveFlashLoan(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata userData
    ) external {
        // console.log("Here");
        require(msg.sender == address(balancerVault), "wrong caller");
        require(ongoingManage, "not being managed");
        // Transfer tokens to vault.
        for (uint256 i = 0; i < amounts.length; ++i) {
            ERC20(tokens[i]).safeTransfer(address(vault), amounts[i]);
        }

        {
            (
                bytes32[][] memory manageProofs,
                string[] memory functionSignatures,
                address[] memory targets,
                bytes[] memory data,
                uint256[] memory values
            ) = abi.decode(userData, (bytes32[][], string[], address[], bytes[], uint256[]));

            ManagerWithMerkleVerification(address(this)).manageVaultWithMerkleVerification(
                manageProofs, functionSignatures, targets, data, values
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

    function _verifyCallData(
        VerifyData memory vd,
        bytes32[] calldata manageProof,
        string calldata functionSignature,
        address target,
        bytes calldata targetData
    ) internal view {
        // Verify we can even call this target with selector, and that functionSignature is correct.
        bytes4 providedSelector = bytes4(targetData);

        // Derive the function selector to verify functionSignature is legitimate.
        bytes4 derivedSelector = bytes4(keccak256(abi.encodePacked(functionSignature)));

        // Verify provided and derived selectors match.
        require(providedSelector == derivedSelector, "Function Selector Mismatch");

        // Use address decoder to get addresses in call data.
        address[] memory argumentAddresses = vd.currentRawDataDecoderAndSanitizer.decodeAndSanitizeRawData(
            address(vault), functionSignature, targetData[4:]
        ); // Slice 4 bytes away to remove function selector.
        require(
            _verifyManageProof(vd.currentTargetSelectorRoot, manageProof, target, providedSelector, argumentAddresses),
            "Failed to verify manage call"
        );
    }

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
