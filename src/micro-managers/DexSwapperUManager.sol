// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IUniswapV3Router} from "src/interfaces/IUniswapV3Router.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";

interface PriceRouter {
    function getValue(ERC20 baseAsset, uint256 amount, ERC20 quoteAsset) external view returns (uint256 value);
}

contract DexSwapperUManager is Auth {
    using FixedPointMathLib for uint256;
    /**
     * Merkle Root Specifications
     * - Should contain leafs to approve router to spend input tokens.
     * - Should contain leafs to call IUniswapV3Router.exactInput(params);
     *
     *
     *
     *
     *
     *
     *
     */

    ManagerWithMerkleVerification internal immutable manager;
    BoringVault internal immutable boringVault;
    IUniswapV3Router internal immutable router;
    PriceRouter internal immutable priceRouter;

    uint16 public allowedSlippage = 0.01e4;

    constructor(address _owner, address _manager, address _boringVault, address _router, address _priceRouter)
        Auth(_owner, Authority(address(0)))
    {
        manager = ManagerWithMerkleVerification(_manager);
        boringVault = BoringVault(payable(_boringVault));
        router = IUniswapV3Router(_router);
        priceRouter = PriceRouter(_priceRouter);
    }

    // TODO main merkle tree should contain approve 0 calls for EVERY possible spender

    function swapWithUniswapV3(
        bytes32[][] calldata manageProofs,
        address[] calldata decodersAndSanitizers,
        ERC20[] memory path,
        uint24[] memory fees,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) external requiresAuth {
        address[] memory targets = new address[](2);
        bytes[] memory targetData = new bytes[](2);
        uint256[] memory values = new uint256[](2);
        // Build first approve data.
        targets[0] = address(path[0]);
        targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(router), amountIn);
        // values[0] = 0;

        // Build ExactInputParams.
        {
            if (path.length - 1 != fees.length) revert("Bad path/fees");
            bytes memory packedPath = abi.encodePacked(path[0]);
            for (uint256 i; i < fees.length; ++i) {
                packedPath = abi.encodePacked(fees[i], path[i + 1]);
            }
            IUniswapV3Router.ExactInputParams memory params = IUniswapV3Router.ExactInputParams({
                path: packedPath,
                recipient: address(boringVault),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: amountOutMinimum
            });
            targets[1] = address(router);
            targetData[1] = abi.encodeWithSelector(IUniswapV3Router.exactInput.selector, params);
            // values[1] = 0;
        }

        ERC20 tokenOut = path[path.length - 1];
        uint256 tokenOutBalanceDelta = tokenOut.balanceOf(address(boringVault));

        // Make the manage call.
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        tokenOutBalanceDelta = tokenOut.balanceOf(address(boringVault)) - tokenOutBalanceDelta;

        uint256 tokenOutQuotedInTokenIn = priceRouter.getValue(tokenOut, tokenOutBalanceDelta, path[0]);

        if (tokenOutQuotedInTokenIn < amountIn.mulDivDown(1e4 - allowedSlippage, 1e4)) revert("slippage");
    }
}
