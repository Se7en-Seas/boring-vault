// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract EigenLayerLSTStakingDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== ERRORS ===============================

    error EigenLayerLSTStakingDecoderAndSanitizer__CanOnlyReceiveAsTokens();

    //============================== EIGEN LAYER ===============================

    function depositIntoStrategy(address strategy, address token, uint256 /*amount*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(strategy, token);
    }

    function queueWithdrawals(DecoderCustomTypes.QueuedWithdrawalParams[] calldata queuedWithdrawalParams)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        for (uint256 i = 0; i < queuedWithdrawalParams.length; i++) {
            for (uint256 j = 0; j < queuedWithdrawalParams[i].strategies.length; j++) {
                addressesFound = abi.encodePacked(addressesFound, queuedWithdrawalParams[i].strategies[j]);
            }
            addressesFound = abi.encodePacked(addressesFound, queuedWithdrawalParams[i].withdrawer);
        }
    }

    function completeQueuedWithdrawals(
        DecoderCustomTypes.Withdrawal[] calldata withdrawals,
        address[][] calldata tokens,
        uint256[] calldata, /*middlewareTimesIndexes*/
        bool[] calldata receiveAsTokens
    ) external pure virtual returns (bytes memory addressesFound) {
        for (uint256 i = 0; i < withdrawals.length; i++) {
            if (!receiveAsTokens[i]) revert EigenLayerLSTStakingDecoderAndSanitizer__CanOnlyReceiveAsTokens();

            addressesFound = abi.encodePacked(
                addressesFound, withdrawals[i].staker, withdrawals[i].delegatedTo, withdrawals[i].withdrawer
            );
            for (uint256 j = 0; j < withdrawals[i].strategies.length; j++) {
                addressesFound = abi.encodePacked(addressesFound, withdrawals[i].strategies[j]);
            }
            for (uint256 j = 0; j < tokens.length; j++) {
                addressesFound = abi.encodePacked(addressesFound, tokens[i][j]);
            }
        }
    }

    function delegateTo(
        address operator,
        DecoderCustomTypes.SignatureWithExpiry calldata, /*approverSignatureAndExpiry*/
        bytes32 /*approverSalt*/
    ) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(operator);
    }

    function undelegate(address staker) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(staker);
    }

    function setClaimerFor(address claimer) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(claimer);
    }

    /**
     * @notice We intentionally do not report claim.earnerLeaf.earner, and claim.tokenLeaves[i].token
     *         These addresses are not important for the security of the call.
     */
    function processClaim(DecoderCustomTypes.RewardsMerkleClaim calldata, /*claim*/ address recipient)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(recipient);
    }
}
