// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TestSetup, PreDeposit, Pool, BondToken} from "./TestSetup.sol";
import "../../src/lib/balancer/IManagedPool.sol";

contract E2ETest is TestSetup {
  address alice = address(0x1111);
  address bob = address(0x2222);
  address chad = address(0x3333);
  address dave = address(0x4444);
  address eve = address(0x5555);

  address[] users = [alice, bob, chad, dave, eve];

  function setUp() public override {
    super.setUp();

    vm.startPrank(governance);
    preDeposit.increaseDepositCap(50 ether);

    for (uint256 i = 0; i < allowedTokens.length; i++) {
      for (uint256 j = 0; j < users.length; j++) {
        deal(allowedTokens[i], users[j], 100 ether);
        vm.startPrank(users[j]);
        IERC20(allowedTokens[i]).approve(address(preDeposit), type(uint256).max);
      }
    }

    vm.stopPrank();
  }

  function testE2EPreDepositFlow() public {
    // Initial deposits for all users
    // Alice deposits all tokens except last one
    vm.startPrank(alice);
    address[] memory selectedTokens = new address[](5); // all except last token
    selectedTokens[0] = address(weEth);
    selectedTokens[1] = address(ezEth);
    selectedTokens[2] = address(cbEth);
    selectedTokens[3] = address(weth);
    selectedTokens[4] = address(rEth);
    _selectTokensAndDeposit(selectedTokens, 2 ether);
    vm.stopPrank();

    // Bob deposits first 3 tokens
    vm.startPrank(bob);
    address[] memory bobTokens = new address[](3);
    bobTokens[0] = address(weEth);
    bobTokens[1] = address(ezEth);
    bobTokens[2] = address(cbEth);
    _selectTokensAndDeposit(bobTokens, 1.5 ether);
    vm.stopPrank();

    // Chad deposits tokens 2-4
    vm.startPrank(chad);
    address[] memory chadTokens = new address[](3);
    chadTokens[0] = address(ezEth);
    chadTokens[1] = address(cbEth);
    chadTokens[2] = address(weth);
    _selectTokensAndDeposit(chadTokens, 1 ether);
    vm.stopPrank();

    // Dave deposits tokens 3-5
    vm.startPrank(dave);
    address[] memory daveTokens = new address[](3);
    daveTokens[0] = address(cbEth);
    daveTokens[1] = address(weth);
    daveTokens[2] = address(rEth);
    _selectTokensAndDeposit(daveTokens, 0.5 ether);
    vm.stopPrank();

    // Eve deposits first 4 tokens
    vm.startPrank(eve);
    address[] memory eveTokens = new address[](4);
    eveTokens[0] = address(weEth);
    eveTokens[1] = address(ezEth);
    eveTokens[2] = address(cbEth);
    eveTokens[3] = address(weth);
    _selectTokensAndDeposit(eveTokens, 0.75 ether);
    vm.stopPrank();

    // Bob withdraws everything
    vm.startPrank(bob);
    _selectTokensAndWithdraw(bobTokens, 1.5 ether);
    vm.stopPrank();

    // Chad partially withdraws and makes small deposit of last token
    vm.startPrank(chad);
    _selectTokensAndWithdraw(chadTokens, 0.5 ether);

    // Small deposit of wstEth (last token)
    address[] memory smallToken = new address[](1);
    smallToken[0] = address(wstEth);
    uint256[] memory smallAmount = new uint256[](1);
    smallAmount[0] = 0.001 ether; // Very small amount
    preDeposit.deposit(smallToken, smallAmount);
    vm.stopPrank();

    // Dave also makes small deposit of last token
    vm.startPrank(dave);
    preDeposit.deposit(smallToken, smallAmount);
    vm.stopPrank();

    // Skip time and create pool
    vm.warp(testStartTime + PRE_DEPOSIT_PERIOD + 1 days);

    // Chad tries to claim rejected tokens
    vm.startPrank(chad);
    vm.expectRevert(PreDeposit.DepositEndedAndPoolNotCreated.selector);
    preDeposit.withdraw(smallToken, smallAmount);
    vm.stopPrank();

    vm.startPrank(governance);
    preDeposit.setBondAndLeverageAmount(INITIAL_BOND, INITIAL_LEVERAGE);
    bytes32 salt = bytes32("salt");
    preDeposit.createPool(salt);
    pool = Pool(preDeposit.pool());
    bondToken = BondToken(pool.bondToken());
    balancerPool = IManagedPool(pool.reserveToken());
    vm.stopPrank();

    // Chad and Dave claim their rejected tokens
    vm.startPrank(chad);
    preDeposit.withdraw(smallToken, smallAmount);
    vm.stopPrank();

    vm.startPrank(dave);
    preDeposit.withdraw(smallToken, smallAmount);
    vm.stopPrank();

    // Everyone claims their tokens
    vm.prank(alice);
    preDeposit.claim();

    vm.prank(bob);
    vm.expectRevert(PreDeposit.NothingToClaim.selector); // Bob withdrew everything so nothing to
      // claim
    preDeposit.claim();

    vm.prank(chad);
    preDeposit.claim();
    vm.expectRevert(PreDeposit.NothingToClaim.selector);
    preDeposit.claim();

    vm.prank(dave);
    preDeposit.claim();

    vm.prank(eve);
    preDeposit.claim();

    console.log("Alice bond token balance: %s", bondToken.balanceOf(alice));
    console.log("Bob bond token balance: %s", bondToken.balanceOf(bob));
    console.log("Chad bond token balance: %s", bondToken.balanceOf(chad));
    console.log("Dave bond token balance: %s", bondToken.balanceOf(dave));
    console.log("Eve bond token balance: %s", bondToken.balanceOf(eve));
  }

  function _selectTokensAndDeposit(address[] memory selectedTokens, uint256 amount) internal {
    uint256[] memory amounts = new uint256[](selectedTokens.length);

    for (uint256 i = 0; i < selectedTokens.length; i++) {
      amounts[i] = amount;
    }
    preDeposit.deposit(selectedTokens, amounts);
  }

  function _selectTokensAndWithdraw(address[] memory selectedTokens, uint256 amount) internal {
    uint256[] memory amounts = new uint256[](selectedTokens.length);
    for (uint256 i = 0; i < selectedTokens.length; i++) {
      amounts[i] = amount;
    }
    preDeposit.withdraw(selectedTokens, amounts);
  }
}
