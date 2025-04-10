// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {TestSetup, LeverageToken} from "./TestSetup.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract LeverageTokenTest is Test, TestSetup {
  LeverageToken private token;
  address minter;

  function setUp() public override {
    super.setUp();
    createPool();
    token = leverageToken;
    minter = address(pool);
    vm.startPrank(minter);
    token.mint(minter, 1000);
    vm.stopPrank();
  }

  function testPause() public {
    // makes sure it starts false
    assertEq(token.paused(), false);

    // makes sure minting works if not paused
    vm.startPrank(minter);
    token.mint(user1, 1000);

    // pause contract
    vm.startPrank(securityCouncil);
    token.pause();

    // check it reverts on minting
    vm.startPrank(minter);
    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    token.mint(user1, 1);

    // check it reverts on burning
    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    token.burn(user1, 1);

    // check it reverts on transfer
    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    token.transfer(user1, 1);

    // @todo: check if contract is still upgradable on pause
    // token._authorizeUpgrade(address(0));

    // unpause contract
    vm.startPrank(securityCouncil);
    token.unpause();

    // make sure you can now do stuff
    vm.startPrank(user1);
    token.transfer(user2, 1000);
  }

  /**
   * @dev Tests minting of tokens by an address with MINTER_ROLE.
   * Asserts that the user's balance is updated correctly.
   */
  function testMinting() public {
    uint256 initialBalance = token.balanceOf(minter);
    uint256 mintAmount = 500;

    vm.startPrank(minter);
    token.mint(user2, mintAmount);
    vm.stopPrank();

    assertEq(token.balanceOf(user2), mintAmount);
    assertEq(token.balanceOf(minter), initialBalance);
  }

  /**
   * @dev Tests minting of tokens by an address without MINTER_ROLE.
   * Expects the transaction to revert.
   */
  function testMintingWithNoPermission() public {
    uint256 initialBalance = token.balanceOf(user1);

    vm.expectRevert();
    vm.startPrank(user1);
    token.mint(user2, 100);
    vm.stopPrank();

    assertEq(token.balanceOf(user1), initialBalance);
  }

  /**
   * @dev Tests burning of tokens by an address with MINTER_ROLE.
   * Asserts that the minter's balance is decreased correctly.
   */
  function testBurning() public {
    uint256 initialBalance = token.balanceOf(minter);
    uint256 burnAmount = 100;

    vm.startPrank(minter);
    token.burn(minter, burnAmount);
    vm.stopPrank();

    assertEq(token.balanceOf(minter), initialBalance - burnAmount);
  }

  /**
   * @dev Tests burning of tokens by an address without MINTER_ROLE.
   * Expects the transaction to revert.
   */
  function testBurningWithNoPermission() public {
    uint256 initialBalance = token.balanceOf(user1);

    vm.expectRevert();
    vm.startPrank(user1);
    token.burn(user2, 50);
    vm.stopPrank();

    assertEq(token.balanceOf(user1), initialBalance);
  }
}
