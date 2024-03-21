// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {INonFungiblePositionManager} from "src/interfaces/RawDataDecoderAndSanitizerInterfaces.sol";
import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract UniswapV3DecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== IMMUTABLES ===============================

    /**
     * @notice The networks uniswapV3 nonfungible position manager.
     */
    INonFungiblePositionManager internal immutable uniswapV3NonFungiblePositionManager;

    constructor(address _uniswapV3NonFungiblePositionManager) {
        uniswapV3NonFungiblePositionManager = INonFungiblePositionManager(_uniswapV3NonFungiblePositionManager);
    }

    //============================== UNISWAP V3 ===============================

    // TODO this could probs be made more efficient since we can slice calldata
    function exactInput(DecoderCustomTypes.ExactInputParams calldata params)
        external
        pure
        virtual
        returns (address[] memory addressesFound)
    {
        // Nothing to sanitize
        // Return addresses found
        // Determine how many addresses are in params.path.
        uint256 chunkSize = 23; // 3 bytes for uint24 fee, and 20 bytes for address token
        uint256 pathLength = params.path.length;
        require(pathLength % chunkSize == 20, "wrong path format"); // We expect a remainder of 20
        uint256 pathAddressLength = 1 + (pathLength / chunkSize);
        addressesFound = new address[](1 + pathAddressLength);
        uint256 pathIndex;
        for (uint256 i; i < pathAddressLength; ++i) {
            bytes20 rawAddress;
            for (uint256 j; j < 20; ++j) {
                rawAddress |= bytes20(params.path[pathIndex + j]) >> (j * 8);
            }
            addressesFound[i] = address(rawAddress);
            pathIndex += chunkSize;
        }
        addressesFound[pathAddressLength] = params.recipient;
    }

    function mint(DecoderCustomTypes.MintParams calldata params)
        external
        pure
        virtual
        returns (address[] memory addressesFound)
    {
        // Nothing to sanitize
        // Return addresses found
        addressesFound = new address[](3);
        addressesFound[0] = params.token0;
        addressesFound[1] = params.token1;
        addressesFound[2] = params.recipient;
    }

    function increaseLiquidity(DecoderCustomTypes.IncreaseLiquidityParams calldata params)
        external
        view
        virtual
        returns (address[] memory addressesFound)
    {
        // Sanitize raw data
        require(
            uniswapV3NonFungiblePositionManager.ownerOf(params.tokenId) == boringVault,
            "adding liquidity to a position not owned by vault"
        );
        // No addresses in data
        return addressesFound;
    }

    function decreaseLiquidity(DecoderCustomTypes.DecreaseLiquidityParams calldata params)
        external
        view
        virtual
        returns (address[] memory addressesFound)
    {
        // Sanitize raw data
        // NOTE ownerOf check is done in PositionManager contract as well, but it is added here
        // just for completeness.
        require(
            uniswapV3NonFungiblePositionManager.ownerOf(params.tokenId) == boringVault,
            "removing liquidity from a position not owned by vault"
        );
        // No addresses in data
        return addressesFound;
    }

    function collect(DecoderCustomTypes.CollectParams calldata params)
        external
        view
        virtual
        returns (address[] memory addressesFound)
    {
        // Sanitize raw data
        // NOTE ownerOf check is done in PositionManager contract as well, but it is added here
        // just for completeness.
        require(
            uniswapV3NonFungiblePositionManager.ownerOf(params.tokenId) == boringVault,
            "collecting from a position not owned by vault"
        );
        // Return addresses found
        addressesFound = new address[](1);
        addressesFound[0] = params.recipient;
    }
}
