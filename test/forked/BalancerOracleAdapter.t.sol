// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {TestSetup, BalancerOracleAdapter} from "./TestSetup.sol";
import {IManagedPool} from "../../src/lib/balancer/IManagedPool.sol";
import {IVault} from "@balancer/contracts/interfaces/contracts/vault/IVault.sol";
import {IERC20} from "@balancer/contracts/interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";

contract BalancerOracleAdapterTest is Test, TestSetup {
  function setUp() public override {
    super.setUp();
    createPool();
  }

  function testReasonableBptPrice() public view {
    bytes32 poolId = IManagedPool(balancerPool).getPoolId();
    (IERC20[] memory tokens, uint256[] memory balances,) = IVault(balancerVault).getPoolTokens(poolId);
    uint256[] memory scalingFactors = IManagedPool(balancerPool).getScalingFactors();

    uint256[] memory prices = new uint256[](tokens.length - 1);
    for (uint8 i = 1; i < tokens.length; i++) {
      prices[i - 1] = balancerOracleAdapter.getOraclePrice(address(tokens[i]), ETH);
    }

    balances = _removeFirstElement(balances);
    for (uint256 i = 0; i < balances.length; i++) {
      balances[i] = balances[i] * scalingFactors[i] / 1e18;
    }

    uint256 totalEthInBalancerPool;
    for (uint256 i = 0; i < balances.length; i++) {
      totalEthInBalancerPool += balances[i] * prices[i] / 1e18;
    }

    uint256 totalUsdInBalancerPool = totalEthInBalancerPool * balancerOracleAdapter.getOraclePrice(ETH, USD)
      / 10 ** balancerOracleAdapter.getOracleDecimals(address(tokens[1]), ETH);

    uint256 fairUintUSDPrice = totalUsdInBalancerPool * 1e18 / IManagedPool(balancerPool).getActualSupply();
    (, int256 adapterPrice,,,) = balancerOracleAdapter.latestRoundData();

    assertApproxEqRel(fairUintUSDPrice, uint256(adapterPrice), 0.00001e18); // 0.001% tolerance
      // between arithmetic and geometric price mean
  }

  function _removeFirstElement(uint256[] memory arr) public pure returns (uint256[] memory) {
    uint256[] memory newArr = new uint256[](arr.length - 1);
    for (uint256 i = 1; i < arr.length; i++) {
      newArr[i - 1] = arr[i];
    }
    return newArr;
  }
}
