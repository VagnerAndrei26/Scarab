// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {TestSetup} from "./TestSetup.sol";

contract UnderlyingsOracleAdapterTest is Test, TestSetup {
  function setUp() public override {
    super.setUp();
  }

  function test_underlyingsOracleAdapter() public view {
    uint256 cbEthUsdPrice = balancerOracleAdapter.getOraclePrice(address(cbEth), USD);
    uint256 cbEthEthPrice = balancerOracleAdapter.getOraclePrice(address(cbEth), ETH);
    uint256 ethUsdPrice = balancerOracleAdapter.getOraclePrice(ETH, USD);

    assertEq(
      cbEthUsdPrice, cbEthEthPrice * ethUsdPrice / 10 ** balancerOracleAdapter.getOracleDecimals(address(cbEth), ETH)
    );
  }
}
