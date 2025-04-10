// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {TestSetup, PreDeposit, PoolFactory, Pool, BondToken, LeverageToken} from "./TestSetup.sol";
import {Token} from "../mocks/Token.sol";
import {IManagedPool} from "../../src/lib/balancer/IManagedPool.sol";

contract PreDepositTest is TestSetup {
  uint256 public constant DEPOSIT_AMOUNT = 1 ether;

  address[] tokens;
  uint256[] amounts;

  function setUp() public override {
    super.setUp();
  }

  function testDeposit() public {
    vm.startPrank(user1);

    _approveSpend();
    address[] memory selectedTokens = new address[](2);
    selectedTokens[0] = address(cbEth);
    selectedTokens[1] = address(rEth);
    _selectTokens(selectedTokens);
    preDeposit.deposit(tokens, amounts);

    assertEq(preDeposit.balances(user1, address(cbEth)), DEPOSIT_AMOUNT);
    assertEq(preDeposit.balances(user1, address(rEth)), DEPOSIT_AMOUNT);
    assertEq(cbEth.balanceOf(address(preDeposit)), DEPOSIT_AMOUNT);
    assertEq(rEth.balanceOf(address(preDeposit)), DEPOSIT_AMOUNT);

    uint256 currentTvl =
      (_tokenPrice(address(cbEth)) * DEPOSIT_AMOUNT + _tokenPrice(address(rEth)) * DEPOSIT_AMOUNT) / 1e18;

    assertEq(preDeposit.currentPredepositTotal(), currentTvl);
    vm.stopPrank();
  }

  function testDepositOnBehalfOf() public {
    vm.startPrank(user1);
    _approveSpend();
    address[] memory selectedTokens = new address[](2);
    selectedTokens[0] = address(cbEth);
    selectedTokens[1] = address(rEth);
    _selectTokens(selectedTokens);
    preDeposit.deposit(tokens, amounts, user2);

    assertEq(preDeposit.balances(user1, address(cbEth)), 0);
    assertEq(preDeposit.balances(user1, address(rEth)), 0);
    assertEq(preDeposit.balances(user2, address(cbEth)), DEPOSIT_AMOUNT);
    assertEq(preDeposit.balances(user2, address(rEth)), DEPOSIT_AMOUNT);
    assertEq(cbEth.balanceOf(address(preDeposit)), DEPOSIT_AMOUNT);
    assertEq(rEth.balanceOf(address(preDeposit)), DEPOSIT_AMOUNT);
    vm.stopPrank();
  }

  function testDepositBeforeStart() public {
    vm.warp(testStartTime - 1 days);
    vm.startPrank(user1);

    vm.expectRevert(PreDeposit.DepositNotYetStarted.selector);
    preDeposit.deposit(tokens, amounts);

    vm.stopPrank();
  }

  function testDepositAfterEnd() public {
    vm.warp(testStartTime + PRE_DEPOSIT_PERIOD + 1 days); // After deposit period
    vm.startPrank(user1);

    vm.expectRevert(PreDeposit.DepositEnded.selector);
    preDeposit.deposit(tokens, amounts);

    vm.stopPrank();
  }

  function testDepositExceedingCap() public {
    vm.startPrank(user1);
    _approveSpend();
    address[] memory selectedTokens = new address[](2);
    selectedTokens[0] = address(cbEth);
    selectedTokens[1] = address(rEth);
    _selectTokens(selectedTokens);
    preDeposit.deposit(tokens, amounts);
    preDeposit.deposit(tokens, amounts);
    preDeposit.deposit(tokens, amounts);
    preDeposit.deposit(tokens, amounts);

    // Each deposit is worth ~2.2ETH. Third deposit will exceed cap of 10ETH
    vm.expectRevert(PreDeposit.DepositCapReached.selector);
    preDeposit.deposit(tokens, amounts);

    vm.stopPrank();
  }

  function testZeroAmountDeposit() public {
    vm.startPrank(user1);
    _approveSpend();
    address[] memory selectedTokens = new address[](2);
    selectedTokens[0] = address(cbEth);
    selectedTokens[1] = address(rEth);
    _selectTokens(selectedTokens);
    amounts[0] = 0;
    vm.expectRevert(PreDeposit.NoTokenValue.selector);
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();
  }

  function testDepositWithInvalidToken() public {
    vm.startPrank(user1);
    Token token = new Token("Invalid Token", "INVALID", true);
    token.mint(user1, 1 ether);
    token.approve(address(preDeposit), 1 ether);

    _approveSpend();
    tokens.push(address(token));
    tokens.push(address(rEth));
    amounts.push(1 ether);
    amounts.push(1 ether);

    vm.expectRevert(PreDeposit.InvalidReserveToken.selector);
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();
  }

  function testWithdraw() public {
    vm.startPrank(user1);
    _approveSpend();
    address[] memory selectedTokens = new address[](2);
    selectedTokens[0] = address(cbEth);
    selectedTokens[1] = address(rEth);
    _selectTokens(selectedTokens);
    preDeposit.deposit(tokens, amounts);

    uint256 balanceBeforeToken1 = cbEth.balanceOf(user1);
    uint256 balanceBeforeToken2 = rEth.balanceOf(user1);

    preDeposit.withdraw(tokens, amounts);
    uint256 balanceAfterToken1 = cbEth.balanceOf(user1);
    uint256 balanceAfterToken2 = rEth.balanceOf(user1);

    assertEq(balanceAfterToken1, balanceBeforeToken1 + DEPOSIT_AMOUNT);
    assertEq(balanceAfterToken2, balanceBeforeToken2 + DEPOSIT_AMOUNT);
    assertEq(preDeposit.balances(user1, address(cbEth)), 0);
    assertEq(preDeposit.balances(user1, address(rEth)), 0);
    assertEq(preDeposit.currentPredepositTotal(), 0);

    vm.stopPrank();
  }

  function testWithdrawMoreThanDeposited() public {
    vm.startPrank(user1);
    _approveSpend();
    address[] memory selectedTokens = new address[](2);
    selectedTokens[0] = address(cbEth);
    selectedTokens[1] = address(rEth);
    _selectTokens(selectedTokens);
    preDeposit.deposit(tokens, amounts);

    amounts[0] = DEPOSIT_AMOUNT + 1;
    vm.expectRevert(PreDeposit.InsufficientBalance.selector);
    preDeposit.withdraw(tokens, amounts);
    vm.stopPrank();
  }

  function testWithdrawAfterDepositEndButBeforePoolCreation() public {
    vm.startPrank(user1);
    _approveSpend();
    address[] memory selectedTokens = new address[](2);
    selectedTokens[0] = address(cbEth);
    selectedTokens[1] = address(rEth);
    _selectTokens(selectedTokens);
    preDeposit.deposit(tokens, amounts);
    vm.warp(testStartTime + PRE_DEPOSIT_PERIOD + 1 days); // After deposit period

    vm.expectRevert(PreDeposit.DepositEndedAndPoolNotCreated.selector);
    preDeposit.withdraw(tokens, amounts);
    vm.stopPrank();
  }

  function testCreatePoolWithAllTokens() public {
    vm.startPrank(user1);

    address[] memory selectedTokens = new address[](6);
    // These are sorted in ascending order
    selectedTokens[0] = address(weEth);
    selectedTokens[1] = address(ezEth);
    selectedTokens[2] = address(cbEth);
    selectedTokens[3] = address(weth);
    selectedTokens[4] = address(rEth);
    selectedTokens[5] = address(wstEth);
    _selectTokens(selectedTokens);

    _approveSpend();
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    vm.startPrank(governance);
    vm.warp(testStartTime + PRE_DEPOSIT_PERIOD + 1 days); // After deposit period
    preDeposit.setBondAndLeverageAmount(INITIAL_BOND, INITIAL_LEVERAGE);

    bytes32 salt = bytes32("salt");
    vm.recordLogs();
    preDeposit.createPool(salt);

    Vm.Log[] memory entries = vm.getRecordedLogs();
    Vm.Log memory log = entries[entries.length - 2];
    address balancerPool = address(uint160(uint256(log.topics[1])));
    console.log("balancerPool", address(balancerPool));
    uint256[] memory actualWeights = IManagedPool(balancerPool).getNormalizedWeights();

    uint256 snapshotCapValue = preDeposit.snapshotCapValue();

    uint256[] memory expectedWeights = new uint256[](6);
    expectedWeights[0] = DEPOSIT_AMOUNT * _tokenPrice(address(weEth)) / snapshotCapValue;
    expectedWeights[1] = DEPOSIT_AMOUNT * _tokenPrice(address(ezEth)) / snapshotCapValue;
    expectedWeights[2] = DEPOSIT_AMOUNT * _tokenPrice(address(cbEth)) / snapshotCapValue;
    expectedWeights[3] = DEPOSIT_AMOUNT * _tokenPrice(address(weth)) / snapshotCapValue;
    expectedWeights[4] = DEPOSIT_AMOUNT * _tokenPrice(address(rEth)) / snapshotCapValue;
    expectedWeights[5] = DEPOSIT_AMOUNT * _tokenPrice(address(wstEth)) / snapshotCapValue;

    expectedWeights = _validateNormalizedWeights(expectedWeights);

    assertEq(actualWeights[0], expectedWeights[0]);
    assertEq(actualWeights[1], expectedWeights[1]);
    assertEq(actualWeights[2], expectedWeights[2]);
    assertEq(actualWeights[3], expectedWeights[3]);
    assertEq(actualWeights[4], expectedWeights[4]);
    assertEq(actualWeights[5], expectedWeights[5]);
    vm.stopPrank();
  }

  function testCreatePoolAndExcludeSomeTokens() public {
    vm.startPrank(user1);
    _approveSpend();

    // Choose just 3 tokens
    address[] memory selectedTokens = new address[](3);
    selectedTokens[0] = address(weEth);
    selectedTokens[1] = address(cbEth);
    selectedTokens[2] = address(rEth);
    _selectTokens(selectedTokens);
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    vm.startPrank(governance);
    vm.warp(testStartTime + PRE_DEPOSIT_PERIOD + 1 days); // After deposit period
    preDeposit.setBondAndLeverageAmount(INITIAL_BOND, INITIAL_LEVERAGE);

    bytes32 salt = bytes32("salt");
    vm.recordLogs();
    preDeposit.createPool(salt);
    Vm.Log[] memory entries = vm.getRecordedLogs();
    Vm.Log memory log = entries[entries.length - 2];
    address balancerPool = address(uint160(uint256(log.topics[1])));
    uint256[] memory actualWeights = IManagedPool(balancerPool).getNormalizedWeights();

    uint256 snapshotCapValue = preDeposit.snapshotCapValue();

    uint256[] memory expectedWeights = new uint256[](3);
    expectedWeights[0] = DEPOSIT_AMOUNT * _tokenPrice(address(weEth)) / snapshotCapValue;
    expectedWeights[1] = DEPOSIT_AMOUNT * _tokenPrice(address(cbEth)) / snapshotCapValue;
    expectedWeights[2] = DEPOSIT_AMOUNT * _tokenPrice(address(rEth)) / snapshotCapValue;

    expectedWeights = _validateNormalizedWeights(expectedWeights);

    assertEq(actualWeights[0], expectedWeights[0]);
    assertEq(actualWeights[1], expectedWeights[1]);
    assertEq(actualWeights[2], expectedWeights[2]);

    vm.stopPrank();
  }

  function testWithdrawExcludedToken() public {
    vm.startPrank(user1);
    _approveSpend();

    // Choose just 3 tokens
    address[] memory selectedTokens = new address[](3);
    selectedTokens[0] = address(weEth);
    selectedTokens[1] = address(cbEth);
    selectedTokens[2] = address(rEth);
    _selectTokens(selectedTokens);

    uint256 smallAmount = 0.0001 ether;
    amounts[2] = smallAmount; // Deposit such that weight will be less than 1%
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    vm.startPrank(governance);
    vm.warp(testStartTime + PRE_DEPOSIT_PERIOD + 1 days); // After deposit period
    preDeposit.setBondAndLeverageAmount(INITIAL_BOND, INITIAL_LEVERAGE);
    vm.stopPrank();

    vm.startPrank(user1);
    bytes32 salt = bytes32("salt");
    preDeposit.createPool(salt);

    assertEq(weEth.balanceOf(address(preDeposit)), 0);
    assertEq(cbEth.balanceOf(address(preDeposit)), 0);
    assertEq(rEth.balanceOf(address(preDeposit)), smallAmount);

    address[] memory withdrawTokens = new address[](1);
    withdrawTokens[0] = address(rEth);
    uint256[] memory withdrawAmounts = new uint256[](1);
    withdrawAmounts[0] = smallAmount;

    uint256 balanceBefore = rEth.balanceOf(user1);
    preDeposit.withdraw(withdrawTokens, withdrawAmounts);
    uint256 balanceAfter = rEth.balanceOf(user1);

    assertEq(balanceAfter, balanceBefore + smallAmount);
    vm.stopPrank();
  }

  function testCreatePoolNoReserveAmount() public {
    vm.startPrank(governance);
    vm.warp(testStartTime + PRE_DEPOSIT_PERIOD + 1 days); // After deposit period
    preDeposit.setBondAndLeverageAmount(INITIAL_BOND, INITIAL_LEVERAGE);

    vm.expectRevert(PreDeposit.NoReserveAmount.selector);
    bytes32 salt = bytes32("salt");
    preDeposit.createPool(salt);
    vm.stopPrank();
  }

  function testCreatePoolInvalidBondOrLeverageAmount() public {
    vm.startPrank(user1);
    _approveSpend();
    address[] memory selectedTokens = new address[](2);
    selectedTokens[0] = address(cbEth);
    selectedTokens[1] = address(rEth);
    _selectTokens(selectedTokens);
    preDeposit.deposit(tokens, amounts);

    vm.warp(testStartTime + PRE_DEPOSIT_PERIOD + 1 days); // After deposit period

    vm.expectRevert(PreDeposit.InvalidBondOrLeverageAmount.selector);
    bytes32 salt = bytes32("salt");
    preDeposit.createPool(salt);
    vm.stopPrank();
  }

  function testCreatePoolBeforeDepositEnd() public {
    vm.startPrank(user1);
    _approveSpend();
    address[] memory selectedTokens = new address[](2);
    selectedTokens[0] = address(cbEth);
    selectedTokens[1] = address(rEth);
    _selectTokens(selectedTokens);
    preDeposit.deposit(tokens, amounts);

    vm.expectRevert(PreDeposit.DepositNotEnded.selector);
    bytes32 salt = bytes32("salt");
    preDeposit.createPool(salt);
  }

  function testCreatePoolAfterCreation() public {
    vm.startPrank(user1);
    _depositAndCreatePool();

    // Try to create pool again
    vm.expectRevert(PreDeposit.PoolAlreadyCreated.selector);
    bytes32 salt = bytes32("salt");
    preDeposit.createPool(salt);
  }

  function testClaim() public {
    vm.startPrank(user1);
    _depositAndCreatePool();

    // Claim tokens
    address bondToken = address(Pool(preDeposit.pool()).bondToken());
    address lToken = address(Pool(preDeposit.pool()).lToken());
    uint256 totalBondBalance = BondToken(bondToken).balanceOf(address(preDeposit));
    uint256 totalLeverageBalance = LeverageToken(lToken).balanceOf(address(preDeposit));

    preDeposit.claim();

    // Single user, so all bond/lev tokens are claimed by user1
    assertEq(BondToken(bondToken).balanceOf(user1), totalBondBalance);
    assertEq(LeverageToken(lToken).balanceOf(user1), totalLeverageBalance);
    vm.stopPrank();
  }

  function testClaimBeforeDepositEnd() public {
    vm.startPrank(user1);
    _approveSpend();
    address[] memory selectedTokens = new address[](2);
    selectedTokens[0] = address(cbEth);
    selectedTokens[1] = address(rEth);
    _selectTokens(selectedTokens);
    preDeposit.deposit(tokens, amounts);

    vm.expectRevert(PreDeposit.DepositNotEnded.selector);
    preDeposit.claim();
    vm.stopPrank();
  }

  function testClaimBeforePoolCreation() public {
    vm.startPrank(user1);
    _approveSpend();
    address[] memory selectedTokens = new address[](2);
    selectedTokens[0] = address(cbEth);
    selectedTokens[1] = address(rEth);
    _selectTokens(selectedTokens);
    preDeposit.deposit(tokens, amounts);

    vm.warp(testStartTime + PRE_DEPOSIT_PERIOD + 1 days); // After deposit period

    vm.expectRevert(PreDeposit.ClaimPeriodNotStarted.selector);
    preDeposit.claim();
    vm.stopPrank();
  }

  function testClaimWithZeroBalance() public {
    // Create pool first
    vm.startPrank(user1);
    _depositAndCreatePool();
    vm.stopPrank();

    // Try to claim with user2 who has no deposits
    vm.startPrank(user2);
    vm.expectRevert(PreDeposit.NothingToClaim.selector);
    preDeposit.claim();
    vm.stopPrank();
  }

  function testClaimTwice() public {
    // Setup initial deposit
    vm.startPrank(user1);
    _depositAndCreatePool();
    preDeposit.claim();

    // Second claim should fail
    vm.expectRevert(PreDeposit.NothingToClaim.selector);
    preDeposit.claim();
    vm.stopPrank();
  }

  function testSetParams() public {
    vm.startPrank(governance);
    PoolFactory.PoolParams memory newParams = PoolFactory.PoolParams({
      fee: 0,
      reserveToken: address(0), // Doesn't matter which address, as reserveToken is set in
        // createPool()
      couponToken: address(couponToken),
      distributionPeriod: 180 days,
      sharesPerToken: 3 * 10 ** 6,
      feeBeneficiary: address(0)
    });
    preDeposit.setParams(newParams);
    vm.stopPrank();
  }

  function testSetParamsNonOwner() public {
    vm.startPrank(user2);
    PoolFactory.PoolParams memory newParams = PoolFactory.PoolParams({
      fee: 0,
      reserveToken: address(0),
      couponToken: address(couponToken),
      distributionPeriod: 180 days,
      sharesPerToken: 3 * 10 ** 6,
      feeBeneficiary: address(0)
    });

    vm.expectRevert(abi.encodeWithSelector(PreDeposit.AccessDenied.selector));
    preDeposit.setParams(newParams);
    vm.stopPrank();
  }

  function testIncreaseDepositCap() public {
    vm.prank(governance);
    preDeposit.increaseDepositCap(PRE_DEPOSIT_CAP * 2);
    assertEq(preDeposit.depositCap(), PRE_DEPOSIT_CAP * 2);
  }

  function testIncreaseDepositCapDecrease() public {
    vm.prank(governance);
    vm.expectRevert(PreDeposit.CapMustIncrease.selector);
    preDeposit.increaseDepositCap(PRE_DEPOSIT_CAP / 2);
  }

  // Time-related Tests
  function testSetDepositStartTime() public {
    // Move time to before deposit start time
    vm.warp(testStartTime - 1 days);

    uint256 newStartTime = testStartTime + 10 hours;
    vm.prank(governance);
    preDeposit.setDepositStartTime(newStartTime);
    assertEq(preDeposit.depositStartTime(), newStartTime);
  }

  function testSetDepositEndTime() public {
    uint256 newEndTime = testStartTime + PRE_DEPOSIT_PERIOD + 14 days;
    vm.prank(governance);
    preDeposit.setDepositEndTime(newEndTime);
    assertEq(preDeposit.depositEndTime(), newEndTime);
  }

  // Pause/Unpause Tests
  function testPauseUnpause() public {
    vm.startPrank(securityCouncil);
    preDeposit.pause();

    vm.startPrank(user1);
    _approveSpend();
    address[] memory selectedTokens = new address[](4);
    selectedTokens[0] = address(weEth);
    selectedTokens[1] = address(ezEth);
    _selectTokens(selectedTokens);
    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    vm.prank(securityCouncil);
    preDeposit.unpause();

    vm.prank(user1);
    preDeposit.deposit(tokens, amounts);
    assertEq(preDeposit.balances(user1, address(weEth)), DEPOSIT_AMOUNT);
    assertEq(preDeposit.balances(user1, address(ezEth)), DEPOSIT_AMOUNT);
  }

  function testClaimTwoUsersSameBondShare() public {
    address[] memory selectedTokens = new address[](2);
    selectedTokens[0] = address(weEth);
    selectedTokens[1] = address(ezEth);
    _selectTokens(selectedTokens);

    // User 1
    vm.startPrank(user1);
    _approveSpend();
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    // User 2
    vm.startPrank(user2);
    _approveSpend();
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    // Create pool
    vm.startPrank(governance);
    vm.warp(testStartTime + PRE_DEPOSIT_PERIOD + 1 days); // After deposit period
    preDeposit.setBondAndLeverageAmount(INITIAL_BOND, INITIAL_LEVERAGE);

    preDeposit.createPool(bytes32("salt"));
    vm.stopPrank();

    // Claim tokens
    address bondToken = address(Pool(preDeposit.pool()).bondToken());

    vm.prank(user1);
    preDeposit.claim();

    vm.prank(user2);
    preDeposit.claim();

    uint256 user1_bond_share = BondToken(bondToken).balanceOf(user1);
    uint256 user2_bond_share = BondToken(bondToken).balanceOf(user2);
    assertEq(user1_bond_share, user2_bond_share);
    assertEq(user1_bond_share, INITIAL_BOND / 2);
  }

  function testTimingAttack() public {
    // Setup initial deposit
    address[] memory selectedTokens = new address[](2);
    selectedTokens[0] = address(weEth);
    selectedTokens[1] = address(ezEth);
    _selectTokens(selectedTokens);

    vm.startPrank(user1);
    _approveSpend();
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    vm.startPrank(user2);
    _approveSpend();
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    // Create pool
    vm.startPrank(governance);
    vm.warp(testStartTime + PRE_DEPOSIT_PERIOD + 1 days); // depositEndTime
    preDeposit.setBondAndLeverageAmount(INITIAL_BOND, INITIAL_LEVERAGE);
    // Start timing attack
    vm.startPrank(user1);

    // user1 trigger createPool, it's allowed because it's not onlyOwner
    preDeposit.createPool(bytes32("salt"));

    // user1 trigger claim
    preDeposit.claim();

    _approveSpend();

    // deposit not possible at the same block as createPool
    vm.expectRevert(PreDeposit.DepositEnded.selector);
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();
  }

  function testExtendStartTimeAfterStartReverts() public {
    // user can deposit
    vm.startPrank(user1);
    _approveSpend();
    address[] memory selectedTokens = new address[](2);
    selectedTokens[0] = address(weEth);
    selectedTokens[1] = address(ezEth);
    _selectTokens(selectedTokens);
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    // Extend start time
    vm.prank(governance);
    vm.expectRevert(PreDeposit.DepositAlreadyStarted.selector);
    preDeposit.setDepositStartTime(block.timestamp + 1 days);
  }

  function testPoolPausedOnCreation() public {
    vm.startPrank(user1);
    Pool pool = _depositAndCreatePool();
    assertEq(pool.paused(), true);
    vm.stopPrank();
  }

  function testDepositValueCalculation() public {
    vm.startPrank(user1);
    _approveSpend();
    address[] memory selectedTokens = new address[](4);
    selectedTokens[0] = address(weEth);
    selectedTokens[1] = address(ezEth);
    selectedTokens[2] = address(cbEth);
    selectedTokens[3] = address(weth);
    _selectTokens(selectedTokens);
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    uint256 totalValue = preDeposit.currentPredepositTotal();
    uint256 expectedValue = (DEPOSIT_AMOUNT * _tokenPrice(address(weEth)))
      + (DEPOSIT_AMOUNT * _tokenPrice(address(ezEth))) + (DEPOSIT_AMOUNT * _tokenPrice(address(cbEth)))
      + (DEPOSIT_AMOUNT * _tokenPrice(address(weth)));

    assertEq(totalValue, expectedValue / 1e18);
  }

  function testAllowedTokensList() public view {
    address[] memory allowedTokens = preDeposit.getAllowedTokens();
    assertEq(allowedTokens.length, 6);
    assertEq(allowedTokens[0], address(weEth));
    assertEq(allowedTokens[1], address(ezEth));
    assertEq(allowedTokens[2], address(cbEth));
    assertEq(allowedTokens[3], address(weth));
    assertEq(allowedTokens[4], address(rEth));
    assertEq(allowedTokens[5], address(wstEth));
  }

  function _tokenPrice(address token) private view returns (uint256) {
    return balancerOracleAdapter.getOraclePrice(token, ETH);
  }

  function _approveSpend() private {
    wstEth.approve(address(preDeposit), type(uint256).max);
    cbEth.approve(address(preDeposit), type(uint256).max);
    rEth.approve(address(preDeposit), type(uint256).max);
    weEth.approve(address(preDeposit), type(uint256).max);
    ezEth.approve(address(preDeposit), type(uint256).max);
    weth.approve(address(preDeposit), type(uint256).max);
  }

  function _selectTokens(address[] memory selectedTokens) private {
    for (uint256 i = 0; i < selectedTokens.length; i++) {
      if (selectedTokens[i] != address(0)) {
        tokens.push(selectedTokens[i]);
        amounts.push(DEPOSIT_AMOUNT);
      }
    }
  }

  function _depositAndCreatePool() private returns (Pool) {
    _approveSpend();
    address[] memory selectedTokens = new address[](4);
    selectedTokens[0] = address(weEth);
    selectedTokens[1] = address(ezEth);
    selectedTokens[2] = address(cbEth);
    selectedTokens[3] = address(weth);
    _selectTokens(selectedTokens);
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    vm.startPrank(governance);
    vm.warp(testStartTime + PRE_DEPOSIT_PERIOD + 1 days); // After deposit period
    preDeposit.setBondAndLeverageAmount(INITIAL_BOND, INITIAL_LEVERAGE);

    bytes32 salt = bytes32("salt");
    vm.recordLogs();
    preDeposit.createPool(salt);
    Vm.Log[] memory entries = vm.getRecordedLogs();
    Vm.Log memory log = entries[entries.length - 1]; // second to last log is the pool created
      // address
    Pool pool = Pool(address(uint160(uint256(log.topics[1]))));
    vm.stopPrank();
    vm.startPrank(user1);

    return pool;
  }

  function _validateNormalizedWeights(uint256[] memory normalizedWeights) private view returns (uint256[] memory) {
    uint256 MIN_WEIGHT = 1e16; // 1%

    // First pass: count valid tokens and sum their weights
    uint256 validTokenCount = 0;
    uint256 totalValidWeight = 0;
    bool[] memory isValid = new bool[](normalizedWeights.length);

    for (uint256 i = 0; i < normalizedWeights.length; i++) {
      if (normalizedWeights[i] >= MIN_WEIGHT) {
        isValid[i] = true;
        validTokenCount++;
        totalValidWeight += normalizedWeights[i];
      }
    }

    // Create new arrays for valid tokens and weights
    uint256[] memory validatedWeights = new uint256[](validTokenCount);
    address[] memory validTokens = new address[](validTokenCount);
    uint256 validIndex = 0;

    // Second pass: normalize weights and update token array
    for (uint256 i = 0; i < normalizedWeights.length; i++) {
      if (isValid[i]) {
        // Normalize weight relative to total valid weight
        validatedWeights[validIndex] = (normalizedWeights[i] * 1e18) / totalValidWeight;
        validTokens[validIndex] = allowedTokens[i];
        validIndex++;
      }
    }

    // Ensure total weight is exactly 1e18
    uint256 totalWeight = 0;
    for (uint256 i = 0; i < validatedWeights.length; i++) {
      totalWeight += validatedWeights[i];
    }

    // Add or remove weight from largest weight if needed
    if (totalWeight > 1e18) validatedWeights[_getLargestIndex(validatedWeights)] -= totalWeight - 1e18; // Remove excess
      // weight

    else if (totalWeight < 1e18) validatedWeights[_getLargestIndex(validatedWeights)] += 1e18 - totalWeight; // Add
      // missing
      // weight

    return validatedWeights;
  }

  function _getLargestIndex(uint256[] memory values) private pure returns (uint256) {
    uint256 largestIndex = 0;
    for (uint256 i = 1; i < values.length; i++) {
      if (values[i] > values[largestIndex]) largestIndex = i;
    }
    return largestIndex;
  }
}
