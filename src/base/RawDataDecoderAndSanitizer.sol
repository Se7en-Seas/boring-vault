// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {console} from "@forge-std/Test.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {INonFungiblePositionManager} from "src/interfaces/RawDataDecoderAndSanitizerInterfaces.sol";

contract RawDataDecoderAndSanitizer {
    INonFungiblePositionManager internal immutable uniswapV3NonFungiblePositionManager;

    constructor(address _uniswapV3NonFungiblePositionManager) {
        uniswapV3NonFungiblePositionManager = INonFungiblePositionManager(_uniswapV3NonFungiblePositionManager);
    }
    // ========================================= ERC20 =========================================
    // approve, transfer

    bytes32 internal constant HASHED_ARGUMENTS_ADDRESS_UINT256 = keccak256("(address,uint256)");

    // ========================================= ERC4626 =========================================
    // deposit, mint, balancer liquidity gauge deposit, curve liquidity gauge deposit
    bytes32 internal constant HASHED_ARGUMENTS_UINT256_ADDRESS = keccak256("(uint256,address)");
    // withdraw, redeem
    bytes32 internal constant HASHED_ARGUMENTS_UINT256_ADDRESS_ADDRESS = keccak256("(uint256,address,address)");

    // ========================================= BALANCER =========================================
    // flashLoan
    bytes32 internal constant HASHED_ARGUMENTS_ADDRESS_ADDRESS_ARRAY_UINT256_ARRAY_BYTES =
        keccak256("(address,address[],uint256[],bytes)");
    // swap
    bytes32 internal constant HASHED_ARGUMENTS_SINGLE_SWAP_FUND_MANAGEMENT_UINT256_UINT256 =
        keccak256("((bytes32,uint8,address,addressuint256,bytes),(address,bool,address,bool),uint256,uint256)");
    // join, exit
    bytes32 internal constant HASHED_ARGUMENTS_BYTES32_ADDRESS_ADDRESS_POOL_REQUEST =
        keccak256("(bytes32,address,address,(address[],uint256[],bytes,bool))");
    // withdraw from liquidity gauge, withdraw from curve liquidity gauge
    bytes32 internal constant HASHED_ARGUMENTS_UINT256 = keccak256("(uint256)");
    // claim rewards from balancer minter
    bytes32 internal constant HASHED_ARGUMENTS_ADDRESS = keccak256("(address)");

    // ========================================= UNISWAP V3 =========================================
    // Mint
    bytes32 internal constant HASHED_ARGUMENTS_MINT_PARAMS =
        keccak256("((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))");
    // increaseLiquidity
    bytes32 internal constant HASHED_ARGUMENTS_INCREASE_LIQUIDITY_PARAMS =
        keccak256("((uint256,uint256,uint256,uint256,uint256,uint256))");
    // decreaseLiquidity
    bytes32 internal constant HASHED_ARGUMENTS_DECREASE_LIQUIDITY_PARAMS =
        keccak256("((uint256,uint128,uint256,uint256,uint256))");
    // collect
    bytes32 internal constant HASHED_ARGUMENTS_COLLECT_PARAMS = keccak256("((uint256,address,uint128,uint128))");
    // exactInput router swap
    bytes32 internal constant HASHED_ARGUMENTS_EXACT_INPUT_PARAMS =
        keccak256("((bytes,address,uint256,uint256,uint256))");

    // ========================================= CURVE =========================================
    // exchange
    bytes32 internal constant HASHED_ARGUMENTS_INT128_INT128_UINT256_UINT256 =
        keccak256("(int128,int128,uint256,uint256)");
    // add_liquidity Versions
    bytes32 internal constant HASHED_ARGUMENTS_UINT256_FIXED_2_ARRAY_UINT256 = keccak256("(uint256[2],uint256)");
    bytes32 internal constant HASHED_ARGUMENTS_UINT256_FIXED_3_ARRAY_UINT256 = keccak256("(uint256[3],uint256)");
    bytes32 internal constant HASHED_ARGUMENTS_UINT256_ARRAY_UINT256 = keccak256("(uint256[],uint256)");
    // remove_liquidity Versions
    bytes32 internal constant HASHED_ARGUMENTS_UINT256_UINT256_FIXED_2_ARRAY = keccak256("(uint256,uint256[2])");
    bytes32 internal constant HASHED_ARGUMENTS_UINT256_UINT256_FIXED_3_ARRAY = keccak256("(uint256,uint256[3])");
    bytes32 internal constant HASHED_ARGUMENTS_UINT256_UINT256_ARRAY = keccak256("(uint256,uint256[])");
    // claim_rewards
    bytes32 internal constant HASHED_ARGUMENTS_NONE = keccak256("()");

    // ========================================= AURA ERC4626 =========================================
    // getReward, convex getReward
    bytes32 internal constant HASHED_ARGUMENTS_ADDRESS_BOOL = keccak256("(address,bool)");

    // ========================================= CONVEX =========================================
    // deposit
    /// NOTE this setup does not prevent the strategist from depositing into any convex pool, but
    // the strategist would need to get that pools udnerlying curve LP token which is restricted.
    bytes32 internal constant HASHED_ARGUMENTS_UINT256_UINT256_BOOL = keccak256("(uint256,uint256,bool)");
    // withdrawAndUnwrap
    bytes32 internal constant HASHED_ARGUMENTS_UINT256_BOOL = keccak256("(uint256,bool)");

    // ========================================= MORPHO =========================================
    // supplyCollateral
    bytes32 internal constant HASHED_ARGUMENTS_MARKET_PARAMS_UINT256_ADDRESS_BYTES =
        keccak256("((address,address,address,address,uint256),uint256,address,bytes)");
    // borrow, withdraw
    bytes32 internal constant HASHED_ARGUMENTS_MARKET_PARAMS_UINT256_UINT256_ADDRESS_ADDRESS =
        keccak256("((address,address,address,address,uint256),uint256,uint256,address,address)");
    // withdraw collateral
    bytes32 internal constant HASHED_ARGUMENTS_MARKET_PARAMS_UINT256_ADDRESS_ADDRESS =
        keccak256("((address,address,address,address,uint256),uint256,address,address)");
    // repay, supply
    bytes32 internal constant HASHED_ARGUMENTS_MARKET_PARAMS_UINT256_UINT256_ADDRESS_BYTES =
        keccak256("((address,address,address,address,uint256),uint256,uint256,address,bytes)");

    /**
     * @notice This function both decodes, and sanitizes raw contract data.
     * @dev Decoding is needed to find any addresses in the contract data, and return them to the caller.
     * @dev Sanitizing is performing logical checks on non address arguments in the contract data.
     */
    function decodeAndSanitizeRawData(address boringVault, string calldata functionSignature, bytes calldata rawData)
        external
        view
        returns (address[] memory addressesFound)
    {
        // Iterate through string until an open parenthesis is found.
        bytes32 hashedArguments;
        {
            bytes memory functionSignature_bytes = bytes(functionSignature);
            uint256 functionSignature_length = functionSignature_bytes.length;
            bytes1 open_char = bytes1("(");
            for (uint256 i; i < functionSignature_length; ++i) {
                if (functionSignature_bytes[i] == open_char) {
                    // We found the open char, so save the hashedArguments.
                    hashedArguments = keccak256(bytes(functionSignature[i:]));
                    break;
                }
            }
            if (hashedArguments == bytes32(0)) revert("Failed to find arguments");
        }

        if (hashedArguments == HASHED_ARGUMENTS_ADDRESS_UINT256) {
            addressesFound = new address[](1);
            addressesFound[0] = abi.decode(rawData, (address));
        } else if (hashedArguments == HASHED_ARGUMENTS_UINT256_ADDRESS) {
            addressesFound = new address[](1);
            (, addressesFound[0]) = abi.decode(rawData, (uint256, address));
        } else if (hashedArguments == HASHED_ARGUMENTS_UINT256_ADDRESS_ADDRESS) {
            addressesFound = new address[](2);
            (, addressesFound[0], addressesFound[1]) = abi.decode(rawData, (uint256, address, address));
        } else if (hashedArguments == HASHED_ARGUMENTS_ADDRESS_ADDRESS_ARRAY_UINT256_ARRAY_BYTES) {
            (address first, address[] memory second) = abi.decode(rawData, (address, address[]));
            addressesFound = new address[](second.length + 1);
            addressesFound[0] = first;
            for (uint256 i; i < second.length; ++i) {
                addressesFound[i + 1] = second[i];
            }
        } else if (hashedArguments == HASHED_ARGUMENTS_SINGLE_SWAP_FUND_MANAGEMENT_UINT256_UINT256) {
            (DecoderCustomTypes.SingleSwap memory singleSwap, DecoderCustomTypes.FundManagement memory funds) =
                abi.decode(rawData, (DecoderCustomTypes.SingleSwap, DecoderCustomTypes.FundManagement));
            // Sanitize raw data
            require(singleSwap.userData.length == 0, "SingleSwap userData non zero length.");
            // Return addresses found
            addressesFound = new address[](5);
            addressesFound[0] = _getPoolAddressFromPoolId(singleSwap.poolId); // Extract pool address from poolId
            addressesFound[1] = singleSwap.assetIn;
            addressesFound[2] = singleSwap.assetOut;
            addressesFound[3] = funds.sender;
            addressesFound[4] = funds.recipient;
        } else if (hashedArguments == HASHED_ARGUMENTS_BYTES32_ADDRESS_ADDRESS_POOL_REQUEST) {
            (bytes32 poolId, address sender, address recipient, DecoderCustomTypes.PoolRequest memory req) =
                abi.decode(rawData, (bytes32, address, address, DecoderCustomTypes.PoolRequest));
            // Sanitize raw data
            require(!req.useInternalBalance, "internal balances not supported");
            // Return addresses found
            uint256 assetsLength = req.assets.length;
            addressesFound = new address[](3 + assetsLength);
            addressesFound[0] = _getPoolAddressFromPoolId(poolId);
            addressesFound[1] = sender;
            addressesFound[2] = recipient;
            for (uint256 i; i < assetsLength; ++i) {
                addressesFound[i + 3] = req.assets[i];
            }
        } else if (hashedArguments == HASHED_ARGUMENTS_MINT_PARAMS) {
            (DecoderCustomTypes.MintParams memory params) = abi.decode(rawData, (DecoderCustomTypes.MintParams));
            // Nothing to sanitize
            // Return addresses found
            addressesFound = new address[](3);
            addressesFound[0] = params.token0;
            addressesFound[1] = params.token1;
            addressesFound[2] = params.recipient;
        } else if (hashedArguments == HASHED_ARGUMENTS_INCREASE_LIQUIDITY_PARAMS) {
            (DecoderCustomTypes.IncreaseLiquidityParams memory params) =
                abi.decode(rawData, (DecoderCustomTypes.IncreaseLiquidityParams));
            // Sanitize raw data
            require(
                uniswapV3NonFungiblePositionManager.ownerOf(params.tokenId) == boringVault,
                "adding liquidity to a position not owned by vault"
            );
            // No addresses in data
        } else if (hashedArguments == HASHED_ARGUMENTS_DECREASE_LIQUIDITY_PARAMS) {
            (DecoderCustomTypes.DecreaseLiquidityParams memory params) =
                abi.decode(rawData, (DecoderCustomTypes.DecreaseLiquidityParams));
            // Sanitize raw data
            // NOTE ownerOf check is done in PositionManager contract as well, but it is added here
            // just for completeness.
            require(
                uniswapV3NonFungiblePositionManager.ownerOf(params.tokenId) == boringVault,
                "removing liquidity from a position not owned by vault"
            );
            // No addresses in data
        } else if (hashedArguments == HASHED_ARGUMENTS_COLLECT_PARAMS) {
            (DecoderCustomTypes.CollectParams memory params) = abi.decode(rawData, (DecoderCustomTypes.CollectParams));
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
        } else if (hashedArguments == HASHED_ARGUMENTS_INT128_INT128_UINT256_UINT256) {
            // Nothing to sanitize or return
        } else if (hashedArguments == HASHED_ARGUMENTS_UINT256_FIXED_2_ARRAY_UINT256) {
            // Nothing to sanitize or return
        } else if (hashedArguments == HASHED_ARGUMENTS_UINT256_FIXED_3_ARRAY_UINT256) {
            // Nothing to sanitize or return
        } else if (hashedArguments == HASHED_ARGUMENTS_UINT256_ARRAY_UINT256) {
            // Nothing to sanitize or return
        } else if (hashedArguments == HASHED_ARGUMENTS_UINT256_UINT256_FIXED_2_ARRAY) {
            // Nothing to sanitize or return
        } else if (hashedArguments == HASHED_ARGUMENTS_UINT256_UINT256_FIXED_3_ARRAY) {
            // Nothing to sanitize or return
        } else if (hashedArguments == HASHED_ARGUMENTS_UINT256_UINT256_ARRAY) {
            // Nothing to sanitize or return
        } else if (hashedArguments == HASHED_ARGUMENTS_ADDRESS_BOOL) {
            addressesFound = new address[](1);
            addressesFound[0] = abi.decode(rawData, (address));
        } else if (hashedArguments == HASHED_ARGUMENTS_UINT256) {
            // Nothing to sanitize or return
        } else if (hashedArguments == HASHED_ARGUMENTS_ADDRESS) {
            addressesFound = new address[](1);
            addressesFound[0] = abi.decode(rawData, (address));
        } else if (hashedArguments == HASHED_ARGUMENTS_NONE) {
            // Nothing to sanitize or return
        } else if (hashedArguments == HASHED_ARGUMENTS_UINT256_UINT256_BOOL) {
            // Nothing to sanitize or return
        } else if (hashedArguments == HASHED_ARGUMENTS_UINT256_BOOL) {
            // Nothing to sanitize or return
        } else if (hashedArguments == HASHED_ARGUMENTS_EXACT_INPUT_PARAMS) {
            (DecoderCustomTypes.ExactInputParams memory params) =
                abi.decode(rawData, (DecoderCustomTypes.ExactInputParams));
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
                    rawAddress = rawAddress | params.path[pathIndex + j] << (19 - j) * 8;
                }
                addressesFound[i] = address(rawAddress);
                pathIndex += chunkSize;
            }
            addressesFound[pathAddressLength] = params.recipient;
        } else if (hashedArguments == HASHED_ARGUMENTS_MARKET_PARAMS_UINT256_ADDRESS_BYTES) {
            (DecoderCustomTypes.MarketParams memory params,, address onBehalf, bytes memory callbackData) =
                abi.decode(rawData, (DecoderCustomTypes.MarketParams, uint256, address, bytes));
            // Sanitize raw data
            require(callbackData.length == 0, "callback not supported");
            // Return addresses found
            addressesFound = new address[](5);
            addressesFound[0] = params.loanToken;
            addressesFound[1] = params.collateralToken;
            addressesFound[2] = params.oracle;
            addressesFound[3] = params.irm;
            addressesFound[4] = onBehalf;
        } else if (hashedArguments == HASHED_ARGUMENTS_MARKET_PARAMS_UINT256_UINT256_ADDRESS_ADDRESS) {
            (DecoderCustomTypes.MarketParams memory params,,, address onBehalf, address receiver) =
                abi.decode(rawData, (DecoderCustomTypes.MarketParams, uint256, uint256, address, address));
            // Nothing to sanitize
            // Return addresses found
            addressesFound = new address[](6);
            addressesFound[0] = params.loanToken;
            addressesFound[1] = params.collateralToken;
            addressesFound[2] = params.oracle;
            addressesFound[3] = params.irm;
            addressesFound[4] = onBehalf;
            addressesFound[5] = receiver;
        } else if (hashedArguments == HASHED_ARGUMENTS_MARKET_PARAMS_UINT256_ADDRESS_ADDRESS) {
            (DecoderCustomTypes.MarketParams memory params,, address onBehalf, address receiver) =
                abi.decode(rawData, (DecoderCustomTypes.MarketParams, uint256, address, address));
            // Nothing to sanitize
            // Return addresses found
            addressesFound = new address[](6);
            addressesFound[0] = params.loanToken;
            addressesFound[1] = params.collateralToken;
            addressesFound[2] = params.oracle;
            addressesFound[3] = params.irm;
            addressesFound[4] = onBehalf;
            addressesFound[5] = receiver;
        } else if (hashedArguments == HASHED_ARGUMENTS_MARKET_PARAMS_UINT256_UINT256_ADDRESS_BYTES) {
            (DecoderCustomTypes.MarketParams memory params,,, address onBehalf, bytes memory callbackData) =
                abi.decode(rawData, (DecoderCustomTypes.MarketParams, uint256, uint256, address, bytes));
            // Sanitize raw data
            require(callbackData.length == 0, "callback not supported");
            // Return addresses found
            addressesFound = new address[](5);
            addressesFound[0] = params.loanToken;
            addressesFound[1] = params.collateralToken;
            addressesFound[2] = params.oracle;
            addressesFound[3] = params.irm;
            addressesFound[4] = onBehalf;
        } else {
            // We do not know how to safely decode and sanitize this data, so revert.
            revert("unknown hash");
        }
    }

    function _getPoolAddressFromPoolId(bytes32 poolId) internal pure returns (address) {
        return address(uint160(uint256(poolId >> 96)));
    }
}
