// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { ScarabTransferHelper } from "./ScarabTransferHelper.sol";

abstract contract ZeroExSwapHandler is ScarabTransferHelper {
    error InvalidTarget();
    error ApprovalFailed();
    error SwapFailed();

    // see https://docs.0x.org/developer-resources/contract-addresses
    address public immutable EXCHANGE_PROXY_ADDRESS;

    constructor(address exchangeProxyAddress) {
        EXCHANGE_PROXY_ADDRESS = exchangeProxyAddress;
    }

    // Swaps ERC20->ERC20 tokens held by this contract using a 0x-API quote.
    function fillQuote(
        IERC20 inputToken,
        uint256 protocolFee,
        // The `allowanceTarget` field from the API response.
        address spender,
        // The `to` field from the API response.
        address payable swapTarget,
        // The `data` field from the API response.
        bytes calldata swapCallData
    )
        internal
        virtual
    {
        if (swapTarget != EXCHANGE_PROXY_ADDRESS) {
            revert InvalidTarget();
        }
        // NB: the only scenario where spender != swapTarget is when swapping with native ETH, but we don't support this
        // and handle wrap/unwrap in the ScarabRouter
        if (spender != EXCHANGE_PROXY_ADDRESS) {
            revert InvalidTarget();
        }

        // Give `spender` an infinite allowance to spend this contract's `sellToken`.
        // Note that for some tokens (e.g., USDT, KNC), you must first reset any existing
        // allowance to 0 before being able to update it.
        if (!inputToken.approve(spender, type(uint256).max)) {
            revert ApprovalFailed();
        }

        // Call the encoded swap function call on the contract at `swapTarget`,
        // passing along any ETH attached to this function call to cover protocol fees.
        (bool success,) = swapTarget.call{ value: protocolFee }(swapCallData);
        if (!success) {
            revert SwapFailed();
        }
    }
}
