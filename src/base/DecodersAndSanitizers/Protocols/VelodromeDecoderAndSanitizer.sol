// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {INonFungiblePositionManager} from "src/interfaces/RawDataDecoderAndSanitizerInterfaces.sol";
import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract VelodromeDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== ERRORS ===============================

    error VelodromeDecoderAndSanitizer__BadTokenId();
    error VelodromeDecoderAndSanitizer__PoolCreationNotAllowed();

    //============================== IMMUTABLES ===============================

    /**
     * @notice The networks velodrom nonfungible position manager.
     * @notice Optimism 0x416b433906b1B72FA758e166e239c43d68dC6F29
     * @notice Base 0x827922686190790b37229fd06084350E74485b72
     * @notice
     */
    INonFungiblePositionManager internal immutable velodromeNonFungiblePositionManager;

    constructor(address _velodromeNonFungiblePositionManager) {
        velodromeNonFungiblePositionManager = INonFungiblePositionManager(_velodromeNonFungiblePositionManager);
    }

    //============================== VELODROME V3 ===============================

    function mint(DecoderCustomTypes.VelodromeMintParams calldata params)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        if(params.sqrtPriceX96 != 0) {
            revert VelodromeDecoderAndSanitizer__PoolCreationNotAllowed();
        }
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
            revert VelodromeDecoderAndSanitizer__BadTokenId();
        }
        // Extract addresses from VelodromeNonFungiblePositionManager.positions(params.tokenId).
        (, address operator, address token0, address token1,,,,,,,,) =
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
            revert VelodromeDecoderAndSanitizer__BadTokenId();
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
            revert VelodromeDecoderAndSanitizer__BadTokenId();
        }

        // Return addresses found
        addressesFound = abi.encodePacked(params.recipient);
    }

    function burn(uint256 /*tokenId*/ ) external pure virtual returns (bytes memory addressesFound) {
        // positionManager.burn(tokenId) will verify that the tokenId has no liquidity, and no tokens owed.
        // Nothing to sanitize or return
        return addressesFound;
    }

    //============================== VELODROME V2 ===============================

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool, /*stable*/
        uint256, /*amountADesired*/
        uint256, /*amountBDesired*/
        uint256, /*amountAMin*/
        uint256, /*amountBMin*/
        address to,
        uint256 /*deadline*/
    ) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize
        // Return addresses found
        addressesFound = abi.encodePacked(tokenA, tokenB, to);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool, /*stable*/
        uint256, /*liquidity*/
        uint256, /*amountAMin*/
        uint256, /*amountBMin*/
        address to,
        uint256 /*deadline*/
    ) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize
        // Return addresses found
        addressesFound = abi.encodePacked(tokenA, tokenB, to);
    }

    //============================== VELODROME V2/V3 GAUGE ===============================

    function deposit(uint256 /*tokenId_or_amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function withdraw(uint256 /*tokenId_or_amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    // Only callable on V3 gauge
    function getReward(uint256 /*tokenId*/ ) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function getReward(address account) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(account);
    }
}
