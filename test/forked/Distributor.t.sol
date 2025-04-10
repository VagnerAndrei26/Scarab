// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {TestSetup, Pool, PoolFactory, Auction, Distributor, Token} from "./TestSetup.sol";

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract DistributorTest is Test, TestSetup {
  struct PeriodActions {
    bool claimDuringBidding;
    uint256 receiveDuringBidding;
    uint256 sendDuringBidding;
    bool claimAfterBidding;
    uint256 receiveAfterBidding;
    uint256 sendAfterBidding;
    uint256 duringBiddingOrder;
    uint256 afterBiddingOrder;
  }

  function setUp() public override {
    super.setUp();
    createPool();
  }

  function testPause() public {
    Auction auction = Auction(doAuction());

    vm.startPrank(securityCouncil);
    distributor.pause();

    vm.startPrank(address(pool));
    vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
    pool.distribute();

    vm.startPrank(securityCouncil);
    distributor.unpause();

    vm.startPrank(address(pool));
    pool.distribute();
    uint256 storedAmountToDistribute = distributor.couponAmountToDistribute();
    assertEq(storedAmountToDistribute, auction.totalBuyCouponAmount());
  }

  // user1 owns entire bond supply from preDeposit setup
  function testClaimShares() public {
    doAuction();
    pool.distribute();

    vm.startPrank(user1);

    uint256 couponsOwed = bondToken.totalSupply() * SHARES_PER_TOKEN / 1e18;

    vm.expectEmit(true, true, true, true);
    emit Distributor.ClaimedShares(user1, 1, couponsOwed);

    distributor.claim();
    assertEq(couponToken.balanceOf(user1), couponsOwed);
    vm.stopPrank();
  }

  function testClaimSharesNothingToClaim() public {
    doAuction();
    pool.distribute();

    vm.startPrank(user2);

    vm.expectRevert(Distributor.NothingToClaim.selector);
    distributor.claim();
    vm.stopPrank();
  }

  function testClaimSharesCheckPoolInfo() public {
    doAuction();
    pool.distribute();

    vm.startPrank(user1);
    uint256 couponsOwed = bondToken.totalSupply() * SHARES_PER_TOKEN / 1e18;

    vm.expectEmit(true, true, true, true);
    emit Distributor.ClaimedShares(user1, 1, couponsOwed);

    deal(address(couponToken), address(distributor), 100 ether); // Send some arbitrary extra amount
      // to Distributor

    uint256 couponAmountToDistributePreClaim = distributor.couponAmountToDistribute();
    distributor.claim();
    uint256 couponAmountToDistribute = distributor.couponAmountToDistribute();

    // Ensure user still only gets fare share
    assertEq(couponAmountToDistribute + couponsOwed, couponAmountToDistributePreClaim);
    assertEq(couponToken.balanceOf(user1), couponsOwed);
    vm.stopPrank();
  }

  function testAllBondHoldersCanClaim() public {
    uint256 user1BondBalance = bondToken.balanceOf(user1);
    uint256 totalCouponsOwed = bondToken.totalSupply() * SHARES_PER_TOKEN / 1e18;

    vm.startPrank(user1);
    bondToken.transfer(user2, user1BondBalance / 4); // 25% to user2
    bondToken.transfer(user3, user1BondBalance / 2); // 50% to user3
    doAuction();
    pool.distribute();
    distributor.claim();
    assertEq(couponToken.balanceOf(user1), totalCouponsOwed / 4); // 25% to user1
    vm.stopPrank();

    vm.startPrank(user2);
    distributor.claim();
    assertEq(couponToken.balanceOf(user2), totalCouponsOwed / 4); // 25% to user2
    vm.stopPrank();

    vm.startPrank(user3);
    distributor.claim();
    assertEq(couponToken.balanceOf(user3), totalCouponsOwed / 2); // 50% to user3
    vm.stopPrank();
  }

  function testClaimNonExistentPool() public {
    PoolFactory.PoolParams memory params;

    params.fee = 0;
    params.sharesPerToken = 50 * 10 ** 6;
    params.reserveToken = address(new Token("Wrapped ETH", "WETH", false));
    params.distributionPeriod = 0;
    params.couponToken = address(new Token("Circle USD", "USDC", false));

    vm.startPrank(governance);
    // Mint reserve tokens
    Token(params.reserveToken).mint(governance, 10_000_000_000);
    Token(params.reserveToken).approve(address(poolFactory), 10_000_000_000);

    params.couponToken = address(0);
    Pool _pool =
      Pool(poolFactory.createPool(params, 10_000_000_000, 10_000 * 10 ** 18, 10_000 * 10 ** 18, "", "", "", "", false));
    distributor = Distributor(poolFactory.distributors(address(_pool)));
    vm.stopPrank();

    vm.startPrank(user1);
    vm.expectRevert(Distributor.UnsupportedPool.selector);
    distributor.claim();
    vm.stopPrank();
  }

  function testClaimAfterMultiplePeriods() public {
    uint256 couponsOwedPerPeriod = bondToken.totalSupply() * SHARES_PER_TOKEN / 1e18;
    // 3 periods
    doAuction();
    pool.distribute();

    doAuction();
    pool.distribute();

    doAuction();
    pool.distribute();

    vm.startPrank(user1);

    distributor.claim();
    vm.stopPrank();

    assertEq(couponToken.balanceOf(user1), 3 * couponsOwedPerPeriod);
  }

  function testClaimNotEnoughSharesToDistribute() public {
    vm.startPrank(user1);
    bondToken.transfer(user2, bondToken.balanceOf(user1) / 2);
    doAuction();
    pool.distribute();

    // Should never happen in prod where the amount of coupons in Distributor is
    // less than the amount needed to distribute
    vm.startPrank(address(distributor));
    couponToken.transfer(address(0xdead), 1);

    vm.startPrank(user1);
    vm.expectRevert(Distributor.NotEnoughSharesToDistribute.selector);
    distributor.claim();
    vm.stopPrank();
  }

  function testAllocateCallerNotPool() public {
    vm.startPrank(user1);
    vm.expectRevert(Distributor.CallerIsNotPool.selector);
    distributor.allocate(100);
    vm.stopPrank();
  }

  function testAllocateNotEnoughCouponBalance() public {
    uint256 allocateAmount = type(uint256).max;

    vm.startPrank(address(pool));
    vm.expectRevert(Distributor.NotEnoughCouponBalance.selector);
    distributor.allocate(allocateAmount);
    vm.stopPrank();
  }

  function testClaimWithTransferDuringBidding() public {
    // User 1 has total supply
    uint256 totalSupply = bondToken.totalSupply();
    uint256 transferAmount = totalSupply * 3 / 10;
    _startAuction();
    vm.startPrank(user1);
    bondToken.transfer(user2, transferAmount);
    _endAuction();
    pool.distribute();

    vm.startPrank(user1);
    distributor.claim();
    vm.stopPrank();

    vm.startPrank(user2);
    vm.expectRevert(Distributor.NothingToClaim.selector);
    distributor.claim();
    vm.stopPrank();

    uint256 expectedShares1 = totalSupply * SHARES_PER_TOKEN / 1e18;

    assertEq(couponToken.balanceOf(user1), expectedShares1);
    assertEq(couponToken.balanceOf(user2), 0);
  }

  function testClaimWithTransferDuringBiddingAfterMultipleInactivePeriods() public {
    // User 1 has total supply
    uint256 totalSupply = bondToken.totalSupply();
    uint256 transferAmount = totalSupply * 3 / 10;

    doAuction();
    pool.distribute();

    doFailedAuction();
    pool.distribute();

    doAuction();
    pool.distribute();

    _startAuction();
    vm.startPrank(user1);
    bondToken.transfer(user2, transferAmount);
    vm.stopPrank();
    _endAuction();
    pool.distribute();

    doAuction();
    pool.distribute();

    vm.startPrank(user1);
    distributor.claim();
    vm.stopPrank();

    vm.startPrank(user2);
    distributor.claim();
    vm.stopPrank();

    uint256 expectedShares1 = (totalSupply * SHARES_PER_TOKEN / 1e18) * 3 // 3 periods of all
      // coupons
      + (totalSupply - transferAmount) * SHARES_PER_TOKEN / 1e18; // 1 period accounting for transfer

    uint256 expectedShares2 = transferAmount * SHARES_PER_TOKEN / 1e18; // 1 period

    assertEq(couponToken.balanceOf(user1), expectedShares1);
    assertEq(couponToken.balanceOf(user2), expectedShares2);
  }

  function testTransferDuringInitialFailedAuction() public {
    // User 1 has total supply
    uint256 totalBondSupply = bondToken.totalSupply();
    uint256 transferAmount = totalBondSupply * 3 / 10;

    // First auction fails. User 1 transfers during bidding
    _startAuction();
    vm.startPrank(user1);
    bondToken.transfer(user2, transferAmount);
    vm.stopPrank();
    _endFailedAuction();
    pool.distribute();

    vm.startPrank(user1);
    vm.expectRevert(Distributor.NothingToClaim.selector);
    distributor.claim();
    vm.stopPrank();
    vm.startPrank(user2);
    vm.expectRevert(Distributor.NothingToClaim.selector);
    distributor.claim();
    vm.stopPrank();

    // Second auction succeeds. User 1 claims
    doAuction();
    pool.distribute();

    vm.startPrank(user1);
    distributor.claim();
    vm.stopPrank();

    // Third auction fails again. User 1 transfers during bidding again
    _startAuction();
    vm.startPrank(user1);
    bondToken.transfer(user2, transferAmount);
    vm.stopPrank();
    _endFailedAuction();
    pool.distribute();

    vm.startPrank(user1);
    // Tries to claim but should revert, as previous auction failed and the second auction coupons are already claimed
    vm.expectRevert(Distributor.NothingToClaim.selector);
    distributor.claim();
    vm.stopPrank();

    vm.startPrank(user2);
    distributor.claim();
    vm.stopPrank();

    uint256 expectedUser1 = totalBondSupply * 7 / 10 * SHARES_PER_TOKEN / 1e18;
    uint256 expectedUser2 = totalBondSupply * 3 / 10 * SHARES_PER_TOKEN / 1e18;

    assertEq(couponToken.balanceOf(user1), expectedUser1);
    assertEq(couponToken.balanceOf(user2), expectedUser2);
  }

  function testTransferDuringMultipleInitialFailedAuctions() public {
    // User 1 has total supply
    uint256 totalBondSupply = bondToken.totalSupply();
    uint256 transferAmount = totalBondSupply * 2 / 10;

    // First auction fails. User 1 transfers during bidding
    _startAuction();
    vm.startPrank(user1);
    bondToken.transfer(user2, transferAmount);
    vm.stopPrank();
    _endFailedAuction();
    pool.distribute();

    vm.startPrank(user1);
    vm.expectRevert(Distributor.NothingToClaim.selector);
    distributor.claim();
    vm.stopPrank();

    vm.startPrank(user2);
    vm.expectRevert(Distributor.NothingToClaim.selector);
    distributor.claim();
    vm.stopPrank();

    // Second auction fails. User 1 transfers during bidding again
    _startAuction();
    vm.startPrank(user1);
    bondToken.transfer(user2, transferAmount);
    vm.stopPrank();
    _endFailedAuction();
    pool.distribute();

    vm.startPrank(user1);
    vm.expectRevert(Distributor.NothingToClaim.selector);
    distributor.claim();
    vm.stopPrank();

    vm.startPrank(user2);
    vm.expectRevert(Distributor.NothingToClaim.selector);
    distributor.claim();
    vm.stopPrank();

    // Third auction succeeds
    doAuction();
    pool.distribute();

    vm.startPrank(user1);
    distributor.claim();
    vm.stopPrank();

    vm.startPrank(user2);
    distributor.claim();
    vm.stopPrank();

    uint256 expectedUser1 = totalBondSupply * 6 / 10 * SHARES_PER_TOKEN / 1e18;
    uint256 expectedUser2 = totalBondSupply * 4 / 10 * SHARES_PER_TOKEN / 1e18;

    assertEq(couponToken.balanceOf(user1), expectedUser1);
    assertEq(couponToken.balanceOf(user2), expectedUser2);
  }

  function testTransferDuringMultipleFailedAuctionsAfterSuccessfulAuctions() public {
    // User 1 has total supply
    uint256 totalBondSupply = bondToken.totalSupply();
    uint256 transferAmount = totalBondSupply * 2 / 10;

    doAuction();
    pool.distribute();

    doFailedAuction();
    pool.distribute();

    doAuction();
    pool.distribute();

    // Fourth auction fails. User 1 transfers during bidding
    _startAuction();
    vm.startPrank(user1);
    bondToken.transfer(user2, transferAmount);
    vm.stopPrank();
    _endFailedAuction();
    pool.distribute();

    vm.startPrank(user1);
    distributor.claim();
    vm.stopPrank();

    vm.startPrank(user2);
    vm.expectRevert(Distributor.NothingToClaim.selector);
    distributor.claim();
    vm.stopPrank();

    // Fifth auction fails. User 1 transfers during bidding again
    _startAuction();
    vm.startPrank(user1);
    bondToken.transfer(user2, transferAmount);
    vm.stopPrank();
    _endFailedAuction();
    pool.distribute();

    vm.startPrank(user1);
    vm.expectRevert(Distributor.NothingToClaim.selector);
    distributor.claim();
    vm.stopPrank();

    vm.startPrank(user2);
    vm.expectRevert(Distributor.NothingToClaim.selector);
    distributor.claim();
    vm.stopPrank();

    uint256 expectedUser1 = (totalBondSupply * SHARES_PER_TOKEN / 1e18) * 2;
    uint256 expectedUser2 = 0;

    assertEq(couponToken.balanceOf(user1), expectedUser1);
    assertEq(couponToken.balanceOf(user2), expectedUser2);

    doAuction();
    pool.distribute();

    vm.startPrank(user1);
    distributor.claim();
    vm.stopPrank();

    vm.startPrank(user2);
    distributor.claim();
    vm.stopPrank();

    expectedUser1 += totalBondSupply * 6 / 10 * SHARES_PER_TOKEN / 1e18;
    expectedUser2 += totalBondSupply * 4 / 10 * SHARES_PER_TOKEN / 1e18;

    assertEq(couponToken.balanceOf(user1), expectedUser1);
    assertEq(couponToken.balanceOf(user2), expectedUser2);
  }

  function testClaimingDuringAndAfterBidding() public {
    uint256 totalBondSupply = bondToken.totalSupply();
    doAuction();
    pool.distribute();

    _startAuction();
    vm.startPrank(user1);
    (uint256 shares, uint256 lastIndexedPeriodBalance) =
      bondToken.getIndexedUserAmount(user1, bondToken.balanceOf(user1), 2);
    distributor.claim();
    (shares, lastIndexedPeriodBalance) = bondToken.getIndexedUserAmount(user1, bondToken.balanceOf(user1), 2);
    vm.stopPrank();

    uint256 expectedUser1 = totalBondSupply * SHARES_PER_TOKEN / 1e18;
    assertEq(couponToken.balanceOf(user1), expectedUser1);

    _endAuction();
    pool.distribute();

    vm.startPrank(user1);
    (shares, lastIndexedPeriodBalance) = bondToken.getIndexedUserAmount(user1, bondToken.balanceOf(user1), 2);
    distributor.claim();
    (shares, lastIndexedPeriodBalance) = bondToken.getIndexedUserAmount(user1, bondToken.balanceOf(user1), 2);
    vm.stopPrank();

    expectedUser1 += totalBondSupply * SHARES_PER_TOKEN / 1e18;
    assertEq(couponToken.balanceOf(user1), expectedUser1);
  }

  function testClaimingDuringAndAfterBiddingWithTransferBeforeClaim() public {
    uint256 totalBondSupply = bondToken.totalSupply();
    uint256 transferAmount = totalBondSupply * 2 / 10;
    doAuction();
    pool.distribute();

    _startAuction();
    vm.startPrank(user1);
    bondToken.transfer(user2, transferAmount);
    distributor.claim();
    vm.stopPrank();

    uint256 expectedUser1 = totalBondSupply * SHARES_PER_TOKEN / 1e18;
    assertEq(couponToken.balanceOf(user1), expectedUser1);

    _endAuction();
    pool.distribute();

    vm.startPrank(user1);
    distributor.claim();
    vm.stopPrank();

    expectedUser1 += totalBondSupply * SHARES_PER_TOKEN / 1e18;
    assertEq(couponToken.balanceOf(user1), expectedUser1);

    doAuction();
    pool.distribute();

    vm.startPrank(user1);
    distributor.claim();
    vm.stopPrank();

    expectedUser1 += (totalBondSupply - transferAmount) * SHARES_PER_TOKEN / 1e18;
    assertEq(couponToken.balanceOf(user1), expectedUser1);
  }

  function testClaimingDuringAndAfterBiddingWithTransferAfterClaim() public {
    uint256 totalBondSupply = bondToken.totalSupply();
    uint256 transferAmount = totalBondSupply * 2 / 10;
    doAuction();
    pool.distribute();

    _startAuction();
    vm.startPrank(user1);
    distributor.claim();
    bondToken.transfer(user2, transferAmount);
    vm.stopPrank();

    uint256 expectedUser1 = totalBondSupply * SHARES_PER_TOKEN / 1e18;
    assertEq(couponToken.balanceOf(user1), expectedUser1);

    _endAuction();
    pool.distribute();

    doAuction();
    pool.distribute();

    vm.startPrank(user1);
    distributor.claim();
    vm.stopPrank();

    // Add on second and third period expected coupons
    expectedUser1 += (totalBondSupply + totalBondSupply - transferAmount) * SHARES_PER_TOKEN / 1e18;
    assertEq(couponToken.balanceOf(user1), expectedUser1);
  }

  function testVariousClaimPatternsWithTransfersOverMultiplePeriods() public {
    // User 1 always claims in every period.
    // User 2 only claims at the end.
    // User 3 claims once after first period, and once after the 5th period.

    // User 1 starts with 20% of the bonds supply
    // User 2 starts with 30% of the bonds supply
    // User 3 starts with 50% of the bonds supply
    // After 2 auctions, user 3 transfer 20% to user 1
    // After 3 auctions, user 2 transfer all 30% to user 3
    // The 5th auction fails
    // When 6th auction is bidding, user 1 transfer 30% to user 2
    // Total of 6 auctions

    // Setup initial bond balances
    uint256 totalSupply = bondToken.totalSupply();
    vm.startPrank(user1);
    bondToken.transfer(user2, totalSupply * 3 / 10);
    bondToken.transfer(user3, totalSupply / 2);
    vm.stopPrank();

    // First period
    doAuction();
    pool.distribute();

    // Users 1 and 3 claim
    vm.startPrank(user1);
    distributor.claim();
    vm.startPrank(user3);
    distributor.claim();
    vm.stopPrank();

    // Second period
    doAuction();
    pool.distribute();

    // User 3 transfers 20% to user 1 and user 1 claims
    vm.startPrank(user3);
    bondToken.transfer(user1, totalSupply * 2 / 10);
    vm.stopPrank();
    vm.startPrank(user1);
    distributor.claim();
    vm.stopPrank();

    // Third period
    doAuction();
    pool.distribute();

    // User 2 transfers all 30% to user 3, and user 1 claims
    vm.startPrank(user2);
    bondToken.transfer(user3, bondToken.balanceOf(user2));
    vm.stopPrank();
    vm.startPrank(user1);
    distributor.claim();
    vm.stopPrank();

    // Fourth period
    doAuction();
    pool.distribute();

    // User 1 claims
    vm.startPrank(user1);
    distributor.claim();
    vm.stopPrank();

    // Fifth period, failed auction
    doFailedAuction();
    pool.distribute();

    // Users 1 and 3 claim
    vm.startPrank(user1);
    vm.expectRevert(Distributor.NothingToClaim.selector);
    distributor.claim();

    vm.startPrank(user3);
    distributor.claim();
    vm.stopPrank();

    // Sixth period
    _startAuction();
    vm.startPrank(user1);
    bondToken.transfer(user2, totalSupply * 3 / 10);
    vm.stopPrank();
    _endAuction();
    pool.distribute();

    // Users 1 and 2 claim
    vm.startPrank(user1);
    distributor.claim();
    vm.stopPrank();

    vm.startPrank(user2);
    distributor.claim();
    vm.stopPrank();

    // Do final auction
    doAuction();
    pool.distribute();

    // Users 1 and 2 claim
    vm.startPrank(user1);
    distributor.claim();
    vm.stopPrank();

    vm.startPrank(user2);
    distributor.claim();
    vm.stopPrank();

    // Calculate expected final amounts for each user
    uint256 totalBondSupply = bondToken.totalSupply();

    // User 1:
    // - Started with 20%
    // - Got 20% more after period 2 (from User3)
    // - Ended with 40% ownership
    // - Claimed in periods 1,2,3,4, and 6
    uint256 expectedUser1 = (
      (totalBondSupply * 20 / 100) // Period 1 (20% ownership)
        + (totalBondSupply * 20 / 100) // Period 2 (20% ownership)
        + (totalBondSupply * 40 / 100) // Period 3 (40% ownership)
        + (totalBondSupply * 40 / 100) // Period 4 (40% ownership)
        + (totalBondSupply * 40 / 100) // Period 6 (40% ownership)
        + (totalBondSupply * 10 / 100)
    ) // Period 7 (10% ownership)
      * SHARES_PER_TOKEN / 1e18; // (Period 5 was failed auction)

    // User 2:
    // - Started with 30%
    // - Held 30% through periods 1, 2, and 3
    // - Transferred all to User3 after period 3
    // - Claims at the end and gets all accumulated amounts from when they held tokens
    uint256 expectedUser2 = (
      (totalBondSupply * 30 / 100) // Period 1 (30% ownership)
        + (totalBondSupply * 30 / 100) // Period 2 (30% ownership)
        + (totalBondSupply * 30 / 100) // Period 3 (30% ownership)
        + (totalBondSupply * 30 / 100)
    ) // Period 7 (30% ownership)
      * SHARES_PER_TOKEN / 1e18;

    // User 3:
    // - Started with 50%
    // - Gave 20% to User1 after period 2
    // - Got 30% from User2 in period 3
    // - Ended with 60% ownership
    // - Claimed in period 1 and after period 5. Should be missing 6th period shares
    uint256 expectedUser3 = (
      (totalBondSupply * 50 / 100) // Period 1 (50% ownership)
        + (totalBondSupply * 50 / 100) // Period 2 (30% ownership)
        + (totalBondSupply * 30 / 100) // Period 3 (60% ownership)
        + (totalBondSupply * 60 / 100)
    ) // Period 4 (60% ownership)
      // + (totalBondSupply * 60 / 100)                    // Period 6 (60% ownership), not claimed
      * SHARES_PER_TOKEN / 1e18; // (Period 5 was failed auction)

    // Assert final balances
    assertEq(couponToken.balanceOf(user2), expectedUser2, "User2 final balance incorrect");
    assertEq(couponToken.balanceOf(user3), expectedUser3, "User3 final balance incorrect");
    assertEq(couponToken.balanceOf(user1), expectedUser1, "User1 final balance incorrect");
  }

  uint256 constant FUZZ_PERIODS = 48;

  function testFuzzSingleUser(
    uint256[FUZZ_PERIODS] calldata actionSeeds,
    uint256[FUZZ_PERIODS] calldata receiveAmounts,
    uint256[FUZZ_PERIODS] calldata sendFractions,
    bool[FUZZ_PERIODS] calldata auctionSuccessSeeds
  ) public {
    address user = user2;
    uint256 expectedCoupons = 0;

    vm.startPrank(address(pool));
    bondToken.mint(user, 100 ether);
    vm.stopPrank();

    for (uint256 period = 1; period <= FUZZ_PERIODS; period++) {
      PeriodActions memory actions = _seedToActions(
        actionSeeds[period - 1],
        bound(receiveAmounts[period - 1], 1, 100) * 1 ether, // Convert to ether after bounding
        bound(sendFractions[period - 1], 100, 9000)
      );

      _startAuction();
      uint256 balanceAtPeriodStart = bondToken.balanceOf(user);

      // Execute during-bidding actions in random order
      _executeActionsInOrder(
        user,
        actions.claimDuringBidding,
        actions.receiveDuringBidding,
        actions.sendDuringBidding,
        actions.duringBiddingOrder
      );

      // End auction and calculate rewards
      if (auctionSuccessSeeds[period - 1]) {
        _endAuction();
        expectedCoupons += (balanceAtPeriodStart * SHARES_PER_TOKEN) / 1e18;
      } else {
        _endFailedAuction();
      }
      pool.distribute();

      // Execute after-bidding actions in random order
      _executeActionsInOrder(
        user,
        actions.claimAfterBidding,
        actions.receiveAfterBidding,
        actions.sendAfterBidding,
        actions.afterBiddingOrder
      );

      emit log_named_uint("\nPeriod", period);
      emit log_named_uint("Balance at period start", balanceAtPeriodStart);
      emit log_named_uint("Current balance", bondToken.balanceOf(user));
      emit log_named_uint("Expected coupons", expectedCoupons);
    }

    // Claim right at the end to ensure we get all the coupons
    vm.startPrank(user);
    try distributor.claim() {}
    catch (bytes memory reason) {
      if (bytes4(reason) != Distributor.NothingToClaim.selector) revert(string(reason));
    }
    vm.stopPrank();

    assertApproxEqRel(couponToken.balanceOf(user), expectedCoupons, 0.000001e18, "Final coupon balance mismatch"); // 0.0001%
      // difference for rounding errors
  }

  function _executeActionsInOrder(
    address user,
    bool shouldClaim,
    uint256 receiveAmount,
    uint256 sendFraction,
    uint256 orderSeed
  ) internal {
    // Get order based on seed (0-5 for 6 possible permutations)
    uint256 order = orderSeed % 6;

    // Execute actions in determined order
    for (uint256 i = 0; i < 3; i++) {
      if (_getActionAtPosition(order, i) == 0) {
        // Claim
        if (shouldClaim) {
          vm.prank(user);
          try distributor.claim() {}
          catch (bytes memory reason) {
            if (bytes4(reason) != Distributor.NothingToClaim.selector) revert(string(reason));
          }
        }
      } else if (_getActionAtPosition(order, i) == 1) {
        // Receive
        if (receiveAmount > 0) {
          vm.startPrank(address(pool));
          bondToken.mint(user, receiveAmount);
          vm.stopPrank();
        }
      } else {
        // Send
        if (sendFraction > 0) {
          uint256 sendAmount = (bondToken.balanceOf(user) * sendFraction) / 10_000;
          if (sendAmount > 0) {
            vm.startPrank(user);
            bondToken.transfer(address(pool), sendAmount);
            vm.stopPrank();
            vm.startPrank(address(pool));
            bondToken.burn(address(pool), sendAmount);
            vm.stopPrank();
          }
        }
      }
    }
  }

  function _getActionAtPosition(uint256 order, uint256 position) internal pure returns (uint256) {
    // Returns which action (0=claim, 1=receive, 2=send) should be at given position
    // Based on the order seed (0-5)
    if (order == 0) return [0, 1, 2][position];
    if (order == 1) return [0, 2, 1][position];
    if (order == 2) return [1, 0, 2][position];
    if (order == 3) return [1, 2, 0][position];
    if (order == 4) return [2, 0, 1][position];
    return [2, 1, 0][position]; // order == 5
  }

  function _seedToActions(uint256 seed, uint256 receiveAmount, uint256 sendFraction)
    internal
    returns (PeriodActions memory)
  {
    emit log_named_uint("seed", seed);
    emit log_named_string("claimDuringBidding", (seed & 1) == 1 ? "true" : "false");
    emit log_named_uint("receiveDuringBidding", (seed & 2) == 2 ? receiveAmount : 0);
    emit log_named_uint("sendDuringBidding", (seed & 4) == 4 ? sendFraction : 0);
    emit log_named_string("claimAfterBidding", (seed & 8) == 8 ? "true" : "false");
    emit log_named_uint("receiveAfterBidding", (seed & 16) == 16 ? receiveAmount : 0);
    emit log_named_uint("sendAfterBidding", (seed & 32) == 32 ? sendFraction : 0);
    emit log_named_uint("duringBiddingOrder", (seed >> 6) % 6);
    emit log_named_uint("afterBiddingOrder", (seed >> 9) % 6);
    return PeriodActions({
      claimDuringBidding: (seed & 1) == 1,
      receiveDuringBidding: (seed & 2) == 2 ? receiveAmount : 0,
      sendDuringBidding: (seed & 4) == 4 ? sendFraction : 0,
      claimAfterBidding: (seed & 8) == 8,
      receiveAfterBidding: (seed & 16) == 16 ? receiveAmount : 0,
      sendAfterBidding: (seed & 32) == 32 ? sendFraction : 0,
      duringBiddingOrder: (seed >> 6) % 6, // Use next 3 bits for during-bidding order
      afterBiddingOrder: (seed >> 9) % 6 // Use next 3 bits for after-bidding order
    });
  }

  function _startAuction() internal {
    vm.startPrank(governance);
    Pool.PoolInfo memory info = pool.getPoolInfo();
    vm.warp(info.lastDistribution + DISTRIBUTION_PERIOD + 1);

    pool.startAuction();
    vm.stopPrank();
  }

  function _endAuction() internal {
    vm.startPrank(governance);
    (uint256 currentPeriod,) = bondToken.globalPool();
    Auction auction = Auction(pool.auctions(currentPeriod - 1));
    uint256 amount = auction.totalBuyCouponAmount();
    deal(address(couponToken), governance, amount);
    couponToken.approve(address(auction), amount);
    auction.bid(1, amount);

    vm.warp(block.timestamp + AUCTION_PERIOD + 1);
    auction.endAuction();
    vm.stopPrank();
  }

  function _endFailedAuction() internal {
    vm.startPrank(governance);
    (uint256 currentPeriod,) = bondToken.globalPool();
    Auction auction = Auction(pool.auctions(currentPeriod - 1));
    uint256 amount = auction.totalBuyCouponAmount() / 2;
    deal(address(couponToken), governance, amount);
    couponToken.approve(address(auction), amount);
    auction.bid(1, amount);

    vm.warp(block.timestamp + AUCTION_PERIOD + 1);
    auction.endAuction();
    vm.stopPrank();
  }
}
