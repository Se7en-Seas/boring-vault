// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract BalancerV2DecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== BALANCER V2 ===============================

    function flashLoan(address recipient, address[] calldata tokens, uint256[] calldata, bytes calldata)
        external
        pure
        virtual
        returns (address[] memory addressesFound)
    {
        addressesFound = new address[](tokens.length + 1);
        addressesFound[0] = recipient;
        for (uint256 i; i < tokens.length; ++i) {
            addressesFound[i + 1] = tokens[i];
        }
    }

    function swap(
        DecoderCustomTypes.SingleSwap calldata singleSwap,
        DecoderCustomTypes.FundManagement calldata funds,
        uint256,
        uint256
    ) external pure virtual returns (address[] memory addressesFound) {
        // Sanitize raw data
        require(singleSwap.userData.length == 0, "SingleSwap userData non zero length.");
        require(!funds.fromInternalBalance, "internal balances not supported");
        require(!funds.toInternalBalance, "internal balances not supported");

        // Return addresses found
        addressesFound = new address[](5);
        addressesFound[0] = _getPoolAddressFromPoolId(singleSwap.poolId); // Extract pool address from poolId
        addressesFound[1] = singleSwap.assetIn;
        addressesFound[2] = singleSwap.assetOut;
        addressesFound[3] = funds.sender;
        addressesFound[4] = funds.recipient;
    }

    function joinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        DecoderCustomTypes.JoinPoolRequest calldata req
    ) external pure virtual returns (address[] memory addressesFound) {
        // Sanitize raw data
        require(!req.fromInternalBalance, "internal balances not supported");
        // Return addresses found
        uint256 assetsLength = req.assets.length;
        addressesFound = new address[](3 + assetsLength);
        addressesFound[0] = _getPoolAddressFromPoolId(poolId);
        addressesFound[1] = sender;
        addressesFound[2] = recipient;
        for (uint256 i; i < assetsLength; ++i) {
            addressesFound[i + 3] = req.assets[i];
        }
    }

    function exitPool(
        bytes32 poolId,
        address sender,
        address recipient,
        DecoderCustomTypes.ExitPoolRequest calldata req
    ) external pure virtual returns (address[] memory addressesFound) {
        // Sanitize raw data
        require(!req.toInternalBalance, "internal balances not supported");
        // Return addresses found
        uint256 assetsLength = req.assets.length;
        addressesFound = new address[](3 + assetsLength);
        addressesFound[0] = _getPoolAddressFromPoolId(poolId);
        addressesFound[1] = sender;
        addressesFound[2] = recipient;
        for (uint256 i; i < assetsLength; ++i) {
            addressesFound[i + 3] = req.assets[i];
        }
    }

    function deposit(uint256, address recipient) external pure virtual returns (address[] memory addressesFound) {
        addressesFound = new address[](1);
        addressesFound[0] = recipient;
    }

    function withdraw(uint256) external pure virtual returns (address[] memory addressesFound) {
        // No addresses in data
        return addressesFound;
    }

    function mint(address gauge) external pure virtual returns (address[] memory addressesFound) {
        addressesFound = new address[](1);
        addressesFound[0] = gauge;
    }

    // ========================================= INTERNAL HELPER FUNCTIONS =========================================

    /**
     * @notice Internal helper function that converts poolIds to pool addresses.
     */
    function _getPoolAddressFromPoolId(bytes32 poolId) internal pure returns (address) {
        return address(uint160(uint256(poolId >> 96)));
    }
}
