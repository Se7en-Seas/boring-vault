// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract KarakDecoderAndSanitizer is BaseDecoderAndSanitizer {
    error KarakDecoderAndSanitizer__InvalidRequestsLength();

    //============================== KARAK ===============================

    function deposit(address vault, uint256, /*amount*/ uint256 /*minOut*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(vault);
    }

    function gimmieShares(address vault, uint256 /*shares*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(vault);
    }

    function returnShares(address vault, uint256 /*shares*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(vault);
    }

    function startWithdraw(DecoderCustomTypes.WithdrawRequest[] calldata requests)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        if (requests.length != 1 || requests[0].vaults.length != 1 || requests[0].shares.length != 1) {
            revert KarakDecoderAndSanitizer__InvalidRequestsLength();
        }
        addressesFound = abi.encodePacked(requests[0].vaults[0], requests[0].withdrawer);
    }

    function finishWithdraw(DecoderCustomTypes.QueuedWithdrawal[] calldata startedWithdrawals)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        if (
            startedWithdrawals.length != 1 || startedWithdrawals[0].request.vaults.length != 1
                || startedWithdrawals[0].request.shares.length != 1
        ) {
            revert KarakDecoderAndSanitizer__InvalidRequestsLength();
        }
        addressesFound = abi.encodePacked(
            startedWithdrawals[0].staker,
            startedWithdrawals[0].delegatedTo,
            startedWithdrawals[0].request.vaults[0],
            startedWithdrawals[0].request.withdrawer
        );
    }
}
