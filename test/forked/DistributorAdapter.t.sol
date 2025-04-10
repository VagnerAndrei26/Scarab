// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {TestSetup, Pool, PoolFactory, Auction, DistributorAdapter, Token} from "./TestSetup.sol";

contract DistributorTest is Test, TestSetup {
  address integratingContract1 = address(0xAAAA);
  address integratingContract2 = address(0xBBBB);
  uint256 integratingContract1Amount = 10 ether;
  uint256 integratingContract2Amount = 15 ether;

  string ipfsHash = "ipfsHash";

  function setUp() public override {
    super.setUp();
    createPool();

    // User 1 starts with all bond tokens. Send some to integratingContracts
    vm.startPrank(user1);
    bondToken.transfer(integratingContract1, integratingContract1Amount);
    bondToken.transfer(integratingContract2, integratingContract2Amount);

    vm.startPrank(governance);
    distributorAdapter.addIntegratingContract(integratingContract1);
    distributorAdapter.addIntegratingContract(integratingContract2);
    _startAuction();
  }

  function testDistributeSendsCorrectCouponAmountToAdapter() public {
    _endAuction();
    pool.distribute();
    Auction auction = Auction(pool.auctions(0));
    uint256 totalBuyCouponAmount = auction.totalBuyCouponAmount();
    uint256 expectedCouponAmount = (integratingContract1Amount + integratingContract2Amount) * SHARES_PER_TOKEN / 1e18;
    assertEq(couponToken.balanceOf(address(distributor)), totalBuyCouponAmount - expectedCouponAmount);
    assertEq(couponToken.balanceOf(address(distributorAdapter)), expectedCouponAmount);
  }

  function testClaims() public {
    // Create 4 leaves
    bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(user1, uint256(2 * 1e6)))));
    bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(user2, uint256(3 * 1e6)))));
    bytes32 leaf3 = keccak256(bytes.concat(keccak256(abi.encode(user3, uint256(4 * 1e6)))));
    bytes32 leaf4 = keccak256(bytes.concat(keccak256(abi.encode(user4, uint256(5 * 1e6)))));

    // Hash pairs of leaves to get intermediate nodes
    bytes32 node1 = leaf1 < leaf2 ? keccak256(abi.encode(leaf1, leaf2)) : keccak256(abi.encode(leaf2, leaf1));
    bytes32 node2 = leaf3 < leaf4 ? keccak256(abi.encode(leaf3, leaf4)) : keccak256(abi.encode(leaf4, leaf3));
    // Hash the intermediate nodes to get root
    bytes32 root = node1 < node2 ? keccak256(abi.encode(node1, node2)) : keccak256(abi.encode(node2, node1));

    // Create proof for leaf1 (will need leaf2 and node2)
    bytes32[] memory proof = new bytes32[](2);
    proof[0] = leaf2; // Sibling at leaf level
    proof[1] = node2; // Sibling at intermediate level

    _startAuction();

    vm.startPrank(user1);
    distributorAdapter.submitMerkleRoot(root, ipfsHash);
    vm.stopPrank();

    // Select root as governance
    vm.startPrank(governance);
    distributorAdapter.selectMerkleRoot(0);
    vm.stopPrank();

    _endAuction();
    pool.distribute();

    uint256 claimPeriod = 1;

    // Claim as user
    vm.startPrank(user1);
    distributorAdapter.claim(claimPeriod, 2 * 1e6, proof);

    // Verify claim
    assertEq(couponToken.balanceOf(user1), 2 * 1e6);
    assertTrue(distributorAdapter.hasClaimed(user1, claimPeriod));

    // Claim as user4
    vm.startPrank(user4);
    proof[0] = leaf3;
    proof[1] = node1;
    distributorAdapter.claim(claimPeriod, 5 * 1e6, proof);
    assertEq(couponToken.balanceOf(user4), 5 * 1e6);
    assertTrue(distributorAdapter.hasClaimed(user4, claimPeriod));

    // Can't claim again
    vm.expectRevert(DistributorAdapter.AlreadyClaimed.selector);
    distributorAdapter.claim(claimPeriod, 5 * 1e6, proof);
    vm.stopPrank();
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
