// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract StandardBridgeDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== StandardBridge ===============================

    // TODO we could require _minGasLimit is atleast 200_000.
    /// @notice Example TX https://etherscan.io/tx/0x0b1cc213286c328e3fb483cfef9342aee51409b67ee5af1dc409e37273710f9f
    /// @notice Eample TX https://basescan.org/tx/0x7805ac08f38bec2d98edafc2e6f9571271a76b5ede3928f96d3edbc459d0ea4d
    function depositETHTo(address _to, uint32, /*_minGasLimit*/ bytes calldata /*_extraData*/ )
        external
        pure
        virtual
        returns (bytes memory sensitiveArguments)
    {
        // Extract sensitive arguments.
        sensitiveArguments = abi.encodePacked(_to);
    }

    // TODO we could require _minGasLimit is atleast 200_000.
    function bridgeERC20To(
        address _localToken,
        address _remoteToken,
        address _to,
        uint256, /*_amount*/
        uint32, /*_minGasLimit*/
        bytes calldata /*_extraData*/
    ) external pure virtual returns (bytes memory sensitiveArguments) {
        // Extract sensitive arguments.
        sensitiveArguments = abi.encodePacked(_localToken, _remoteToken, _to);
    }

    // TODO do we need to sanitize _tx.data
    /// @notice Example TX https://etherscan.io/tx/0x774db0b2aac5123f7a67fe00d57fb6c1f731457df435097481e7c8c913630fe1
    /// @notice This appears to be callable by anyone, so I would think that the sender and target values are constrained by the proofs
    // Playing with tendely sims, this does seem to be the case, so I am not sure it is worth it to sanitize these arguments
    function proveWithdrawalTransaction(
        DecoderCustomTypes.WithdrawalTransaction calldata _tx,
        uint256, /*_l2OutputIndex*/
        DecoderCustomTypes.OutputRootProof calldata, /*_outputRootProof*/
        bytes[] calldata /*_withdrawalProof*/
    ) external pure virtual returns (bytes memory sensitiveArguments) {
        sensitiveArguments = abi.encodePacked(_tx.sender, _tx.target);
    }

    // TODO do we need to sanitize _tx.data
    function finalizeWithdrawalTransaction(DecoderCustomTypes.WithdrawalTransaction calldata _tx)
        external
        pure
        virtual
        returns (bytes memory sensitiveArguments)
    {
        sensitiveArguments = abi.encodePacked(_tx.sender, _tx.target);
    }
}
