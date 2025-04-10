// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {Utils} from "../src/lib/Utils.sol";
import {PreDeposit} from "../src/PreDeposit.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {Token} from "../test/mocks/Token.sol";

contract PreDepositScript is Script {
  PreDeposit public preDeposit;
  PoolFactory.PoolParams private params;

  uint256 constant RESERVE_CAP = 100 ether;

  function run(
    address _reserveToken,
    address _couponToken,
    address _poolFactory,
    address _balancerPoolFactory,
    address _balancerVault,
    address _balancerOracleAdapter,
    address[] memory _allowedTokens,
    address _feeBeneficiary,
    uint256 _distributionPeriod,
    uint256 _sharesPerToken
  ) public {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

    params = PoolFactory.PoolParams({
      fee: 0,
      reserveToken: _reserveToken,
      couponToken: _couponToken,
      distributionPeriod: _distributionPeriod,
      sharesPerToken: _sharesPerToken,
      feeBeneficiary: _feeBeneficiary
    });

    preDeposit = PreDeposit(
      Utils.deploy(
        address(new PreDeposit()),
        abi.encodeCall(
          PreDeposit.initialize,
          (
            params,
            _poolFactory,
            _balancerPoolFactory,
            _balancerVault,
            _balancerOracleAdapter,
            block.timestamp,
            block.timestamp + 7 days,
            RESERVE_CAP,
            _allowedTokens,
            "Bond ETH",
            "bondETH",
            "Levered ETH",
            "levETH"
          )
        )
      )
    );
  }
}
