// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IAsset} from "@balancer/contracts/interfaces/contracts/vault/IAsset.sol";

contract MockBalancerPool is ERC20 {
  address balancerVault;
  bytes32 private poolId = keccak256(abi.encode("MockBalancerPool"));

  constructor(address _balancerVault) ERC20("MockBalancerPool", "MBP") {
    balancerVault = _balancerVault;
  }

  /**
   * @dev Simple mock which mints LP tokens equal to the sum of the assets joined
   * @param assets The assets to join the pool
   * @param amountsIn The amounts of assets to join the pool
   * @param recipient The recipient of the pool tokens
   */
  function joinPool(IAsset[] memory assets, uint256[] memory amountsIn, address recipient) external {
    require(msg.sender == balancerVault, "OnlyVault");
    uint256 totalLpToMint;
    for (uint256 i = 0; i < assets.length; i++) {
      if (address(assets[i]) == address(this)) continue;
      IERC20(address(assets[i])).transferFrom(msg.sender, address(this), amountsIn[i]);
      totalLpToMint += amountsIn[i];
    }
    _mint(recipient, totalLpToMint);
  }

  function getPoolId() external view returns (bytes32) {
    return poolId;
  }
}
