// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import {Utils} from "../../src/lib/Utils.sol";
import {Decimals} from "../../src/lib/Decimals.sol";
import {OracleFeeds} from "../../src/OracleFeeds.sol";
import {FixedPoint} from "../../src/lib/balancer/FixedPoint.sol";
import {BalancerOracleAdapter} from "../../src/BalancerOracleAdapter.sol";
import {IVault} from "@balancer/contracts/interfaces/contracts/vault/IVault.sol";
import {IBalancerV2ManagedPool} from "../../src/lib/balancer/IBalancerV2ManagedPool.sol";
import {IERC20} from "@balancer/contracts/interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract BalancerOracleAdapterTest is Test, BalancerOracleAdapter {
  using Decimals for uint256;
  using FixedPoint for uint256;

  BalancerOracleAdapter private adapter;

  address private poolAddr = address(0x1);
  address private oracleFeed;
  address private ethPriceFeed = address(0x18);
  address private token1PriceFeed = address(0x19);
  address private token2PriceFeed = address(0x1a);
  address private deployer = address(0x3);

  uint256 private ethPrice = 2200 ether; // 2200 USD
  uint256 private token1Price = 1.2 ether; // 1.2 ETH
  uint256 private token2Price = 1.08 ether; // 1.08 ETH

  /**
   * @dev Sets up the testing environment.
   * Deploys the BondToken contract and a proxy, then initializes them.
   * Grants the minter and governance roles and mints initial tokens.
   */
  function setUp() public {
    vm.startPrank(deployer);
    oracleFeed = address(new OracleFeeds());

    // Deploy and initialize BondToken
    adapter = BalancerOracleAdapter(
      Utils.deploy(
        address(new BalancerOracleAdapter()),
        abi.encodeCall(BalancerOracleAdapter.initialize, (poolAddr, 18, oracleFeed, deployer))
      )
    );

    OracleFeeds(oracleFeed).setPriceFeed(adapter.ETH(), adapter.USD(), ethPriceFeed, 1 days);
    OracleFeeds(oracleFeed).setPriceFeed(address(0x5), adapter.ETH(), token1PriceFeed, 1 days);
    OracleFeeds(oracleFeed).setPriceFeed(address(0x6), adapter.ETH(), token2PriceFeed, 1 days);
    vm.stopPrank();
  }

  function testOwner() public view {
    assertEq(adapter.owner(), deployer);
  }

  function testLatestRoundData() public {
    _mockPriceFeeds();

    // Mock required external calls
    vm.mockCall(poolAddr, abi.encodeWithSelector(IBalancerV2ManagedPool.getVault.selector), abi.encode(address(0x4)));

    vm.mockCall(address(0x4), abi.encodeWithSelector(IVault.manageUserBalance.selector), bytes(""));

    vm.mockCall(poolAddr, abi.encodeWithSelector(IBalancerV2ManagedPool.getPoolId.selector), abi.encode(bytes32(0)));

    IERC20[] memory tokens = new IERC20[](3);
    tokens[0] = IERC20(address(0xdddd)); // dummy token, where prod environmet will return BPT
      // address itself
    tokens[1] = IERC20(address(0x5));
    tokens[2] = IERC20(address(0x6));

    uint256[] memory balances = new uint256[](3);
    balances[0] = 0;
    balances[1] = 0.5 ether;
    balances[2] = 0.5 ether;

    vm.mockCall(
      address(0x4), abi.encodeWithSelector(IVault.getPoolTokens.selector), abi.encode(tokens, balances, block.timestamp)
    );

    // Mock getScalingFactors
    uint256[] memory scalingFactors = new uint256[](2);
    scalingFactors[0] = 1e18;
    scalingFactors[1] = 1e18;
    vm.mockCall(
      poolAddr, abi.encodeWithSelector(IBalancerV2ManagedPool.getScalingFactors.selector), abi.encode(scalingFactors)
    );

    // Mock getNormalizedWeights call
    uint256[] memory weights = new uint256[](2);
    weights[0] = 0.5 ether; // 0.5
    weights[1] = 0.5 ether; // 0.5
    vm.mockCall(
      poolAddr, abi.encodeWithSelector(IBalancerV2ManagedPool.getNormalizedWeights.selector), abi.encode(weights)
    );

    // Mock getActualSupply
    vm.mockCall(poolAddr, abi.encodeWithSelector(IBalancerV2ManagedPool.getActualSupply.selector), abi.encode(1 ether));

    // Get latest round data
    (, int256 answer,,,) = adapter.latestRoundData();

    // 2504.5 USD, which is how much each bpt would be with above mocked values:
    // 0.5 * 1.2 + 0.5 * 1.08 = 1.14 ETH
    // Arithmetic mean: 1.14 ETH * 2200 USD/ETH = 2508 USD
    // Geometric mean: 2504.5 USD
    // 0.13% difference between the two is expected
    assertEq(answer, 2_504_523_906_853_256_230_800);
  }

  function testCalculateFairUintPrice() public pure {
    uint256[] memory prices = new uint256[](2);
    prices[0] = 3_009_270_000_000_000_000_000;
    prices[1] = 151_850_000_000_000_000_000;
    uint256[] memory weights = new uint256[](2);
    weights[0] = 200_000_000_000_000_000;
    weights[1] = 800_000_000_000_000_000;
    uint256 invariant = 376_668_723_340_106_111_392_035;
    uint256 totalBPTSupply = 747_200_595_087_878_845_066_224;

    uint256 price = _calculateFairUintPrice(prices, weights, invariant, totalBPTSupply);
    assertTrue(price > 0);
  }

  function _mockPriceFeeds() internal {
    // Mock latestRoundData call for oracle feed
    vm.mockCall(
      ethPriceFeed,
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(uint80(0), int256(ethPrice), uint256(0), block.timestamp, uint80(0))
    );

    vm.mockCall(
      token1PriceFeed,
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(uint80(0), int256(token1Price), uint256(0), block.timestamp, uint80(0))
    );

    vm.mockCall(
      token2PriceFeed,
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(uint80(0), int256(token2Price), uint256(0), block.timestamp, uint80(0))
    );

    // Mock decimals call
    vm.mockCall(ethPriceFeed, abi.encodeWithSelector(AggregatorV3Interface.decimals.selector), abi.encode(uint8(18)));

    vm.mockCall(token1PriceFeed, abi.encodeWithSelector(AggregatorV3Interface.decimals.selector), abi.encode(uint8(18)));

    vm.mockCall(token2PriceFeed, abi.encodeWithSelector(AggregatorV3Interface.decimals.selector), abi.encode(uint8(18)));
  }
}
