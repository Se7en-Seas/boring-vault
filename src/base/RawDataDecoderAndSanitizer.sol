// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {INonFungiblePositionManager} from "src/interfaces/RawDataDecoderAndSanitizerInterfaces.sol";
import {console} from "@forge-std/Test.sol"; // TODO remove
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract RawDataDecoderAndSanitizer {
    using Address for address;
    // ========================================= CONSTANTS =========================================

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

    //============================== IMMUTABLES ===============================

    /**
     * @notice The networks uniswapV3 nonfungible position manager.
     */
    INonFungiblePositionManager internal immutable uniswapV3NonFungiblePositionManager;

    constructor(address _uniswapV3NonFungiblePositionManager) {
        uniswapV3NonFungiblePositionManager = INonFungiblePositionManager(_uniswapV3NonFungiblePositionManager);
    }

    /**
     * @notice This function both decodes, and sanitizes raw contract data.
     * @dev Decoding is needed to find any addresses in the contract data, and return them to the caller.
     * @dev Sanitizing is performing logical checks on non address arguments in the contract data.
     * @param boringVault the BoringVault that will be making a call using rawData
     * @param rawData the raw call data with the bytes4 selector removed
     */
    function decodeAndSanitizeRawData(address boringVault, bytes calldata rawData)
        external
        view
        returns (address[] memory addressesFound)
    {
        bytes memory result = address(this).functionStaticCall(rawData);
        addressesFound = abi.decode(result, (address[]));
        // Iterate through string until an open parenthesis is found.
        bytes32 hashedArguments;

        // TODO should these verify the length of the raw data? So we know that we aren't trying to pass extra arguments in the msg.data?
        if (hashedArguments == HASHED_ARGUMENTS_UINT256_ADDRESS_ADDRESS) {
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
            // (bytes32 poolId, address sender, address recipient, DecoderCustomTypes.PoolRequest memory req) =
            //     abi.decode(rawData, (bytes32, address, address, DecoderCustomTypes.PoolRequest));
            // // Sanitize raw data
            // require(!req.useInternalBalance, "internal balances not supported");
            // // Return addresses found
            // uint256 assetsLength = req.assets.length;
            // addressesFound = new address[](3 + assetsLength);
            // addressesFound[0] = _getPoolAddressFromPoolId(poolId);
            // addressesFound[1] = sender;
            // addressesFound[2] = recipient;
            // for (uint256 i; i < assetsLength; ++i) {
            //     addressesFound[i + 3] = req.assets[i];
            // }
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

    // ========================================= INTERNAL HELPER FUNCTIONS =========================================

    /**
     * @notice Internal helper function that converts poolIds to pool addresses.
     */
    function _getPoolAddressFromPoolId(bytes32 poolId) internal pure returns (address) {
        return address(uint160(uint256(poolId >> 96)));
    }
}
