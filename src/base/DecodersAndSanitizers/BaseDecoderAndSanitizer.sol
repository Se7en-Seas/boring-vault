// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract BaseDecoderAndSanitizer {
    //============================== IMMUTABLES ===============================

    /**
     * @notice The networks uniswapV3 nonfungible position manager.
     */
    address internal immutable boringVault;

    constructor(address _boringVault) {
        boringVault = _boringVault;
    }

    function approve(address a, uint256) external pure returns (address[] memory addressesFound) {
        addressesFound = new address[](1);
        addressesFound[0] = a;
    }

    //     leafs[0] = ManageLeaf(address(WETH), "approve(address,uint256)", new address[](1));
    // leafs[0].argumentAddresses[0] = uniV3Router;
    // leafs[1] = ManageLeaf(uniV3Router, "exactInput((bytes,address,uint256,uint256,uint256))", new address[](3));
    // leafs[1].argumentAddresses[0] = address(WETH);
    // leafs[1].argumentAddresses[1] = address(RETH);
    // leafs[1].argumentAddresses[2] = address(boringVault);
    // leafs[2] = ManageLeaf(address(RETH), "approve(address,uint256)", new address[](1));
    // leafs[2].argumentAddresses[0] = uniswapV3NonFungiblePositionManager;
    // leafs[3] = ManageLeaf(address(WEETH), "approve(address,uint256)", new address[](1));
    // leafs[3].argumentAddresses[0] = uniswapV3NonFungiblePositionManager;
    // leafs[4] = ManageLeaf(
    //     uniswapV3NonFungiblePositionManager,
    //     "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))",
    //     new address[](3)
    // );
    // leafs[4].argumentAddresses[0] = address(RETH);
    // leafs[4].argumentAddresses[1] = address(WEETH);
    // leafs[4].argumentAddresses[2] = address(boringVault);
    // leafs[5] = ManageLeaf(
    //     uniswapV3NonFungiblePositionManager,
    //     "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))",
    //     new address[](0)
    // );
    // leafs[6] = ManageLeaf(
    //     uniswapV3NonFungiblePositionManager,
    //     "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))",
    //     new address[](0)
    // );
    // leafs[7] = ManageLeaf(
    //     uniswapV3NonFungiblePositionManager, "collect((uint256,address,uint128,uint128))", new address[](1)
    // );
    // leafs[7].argumentAddresses[0] = address(boringVault);
}
