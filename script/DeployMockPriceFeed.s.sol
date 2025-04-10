// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ezEthMockPriceFeed is Ownable {
  uint256 public price;

  constructor() Ownable(msg.sender) {}

  function setPrice(uint256 _price) external onlyOwner {
    price = _price;
  }

  function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
    return (0, int256(price), 0, block.timestamp, 0);
  }

  function decimals() external pure returns (uint256) {
    return 18;
  }
}

contract DeployMockPriceFeed is Script {
  function run() public {
    vm.createSelectFork(vm.envString("BASE_SEPOLIA_RPC"));
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
    ezEthMockPriceFeed feed = new ezEthMockPriceFeed();
    feed.setPrice(1.03 ether);
    vm.stopBroadcast();
  }
}
