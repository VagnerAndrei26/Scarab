// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {RoycoHelper} from "../src/RoycoHelper.sol";

contract RoycoHelperScript is Script {
  function run() public {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

    new RoycoHelper();

    vm.stopBroadcast();
  }
}
