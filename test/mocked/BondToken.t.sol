// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../../src/BondToken.sol";
import {Utils} from "../../src/lib/Utils.sol";
import {PoolFactory} from "../../src/PoolFactory.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract BondTokenTest is Test {
  BondToken private token;
  ERC1967Proxy private proxy;
  address private deployer = address(0x1);
  address private minter = address(0x2);
  address private governance = address(0x3);
  address private user = address(0x4);
  address private user2 = address(0x5);
  address private distributor = address(0x6);
  address private securityCouncil = address(0x7);
  address private mockPool = address(0x8);
  address private mockAuction = address(0x9);
  PoolFactory private poolFactory;
  /**
   * @dev Sets up the testing environment.
   * Deploys the BondToken contract and a proxy, then initializes them.
   * Grants the minter and governance roles and mints initial tokens.
   */

  function setUp() public {
    vm.startPrank(governance);
    poolFactory = PoolFactory(
      Utils.deploy(
        address(new PoolFactory()),
        abi.encodeCall(
          PoolFactory.initialize, (governance, address(0), address(0), address(0), address(0), address(0), address(0))
        )
      )
    );

    poolFactory.grantRole(poolFactory.SECURITY_COUNCIL_ROLE(), securityCouncil);
    vm.stopPrank();

    vm.startPrank(deployer);
    // Deploy and initialize BondToken
    BondToken implementation = new BondToken();

    // Deploy the proxy and initialize the contract through the proxy
    proxy = new ERC1967Proxy(
      address(implementation),
      abi.encodeCall(
        implementation.initialize, ("BondToken", "BOND", minter, governance, address(poolFactory), 50 * 10 ** 18)
      )
    );

    // Attach the BondToken interface to the deployed proxy
    token = BondToken(address(proxy));
    vm.stopPrank();

    // Mint some initial tokens to the minter for testing
    vm.startPrank(minter);
    token.mint(minter, 1000);
    vm.stopPrank();

    // Increase the indexed asset period for testing
    vm.startPrank(governance);
    token.grantRole(token.DISTRIBUTOR_ROLE(), governance);
    token.grantRole(token.DISTRIBUTOR_ROLE(), distributor);
    token.increaseIndexedAssetPeriod(20_000);
    vm.stopPrank();

    _mockSuccessfulAuctionState(0);
  }

  function testPause() public {
    // makes sure it starts false
    assertEq(token.paused(), false);

    // makes sure minting works if not paused
    vm.startPrank(minter);
    token.mint(user, 1000);

    // pause contract
    vm.startPrank(securityCouncil);
    token.pause();

    // check it reverts on minting
    vm.startPrank(minter);
    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    token.mint(user, 1);

    // check it reverts on burning
    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    token.burn(user, 1);

    // check it reverts on transfer
    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    token.transfer(user, 1);

    // @todo: remove when distributor is merged
    vm.startPrank(governance);
    token.grantRole(keccak256("DISTRIBUTOR_ROLE"), minter);
    vm.startPrank(minter);

    // check it reverts on reseting indexed user assets
    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    token.resetIndexedUserAssets(user, true);

    // check it reverts on increasing period
    vm.startPrank(governance);
    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    token.increaseIndexedAssetPeriod(0);

    // @todo: check if contract is still upgradable on pause
    // token._authorizeUpgrade(address(0));

    // unpause contract
    vm.startPrank(securityCouncil);
    token.unpause();

    // make sure you can now do stuff
    vm.startPrank(user);
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
    token.mint(user, mintAmount);
    vm.stopPrank();

    assertEq(token.balanceOf(user), mintAmount);
    assertEq(token.balanceOf(minter), initialBalance);
  }

  /**
   * @dev Tests minting of tokens by an address without MINTER_ROLE.
   * Expects the transaction to revert.
   */
  function testMintingWithNoPermission() public {
    uint256 initialBalance = token.balanceOf(user);

    vm.expectRevert();
    vm.startPrank(user);
    token.mint(user, 100);
    vm.stopPrank();

    assertEq(token.balanceOf(user), initialBalance);
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
    uint256 initialBalance = token.balanceOf(user);

    vm.expectRevert();
    vm.startPrank(user);
    token.burn(user, 50);
    vm.stopPrank();

    assertEq(token.balanceOf(user), initialBalance);
  }

  /**
   * @dev Tests increasing the indexed asset period by an address with GOV_ROLE.
   * Asserts that the globalPool's period and sharesPerToken are updated correctly.
   */
  function testIncreaseIndexedAssetPeriod() public {
    vm.startPrank(governance);
    token.increaseIndexedAssetPeriod(5000);
    vm.stopPrank();

    (uint256 currentPeriod, uint256 sharesPerToken) = token.globalPool();

    assertEq(currentPeriod, 2);
    assertEq(sharesPerToken, 5000);
  }

  /**
   * @dev Tests increasing the indexed asset period by an address without GOV_ROLE.
   * Expects the transaction to revert.
   */
  function testIncreaseIndexedAssetPeriodWithNoPermission() public {
    vm.expectRevert();
    vm.startPrank(user);
    token.increaseIndexedAssetPeriod(5000);
    vm.stopPrank();
  }

  /**
   * @dev Tests token transfer within the same period without affecting indexed shares.
   * Asserts that the user's lastUpdatedPeriod and indexedAmountShares remain unchanged.
   */
  function testTransferSamePeriod() public {
    vm.startPrank(minter);
    token.mint(user, 1000);
    vm.stopPrank();

    (uint256 lastUpdatedPeriod, uint256 indexedAmountShares, uint256 lastIndexedPeriodShares) = token.userAssets(user);
    assertEq(lastUpdatedPeriod, 1);
    assertEq(indexedAmountShares, 0);
    assertEq(lastIndexedPeriodShares, 0);

    vm.startPrank(user);
    token.transfer(user2, 100);
    vm.stopPrank();

    (lastUpdatedPeriod, indexedAmountShares, lastIndexedPeriodShares) = token.userAssets(user);
    assertEq(lastUpdatedPeriod, 1);
    assertEq(indexedAmountShares, 0);
    assertEq(lastIndexedPeriodShares, 0);
  }

  /**
   * @dev Tests token transfer after an indexed asset period increase.
   * Asserts the updates to user assets and global pool data.
   */
  function testTransferAfterPeriodIncrease() public {
    vm.startPrank(minter);
    token.mint(user, 1_000_000);
    vm.stopPrank();

    vm.startPrank(governance);
    token.increaseIndexedAssetPeriod(2_500_000);
    vm.stopPrank();
    _mockSuccessfulAuctionState(1);

    (uint256 lastUpdatedPeriod, uint256 indexedAmountShares, uint256 lastIndexedPeriodBalance) = token.userAssets(user);
    assertEq(lastUpdatedPeriod, 1);
    assertEq(indexedAmountShares, 0);
    assertEq(lastIndexedPeriodBalance, 0);

    (lastUpdatedPeriod, indexedAmountShares) = token.globalPool();
    assertEq(lastUpdatedPeriod, 2);
    assertEq(indexedAmountShares, 2_500_000);

    vm.startPrank(user);
    token.transfer(user2, 100_000);
    vm.stopPrank();

    // User1
    (lastUpdatedPeriod, indexedAmountShares, lastIndexedPeriodBalance) = token.userAssets(user);
    assertEq(lastUpdatedPeriod, 2);
    assertEq(indexedAmountShares, 0);
    assertEq(lastIndexedPeriodBalance, 1_000_000);
    assertEq(token.balanceOf(user), 900_000);

    // User2
    (lastUpdatedPeriod, indexedAmountShares, lastIndexedPeriodBalance) = token.userAssets(user2);
    assertEq(lastUpdatedPeriod, 2);
    assertEq(indexedAmountShares, 0);
    assertEq(lastIndexedPeriodBalance, 0);
    assertEq(token.balanceOf(user2), 100_000);
  }

  /**
   * @dev Tests token transfer after an indexed asset period increase with both users receiving
   * shares.
   * Asserts the updates to both users' assets and global pool data.
   */
  function testTransferAfterPeriodIncreaseBothUsersPaid() public {
    vm.startPrank(minter);
    token.mint(user, 1_000_000);
    token.mint(user2, 2_000_000);
    vm.stopPrank();

    vm.startPrank(governance);
    token.increaseIndexedAssetPeriod(2_500_000);
    vm.stopPrank();
    _mockSuccessfulAuctionState(1);

    (uint256 lastUpdatedPeriod, uint256 indexedAmountShares, uint256 lastIndexedPeriodBalance) = token.userAssets(user);
    assertEq(lastUpdatedPeriod, 1);
    assertEq(indexedAmountShares, 0);
    assertEq(lastIndexedPeriodBalance, 0);

    (lastUpdatedPeriod, indexedAmountShares) = token.globalPool();
    assertEq(lastUpdatedPeriod, 2);
    assertEq(indexedAmountShares, 2_500_000);

    vm.startPrank(user);
    token.transfer(user2, 100_000);
    vm.stopPrank();

    // User1
    (lastUpdatedPeriod, indexedAmountShares, lastIndexedPeriodBalance) = token.userAssets(user);
    assertEq(lastUpdatedPeriod, 2);
    assertEq(indexedAmountShares, 0);
    assertEq(lastIndexedPeriodBalance, 1_000_000);
    assertEq(token.balanceOf(user), 900_000);

    // User2
    (lastUpdatedPeriod, indexedAmountShares, lastIndexedPeriodBalance) = token.userAssets(user2);
    assertEq(lastUpdatedPeriod, 2);
    assertEq(indexedAmountShares, 0);
    assertEq(lastIndexedPeriodBalance, 2_000_000);
    assertEq(token.balanceOf(user2), 2_100_000);
  }

  function testResetIndexedUserAssetsUnauthorized() public {
    vm.expectRevert();
    token.resetIndexedUserAssets(user, true);
  }

  function testResetIndexedUserAssetsPeriodReset() public {
    vm.startPrank(governance);
    token.increaseIndexedAssetPeriod(200);
    _mockSuccessfulAuctionState(1);
    vm.stopPrank();

    vm.startPrank(distributor);
    token.resetIndexedUserAssets(user, true);
    vm.stopPrank();

    (uint256 lastUpdatedPeriod,,) = token.userAssets(user);
    assertEq(lastUpdatedPeriod, 2);
  }

  function testResetIndexedUserAssetsSharesReset() public {
    // Issue bond
    vm.startPrank(minter);
    token.mint(user, 1_000_000);

    // Update period
    vm.startPrank(governance);
    token.increaseIndexedAssetPeriod(2_500_000);
    vm.stopPrank();

    _mockSuccessfulAuctionState(1);

    // Transfer to another user to update the intermediate balance
    vm.startPrank(user);
    token.transfer(user2, 1_000_000);

    (uint256 lastUpdatedPeriod, uint256 shares, uint256 lastIndexedPeriodBalance) = token.userAssets(user);
    assertEq(shares, 0);
    assertEq(lastIndexedPeriodBalance, 1_000_000);

    // Execute reset
    vm.startPrank(distributor);
    token.resetIndexedUserAssets(user, true);

    (lastUpdatedPeriod, shares, lastIndexedPeriodBalance) = token.userAssets(user);
    assertEq(lastUpdatedPeriod, 2);
    assertEq(shares, 0);
    assertEq(lastIndexedPeriodBalance, 0);
  }

  function testSharesNotCountedDuringBiddingAuctions() public {
    // Issue bond
    vm.prank(minter);
    token.mint(user, 1 ether);

    // Update period
    vm.startPrank(governance);
    token.increaseIndexedAssetPeriod(2_500_000);
    vm.stopPrank();

    vm.mockCall(mockPool, abi.encodeWithSignature("auctions(uint256)", 1), abi.encode(mockAuction));

    vm.mockCall(mockAuction, abi.encodeWithSignature("state()"), abi.encode(Auction.State.BIDDING));

    (uint256 shares, uint256 lastIndexedPeriodShares) = token.getIndexedUserAmount(user, 1 ether, 1);
    assertEq(shares, 0);
    assertEq(lastIndexedPeriodShares, 0);
  }

  function _mockSuccessfulAuctionState(uint256 period) internal {
    vm.startPrank(address(poolFactory));

    token.setPool(mockPool);
    vm.mockCall(mockPool, abi.encodeWithSignature("auctions(uint256)", period), abi.encode(mockAuction));

    vm.mockCall(mockAuction, abi.encodeWithSignature("state()"), abi.encode(Auction.State.SUCCEEDED));

    vm.stopPrank();
  }
}
