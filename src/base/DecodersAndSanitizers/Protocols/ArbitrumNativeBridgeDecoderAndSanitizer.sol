// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract ArbitrumNativeBridgeDecoderAndSanitizer is BaseDecoderAndSanitizer {
    error ArbitrumNativeBridgeDecoderAndSanitizer__ExtraDataNotSupported();
    error ArbitrumNativeBridgeDecoderAndSanitizer__GasLimitTooSmall();
    error ArbitrumNativeBridgeDecoderAndSanitizer__NoCallDataForRetryables();
    error ArbitrumNativeBridgeDecoderAndSanitizer__MaxGasPriceBid();

    /**
     * @notice The minimum gas limit for retryable tickets.
     */
    uint256 internal constant MINIMUM_RETRYABLE_GAS_LIMIT = 25_000;

    /**
     * @notice The maximum gas price bid for outbound transfers.
     */
    uint256 internal constant MAXIMUM_GAS_PRICE_BID = 100e9;

    //============================== BRIDGING NATIVE ETH ===============================

    /// @notice This function will not be added to the merkle tree, as it will
    /// transfer ETH to the BoringVault's aliased address on Arbitrum.
    /// Money can be retrieved from this aliased address, but to limit the amount of money going
    /// to this aliased address, if ETH needs to be bridged,
    /// @notice It is left here in case the Arbitrum bridge contracts are upgraded to remove the Alias feature.
    function depositEth() external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    // Used to withdraw ETH from Arbitrum
    // Target 0x0000000000000000000000000000000000000064
    // Example TX https://arbiscan.io/tx/0xc5882e2c94e26eb352be67fc1c97e4c605b39d4458ba8858dd0c96f7ad641d5b
    function withdrawEth(address destination) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(destination);
    }

    // Used to claim withdrawn ETH/ERC20s from Arbitrum
    // Target 0x0B9857ae2D4A3DBe74ffE1d7DF045bb7F96E4840
    // Example TX for native https://etherscan.io/tx/0x2db24bbaa8b7d8a282b9eb29d4ac3703561270c8a851ad7c697c96a4b31f707e
    // Example TX for ERC20 https://etherscan.io/tx/0x576736e900bb0c45d693aa7e6cc13f07ba4e967b19c453aa01d16f4144c71f68
    function executeTransaction(
        bytes32[] calldata, /*proof*/
        uint256, /*index*/
        address l2Sender,
        address to,
        uint256, /*l2Block*/
        uint256, /*l1Block*/
        uint256, /*l2Timestamp*/
        uint256, /*value*/
        bytes calldata /*data*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(l2Sender, to);
    }

    //============================== BRIDGING ERC20 ===============================

    // Used to deposit ERC20 into Arbitrum
    // Target 0x72Ce9c846789fdB6fC1f34aC4AD25Dd9ef7031ef
    // Example TX https://etherscan.io/tx/0xb8f15f2ce92f7a2a492fec769209f93a4d7b379539253b6092ecdfe292fb6ef1
    function outboundTransfer(
        address _token,
        address _to,
        uint256, /*_amount*/
        uint256, /*_maxGas*/
        uint256 _gasPriceBid,
        bytes calldata _data
    ) external pure virtual returns (bytes memory addressesFound) {
        (, bytes memory extraData) = abi.decode(_data, (uint256, bytes));
        if (extraData.length > 0) {
            revert ArbitrumNativeBridgeDecoderAndSanitizer__ExtraDataNotSupported();
        }
        if (_gasPriceBid > MAXIMUM_GAS_PRICE_BID) {
            revert ArbitrumNativeBridgeDecoderAndSanitizer__MaxGasPriceBid();
        }
        addressesFound = abi.encodePacked(_token, _to);
    }

    // Used to deposit ERC20 into Arbitrum
    // Target 0x72Ce9c846789fdB6fC1f34aC4AD25Dd9ef7031ef
    /// @notice This function will not be added to the merkle tree for tree simplicity, as it behaves the same way as `outboundTransfer`,
    /// sending excess ETH to the aliased address.
    /// @notice It is left here in case the Arbitrum bridge contracts are upgraded such that `_refundTo` actually goes to the address provided.
    function outboundTransferCustomRefund(
        address _token,
        address _refundTo,
        address _to,
        uint256, /*_amount*/
        uint256, /*_maxGas*/
        uint256 _gasPriceBid,
        bytes calldata _data
    ) external pure virtual returns (bytes memory addressesFound) {
        (, bytes memory extraData) = abi.decode(_data, (uint256, bytes));
        if (extraData.length > 0) {
            revert ArbitrumNativeBridgeDecoderAndSanitizer__ExtraDataNotSupported();
        }
        if (_gasPriceBid > MAXIMUM_GAS_PRICE_BID) {
            revert ArbitrumNativeBridgeDecoderAndSanitizer__MaxGasPriceBid();
        }
        addressesFound = abi.encodePacked(_token, _refundTo, _to);
    }

    // Used to withdraw ERC20 from Arbitrum
    // Target 0x5288c571Fd7aD117beA99bF60FE0846C4E84F933
    // Example TX https://arbiscan.io/tx/0x4d0ccd99024b3ee0d49820625371fc7117036459bff67ed3887ffc7648c7d020
    function outboundTransfer(address _l1Token, address _to, uint256, /*_amount*/ bytes calldata _data)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        if (_data.length > 0) {
            revert ArbitrumNativeBridgeDecoderAndSanitizer__ExtraDataNotSupported();
        }
        addressesFound = abi.encodePacked(_l1Token, _to);
    }

    // Called on the L2 when a bridge TX fails.
    // Target 0x000000000000000000000000000000000000006E
    // Example TX https://arbiscan.io/tx/0x4465fc37c9f970a2961c855f612cfb04536108dfe88873db44bcd75a08887ab4
    function redeem(bytes32 /*ticketId*/ ) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function createRetryableTicket(
        address to,
        uint256, /*l2CallValue*/
        uint256, /*maxSubmissionCost*/
        address excessFeeRefundAddress,
        address callValueRefundAddress,
        uint256 gasLimit,
        uint256 maxFeePerGas,
        bytes calldata data
    ) external pure virtual returns (bytes memory addressesFound) {
        if (gasLimit < MINIMUM_RETRYABLE_GAS_LIMIT) {
            revert ArbitrumNativeBridgeDecoderAndSanitizer__GasLimitTooSmall();
        }
        if (data.length > 0) {
            revert ArbitrumNativeBridgeDecoderAndSanitizer__NoCallDataForRetryables();
        }
        if (maxFeePerGas > MAXIMUM_GAS_PRICE_BID) {
            revert ArbitrumNativeBridgeDecoderAndSanitizer__MaxGasPriceBid();
        }
        addressesFound = abi.encodePacked(to, excessFeeRefundAddress, callValueRefundAddress);
    }

    // Also unsafe one should not have gasLimit and maxFeePerGas set to 1
    function unsafeCreateRetryableTicket(
        address to,
        uint256, /*l2CallValue*/
        uint256, /*maxSubmissionCost*/
        address excessFeeRefundAddress,
        address callValueRefundAddress,
        uint256 gasLimit,
        uint256 maxFeePerGas,
        bytes calldata data
    ) external pure virtual returns (bytes memory addressesFound) {
        if (gasLimit < MINIMUM_RETRYABLE_GAS_LIMIT) {
            revert ArbitrumNativeBridgeDecoderAndSanitizer__GasLimitTooSmall();
        }
        if (data.length > 0) {
            revert ArbitrumNativeBridgeDecoderAndSanitizer__NoCallDataForRetryables();
        }
        if (maxFeePerGas > MAXIMUM_GAS_PRICE_BID) {
            revert ArbitrumNativeBridgeDecoderAndSanitizer__MaxGasPriceBid();
        }

        addressesFound = abi.encodePacked(to, excessFeeRefundAddress, callValueRefundAddress);
    }
}
