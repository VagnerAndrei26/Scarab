// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MockBalancerPool} from "./MockBalancerPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVault} from "@balancer/contracts/interfaces/contracts/vault/IVault.sol";

contract MockBalancerVault {
  mapping(bytes32 => address) public pools;

  function joinPool(bytes32 poolId, address sender, address recipient, IVault.JoinPoolRequest memory request) external {
    address pool = pools[poolId];
    require(pool != address(0), "Pool not found");
    for (uint256 i = 0; i < request.assets.length; i++) {
      if (address(request.assets[i]) == pool) continue;
      IERC20(address(request.assets[i])).transferFrom(sender, address(this), request.maxAmountsIn[i]);
      IERC20(address(request.assets[i])).approve(pool, request.maxAmountsIn[i]);
    }

    MockBalancerPool(pool).joinPool(request.assets, request.maxAmountsIn, recipient);
  }

  function setPool(bytes32 poolId, address pool) external {
    pools[poolId] = pool;
  }
}
