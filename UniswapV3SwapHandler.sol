// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import { ISwapRouter } from "uni-v3-periphery/interfaces/ISwapRouter.sol";
import { TransferHelper } from "uni-v3-periphery/libraries/TransferHelper.sol";
import { ScarabTransferHelper } from "./ScarabTransferHelper.sol";

interface IUniswapRouter is ISwapRouter {
    function refundETH() external payable;
}

abstract contract UniswapV3SwapHandler is ScarabTransferHelper {
    function swapETHExactInV3(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint24 poolFee,
        address to,
        uint256 deadline,
        ISwapRouter uniswapRouter
    )
        internal
    {
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: path[0],
            tokenOut: path[1],
            fee: poolFee,
            recipient: to,
            deadline: deadline,
            amountIn: amountIn,
            amountOutMinimum: amountOutMin,
            sqrtPriceLimitX96: 0
        });
        uniswapRouter.exactInputSingle{ value: amountIn }(params);
    }

    function swapETHExactOutV3(
        uint256 amountIn,
        uint256 amountOut,
        address[] calldata path,
        uint24 poolFee,
        address to,
        uint256 deadline,
        ISwapRouter uniswapRouter
    )
        internal
    {
        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter.ExactOutputSingleParams({
            tokenIn: path[0],
            tokenOut: path[1],
            fee: poolFee,
            recipient: to,
            deadline: deadline,
            amountOut: amountOut,
            amountInMaximum: amountIn,
            sqrtPriceLimitX96: 0
        });
        uniswapRouter.exactOutputSingle{ value: amountIn }(params);
        IUniswapRouter(address(uniswapRouter)).refundETH();
    }

    function swapTokensExactInV3(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint24 poolFee,
        uint256 deadline,
        ISwapRouter uniswapRouter
    )
        internal
    {
        uint256 amountInMax = transferToken(path[0], amountIn, address(this));
        TransferHelper.safeApprove(path[0], address(uniswapRouter), amountInMax);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: path[0],
            tokenOut: path[1],
            fee: poolFee,
            recipient: address(this),
            deadline: deadline,
            amountIn: amountIn,
            amountOutMinimum: amountOutMin,
            sqrtPriceLimitX96: 0
        });
        uniswapRouter.exactInputSingle(params);
    }

    function swapTokensExactOutV3(
        uint256 amountIn,
        uint256 amountOut,
        address[] calldata path,
        uint24 poolFee,
        uint256 deadline,
        ISwapRouter uniswapRouter
    )
        internal
    {
        uint256 amountInMax = transferToken(path[0], amountIn, address(this));
        TransferHelper.safeApprove(path[0], address(uniswapRouter), amountInMax);

        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter.ExactOutputSingleParams({
            tokenIn: path[0],
            tokenOut: path[1],
            fee: poolFee,
            recipient: address(this),
            deadline: deadline,
            amountOut: amountOut,
            amountInMaximum: amountInMax,
            sqrtPriceLimitX96: 0
        });
        uniswapRouter.exactOutputSingle(params);
        IUniswapRouter(address(uniswapRouter)).refundETH();
    }
}
