// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Utils} from "../src/lib/Utils.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {PreDeposit} from "../src/PreDeposit.sol";
import {PreDepositScript} from "./PreDeposit.s.sol";

contract TestnetBalancerScript is Script {
  // Base Sepolia addresses
  address private constant ETH = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
  address private constant couponToken = address(0xf7464321dE37BdE4C03AAeeF6b1e7b71379A9a64); // Fake
    // USDC
  address private constant wstEthToken = address(0x13e5FB0B6534BB22cBC59Fae339dbBE0Dc906871); // Fake
    // wstETH
  address private constant rEthToken = address(0x93109dd4825F07DdD347F207C15ccCb16D3E1107); // Fake
    // rEth
  address private constant ezEthToken = address(0x64cC334A5eb3148664b8711235b0C752CC84E962); // Fake
    // ezETH
  address private constant cbEthToken = address(0x016803f8a916eE5ccBEf0dFd2CBEE7041F4282F4); // Fake
    // cbETH

  address private constant balancerPoolFactory = address(0xf904a7E9dfcB0b903D3eb534F2398b2A2D0608c4);
  address private constant balancerVault = address(0x37287AddE7a3D4d05af9cB8811c62E1Bade796d0);
  address private constant balancerOracleAdapter = address(0x228Ca1063262fE6Ccd188a58A699d415327D720A);
  address private constant plazaPoolFactory = address(0xB9B23c2b1dc99181402e4399a45404d368E864FC);

  PoolFactory.PoolParams private params;

  function run() public {
    vm.createSelectFork(vm.envString("BASE_SEPOLIA_RPC"));
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
    // address deployerAddress = vm.addr(vm.envUint("PRIVATE_KEY"));

    // PoolFactory factory = PoolFactory(plazaPoolFactory);
    // uint256 RESERVE_CAP = 1 ether;

    // address[] memory allowedTokens = new address[](4);
    // allowedTokens[0] = wstEthToken;
    // allowedTokens[1] = rEthToken;
    // allowedTokens[2] = ezEthToken;
    // allowedTokens[3] = cbEthToken;

    // params = PoolFactory.PoolParams({
    // 	fee: 0,
    // 	reserveToken: address(0), // Set on createPool() call after predeposit period ends
    // 	couponToken: couponToken,
    // 	distributionPeriod: 1 days,
    // 	sharesPerToken: 2_500_000,
    // 	feeBeneficiary: deployerAddress
    // });

    // PreDeposit preDeposit = PreDeposit(Utils.deploy(address(new PreDeposit()),
    // abi.encodeCall(PreDeposit.initialize, (
    // 		params,
    // 		plazaPoolFactory,
    // 		balancerPoolFactory,
    // 		balancerVault,
    // 		balancerOracleAdapter,
    // 		block.timestamp,
    // 		block.timestamp + 45 seconds,
    // 		RESERVE_CAP,
    // 		allowedTokens,
    // 		"Bond ETH",
    // 		"bondETH",
    // 		"Levered ETH",
    // 		"levETH"
    // ))));

    // factory.grantRole(factory.POOL_ROLE(), address(preDeposit));

    // uint256[] memory amounts = new uint256[](4);
    // amounts[0] = 0.1 ether; // mint some directly from cbEth contract
    // amounts[1] = 0.3 ether; // Get some wstETH from faucet on plaza.finance
    // amounts[2] = 0.2 ether; // mint some directly from ezEth contract
    // amounts[3] = 0.15 ether; // mint some directly from rEth contract

    // for (uint256 i = 0; i < amounts.length; i++) {
    // 	IERC20(allowedTokens[i]).approve(address(preDeposit), amounts[i]);
    // }

    // preDeposit.deposit(allowedTokens, amounts);

    // console.log("PreDeposit deployed at:", address(preDeposit));

    // vm.stopBroadcast();

    // Wait 45 seconds, then do:
    PreDeposit preDeposit = PreDeposit(0x20a0730024AeC8AD06Af77eb9f05Ed4f31580357);
    preDeposit.setBondAndLeverageAmount(10 ether, 10 ether);
    preDeposit.createPool(keccak256("Bond ETH"));
    preDeposit.claim();
    vm.stopBroadcast();
  }
}
