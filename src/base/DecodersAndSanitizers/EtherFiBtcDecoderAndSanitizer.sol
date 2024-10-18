// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {UniswapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3DecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {OneInchDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";
import {EigenLayerLSTStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/EigenLayerLSTStakingDecoderAndSanitizer.sol";
import {SymbioticDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SymbioticDecoderAndSanitizer.sol";
import {KarakDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/KarakDecoderAndSanitizer.sol";
import {SatlayerStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/SatlayerStakingDecoderAndSanitizer.sol";
import {CornStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/CornStakingDecoderAndSanitizer.sol";

contract EtherFiBtcDecoderAndSanitizer is
    UniswapV3DecoderAndSanitizer,
    ERC4626DecoderAndSanitizer,
    OneInchDecoderAndSanitizer,
    EigenLayerLSTStakingDecoderAndSanitizer,
    SymbioticDecoderAndSanitizer,
    KarakDecoderAndSanitizer,
    SatlayerStakingDecoderAndSanitizer,
    CornStakingDecoderAndSanitizer
{
    constructor(address _boringVault, address _uniswapV3NonFungiblePositionManager)
        BaseDecoderAndSanitizer(_boringVault)
        UniswapV3DecoderAndSanitizer(_uniswapV3NonFungiblePositionManager)
    {}

    //============================== HANDLE FUNCTION COLLISIONS ===============================

    /**
     * @notice Symbiotic, and CornStaking both specify a `withdraw(address,uint256)`,
     *         all cases are handled the same way.
     */
    function withdraw(address recipient, uint256 /*amount*/ )
        external
        pure
        override(SymbioticDecoderAndSanitizer, SatlayerStakingDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(recipient);
    }

    /**
     * @notice Symbiotic, and CornStaking both specify a `deposit(address,uint256)`,
     *         all cases are handled the same way.
     */
    function deposit(address recipient, uint256 /*amount*/ )
        external
        pure
        override(SymbioticDecoderAndSanitizer, CornStakingDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(recipient);
    }
}
