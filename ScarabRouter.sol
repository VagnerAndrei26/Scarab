// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import { IScarabRouter, RouterType } from "./interfaces/IScarabRouter.sol";
import { UniswapUniversalSwapHandler } from "./UniswapUniversalSwapHandler.sol";
import { UniswapV3SwapHandler } from "./UniswapV3SwapHandler.sol";
import { UniswapV2SwapHandler } from "./UniswapV2SwapHandler.sol";
import { ZeroExSwapHandler } from "./ZeroExSwapHandler.sol";
import { Ownable } from "openzeppelin/access/Ownable.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { IWETH } from "uni-v2-periphery/interfaces/IWETH.sol";
import { IUniswapV2Router02 } from "uni-v2-periphery/interfaces/IUniswapV2Router02.sol";
import { ISwapRouter } from "uni-v3-periphery/interfaces/ISwapRouter.sol";
import { IUniversalRouter } from "./interfaces/IUniversalRouter.sol";
import { TransferHelper } from "uni-v3-periphery/libraries/TransferHelper.sol";

contract ScarabRouter is
    IScarabRouter,
    UniswapUniversalSwapHandler,
    UniswapV3SwapHandler,
    UniswapV2SwapHandler,
    ZeroExSwapHandler,
    Ownable
{
    address payable public feeWallet;
    // MODIFIERS

    modifier checkPath(address[] calldata path) {
        if (path.length != 2) revert InvalidPath();
        _;
    }

    // --------------
    // INIT

    constructor(address feeWallet_, address exchangeProxyAddress) ZeroExSwapHandler(exchangeProxyAddress) {
        feeWallet = payable(feeWallet_);
    }

    receive() external payable { }

    // --------------
    // 0x SWAP

    function fillZeroExBuyQuote(
        address[] calldata path,
        uint256 protocolFee,
        uint256 feeBps,
        address referrer,
        uint256 referralFeeBps,
        address spender,
        address payable swapTarget,
        bytes calldata swapCallData
    )
        external
        payable
    {
        // extract fee from input ETH
        uint256 amountIn =
            msg.value - protocolFee - extractFeeWithReferral(msg.value - protocolFee, feeBps, referrer, referralFeeBps);

        // wrap ETH
        IWETH(path[0]).deposit{ value: amountIn }();

        fillQuote(IERC20(path[0]), protocolFee, spender, swapTarget, swapCallData);

        // send output token to sender
        uint256 amountOut = IERC20(path[1]).balanceOf(address(this));
        TransferHelper.safeTransfer(path[1], msg.sender, amountOut);

        // refund unspent protocol fees
        uint256 refund = address(this).balance;
        if (refund > 0 && refund <= protocolFee) {
            (bool sentRefund,) = payable(msg.sender).call{ value: refund }("");
            if (!sentRefund) revert RefundFailed();
        }
    }

    function fillZeroExSellQuote(
        address[] calldata path,
        uint256 amountIn,
        uint256 feeBps,
        address referrer,
        uint256 referralFeeBps,
        address spender,
        address payable swapTarget,
        bytes calldata swapCallData
    )
        external
        payable
    {
        transferToken(path[0], amountIn, address(this));
        uint256 initialBalance = address(this).balance;

        // fill quote
        IERC20 sellToken = IERC20(path[0]);
        fillQuote(sellToken, msg.value, spender, swapTarget, swapCallData);

        // unwrap weth
        uint256 wethOut = IERC20(path[1]).balanceOf(address(this));
        IWETH(path[1]).withdraw(wethOut);

        // extract fee
        uint256 amountOut = address(this).balance - initialBalance;
        uint256 remainder = amountOut - extractFeeWithReferral(amountOut, feeBps, referrer, referralFeeBps);

        // refund remainder
        (bool sent,) = payable(msg.sender).call{ value: remainder }("");
        if (!sent) revert SendFailed();
    }

    // --------------
    // SWAP

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        uint256 deadline,
        uint256 feeBps,
        address referrer,
        uint256 referralFeeBps,
        address router,
        RouterType routerType,
        uint24 poolFee // V3 pool fee
    )
        external
        payable
    {
        // extract fee from input ETH
        uint256 amountIn = msg.value - extractFeeWithReferral(msg.value, feeBps, referrer, referralFeeBps);

        if (routerType == RouterType.UNI_V3) {
            swapETHExactInV3(amountIn, amountOutMin, path, poolFee, msg.sender, deadline, IUniversalRouter(router));
        } else if (routerType == RouterType.UNI_V2) {
            swapETHExactInV2(amountIn, amountOutMin, path, msg.sender, deadline, IUniversalRouter(router));
        } else if (routerType == RouterType.V3) {
            swapETHExactInV3(amountIn, amountOutMin, path, poolFee, msg.sender, deadline, ISwapRouter(router));
        } else if (routerType == RouterType.V2) {
            swapETHExactInV2(amountIn, amountOutMin, path, msg.sender, deadline, IUniswapV2Router02(router));
        } else {
            revert InvalidRouterType();
        }
    }

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        uint256 deadline,
        uint256 feeBps,
        address referrer,
        uint256 referralFeeBps,
        address router,
        RouterType routerType,
        uint24 poolFee // V3 pool fee
    )
        external
        payable
    {
        uint256 initialBalance = address(this).balance;

        // subtract max fee from input ETH then swap
        uint256 amountIn = msg.value - ((msg.value * feeBps) / 10_000);

        if (routerType == RouterType.UNI_V3) {
            swapETHExactOutV3(amountIn, amountOut, path, poolFee, msg.sender, deadline, IUniversalRouter(router));
        } else if (routerType == RouterType.UNI_V2) {
            swapETHExactOutV2(amountIn, amountOut, path, msg.sender, deadline, IUniversalRouter(router));
        } else if (routerType == RouterType.V3) {
            swapETHExactOutV3(amountIn, amountOut, path, poolFee, msg.sender, deadline, ISwapRouter(router));
        } else if (routerType == RouterType.V2) {
            swapETHExactOutV2(amountIn, amountOut, path, msg.sender, deadline, IUniswapV2Router02(router));
        } else {
            revert InvalidRouterType();
        }

        // extract fee on actual amount spent
        uint256 amountSpent = initialBalance - address(this).balance;
        uint256 actualFee = extractFeeWithReferral(amountSpent, feeBps, referrer, referralFeeBps);

        // refund remainder
        uint256 refund = msg.value - amountSpent - actualFee;
        if (refund > 0) {
            (bool sentRefund,) = payable(msg.sender).call{ value: refund }("");
            if (!sentRefund) revert RefundFailed();
        }
    }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint256 deadline,
        uint256 feeBps,
        address referrer,
        uint256 referralFeeBps,
        address router,
        RouterType routerType,
        uint24 poolFee // V3 pool fee
    )
        external
    {
        // swap token for ETH then extract fee
        uint256 prevBalance = address(this).balance;

        if (routerType == RouterType.UNI_V3) {
            swapTokensExactInV3(amountIn, amountOutMin, path, poolFee, deadline, IUniversalRouter(router));
        } else if (routerType == RouterType.UNI_V2) {
            swapTokensExactInV2(amountIn, amountOutMin, path, deadline, IUniversalRouter(router));
        } else if (routerType == RouterType.V3) {
            swapTokensExactInV3(amountIn, amountOutMin, path, poolFee, deadline, ISwapRouter(router));
        } else if (routerType == RouterType.V2) {
            swapTokensExactInV2(amountIn, amountOutMin, path, deadline, IUniswapV2Router02(router));
        } else {
            revert InvalidRouterType();
        }

        uint256 wethOut = IERC20(path[1]).balanceOf(address(this));
        IWETH(path[1]).withdraw(wethOut);

        uint256 amountOut = address(this).balance - prevBalance;
        uint256 remainder = amountOut - extractFeeWithReferral(amountOut, feeBps, referrer, referralFeeBps);
        (bool sent,) = payable(msg.sender).call{ value: remainder }("");
        if (!sent) revert SendFailed();
    }

    function swapTokensForExactETH(
        uint256 amountInMax,
        uint256 amountOut,
        address[] calldata path,
        uint256 deadline,
        uint256 feeBps,
        address referrer,
        uint256 referralFeeBps,
        address router,
        RouterType routerType,
        uint24 poolFee // V3 pool fee
    )
        external
    {
        // swap token for ETH then extract fee
        uint256 prevBalance = address(this).balance;

        if (routerType == RouterType.UNI_V3) {
            swapTokensExactOutV3(amountInMax, amountOut, path, poolFee, deadline, IUniversalRouter(router));
        } else if (routerType == RouterType.UNI_V2) {
            swapTokensExactOutV2(amountInMax, amountOut, path, deadline, IUniversalRouter(router));
        } else if (routerType == RouterType.V3) {
            swapTokensExactOutV3(amountInMax, amountOut, path, poolFee, deadline, ISwapRouter(router));
        } else if (routerType == RouterType.V2) {
            swapTokensExactOutV2(amountInMax, amountOut, path, deadline, IUniswapV2Router02(router));
        } else {
            revert InvalidRouterType();
        }

        uint256 wethOut = IERC20(path[1]).balanceOf(address(this));
        IWETH(path[1]).withdraw(wethOut);

        uint256 tokenRemainder = IERC20(path[0]).balanceOf(address(this));
        if (tokenRemainder > 0) {
            TransferHelper.safeTransfer(path[0], msg.sender, tokenRemainder);
        }

        uint256 amountReceived = address(this).balance - prevBalance;
        uint256 remainder = amountReceived - extractFeeWithReferral(amountReceived, feeBps, referrer, referralFeeBps);
        (bool sent,) = payable(msg.sender).call{ value: remainder }("");
        if (!sent) revert SendFailed();
    }

    // HELPERS

    function extractFeeWithReferral(
        uint256 amountIn,
        uint256 feeBps,
        address referrer,
        uint256 referralFeeBps
    )
        internal
        returns (uint256)
    {
        uint256 totalFee = (amountIn * feeBps) / 10_000;
        uint256 referralFee = (totalFee * referralFeeBps) / 10_000;
        uint256 fee = totalFee - referralFee;

        (bool sent,) = feeWallet.call{ value: fee }("");
        if (!sent) revert SendFailed();
        emit FeePaid(msg.sender, feeWallet, fee);

        if (referralFee > 0) {
            (bool sentReferral,) = referrer.call{ value: referralFee }("");
            if (!sentReferral) revert SendFailed();
            emit ReferralFeePaid(msg.sender, referrer, referralFee);
        }

        return totalFee;
    }

    // ADMIN

    function setFeeWallet(address addr) external onlyOwner {
        feeWallet = payable(addr);
    }
}
