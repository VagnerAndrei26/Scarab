// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

// TYPES
enum RouterType {
    V2,
    V3,
    UNI_V2,
    UNI_V3,
    ZERO_EX
}

interface IScarabRouter {
    // EVENTS

    event FeePaid(address indexed from, address indexed to, uint256 amount);
    event ReferralFeePaid(address indexed from, address indexed to, uint256 amount);

    // CUSTOM ERRORS

    error InvalidRouterType();
    error InvalidPath();
    error RefundFailed();
    error SendFailed();

    // FUNCTIONS

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
        payable;

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
        payable;

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
        external;

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
        external;
}
