// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {TestSetup, Pool, Auction} from "./TestSetup.sol";

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract AuctionTest is Test, TestSetup {
  Auction public auction;
  address public bidder = user1;
  address public bidder2 = user2;
  uint256 slotSize;
  uint256 reserveBuyAmount5p; // Arbitrarily buy 5% of the pool's reserve

  function setUp() public override {
    super.setUp();
    createPool();
    _startAuction();

    slotSize = auction.slotSize();
    reserveBuyAmount5p = reserveToken.balanceOf(address(pool)) / 20; // Arbitrarily by 5% of the
      // pool's reserve

    deal(address(couponToken), bidder, 1_000_000_000 ether);
    deal(address(couponToken), bidder2, 1_000_000_000 ether);

    vm.startPrank(bidder);
    couponToken.approve(address(auction), 1_000_000_000 ether);
    vm.stopPrank();

    vm.startPrank(bidder2);
    couponToken.approve(address(auction), 1_000_000_000 ether);
    vm.stopPrank();
  }

  function testConstructor() public view {
    assertEq(auction.endTime(), block.timestamp + AUCTION_PERIOD);
    assertEq(auction.buyCouponToken(), address(couponToken));
    assertEq(auction.sellReserveToken(), address(reserveToken));
    assertEq(auction.beneficiary(), address(pool));

    uint256 totalBuyCouponAmount = bondToken.totalSupply() * SHARES_PER_TOKEN / 10 ** bondToken.decimals();
    assertEq(auction.totalBuyCouponAmount(), totalBuyCouponAmount);
  }

  function testPause() public {
    vm.startPrank(securityCouncil);
    auction.pause();

    vm.startPrank(bidder);
    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    auction.bid(100 ether, slotSize);

    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    vm.warp(block.timestamp + 15 days);
    auction.endAuction();

    vm.startPrank(securityCouncil);
    auction.unpause();

    vm.warp(block.timestamp - 14 days);

    vm.startPrank(bidder);
    auction.bid(100 ether, slotSize);

    assertEq(auction.bidCount(), 1);
  }

  function testBidSuccess() public {
    vm.startPrank(bidder);

    auction.bid(100 ether, slotSize);

    assertEq(auction.bidCount(), 1);
    (address bidderAddress, uint256 buyAmount, uint256 sellAmount,,, bool claimed) = auction.bids(1);
    assertEq(bidderAddress, bidder);
    assertEq(buyAmount, 100 ether);
    assertEq(sellAmount, slotSize);
    assertEq(claimed, false);

    vm.stopPrank();
  }

  function testBidInvalidSellAmount() public {
    vm.startPrank(bidder);

    vm.expectRevert(Auction.InvalidSellAmount.selector);
    auction.bid(100 ether, 0);

    vm.expectRevert(Auction.InvalidSellAmount.selector);
    auction.bid(100 ether, slotSize + 1);

    vm.stopPrank();
  }

  function testBidAmountTooLow() public {
    vm.startPrank(bidder);

    vm.expectRevert(Auction.BidAmountTooLow.selector);
    auction.bid(0, slotSize);

    vm.stopPrank();
  }

  function testBidAuctionEnded() public {
    vm.warp(block.timestamp + AUCTION_PERIOD + 1);
    vm.startPrank(bidder);

    vm.expectRevert(Auction.AuctionHasEnded.selector);
    auction.bid(100 ether, slotSize);

    vm.stopPrank();
  }

  function testEndAuctionSuccess() public {
    vm.startPrank(bidder);
    auction.bid(1, auction.totalBuyCouponAmount());
    vm.stopPrank();

    vm.warp(block.timestamp + AUCTION_PERIOD + 1);
    vm.prank(address(pool));
    auction.endAuction();

    assertEq(uint256(auction.state()), uint256(Auction.State.SUCCEEDED));
  }

  function testEndAuctionFailed() public {
    uint256 lastPeriodSharesPerToken = Pool(pool).bondToken().getPreviousPoolAmounts()[0].sharesPerToken;
    assertEq(lastPeriodSharesPerToken, SHARES_PER_TOKEN);

    vm.warp(block.timestamp + AUCTION_PERIOD + 1);
    vm.prank(address(pool));
    auction.endAuction();

    assertEq(uint256(auction.state()), uint256(Auction.State.FAILED_UNDERSOLD));

    lastPeriodSharesPerToken = Pool(pool).bondToken().getPreviousPoolAmounts()[0].sharesPerToken;
    assertEq(lastPeriodSharesPerToken, 0);
  }

  function testEndAuctionFailedPoolSale() public {
    uint256 lastPeriodSharesPerToken = Pool(pool).bondToken().getPreviousPoolAmounts()[0].sharesPerToken;
    assertEq(lastPeriodSharesPerToken, SHARES_PER_TOKEN);

    uint256 usdcBidAmount = auction.totalBuyCouponAmount();
    uint256 reserveBidAmount = reserveToken.balanceOf(address(pool)) * (91) / 100;

    // Place a bid that would require too much of the reserve
    vm.startPrank(bidder);
    auction.bid(reserveBidAmount, usdcBidAmount); // 96% of pool's reserve

    // End the auction
    vm.warp(block.timestamp + AUCTION_PERIOD + 1);

    auction.endAuction();

    // Check that auction failed due to too much of the reserve being sold
    assertEq(uint256(auction.state()), uint256(Auction.State.FAILED_POOL_SALE_LIMIT));

    lastPeriodSharesPerToken = Pool(pool).bondToken().getPreviousPoolAmounts()[0].sharesPerToken;
    assertEq(lastPeriodSharesPerToken, 0);
  }

  function testEndAuctionStillOngoing() public {
    vm.expectRevert(Auction.AuctionStillOngoing.selector);
    auction.endAuction();
  }

  function testClaimBidSuccess() public {
    vm.startPrank(bidder);
    auction.bid(reserveBuyAmount5p, auction.totalBuyCouponAmount());
    vm.stopPrank();

    vm.warp(block.timestamp + AUCTION_PERIOD + 1);
    vm.prank(address(pool));
    auction.endAuction();

    uint256 initialBalance = reserveToken.balanceOf(bidder);

    vm.prank(bidder);
    auction.claimBid(1);

    assertEq(reserveToken.balanceOf(bidder), initialBalance + reserveBuyAmount5p);
  }

  function testPartialRefund() public {
    vm.startPrank(bidder);
    auction.bid(reserveBuyAmount5p, auction.totalBuyCouponAmount());
    vm.stopPrank();

    uint256 postBidBalance = couponToken.balanceOf(bidder);

    // New bidder
    vm.startPrank(bidder2);

    // Higher bid, kicks out the first bid partially (1 slot)
    auction.bid(reserveBuyAmount5p / 4, auction.totalBuyCouponAmount() / 2); // bids at half the
      // price
    vm.stopPrank();

    vm.warp(block.timestamp + AUCTION_PERIOD + 1);
    auction.endAuction();

    // Check that the bidder does not receive the partial refund and updated pending refunds
    assertEq(couponToken.balanceOf(bidder), postBidBalance);
    assertEq(auction.pendingRefunds(bidder), auction.totalBuyCouponAmount() / 2);

    vm.startPrank(bidder);
    auction.claimBid(1);
    auction.claimRefund();
    vm.stopPrank();

    assertEq(couponToken.balanceOf(bidder), postBidBalance + auction.totalBuyCouponAmount() / 2);
  }

  function testClaimBidAuctionNotEnded() public {
    vm.startPrank(bidder);
    auction.bid(reserveBuyAmount5p, auction.totalBuyCouponAmount());

    vm.expectRevert(Auction.AuctionStillOngoing.selector);
    auction.claimBid(0);

    vm.stopPrank();
  }

  function testClaimBidAuctionFailed() public {
    vm.warp(block.timestamp + AUCTION_PERIOD + 1);
    auction.endAuction();

    vm.expectRevert(Auction.AuctionFailed.selector);
    auction.claimBid(0);
  }

  function testClaimBidNothingToClaim() public {
    vm.startPrank(bidder);
    auction.bid(reserveBuyAmount5p, auction.totalBuyCouponAmount());
    vm.stopPrank();

    vm.warp(block.timestamp + AUCTION_PERIOD + 1);
    auction.endAuction();

    vm.expectRevert(Auction.NothingToClaim.selector);
    vm.prank(address(0xdead));
    auction.claimBid(0);
  }

  function testClaimBidAlreadyClaimed() public {
    vm.startPrank(bidder);
    auction.bid(reserveBuyAmount5p, auction.totalBuyCouponAmount());
    vm.stopPrank();

    vm.warp(block.timestamp + AUCTION_PERIOD + 1);
    auction.endAuction();

    vm.startPrank(bidder);
    auction.claimBid(1);

    vm.expectRevert(Auction.AlreadyClaimed.selector);
    auction.claimBid(1);
    vm.stopPrank();
  }

  function testClaimRefundSuccess() public {
    vm.startPrank(bidder);
    uint256 bidAmount = auction.totalBuyCouponAmount() / 1000;
    uint256 bidIndex = auction.bid(reserveBuyAmount5p, bidAmount);

    vm.warp(block.timestamp + AUCTION_PERIOD + 1);
    auction.endAuction();

    uint256 initialBalance = couponToken.balanceOf(bidder);

    auction.claimRefund(bidIndex);

    assertEq(couponToken.balanceOf(bidder), initialBalance + bidAmount);
  }

  function testClaimRefundSuccessManyBidders() public {
    uint256 bidAmount = auction.totalBuyCouponAmount() / 1000;

    vm.startPrank(bidder);
    uint256 bidIndex = auction.bid(reserveBuyAmount5p, bidAmount);
    vm.stopPrank();

    vm.startPrank(bidder2);
    uint256 bidIndex2 = auction.bid(reserveBuyAmount5p, bidAmount);
    vm.stopPrank();

    vm.warp(block.timestamp + AUCTION_PERIOD + 1);
    auction.endAuction();

    uint256 initialBalance = couponToken.balanceOf(bidder);
    vm.prank(bidder);
    auction.claimRefund(bidIndex);
    assertEq(couponToken.balanceOf(bidder), initialBalance + bidAmount);

    uint256 initialBalanceBidder2 = couponToken.balanceOf(bidder2);
    vm.prank(bidder2);
    auction.claimRefund(bidIndex2);
    assertEq(couponToken.balanceOf(bidder2), initialBalanceBidder2 + bidAmount);
  }

  function testClaimRefundAuctionNotFailed() public {
    vm.startPrank(bidder);
    uint256 bidIndex = auction.bid(reserveBuyAmount5p, auction.totalBuyCouponAmount());
    vm.stopPrank();

    vm.warp(block.timestamp + AUCTION_PERIOD + 1);
    auction.endAuction();

    vm.expectRevert(Auction.AuctionSucceededOrOngoing.selector);
    vm.prank(bidder);
    auction.claimRefund(bidIndex);
  }

  function testClaimRefundNothingToClaim() public {
    vm.startPrank(bidder);
    auction.bid(reserveBuyAmount5p, auction.totalBuyCouponAmount() / 1000);
    vm.stopPrank();

    vm.warp(block.timestamp + AUCTION_PERIOD + 1);
    auction.endAuction();

    vm.expectRevert(Auction.NothingToClaim.selector);
    vm.prank(address(0xdead));
    auction.claimRefund();
  }

  function testClaimRefundAlreadyClaimed() public {
    vm.startPrank(bidder);
    uint256 bidAmount = auction.totalBuyCouponAmount() / 1000;
    uint256 bidIndex = auction.bid(reserveBuyAmount5p, bidAmount);
    vm.stopPrank();

    vm.warp(block.timestamp + AUCTION_PERIOD + 1);
    auction.endAuction();

    vm.startPrank(bidder);
    auction.claimRefund(bidIndex);

    vm.expectRevert(Auction.AlreadyClaimed.selector);
    auction.claimRefund(bidIndex);
    vm.stopPrank();
  }

  function testClaimRefundAuctionNotEnded() public {
    vm.startPrank(bidder);
    uint256 bidIndex = auction.bid(reserveBuyAmount5p, auction.totalBuyCouponAmount() / 1000);
    vm.stopPrank();

    vm.expectRevert(Auction.AuctionStillOngoing.selector);
    vm.prank(bidder);
    auction.claimRefund(bidIndex);
  }

  function testWithdrawSuccess() public {
    vm.startPrank(bidder);
    auction.bid(reserveBuyAmount5p, auction.totalBuyCouponAmount());
    vm.stopPrank();

    vm.warp(block.timestamp + AUCTION_PERIOD + 1);

    uint256 initialBalance = couponToken.balanceOf(address(pool));

    auction.endAuction();
    assertEq(couponToken.balanceOf(address(pool)), initialBalance + auction.totalBuyCouponAmount());
  }

  function testMultipleBidsWithNewHighBid() public {
    uint256 initialBidAmount = reserveToken.balanceOf(address(pool)) / 2000; // 0.05% of the pool's
      // reserve
    uint256 initialSellAmount = auction.totalBuyCouponAmount() / 1000;

    // Create 1000 bids
    for (uint256 i = 0; i < 1000; i++) {
      address newBidder = address(uint160(i + 1));
      vm.startPrank(newBidder);
      deal(address(couponToken), newBidder, initialSellAmount);
      couponToken.approve(address(auction), initialSellAmount);
      auction.bid(initialBidAmount, initialSellAmount);
      vm.stopPrank();
    }

    // Check initial state
    assertEq(auction.bidCount(), 1000, "bid count 1");
    assertEq(auction.highestBidIndex(), 1, "highest bid index 1");
    assertEq(auction.lowestBidIndex(), 1000, "lowest bid index 1");

    // Place a new high bid
    address highBidder = address(1001);
    uint256 highBidAmount = initialBidAmount / 2;
    uint256 highSellAmount = initialSellAmount;

    vm.startPrank(highBidder);
    deal(address(couponToken), highBidder, highSellAmount);
    couponToken.approve(address(auction), highSellAmount);
    auction.bid(highBidAmount, highSellAmount);
    vm.stopPrank();

    // Check updated state
    assertEq(auction.bidCount(), 1000, "bid count 2");
    assertEq(auction.highestBidIndex(), 1001, "highest bid index 2");

    // The lowest bid should have been kicked out
    (, uint256 lowestBuyAmount,,,,) = auction.bids(auction.lowestBidIndex());
    assertGt(lowestBuyAmount, highBidAmount, "lowest buy amount 2");

    // Verify the new high bid
    (address highestBidder, uint256 highestBuyAmount, uint256 highestSellAmount,,,) =
      auction.bids(auction.highestBidIndex());
    assertEq(highestBidder, highBidder, "highest bidder");
    assertEq(highestBuyAmount, highBidAmount, "highest buy amount");
    assertEq(highestSellAmount, highSellAmount, "highest sell amount");
  }

  function testRemoveManyBids() public {
    uint256 initialBidAmount = reserveToken.balanceOf(address(pool)) / 2000; // 0.05% of the pool's
      // reserve
    uint256 initialSellAmount = auction.totalBuyCouponAmount() / 1000;

    // Create 1000 bids
    for (uint256 i = 0; i < 1000; i++) {
      address newBidder = address(uint160(i + 1));
      vm.startPrank(newBidder);
      deal(address(couponToken), newBidder, initialSellAmount);
      couponToken.approve(address(auction), initialSellAmount);
      auction.bid(initialBidAmount, initialSellAmount);
      vm.stopPrank();
    }

    // Check initial state
    assertEq(auction.bidCount(), 1000, "bid count 1");
    assertEq(auction.highestBidIndex(), 1, "highest bid index 1");
    assertEq(auction.lowestBidIndex(), 1000, "lowest bid index 1");

    // Place a new high bid
    address highBidder = address(1001);
    uint256 highBidAmount = initialBidAmount / 2;
    uint256 highSellAmount = initialSellAmount * 10; // this should take 10 slots

    vm.startPrank(highBidder);
    deal(address(couponToken), highBidder, highSellAmount);
    couponToken.approve(address(auction), highSellAmount);
    auction.bid(highBidAmount, highSellAmount);
    vm.stopPrank();

    // Check updated state
    assertEq(auction.bidCount(), 991, "bid count 2");
    assertEq(auction.highestBidIndex(), 1001, "highest bid index 2");

    // The lowest bid should have been kicked out
    (, uint256 lowestBuyAmount,,,,) = auction.bids(auction.lowestBidIndex());
    assertGt(lowestBuyAmount, highBidAmount, "lowest buy amount 2");

    // Verify the new high bid
    (address highestBidder, uint256 highestBuyAmount, uint256 highestSellAmount,,,) =
      auction.bids(auction.highestBidIndex());
    assertEq(highestBidder, highBidder, "highest bidder");
    assertEq(highestBuyAmount, highBidAmount, "highest buy amount");
    assertEq(highestSellAmount, highSellAmount, "highest sell amount");
  }

  function testRefundBidSuccessful() public {
    uint256 initialBidAmount = reserveToken.balanceOf(address(pool)) / 2000; // 0.05% of the pool's
      // reserve
    uint256 initialSellAmount = auction.totalBuyCouponAmount() / 1000;

    // Create 1000 bids
    for (uint256 i = 0; i < 1000; i++) {
      address newBidder = address(uint160(i + 1));
      vm.startPrank(newBidder);
      deal(address(couponToken), newBidder, initialSellAmount);
      couponToken.approve(address(auction), initialSellAmount);
      auction.bid(initialBidAmount, initialSellAmount);
      vm.stopPrank();
    }

    // Check initial state
    assertEq(auction.bidCount(), 1000, "bid count 1");
    assertEq(auction.highestBidIndex(), 1, "highest bid index 1");
    assertEq(auction.lowestBidIndex(), 1000, "lowest bid index 1");

    (address lowestBidder,, uint256 lowestSellCouponAmount,,,) = auction.bids(auction.lowestBidIndex());
    uint256 lowestBidderCouponBalance = couponToken.balanceOf(lowestBidder);

    // Place a new high bid
    address highBidder = address(1001);
    uint256 highSellAmount = initialSellAmount * 10; // this should take 10 slots

    vm.startPrank(highBidder);
    deal(address(couponToken), highBidder, highSellAmount);
    couponToken.approve(address(auction), highSellAmount);
    auction.bid(initialBidAmount, highSellAmount);
    vm.stopPrank();

    // Check refunds behaviour
    assertEq(auction.pendingRefunds(lowestBidder), lowestSellCouponAmount);
    vm.prank(lowestBidder);
    auction.claimRefund();
    assertEq(auction.pendingRefunds(lowestBidder), 0);
    assertEq(couponToken.balanceOf(lowestBidder), lowestBidderCouponBalance + lowestSellCouponAmount);
  }

  function testPartialRefundUpdatesTotalReserves() public {
    vm.startPrank(bidder);
    uint256 initialBidAmount = auction.totalBuyCouponAmount();
    deal(address(couponToken), bidder, initialBidAmount);
    couponToken.approve(address(auction), initialBidAmount);
    auction.bid(reserveBuyAmount5p, initialBidAmount);
    vm.stopPrank();

    address user = address(1001);

    vm.startPrank(user);
    // initialBidAmount + newBidderBid - totalBuyCouponAmount = 5000 ether
    uint256 newBidderBid = initialBidAmount / 2;
    deal(address(couponToken), user, newBidderBid);
    couponToken.approve(address(auction), newBidderBid);
    auction.bid(reserveBuyAmount5p / 4, newBidderBid);
    vm.stopPrank();

    (, uint256 amount1,,,,) = auction.bids(1);
    (, uint256 amount2,,,,) = auction.bids(2);

    assertEq(amount1 + amount2, auction.totalSellReserveAmount());
    assertEq(reserveBuyAmount5p / 2 + reserveBuyAmount5p / 4, auction.totalSellReserveAmount());
  }

  function testAuctionBidOverflow() public {
    vm.startPrank(bidder);
    uint256 initialBidAmount = auction.totalBuyCouponAmount() / 2;
    deal(address(couponToken), bidder, initialBidAmount);
    couponToken.approve(address(auction), initialBidAmount);

    uint256 maxBidAmount = auction.MAX_BID_AMOUNT();
    vm.expectRevert(Auction.BidAmountTooHigh.selector);
    auction.bid(maxBidAmount + 1, initialBidAmount);
    vm.stopPrank();
  }

  function _startAuction() internal {
    Pool.PoolInfo memory info = pool.getPoolInfo();
    vm.warp(info.lastDistribution + DISTRIBUTION_PERIOD + 1);

    pool.startAuction();
    (uint256 currentPeriod,) = bondToken.globalPool();
    auction = Auction(pool.auctions(currentPeriod - 1));
  }
}
