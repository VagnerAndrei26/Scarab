// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {TestSetup, Pool, PoolFactory, Auction, Distributor, Token} from "./TestSetup.sol";

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract BondTokenTest is Test, TestSetup {
  function setUp() public override {
    super.setUp();
    createPool();
  }

  /**
   * @dev Tests minting of tokens by an address with MINTER_ROLE.
   * Asserts that the user's balance is updated correctly.
   */
  function testMinting() public {
    uint256 initialBalance = bondToken.balanceOf(address(pool));
    uint256 mintAmount = 500;

    vm.startPrank(address(pool));
    bondToken.mint(user2, mintAmount);
    vm.stopPrank();

    assertEq(bondToken.balanceOf(user2), mintAmount);
    assertEq(bondToken.balanceOf(address(pool)), initialBalance);
  }

  /**
   * @dev Tests minting of tokens by an address without MINTER_ROLE.
   * Expects the transaction to revert.
   */
  function testMintingWithNoPermission() public {
    uint256 initialBalance = bondToken.balanceOf(user2);

    vm.expectRevert();
    vm.startPrank(user2);
    bondToken.mint(user2, 100);
    vm.stopPrank();

    assertEq(bondToken.balanceOf(user2), initialBalance);
  }

  /**
   * @dev Tests burning of tokens by an address with MINTER_ROLE.
   * Asserts that the minter's balance is decreased correctly.
   */
  function testBurning() public {
    deal(address(bondToken), user2, 100 ether);
    uint256 initialBalance = bondToken.balanceOf(user2);
    uint256 burnAmount = 100;

    vm.startPrank(address(pool));
    bondToken.burn(user2, burnAmount);
    vm.stopPrank();

    assertEq(bondToken.balanceOf(user2), initialBalance - burnAmount);
  }

  /**
   * @dev Tests burning of tokens by an address without MINTER_ROLE.
   * Expects the transaction to revert.
   */
  function testBurningWithNoPermission() public {
    uint256 initialBalance = bondToken.balanceOf(user2);

    vm.expectRevert();
    vm.startPrank(user2);
    bondToken.burn(user2, 50);
    vm.stopPrank();

    assertEq(bondToken.balanceOf(user2), initialBalance);
  }

  /**
   * @dev Tests increasing the indexed asset period by an address with GOV_ROLE.
   * Asserts that the globalPool's period and sharesPerToken are updated correctly.
   */
  function testIncreaseIndexedAssetPeriod() public {
    vm.startPrank(address(distributor));
    bondToken.increaseIndexedAssetPeriod(5000);
    vm.stopPrank();

    (uint256 currentPeriod, uint256 sharesPerToken) = bondToken.globalPool();

    assertEq(currentPeriod, 1);
    assertEq(sharesPerToken, 5000);
  }

  /**
   * @dev Tests increasing the indexed asset period by an address without GOV_ROLE.
   * Expects the transaction to revert.
   */
  function testIncreaseIndexedAssetPeriodWithNoPermission() public {
    vm.expectRevert();
    vm.startPrank(user2);
    bondToken.increaseIndexedAssetPeriod(5000);
    vm.stopPrank();
  }

  /**
   * @dev Tests getting the indexed user amount.
   */
  function testGetIndexedUserAmount() public {
    vm.startPrank(address(pool));
    uint256 initialBalance = 100 ether;
    bondToken.mint(user2, initialBalance);
    vm.stopPrank();

    doAuction();
    doAuction();

    (uint256 shares, uint256 lastIndexedPeriodBalance) = bondToken.getIndexedUserAmount(user2);
    assertEq(shares, initialBalance * SHARES_PER_TOKEN / 10 ** COUPON_DECIMALS);
    assertEq(lastIndexedPeriodBalance, initialBalance);
  }

  /**
   * @dev Tests token transfer within the same period without affecting indexed shares.
   * Asserts that the user's lastUpdatedPeriod and indexedAmountShares remain unchanged.
   */
  function testTransferSamePeriod() public {
    vm.startPrank(address(pool));
    bondToken.mint(user2, 1000);
    vm.stopPrank();

    (uint256 lastUpdatedPeriod, uint256 indexedAmountShares, uint256 lastIndexedPeriodBalance) =
      bondToken.userAssets(user2);
    assertEq(lastUpdatedPeriod, 0);
    assertEq(indexedAmountShares, 0);
    assertEq(lastIndexedPeriodBalance, 0);
    vm.startPrank(user2);
    bondToken.transfer(user2, 100);
    vm.stopPrank();

    (lastUpdatedPeriod, indexedAmountShares, lastIndexedPeriodBalance) = bondToken.userAssets(user2);
    assertEq(lastUpdatedPeriod, 0);
    assertEq(indexedAmountShares, 0);
    assertEq(lastIndexedPeriodBalance, 0);
  }

  function testTransferAfterPeriodIncrease() public {
    vm.startPrank(address(pool));
    uint256 initialBalance = 100 ether;
    bondToken.mint(user2, initialBalance);
    vm.stopPrank();

    doAuction();

    (uint256 lastUpdatedPeriod, uint256 indexedAmountShares, uint256 lastIndexedPeriodBalance) =
      bondToken.userAssets(user2);
    assertEq(lastUpdatedPeriod, 0);
    assertEq(indexedAmountShares, 0);
    assertEq(lastIndexedPeriodBalance, 0);

    (lastUpdatedPeriod, indexedAmountShares) = bondToken.globalPool();
    assertEq(lastUpdatedPeriod, 1);
    assertEq(indexedAmountShares, 2_500_000);

    vm.startPrank(user2);
    bondToken.transfer(user3, 10 ether);
    vm.stopPrank();

    // User2
    (lastUpdatedPeriod, indexedAmountShares, lastIndexedPeriodBalance) = bondToken.userAssets(user2);
    assertEq(lastUpdatedPeriod, 1);
    assertEq(indexedAmountShares, 0);
    assertEq(lastIndexedPeriodBalance, initialBalance);
    assertEq(bondToken.balanceOf(user2), 90 ether);

    // User3
    (lastUpdatedPeriod, indexedAmountShares, lastIndexedPeriodBalance) = bondToken.userAssets(user3);
    assertEq(lastUpdatedPeriod, 1);
    assertEq(indexedAmountShares, 0);
    assertEq(lastIndexedPeriodBalance, 0);
    assertEq(bondToken.balanceOf(user3), 10 ether);
  }

  /**
   * @dev Tests token transfer after an indexed asset period increase with both users receiving
   * shares.
   * Asserts the updates to both users' assets and global pool data.
   */
  function testTransferAfterPeriodIncreaseBothUsersPaid() public {
    vm.startPrank(address(pool));
    uint256 initialBalance1 = 100 ether;
    uint256 initialBalance2 = 200 ether;
    bondToken.mint(user2, initialBalance1);
    bondToken.mint(user3, initialBalance2);
    vm.stopPrank();

    doAuction();

    (uint256 lastUpdatedPeriod, uint256 indexedAmountShares, uint256 lastIndexedPeriodBalance) =
      bondToken.userAssets(user2);
    assertEq(lastUpdatedPeriod, 0);
    assertEq(indexedAmountShares, 0);
    assertEq(lastIndexedPeriodBalance, 0);

    (lastUpdatedPeriod, indexedAmountShares) = bondToken.globalPool();
    assertEq(lastUpdatedPeriod, 1);
    assertEq(indexedAmountShares, SHARES_PER_TOKEN);

    vm.startPrank(user2);
    bondToken.transfer(user3, 50 ether);
    vm.stopPrank();

    // User2
    (lastUpdatedPeriod, indexedAmountShares, lastIndexedPeriodBalance) = bondToken.userAssets(user2);
    assertEq(lastUpdatedPeriod, 1);
    assertEq(indexedAmountShares, 0);
    assertEq(lastIndexedPeriodBalance, initialBalance1);
    assertEq(bondToken.balanceOf(user2), 50 ether);

    // User3
    (lastUpdatedPeriod, indexedAmountShares, lastIndexedPeriodBalance) = bondToken.userAssets(user3);
    assertEq(lastUpdatedPeriod, 1);
    assertEq(indexedAmountShares, 0);
    assertEq(lastIndexedPeriodBalance, initialBalance2);
    assertEq(bondToken.balanceOf(user3), 250 ether);
  }

  function testSharesAccountingDuringBiddingAuctions() public {
    Pool.PoolInfo memory info = pool.getPoolInfo();
    vm.warp(info.lastDistribution + DISTRIBUTION_PERIOD + 1);
    pool.startAuction();

    vm.startPrank(user1);
    bondToken.transfer(user2, 10 ether); // indexed during bidding

    (uint256 shares, uint256 lastIndexedPeriodBalance) = bondToken.getIndexedUserAmount(user1, 10 ether, 1);
    assertEq(shares, 0);
    assertEq(lastIndexedPeriodBalance, INITIAL_BOND);

    (shares, lastIndexedPeriodBalance) = bondToken.getIndexedUserAmount(user2, 10 ether, 1);
    assertEq(shares, 0);
    assertEq(lastIndexedPeriodBalance, 0);
  }

  function testLastSharesUpdatedAfterSeveralPeriodsWithDifferentTransferPatterns() public {
    vm.startPrank(address(pool));
    uint256 initialBalance2 = 100 ether;
    uint256 initialBalance3 = 200 ether;
    uint256 initialBalance4 = 300 ether;
    bondToken.mint(user2, initialBalance2);
    bondToken.mint(user3, initialBalance3);
    bondToken.mint(user4, initialBalance4);
    vm.stopPrank();

    // All should have zero shares indexed
    (uint256 currentPeriod,) = bondToken.globalPool();
    (uint256 shares, uint256 lastIndexedPeriodBalance) =
      bondToken.getIndexedUserAmount(user2, initialBalance2, currentPeriod);
    assertEq(shares, 0);
    assertEq(lastIndexedPeriodBalance, 0);

    (shares, lastIndexedPeriodBalance) = bondToken.getIndexedUserAmount(user3, initialBalance3, currentPeriod);
    assertEq(shares, 0);
    assertEq(lastIndexedPeriodBalance, 0);

    (shares, lastIndexedPeriodBalance) = bondToken.getIndexedUserAmount(user4, initialBalance4, currentPeriod);
    assertEq(shares, 0);
    assertEq(lastIndexedPeriodBalance, 0);

    // Do 1 auction. All users should have balances indexed in lastIndexedPeriodBalance
    doAuction();
    (currentPeriod,) = bondToken.globalPool();
    (shares, lastIndexedPeriodBalance) = bondToken.getIndexedUserAmount(user2, initialBalance2, currentPeriod);
    assertEq(shares, 0);
    assertEq(lastIndexedPeriodBalance, initialBalance2);

    (shares, lastIndexedPeriodBalance) = bondToken.getIndexedUserAmount(user3, initialBalance3, currentPeriod);
    assertEq(shares, 0);
    assertEq(lastIndexedPeriodBalance, initialBalance3);

    (shares, lastIndexedPeriodBalance) = bondToken.getIndexedUserAmount(user4, initialBalance4, currentPeriod);
    assertEq(shares, 0);
    assertEq(lastIndexedPeriodBalance, initialBalance4);

    // Do 1 failed auction. lastIndexedPeriodBalance should from last round should move to 'shares',
    // and this round's lastIndexedPeriodBalance
    // should be zero due to the auction failing.
    doFailedAuction();
    (currentPeriod,) = bondToken.globalPool();
    (shares, lastIndexedPeriodBalance) = bondToken.getIndexedUserAmount(user2, initialBalance2, currentPeriod);
    assertEq(shares, initialBalance2 * SHARES_PER_TOKEN / 10 ** COUPON_DECIMALS);
    assertEq(lastIndexedPeriodBalance, initialBalance2);

    (shares, lastIndexedPeriodBalance) = bondToken.getIndexedUserAmount(user3, initialBalance3, currentPeriod);
    assertEq(shares, initialBalance3 * SHARES_PER_TOKEN / 10 ** COUPON_DECIMALS);
    assertEq(lastIndexedPeriodBalance, initialBalance3);

    (shares, lastIndexedPeriodBalance) = bondToken.getIndexedUserAmount(user4, initialBalance4, currentPeriod);
    assertEq(shares, initialBalance4 * SHARES_PER_TOKEN / 10 ** COUPON_DECIMALS);
    assertEq(lastIndexedPeriodBalance, initialBalance4);

    // Start an auction and check shares. Auction for period 2 is still active, but balance is still
    // indexed in lastIndexedPeriodBalance
    Pool.PoolInfo memory info = pool.getPoolInfo();
    vm.warp(info.lastDistribution + DISTRIBUTION_PERIOD + 1);
    pool.startAuction();
    (currentPeriod,) = bondToken.globalPool();

    (shares, lastIndexedPeriodBalance) = bondToken.getIndexedUserAmount(user2, initialBalance2, currentPeriod);
    assertEq(shares, initialBalance2 * SHARES_PER_TOKEN / 10 ** COUPON_DECIMALS);
    assertEq(lastIndexedPeriodBalance, initialBalance2);

    (shares, lastIndexedPeriodBalance) = bondToken.getIndexedUserAmount(user3, initialBalance3, currentPeriod);
    assertEq(shares, initialBalance3 * SHARES_PER_TOKEN / 10 ** COUPON_DECIMALS);
    assertEq(lastIndexedPeriodBalance, initialBalance3);

    (shares, lastIndexedPeriodBalance) = bondToken.getIndexedUserAmount(user4, initialBalance4, currentPeriod);
    assertEq(shares, initialBalance4 * SHARES_PER_TOKEN / 10 ** COUPON_DECIMALS);
    assertEq(lastIndexedPeriodBalance, initialBalance4);

    // User 2 transfers to user 3. Even though the auction is still active, shares for period 2 are
    // indexed as before
    vm.startPrank(user2);
    uint256 amountToTransfer = 50 ether;
    bondToken.transfer(user3, amountToTransfer);
    vm.stopPrank();

    (shares, lastIndexedPeriodBalance) =
      bondToken.getIndexedUserAmount(user2, bondToken.balanceOf(user2), currentPeriod);
    assertEq(shares, initialBalance2 * SHARES_PER_TOKEN / 10 ** COUPON_DECIMALS);
    assertEq(lastIndexedPeriodBalance, initialBalance2);

    (shares, lastIndexedPeriodBalance) =
      bondToken.getIndexedUserAmount(user3, bondToken.balanceOf(user3), currentPeriod);
    assertEq(shares, initialBalance3 * SHARES_PER_TOKEN / 10 ** COUPON_DECIMALS);
    assertEq(lastIndexedPeriodBalance, initialBalance3);

    (shares, lastIndexedPeriodBalance) =
      bondToken.getIndexedUserAmount(user4, bondToken.balanceOf(user4), currentPeriod);
    assertEq(shares, initialBalance4 * SHARES_PER_TOKEN / 10 ** COUPON_DECIMALS);
    assertEq(lastIndexedPeriodBalance, initialBalance4);

    // Conclude auction and check shares are still same as before (where transfers during auction
    // are not indexed for the
    // for the previous period)
    vm.startPrank(governance);
    Auction auction = Auction(pool.auctions(currentPeriod - 1));
    uint256 amount = auction.totalBuyCouponAmount();
    deal(address(couponToken), governance, amount);
    couponToken.transfer(user1, amount);
    vm.stopPrank();

    vm.startPrank(user1);
    couponToken.approve(address(auction), amount);
    auction.bid(1, amount);

    vm.warp(pool.lastAuctionStart() + AUCTION_PERIOD + 1);
    auction.endAuction();

    (shares, lastIndexedPeriodBalance) =
      bondToken.getIndexedUserAmount(user2, bondToken.balanceOf(user2), currentPeriod);
    assertEq(shares, initialBalance2 * SHARES_PER_TOKEN / 10 ** COUPON_DECIMALS);
    assertEq(lastIndexedPeriodBalance, initialBalance2);

    (shares, lastIndexedPeriodBalance) =
      bondToken.getIndexedUserAmount(user3, bondToken.balanceOf(user3), currentPeriod);
    assertEq(shares, initialBalance3 * SHARES_PER_TOKEN / 10 ** COUPON_DECIMALS);
    assertEq(lastIndexedPeriodBalance, initialBalance3);

    (shares, lastIndexedPeriodBalance) =
      bondToken.getIndexedUserAmount(user4, bondToken.balanceOf(user4), currentPeriod);
    assertEq(shares, initialBalance4 * SHARES_PER_TOKEN / 10 ** COUPON_DECIMALS);
    assertEq(lastIndexedPeriodBalance, initialBalance4);

    // Start another auction, and check shares amount has updated to include 2 successful periods
    // (and a failed period), with the 4th auction
    // accounted for in lastIndexedPeriodBalance. For period=3, amount stored in
    // lastIndexedPeriodBalance will reflect the token transfer from
    // user2 to user3.
    info = pool.getPoolInfo();
    vm.warp(info.lastDistribution + DISTRIBUTION_PERIOD + 1);
    pool.startAuction();
    (currentPeriod,) = bondToken.globalPool();

    uint256 expectedShares2 = (initialBalance2 * SHARES_PER_TOKEN / 10 ** COUPON_DECIMALS) * 2; // 2
      // successful periods
    uint256 expectedLastIndexedPeriodBalance2 = bondToken.balanceOf(user2);
    (shares, lastIndexedPeriodBalance) =
      bondToken.getIndexedUserAmount(user2, bondToken.balanceOf(user2), currentPeriod);
    assertEq(shares, expectedShares2);
    assertEq(lastIndexedPeriodBalance, expectedLastIndexedPeriodBalance2);

    uint256 expectedShares3 = (initialBalance3 * SHARES_PER_TOKEN / 10 ** COUPON_DECIMALS) * 2; // 2
      // successful periods
    uint256 expectedLastIndexedPeriodBalance3 = bondToken.balanceOf(user3);
    (shares, lastIndexedPeriodBalance) =
      bondToken.getIndexedUserAmount(user3, bondToken.balanceOf(user3), currentPeriod);
    assertEq(shares, expectedShares3);
    assertEq(lastIndexedPeriodBalance, expectedLastIndexedPeriodBalance3);

    uint256 expectedShares4 = (initialBalance4 * SHARES_PER_TOKEN / 10 ** COUPON_DECIMALS) * 2; // 2
      // successful periods
    uint256 expectedLastIndexedPeriodBalance4 = bondToken.balanceOf(user4);
    (shares, lastIndexedPeriodBalance) =
      bondToken.getIndexedUserAmount(user4, bondToken.balanceOf(user4), currentPeriod);
    assertEq(shares, expectedShares4);
    assertEq(lastIndexedPeriodBalance, expectedLastIndexedPeriodBalance4);

    // Fail the auction this time, and check that expectedShares and lastIndexedPeriodBalance are the same
    vm.startPrank(governance);
    auction = Auction(pool.auctions(currentPeriod - 1));
    amount = auction.totalBuyCouponAmount();
    deal(address(couponToken), governance, amount);
    couponToken.transfer(user1, amount);
    vm.stopPrank();

    vm.startPrank(user1);
    couponToken.approve(address(auction), amount);
    auction.bid(1, amount / 2); // Bid half to fail auction

    vm.warp(pool.lastAuctionStart() + AUCTION_PERIOD + 1);
    auction.endAuction();

    (shares, lastIndexedPeriodBalance) =
      bondToken.getIndexedUserAmount(user2, bondToken.balanceOf(user2), currentPeriod);
    assertEq(shares, expectedShares2);
    assertEq(lastIndexedPeriodBalance, expectedLastIndexedPeriodBalance2);

    (shares, lastIndexedPeriodBalance) =
      bondToken.getIndexedUserAmount(user3, bondToken.balanceOf(user3), currentPeriod);
    assertEq(shares, expectedShares3);
    assertEq(lastIndexedPeriodBalance, expectedLastIndexedPeriodBalance3);

    (shares, lastIndexedPeriodBalance) =
      bondToken.getIndexedUserAmount(user4, bondToken.balanceOf(user4), currentPeriod);
    assertEq(shares, expectedShares4);
    assertEq(lastIndexedPeriodBalance, expectedLastIndexedPeriodBalance4);

    // Check that user4's storage mapping of userAssets is still zero, since they haven't done any
    // transfers
    // The previous checks ensure that accounting is still done properly
    (uint256 lastUpdatedPeriodStorage, uint256 indexedAmountSharesStorage, uint256 lastIndexedPeriodBalanceStorage) =
      bondToken.userAssets(user4);
    assertEq(lastUpdatedPeriodStorage, 0);
    assertEq(indexedAmountSharesStorage, 0);
    assertEq(lastIndexedPeriodBalanceStorage, 0);

    // Do a transfer from user4 and check that shares are updated correctly in storage
    vm.startPrank(user4);
    bondToken.transfer(user2, 10 ether); // Random amount
    vm.stopPrank();

    (currentPeriod,) = bondToken.globalPool();
    (shares, lastIndexedPeriodBalance) =
      bondToken.getIndexedUserAmount(user4, bondToken.balanceOf(user4), currentPeriod);
    (lastUpdatedPeriodStorage, indexedAmountSharesStorage, lastIndexedPeriodBalanceStorage) =
      bondToken.userAssets(user4);
    assertEq(shares, indexedAmountSharesStorage);
    assertEq(lastIndexedPeriodBalance, lastIndexedPeriodBalanceStorage);
    assertEq(lastUpdatedPeriodStorage, currentPeriod);
  }

  function testResetIndexedUserAssetsUnauthorized() public {
    vm.expectRevert();
    bondToken.resetIndexedUserAssets(user2, true);
  }
}
