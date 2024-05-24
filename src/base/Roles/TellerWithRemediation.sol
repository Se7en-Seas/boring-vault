// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {TellerWithMultiAssetSupport, ERC20} from "src/base/Roles/TellerWithMultiAssetSupport.sol";

contract TellerWithRemediation is TellerWithMultiAssetSupport {
    // ========================================= STRUCTS =========================================

    /**
     * @param remediationTime The time the remediation process will be completed.
     * @param remediationAddress The address to send remediated shares to.
     * @param amount The amount of shares to remediate, use type(uint256).max to remediate all shares,
     *               at completion.
     */
    struct RemediationInfo {
        bool isFrozen;
        uint64 remediationTime;
        address remediationAddress;
        uint256 amount;
    }
    // ========================================= CONSTANTS =========================================

    /**
     * @notice The time till a users shares are remediated after lock.
     */
    uint256 internal constant REMEDIATION_PERIOD = 3 days;

    // ========================================= STATE =========================================
    /**
     * @notice Maps user address to their remediation info.
     */
    mapping(address => RemediationInfo) public remediationInfo;

    //============================== ERRORS ===============================

    error TellerWithRemediation__RemediationTimeNotMet();
    error TellerWithRemediation__RemediationNotStarted();
    error TellerWithRemediation__RemediationInProgress(address user);

    //============================== EVENTS ===============================

    event SharesUndergoingRemediation(address indexed user);
    event SharesRemediated(address indexed user, address indexed remediationAddress, uint256 amount);
    event RemediationCancelled(address indexed user);

    //============================== IMMUTABLES ===============================

    constructor(address _owner, address _vault, address _accountant, address _weth)
        TellerWithMultiAssetSupport(_owner, _vault, _accountant, _weth)
    {}

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Freezes user shares, and starts remediation process.
     * @dev This will lock `user` shares, and start the remediation process. once REMEDIATION_PERIOD has passed,
     *      `completeRemediation` can be called to remediate the shares.
     * @dev Use type(uint256).max for `amountToRemediate` to remediate all shares at the time of remediation completion.
     * @dev The type(uint256).max logic is a convenience feature, but is not really required since once this function is
     *      called the users balance can not change.
     * @dev Callable by REMEDIATION_ROLE.
     */
    function freezeSharesAndStartRemediation(address user, address remediationAddress, uint256 amountToRemediate)
        external
        requiresAuth
    {
        // Set remediation info.
        remediationInfo[user].isFrozen = true;
        remediationInfo[user].remediationTime = uint64(block.timestamp + REMEDIATION_PERIOD);
        remediationInfo[user].remediationAddress = remediationAddress;
        remediationInfo[user].amount = amountToRemediate;

        emit SharesUndergoingRemediation(user);
    }

    /**
     * @notice Cancels an ongoing remediation process, and unlocks user shares.
     * @dev Callable by REMEDIATION_ROLE, and MULTISIG_ROLE.
     */
    function cancelRemediationAndUnlockShares(address user) external requiresAuth {
        if (!remediationInfo[user].isFrozen) revert TellerWithRemediation__RemediationNotStarted();
        delete remediationInfo[user];

        emit RemediationCancelled(user);
    }

    /**
     * @notice Completes the remediation process, and remediates the shares.
     * @dev Callable by REMEDIATION_ROLE.
     */
    function completeRemediation(address user) external requiresAuth {
        RemediationInfo storage info = remediationInfo[user];

        // Make sure user is actually undergoing remediation, and that enough time has passed.
        if (!info.isFrozen) revert TellerWithRemediation__RemediationNotStarted();
        if (info.remediationTime >= block.timestamp) {
            revert TellerWithRemediation__RemediationTimeNotMet();
        }

        uint256 amountToRemediate = info.amount;
        if (amountToRemediate == type(uint256).max) amountToRemediate = vault.balanceOf(user);

        // Burn shares from user, and mint shares to remediation address.
        vault.exit(address(0), ERC20(address(0)), 0, user, amountToRemediate);
        vault.enter(address(0), ERC20(address(0)), 0, info.remediationAddress, amountToRemediate);

        emit SharesRemediated(user, info.remediationAddress, amountToRemediate);

        // Delete remediation info.
        delete remediationInfo[user];
    }

    // ========================================= BeforeTransferHook FUNCTIONS =========================================

    /**
     * @notice Implement beforeTransfer hook to check if shares are locked, or if `from`, `to`, or `operator` are on the deny list.
     */
    function beforeTransfer(address from, address to, address operator) public view override {
        if (remediationInfo[from].isFrozen) revert TellerWithRemediation__RemediationInProgress(from);
        if (remediationInfo[to].isFrozen) revert TellerWithRemediation__RemediationInProgress(to);
        if (remediationInfo[operator].isFrozen) revert TellerWithRemediation__RemediationInProgress(operator);
        super.beforeTransfer(from, to, operator);
    }
}
