// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import { TransferHelper } from "uni-v3-periphery/libraries/TransferHelper.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

abstract contract ScarabTransferHelper {
    function transferToken(address token, uint256 amountIn, address target) internal returns (uint256) {
        TransferHelper.safeTransferFrom(token, msg.sender, target, amountIn);

        // transfer may take a fee
        uint256 balance = IERC20(token).balanceOf(target);
        if (amountIn > balance) {
            amountIn = balance;
        }

        return amountIn;
    }
}
