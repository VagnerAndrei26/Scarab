// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {
  IManagedPoolFactory,
  ManagedPoolParams,
  ManagedPoolSettingsParams
} from "../../src/lib/balancer/IManagedPoolFactory.sol";
import {IVault} from "@balancer/contracts/interfaces/contracts/vault/IVault.sol";
import {MockBalancerPool} from "./MockBalancerPool.sol";
import {MockBalancerVault} from "./MockBalancerVault.sol";

contract MockBalancerPoolFactory is IManagedPoolFactory {
  address balancerVault;

  constructor(address _balancerVault) {
    balancerVault = _balancerVault;
  }

  function create(ManagedPoolParams memory, ManagedPoolSettingsParams memory, address, bytes32)
    external
    returns (address)
  {
    address pool = address(new MockBalancerPool(balancerVault));
    bytes32 poolId = MockBalancerPool(pool).getPoolId();
    MockBalancerVault(balancerVault).setPool(poolId, pool);
    return pool;
  }
}
