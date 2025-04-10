// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {BalancerRouter} from "../src/BalancerRouter.sol";

contract BalancerRouterScript is Script {
  function run() public {
    address balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

    new BalancerRouter(balancerVault);

    vm.stopBroadcast();
  }
}
