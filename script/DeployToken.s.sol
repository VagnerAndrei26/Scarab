// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Token} from "../test/mocks/Token.sol";

contract DeployToken is Script {
  function run() public {
    vm.createSelectFork(vm.envString("BASE_SEPOLIA_RPC"));
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
    new Token("fake renzo ETH", "ezETH", false);
    new Token("fake cbETH", "cbETH", false);
    vm.stopBroadcast();
  }
}
