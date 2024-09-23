// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import { IUniswapV2Router02 } from "uni-v2-periphery/interfaces/IUniswapV2Router02.sol";
import { TransferHelper } from "uni-v3-periphery/libraries/TransferHelper.sol";
import { ScarabTransferHelper } from "./ScarabTransferHelper.sol";

abstract contract UniswapV2SwapHandler is ScarabTransferHelper {
    function swapETHExactInV2(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline,
        IUniswapV2Router02 uniswapRouter
    )
        internal
    {
        uniswapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{ value: amountIn }(
            amountOutMin, path, to, deadline
        );
    }

    function swapETHExactOutV2(
        uint256 amountIn,
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline,
        IUniswapV2Router02 uniswapRouter
    )
        internal
    {
        uniswapRouter.swapETHForExactTokens{ value: amountIn }(amountOut, path, to, deadline);
    }

    function swapTokensExactInV2(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint256 deadline,
        IUniswapV2Router02 uniswapRouter
    )
        internal
    {
        uint256 amountInMax = transferToken(path[0], amountIn, address(this));
        TransferHelper.safeApprove(path[0], address(uniswapRouter), amountInMax);
        uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountInMax, amountOutMin, path, address(this), deadline
        );
    }

    function swapTokensExactOutV2(
        uint256 amountIn,
        uint256 amountOut,
        address[] calldata path,
        uint256 deadline,
        IUniswapV2Router02 uniswapRouter
    )
        internal
    {
        uint256 amountInMax = transferToken(path[0], amountIn, address(this));
        TransferHelper.safeApprove(path[0], address(uniswapRouter), amountInMax);
        uniswapRouter.swapTokensForExactETH(amountOut, amountInMax, path, address(this), deadline);
    }
}
