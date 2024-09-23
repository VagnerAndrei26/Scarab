// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import { IUniversalRouter } from "./interfaces/IUniversalRouter.sol";
import { Commands } from "universal-router/libraries/Commands.sol";
import { Constants } from "universal-router/libraries/Constants.sol";
import { ScarabTransferHelper } from "./ScarabTransferHelper.sol";

abstract contract UniswapUniversalSwapHandler is ScarabTransferHelper {
    function swapETHExactInV2(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline,
        IUniversalRouter universalRouter
    )
        internal
    {
        bytes memory commands =
            abi.encodePacked(bytes1(uint8(Commands.WRAP_ETH)), bytes1(uint8(Commands.V2_SWAP_EXACT_IN)));
        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(universalRouter, amountIn);
        inputs[1] = abi.encode(to, amountIn, amountOutMin, path, false);

        universalRouter.execute{ value: amountIn }(commands, inputs, deadline);
    }

    function swapETHExactInV3(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint24 poolFee,
        address to,
        uint256 deadline,
        IUniversalRouter universalRouter
    )
        internal
    {
        bytes memory commands =
            abi.encodePacked(bytes1(uint8(Commands.WRAP_ETH)), bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));
        bytes[] memory inputs = new bytes[](2);
        bytes memory pathV3 = abi.encodePacked(path[0], poolFee, path[1]);
        inputs[0] = abi.encode(universalRouter, amountIn);
        inputs[1] = abi.encode(to, amountIn, amountOutMin, pathV3, false);

        universalRouter.execute{ value: amountIn }(commands, inputs, deadline);
    }

    function swapETHExactOutV2(
        uint256 amountIn,
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline,
        IUniversalRouter universalRouter
    )
        internal
    {
        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.WRAP_ETH)),
            bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)),
            bytes1(uint8(Commands.UNWRAP_WETH)),
            bytes1(uint8(Commands.SWEEP))
        );

        bytes[] memory inputs = new bytes[](4);
        inputs[0] = abi.encode(address(universalRouter), amountIn);
        inputs[1] = abi.encode(to, amountOut, amountIn, path, false);
        inputs[2] = abi.encode(address(universalRouter), 0);
        inputs[3] = abi.encode(Constants.ETH, address(this), 0);

        universalRouter.execute{ value: amountIn }(commands, inputs, deadline);
    }

    function swapETHExactOutV3(
        uint256 amountIn,
        uint256 amountOut,
        address[] calldata path,
        uint24 poolFee,
        address to,
        uint256 deadline,
        IUniversalRouter universalRouter
    )
        internal
    {
        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.WRAP_ETH)),
            bytes1(uint8(Commands.V3_SWAP_EXACT_OUT)),
            bytes1(uint8(Commands.UNWRAP_WETH)),
            bytes1(uint8(Commands.SWEEP))
        );

        bytes memory pathV3 = abi.encodePacked(path[1], poolFee, path[0]);
        bytes[] memory inputs = new bytes[](4);
        inputs[0] = abi.encode(address(universalRouter), amountIn);
        inputs[1] = abi.encode(to, amountOut, amountIn, pathV3, false);
        inputs[2] = abi.encode(address(universalRouter), 0);
        inputs[3] = abi.encode(Constants.ETH, address(this), 0);

        universalRouter.execute{ value: amountIn }(commands, inputs, deadline);
    }

    function swapTokensExactInV2(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint256 deadline,
        IUniversalRouter universalRouter
    )
        internal
    {
        uint256 amountToSwap = transferToken(path[0], amountIn, address(universalRouter));

        bytes memory commands =
            abi.encodePacked(bytes1(uint8(Commands.V2_SWAP_EXACT_IN)), bytes1(uint8(Commands.UNWRAP_WETH)));

        bytes[] memory inputs = new bytes[](2);
        inputs[0] = abi.encode(address(this), amountToSwap, amountOutMin, path, false);
        inputs[1] = abi.encode(address(this), 0);

        universalRouter.execute(commands, inputs, deadline);
    }

    function swapTokensExactInV3(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint24 poolFee,
        uint256 deadline,
        IUniversalRouter universalRouter
    )
        internal
    {
        uint256 amountToSwap = transferToken(path[0], amountIn, address(universalRouter));

        bytes memory commands =
            abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)), bytes1(uint8(Commands.UNWRAP_WETH)));

        bytes memory pathV3 = abi.encodePacked(path[0], poolFee, path[1]);
        bytes[] memory inputs = new bytes[](2);

        inputs[0] = abi.encode(address(this), amountToSwap, amountOutMin, pathV3, false);
        inputs[1] = abi.encode(address(this), 0);

        universalRouter.execute(commands, inputs, deadline);
    }

    function swapTokensExactOutV2(
        uint256 amountIn,
        uint256 amountOut,
        address[] calldata path,
        uint256 deadline,
        IUniversalRouter universalRouter
    )
        internal
    {
        uint256 amountInMax = transferToken(path[0], amountIn, address(universalRouter));

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.V2_SWAP_EXACT_OUT)),
            bytes1(uint8(Commands.UNWRAP_WETH)),
            bytes1(uint8(Commands.SWEEP))
        );

        bytes[] memory inputs = new bytes[](3);
        inputs[0] = abi.encode(address(this), amountOut, amountInMax, path, false);
        inputs[1] = abi.encode(address(this), 0);
        inputs[2] = abi.encode(path[0], msg.sender, 0);

        universalRouter.execute(commands, inputs, deadline);
    }

    function swapTokensExactOutV3(
        uint256 amountIn,
        uint256 amountOut,
        address[] calldata path,
        uint24 poolFee,
        uint256 deadline,
        IUniversalRouter universalRouter
    )
        internal
    {
        uint256 amountInMax = transferToken(path[0], amountIn, address(universalRouter));

        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.V3_SWAP_EXACT_OUT)),
            bytes1(uint8(Commands.UNWRAP_WETH)),
            bytes1(uint8(Commands.SWEEP))
        );

        // NB: path is reversed for V3
        bytes memory pathV3 = abi.encodePacked(path[1], poolFee, path[0]);
        bytes[] memory inputs = new bytes[](3);
        inputs[0] = abi.encode(address(this), amountOut, amountInMax, pathV3, false);
        inputs[1] = abi.encode(address(this), 0);
        inputs[2] = abi.encode(path[0], msg.sender, 0);

        universalRouter.execute(commands, inputs, deadline);
    }
}
