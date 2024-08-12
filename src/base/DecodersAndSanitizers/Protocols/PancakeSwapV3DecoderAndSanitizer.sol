// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {UniswapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3DecoderAndSanitizer.sol";
import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {PancakeSwapV3MasterChef} from "src/interfaces/RawDataDecoderAndSanitizerInterfaces.sol";

/// @notice When positions are staked in Masterchef, they can be managed, as if they were being held in the BoringVault.
/// To support this, we just need the merkle tree to specify the masterchef contract instead of the position manager.
/// This also harvests rewards.
abstract contract PancakeSwapV3DecoderAndSanitizer is UniswapV3DecoderAndSanitizer {
    //============================== IMMUTABLES ===============================

    PancakeSwapV3MasterChef internal immutable pancakeSwapV3MasterChef;

    constructor(address _pancakeSwapV3NonFungiblePositionManager, address _pancakeSwapV3MasterChef)
        UniswapV3DecoderAndSanitizer(_pancakeSwapV3NonFungiblePositionManager)
    {
        pancakeSwapV3MasterChef = PancakeSwapV3MasterChef(_pancakeSwapV3MasterChef);
    }

    function exactInput(DecoderCustomTypes.PancakeSwapExactInputParams calldata params)
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
        if (pathLength % chunkSize != 20) revert UniswapV3DecoderAndSanitizer__BadPathFormat();
        uint256 pathAddressLength = 1 + (pathLength / chunkSize);
        uint256 pathIndex;
        for (uint256 i; i < pathAddressLength; ++i) {
            addressesFound = abi.encodePacked(addressesFound, params.path[pathIndex:pathIndex + 20]);
            pathIndex += chunkSize;
        }
        addressesFound = abi.encodePacked(addressesFound, params.recipient);
    }

    function increaseLiquidity(DecoderCustomTypes.IncreaseLiquidityParams calldata params)
        external
        view
        override
        returns (bytes memory addressesFound)
    {
        // Sanitize raw data
        address owner = uniswapV3NonFungiblePositionManager.ownerOf(params.tokenId);
        if (owner != boringVault) {
            (,,,,,, address stakedUser,,) = pancakeSwapV3MasterChef.userPositionInfos(params.tokenId);
            if (owner != address(pancakeSwapV3MasterChef) || stakedUser != boringVault) {
                revert UniswapV3DecoderAndSanitizer__BadTokenId();
            }
        }

        // Extract addresses from uniswapV3NonFungiblePositionManager.positions(params.tokenId).
        (, address operator, address token0, address token1,,,,,,,,) =
            uniswapV3NonFungiblePositionManager.positions(params.tokenId);
        addressesFound = abi.encodePacked(operator, token0, token1);
    }

    function decreaseLiquidity(DecoderCustomTypes.DecreaseLiquidityParams calldata params)
        external
        view
        override
        returns (bytes memory addressesFound)
    {
        // Sanitize raw data
        // NOTE ownerOf check is done in PositionManager contract as well, but it is added here
        // just for completeness.
        address owner = uniswapV3NonFungiblePositionManager.ownerOf(params.tokenId);
        if (owner != boringVault) {
            (,,,,,, address stakedUser,,) = pancakeSwapV3MasterChef.userPositionInfos(params.tokenId);
            if (owner != address(pancakeSwapV3MasterChef) || stakedUser != boringVault) {
                revert UniswapV3DecoderAndSanitizer__BadTokenId();
            }
        }

        // No addresses in data
        return addressesFound;
    }

    function collect(DecoderCustomTypes.CollectParams calldata params)
        external
        view
        override
        returns (bytes memory addressesFound)
    {
        // Sanitize raw data
        // NOTE ownerOf check is done in PositionManager contract as well, but it is added here
        // just for completeness.
        address owner = uniswapV3NonFungiblePositionManager.ownerOf(params.tokenId);
        if (owner != boringVault) {
            (,,,,,, address stakedUser,,) = pancakeSwapV3MasterChef.userPositionInfos(params.tokenId);
            if (owner != address(pancakeSwapV3MasterChef) || stakedUser != boringVault) {
                revert UniswapV3DecoderAndSanitizer__BadTokenId();
            }
        }
        // Return addresses found
        addressesFound = abi.encodePacked(params.recipient);
    }
    // TODO remove these comments?
    // In order to stake, the NFT must be transferred to the PancakeSwapV3 Masterchef contract
    // Target 0x46A15B0b27311cedF172AB29E4f4766fbE7F4364
    // Exmaple TX https://etherscan.io/tx/0x78226c1fa7a7a003f696bd8e622c8362da9acc3e00f6f3a6aff87b04b144e10e

    function safeTransferFrom(address from, address to, uint256 /*tokenId*/ )
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(from, to);
    }

    // In order to harvest cake rewards.
    // Target 0x556B9306565093C855AEA9AE92A594704c2Cd59e
    // Example TX https://etherscan.io/tx/0x27e1a277f1211ee1ab214e94effb139f6a7681e18edf552d4fea100ed9a8d3a3
    function harvest(uint256, /*_tokenId*/ address _to) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_to);
    }

    // In order to unstake, this will also harvest rewards.
    // Target 0x556B9306565093C855AEA9AE92A594704c2Cd59e
    // Example TX https://etherscan.io/tx/0x5759e8965232d86822f137af6aae3c9cdbc3b5f73ec50b5a8c24e3646b9d6af2
    function withdraw(uint256, /*_tokenId*/ address _to) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_to);
    }
}
