// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {TestSetup, BalancerOracleAdapter, BondToken, BondOracleAdapter} from "./TestSetup.sol";
import {IManagedPool} from "../../src/lib/balancer/IManagedPool.sol";
import {IVault} from "@balancer/contracts/interfaces/contracts/vault/IVault.sol";
import {IERC20} from "@balancer/contracts/interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";

import {ICLFactory} from "../../src/lib/concentrated-liquidity/ICLFactory.sol";
import {ICLPool} from "../../src/lib/concentrated-liquidity/ICLPool.sol";
import {TickMath} from "../../src/lib/concentrated-liquidity/TickMath.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {FullMath} from "../../src/lib/concentrated-liquidity/FullMath.sol";
import {Utils} from "../../src/lib/Utils.sol";

interface IDecimals {
  function decimals() external view returns (uint256);
}

contract BondOracleAdapterTest is Test, TestSetup {
  address aerodromePool;

  function setUp() public override {
    super.setUp();
    createPool();
  }

  function testDeployAerodomeCLPool() public {
    vm.startPrank(user1);

    // Provide substantial initial amounts
    deal(address(couponToken), user1, 1_000_000 * 10 ** 6); // 1M USDC
    deal(address(bondToken), user1, 10_000 * 10 ** 18); // 10K bondToken

    couponToken.approve(address(aerodromeCLFactory), type(uint256).max);
    bondToken.approve(address(aerodromeCLFactory), type(uint256).max);
    bondToken.approve(address(aerodromePositionManager), type(uint256).max);
    couponToken.approve(address(aerodromePositionManager), type(uint256).max);

    // Calculate initial sqrt price for 100 USDC per bondToken
    uint256 price = 100 * 10 ** 12; // 100 * (10^18 / 10^6)
    uint256 Q96 = 2 ** 96;
    uint160 sqrtPriceX96 = uint160(Math.sqrt(price) * Q96);
    int24 tickSpacing = 200;

    // Create pool
    aerodromePool =
      ICLFactory(aerodromeCLFactory).createPool(address(bondToken), address(couponToken), tickSpacing, sqrtPriceX96);

    console.log("Pool deployed at:", aerodromePool);

    // Sort tokens (token0 must be the lower address)
    (address token0, address token1) = address(bondToken) < address(couponToken)
      ? (address(bondToken), address(couponToken))
      : (address(couponToken), address(bondToken));

    // Get current tick from pool
    (uint160 currentSqrtPriceX96, int24 currentTick,,,,) = ICLPool(aerodromePool).slot0();

    console.log("Current tick:", currentTick);
    console.log("Current sqrtPriceX96:", getPriceFromSqrtPriceX96(currentSqrtPriceX96));

    // Calculate ticks for price range, ensuring they're rounded to valid tick spacing
    int24 tickLower = ((currentTick - tickSpacing * 10) / tickSpacing) * tickSpacing;
    int24 tickUpper = ((currentTick + tickSpacing * 10) / tickSpacing) * tickSpacing;

    // Prepare substantial amounts for initial liquidity
    uint256 amount0Desired = 1000 * 10 ** 18; // 1000 bondTokens
    uint256 amount1Desired = 100_000 * 10 ** 6; // 100,000 USDC

    // Create mint params
    ICLPool.MintParams memory params = ICLPool.MintParams({
      token0: token0,
      token1: token1,
      tickSpacing: tickSpacing,
      tickLower: tickLower,
      tickUpper: tickUpper,
      amount0Desired: amount0Desired,
      amount1Desired: amount1Desired,
      amount0Min: 0, // Set to 0 for testing
      amount1Min: 0, // Set to 0 for testing
      recipient: user1,
      deadline: block.timestamp + 1 hours,
      sqrtPriceX96: 0
    });

    // Mint position
    (uint256 amount0, uint256 amount1, uint128 liquidity, uint256 tokenId) =
      ICLPool(aerodromePositionManager).mint(params);

    console.log("Amount0:", amount0);
    console.log("Amount1:", amount1);
    console.log("Liquidity:", liquidity);
    console.log("Token ID:", tokenId);

    (currentSqrtPriceX96, currentTick,,,,) = ICLPool(aerodromePool).slot0();

    console.log("Current tick:", currentTick);
    console.log("sqrtPriceX96:", currentSqrtPriceX96);
    console.log("Current sqrtPriceX96:", getPriceFromSqrtPriceX96(currentSqrtPriceX96));

    bondOracleAdapter = BondOracleAdapter(
      Utils.deploy(
        address(new BondOracleAdapter()),
        abi.encodeCall(
          BondOracleAdapter.initialize,
          (address(bondToken), address(couponToken), 60, address(aerodromeCLFactory), user1)
        )
      )
    );

    console.log("BondOracleAdapter deployed at:", address(bondOracleAdapter));

    vm.warp(block.timestamp + 2 minutes);
    (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
      bondOracleAdapter.latestRoundData();

    console.log("roundId:", roundId);
    console.log("answer:", answer);
    console.log("startedAt:", startedAt);
    console.log("updatedAt:", updatedAt);
    console.log("answeredInRound:", answeredInRound);

    vm.stopPrank();
  }

  function getPriceFromSqrtPriceX96(uint160 sqrtPriceX96) public view returns (uint256) {
    uint256 Q96 = 0x1000000000000000000000000;
    // Compute the price in Q96 format
    uint256 priceX96 = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, Q96);

    console.log("priceX96:", priceX96);

    bool isPoolInverted = ICLPool(aerodromePool).token0() == address(bondToken);

    console.log("isPoolInverted:", isPoolInverted);

    // Convert from Q96 to bondToken decimals
    return isPoolInverted
      ? FullMath.mulDiv(priceX96, 10 ** IDecimals(address(couponToken)).decimals(), Q96)
      : FullMath.mulDiv(10 ** IDecimals(address(couponToken)).decimals(), Q96, priceX96);
  }
}
