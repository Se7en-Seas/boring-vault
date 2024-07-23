// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {CamelotNonFungiblePositionManager} from "src/interfaces/RawDataDecoderAndSanitizerInterfaces.sol";
import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract CamelotDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== ERRORS ===============================

    error CamelotDecoderAndSanitizer__BadTokenId();
    error CamelotDecoderAndSanitizer__BadPathFormat();

    //============================== IMMUTABLES ===============================

    /**
     * @notice The networks Camelot nonfungible position manager.
     * @notice Arbitrum 0x00c7f3082833e796A5b3e4Bd59f6642FF44DCD15
     * @notice
     */
    CamelotNonFungiblePositionManager internal immutable velodromeNonFungiblePositionManager;

    constructor(address _velodromeNonFungiblePositionManager) {
        velodromeNonFungiblePositionManager = CamelotNonFungiblePositionManager(_velodromeNonFungiblePositionManager);
    }

    //============================== CAMELOT V3 ===============================

    function exactInput(DecoderCustomTypes.ExactInputParams calldata params)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize
        // Return addresses found
        // Determine how many addresses are in params.path.
        uint256 chunkSize = 23; // 3 bytes for uint24 fee, and 20 bytes for address token
        uint256 pathLength = params.path.length;
        if (pathLength % chunkSize != 20) revert CamelotDecoderAndSanitizer__BadPathFormat();
        uint256 pathAddressLength = 1 + (pathLength / chunkSize);
        uint256 pathIndex;
        for (uint256 i; i < pathAddressLength; ++i) {
            addressesFound = abi.encodePacked(addressesFound, params.path[pathIndex:pathIndex + 20]);
            pathIndex += chunkSize;
        }
        addressesFound = abi.encodePacked(addressesFound, params.recipient);
    }

    function mint(DecoderCustomTypes.CamelotMintParams calldata params)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize
        // Return addresses found
        addressesFound = abi.encodePacked(params.token0, params.token1, params.recipient);
    }

    function increaseLiquidity(DecoderCustomTypes.IncreaseLiquidityParams calldata params)
        external
        view
        virtual
        returns (bytes memory addressesFound)
    {
        // Sanitize raw data
        if (velodromeNonFungiblePositionManager.ownerOf(params.tokenId) != boringVault) {
            revert CamelotDecoderAndSanitizer__BadTokenId();
        }
        // Extract addresses from VelodromeNonFungiblePositionManager.positions(params.tokenId).
        (, address operator, address token0, address token1,,,,,,,) =
            velodromeNonFungiblePositionManager.positions(params.tokenId);
        addressesFound = abi.encodePacked(operator, token0, token1);
    }

    function decreaseLiquidity(DecoderCustomTypes.DecreaseLiquidityParams calldata params)
        external
        view
        virtual
        returns (bytes memory addressesFound)
    {
        // Sanitize raw data
        // NOTE ownerOf check is done in PositionManager contract as well, but it is added here
        // just for completeness.
        if (velodromeNonFungiblePositionManager.ownerOf(params.tokenId) != boringVault) {
            revert CamelotDecoderAndSanitizer__BadTokenId();
        }

        // No addresses in data
        return addressesFound;
    }

    function collect(DecoderCustomTypes.CollectParams calldata params)
        external
        view
        virtual
        returns (bytes memory addressesFound)
    {
        // Sanitize raw data
        // NOTE ownerOf check is done in PositionManager contract as well, but it is added here
        // just for completeness.
        if (velodromeNonFungiblePositionManager.ownerOf(params.tokenId) != boringVault) {
            revert CamelotDecoderAndSanitizer__BadTokenId();
        }

        // Return addresses found
        addressesFound = abi.encodePacked(params.recipient);
    }

    function burn(uint256 /*tokenId*/ ) external pure virtual returns (bytes memory addressesFound) {
        // positionManager.burn(tokenId) will verify that the tokenId has no liquidity, and no tokens owed.
        // Nothing to sanitize or return
        return addressesFound;
    }
}