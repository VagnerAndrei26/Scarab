// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import {TestCases} from "../data/TestCases.sol";

import {Validator} from "../../src/utils/Validator.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Decimals} from "../../src/lib/Decimals.sol";

import {
  TestSetup, Auction, Distributor, PreDeposit, PoolFactory, Pool, BondToken, LeverageToken
} from "./TestSetup.sol";
import {Token} from "../mocks/Token.sol";
import {OracleReader} from "../../src/OracleReader.sol";
import {IManagedPool} from "../../src/lib/balancer/IManagedPool.sol";

contract PoolTest is Test, TestSetup, TestCases {
  using Strings for uint256;
  using Decimals for uint256;

  function setUp() public override {
    super.setUp();
    pool = createPool();
  }

  function testGetCreateAmount() public {
    initializeTestCases();

    for (uint256 i = 0; i < calcTestCases.length; i++) {
      uint256 amount = pool.getCreateAmount(
        calcTestCases[i].assetType,
        calcTestCases[i].inAmount,
        calcTestCases[i].DebtAssets,
        calcTestCases[i].LeverageAssets,
        calcTestCases[i].TotalUnderlyingAssets,
        calcTestCases[i].ethPrice * CHAINLINK_DECIMAL_PRECISION,
        CHAINLINK_DECIMAL
      );
      assertEq(amount, calcTestCases[i].expectedCreate);
    }
  }

  function testGetCreateAmountZeroDebtSupply() public {
    vm.expectRevert(Pool.ZeroDebtSupply.selector);
    pool.getCreateAmount(Pool.TokenType.BOND, 10, 0, 100, 100, 3000, CHAINLINK_DECIMAL);
  }

  function testGetCreateAmountZeroLeverageSupply() public {
    vm.expectRevert(Pool.ZeroLeverageSupply.selector);
    pool.getCreateAmount(
      Pool.TokenType.LEVERAGE, 10, 100_000, 0, 10_000, 30_000_000 * CHAINLINK_DECIMAL_PRECISION, CHAINLINK_DECIMAL
    );
  }

  function testGetCreateAmountZeroLeverageSupplyCollatLower() public {
    vm.expectRevert(Pool.ZeroLeverageSupply.selector);
    // collateral level is 1/10000000, less than threshold
    pool.getCreateAmount(Pool.TokenType.LEVERAGE, 10, 100_000, 0, 1, 1, CHAINLINK_DECIMAL);
  }

  function testCreate() public {
    initializeTestCasesFixedEth();
    vm.startPrank(governance);

    _mockReservePrice(3000);

    for (uint256 i = 0; i < calcTestCases.length; i++) {
      if (calcTestCases[i].inAmount == 0) continue;

      // Mint reserve tokens
      deal(address(reserveToken), governance, calcTestCases[i].TotalUnderlyingAssets + calcTestCases[i].inAmount);
      reserveToken.approve(address(poolFactory), calcTestCases[i].TotalUnderlyingAssets);

      string memory salt = i.toString();

      // Create pool and approve deposit amount
      Pool _pool = Pool(
        poolFactory.createPool(
          params,
          calcTestCases[i].TotalUnderlyingAssets,
          calcTestCases[i].DebtAssets,
          calcTestCases[i].LeverageAssets,
          "",
          salt,
          "",
          "",
          false
        )
      );
      reserveToken.approve(address(_pool), calcTestCases[i].inAmount);

      uint256 startBondBalance = BondToken(_pool.bondToken()).balanceOf(governance);
      uint256 startLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);
      uint256 startReserveBalance = reserveToken.balanceOf(governance);

      vm.expectEmit(true, true, true, true);
      emit Pool.TokensCreated(
        governance, governance, calcTestCases[i].assetType, calcTestCases[i].inAmount, calcTestCases[i].expectedCreate
      );

      // Call create and assert minted tokens
      uint256 amount = _pool.create(calcTestCases[i].assetType, calcTestCases[i].inAmount, 0);
      assertEq(amount, calcTestCases[i].expectedCreate);

      uint256 endBondBalance = BondToken(_pool.bondToken()).balanceOf(governance);
      uint256 endLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);
      uint256 endReserveBalance = reserveToken.balanceOf(governance);
      assertEq(calcTestCases[i].inAmount, startReserveBalance - endReserveBalance);

      if (calcTestCases[i].assetType == Pool.TokenType.BOND) {
        assertEq(amount, endBondBalance - startBondBalance);
        assertEq(0, endLevBalance - startLevBalance);
      } else {
        assertEq(0, endBondBalance - startBondBalance);
        assertEq(amount, endLevBalance - startLevBalance);
      }
    }
  }

  function testCreateOnBehalfOf() public {
    vm.startPrank(governance);

    _mockReservePrice(3000);

    for (uint256 i = 0; i < calcTestCases.length; i++) {
      if (calcTestCases[i].inAmount == 0) continue;

      // Mint reserve tokens
      deal(address(reserveToken), governance, calcTestCases[i].TotalUnderlyingAssets + calcTestCases[i].inAmount);
      reserveToken.approve(address(poolFactory), calcTestCases[i].TotalUnderlyingAssets);

      // Create salt to create the pool at a different address
      string memory salt = i.toString();

      // Create pool and approve deposit amount
      Pool _pool = Pool(
        poolFactory.createPool(
          params,
          calcTestCases[i].TotalUnderlyingAssets,
          calcTestCases[i].DebtAssets,
          calcTestCases[i].LeverageAssets,
          "",
          salt,
          "",
          "",
          false
        )
      );
      reserveToken.approve(address(_pool), calcTestCases[i].inAmount);

      uint256 startBondBalance = BondToken(_pool.bondToken()).balanceOf(user2);
      uint256 startLevBalance = LeverageToken(_pool.lToken()).balanceOf(user2);
      uint256 startReserveBalance = reserveToken.balanceOf(governance);

      // Call create and assert minted tokens
      uint256 amount = _pool.create(calcTestCases[i].assetType, calcTestCases[i].inAmount, 0, block.timestamp, user2);
      assertEq(amount, calcTestCases[i].expectedCreate);

      uint256 endBondBalance = BondToken(_pool.bondToken()).balanceOf(user2);
      uint256 endLevBalance = LeverageToken(_pool.lToken()).balanceOf(user2);
      uint256 endReserveBalance = reserveToken.balanceOf(governance);
      assertEq(calcTestCases[i].inAmount, startReserveBalance - endReserveBalance);

      if (calcTestCases[i].assetType == Pool.TokenType.BOND) {
        assertEq(amount, endBondBalance - startBondBalance);
        assertEq(0, endLevBalance - startLevBalance);
      } else {
        assertEq(0, endBondBalance - startBondBalance);
        assertEq(amount, endLevBalance - startLevBalance);
      }
    }
  }

  function testCreateDeadlineExactSuccess() public {
    vm.startPrank(governance);

    // Mint reserve tokens
    deal(address(reserveToken), governance, 10_000_001_000);
    reserveToken.approve(address(poolFactory), 10_000_000_000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(poolFactory.createPool(params, 10_000_000_000, 10_000, 10_000, "", "", "", "", false));

    reserveToken.approve(address(_pool), 1000);

    // Call create and assert minted tokens
    _mockReservePrice(3000);
    uint256 amount = _pool.create(Pool.TokenType.BOND, 1000, 30_000, block.timestamp, governance);
    assertEq(amount, 30_000);
  }

  function testCreateDeadlineSuccess() public {
    vm.startPrank(governance);

    // Mint reserve tokens
    deal(address(reserveToken), governance, 10_000_001_000);
    reserveToken.approve(address(poolFactory), 10_000_000_000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(poolFactory.createPool(params, 10_000_000_000, 10_000, 10_000, "", "", "", "", false));

    reserveToken.approve(address(_pool), 1000);

    // Call create and assert minted tokens
    _mockReservePrice(3000);
    uint256 amount = _pool.create(Pool.TokenType.BOND, 1000, 30_000, block.timestamp + 10_000, governance);
    assertEq(amount, 30_000);
  }

  function testCreateDeadlineRevert() public {
    vm.startPrank(governance);

    // Mint reserve tokens
    deal(address(reserveToken), governance, 10_000_001_000);
    reserveToken.approve(address(poolFactory), 10_000_000_000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(poolFactory.createPool(params, 10_000_000_000, 10_000, 10_000, "", "", "", "", false));

    reserveToken.approve(address(_pool), 1000);

    // Call create and assert minted tokens
    vm.expectRevert(Validator.TransactionTooOld.selector);
    _pool.create(Pool.TokenType.BOND, 1000, 30_000, block.timestamp - 1, governance);
  }

  function testCreateDeadlineSimulateBlockAdvanceRevert() public {
    vm.startPrank(governance);

    // Mint reserve tokens
    deal(address(reserveToken), governance, 10_000_001_000);
    reserveToken.approve(address(poolFactory), 10_000_000_000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(poolFactory.createPool(params, 10_000_000_000, 10_000, 10_000, "", "", "", "", false));

    // Simulate block advanced
    uint256 deadline = block.timestamp + 100;
    vm.warp(deadline + 100);

    reserveToken.approve(address(_pool), 1000);

    // Call create and assert minted tokens
    vm.expectRevert(Validator.TransactionTooOld.selector);
    _pool.create(Pool.TokenType.BOND, 1000, 30_000, deadline, governance);
  }

  function testCreateMinAmountExactSuccess() public {
    vm.startPrank(governance);

    // Mint reserve tokens
    deal(address(reserveToken), governance, 10_000_001_000);
    reserveToken.approve(address(poolFactory), 10_000_000_000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(poolFactory.createPool(params, 10_000_000_000, 10_000, 10_000, "", "", "", "", false));
    reserveToken.approve(address(_pool), 1000);

    // Call create and assert minted tokens
    _mockReservePrice(3000);
    uint256 amount = _pool.create(Pool.TokenType.BOND, 1000, 30_000);
    assertEq(amount, 30_000);
  }

  function testCreateMinAmountError() public {
    vm.startPrank(governance);

    // Mint reserve tokens
    deal(address(reserveToken), governance, 10_000_001_000);
    reserveToken.approve(address(poolFactory), 10_000_000_000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(poolFactory.createPool(params, 10_000_000_000, 10_000, 10_000, "", "", "", "", false));
    reserveToken.approve(address(_pool), 1000);

    // Call create and expect error
    vm.expectRevert(Pool.MinAmount.selector);
    _pool.create(Pool.TokenType.BOND, 1000, 30_001);
  }

  function testGetRedeemAmount() public {
    initializeTestCases();

    for (uint256 i = 0; i < calcTestCases.length; i++) {
      uint256 amount = pool.getRedeemAmount(
        calcTestCases[i].assetType,
        calcTestCases[i].inAmount,
        calcTestCases[i].DebtAssets,
        calcTestCases[i].LeverageAssets,
        calcTestCases[i].TotalUnderlyingAssets,
        calcTestCases[i].ethPrice * CHAINLINK_DECIMAL_PRECISION,
        CHAINLINK_DECIMAL,
        0
      );
      assertEq(amount, calcTestCases[i].expectedRedeem);
    }
  }

  function testRedeem() public {
    initializeTestCasesFixedEth();

    _mockReservePrice(3000);

    vm.startPrank(governance);

    for (uint256 i = 0; i < calcTestCases.length; i++) {
      if (calcTestCases[i].inAmount == 0) continue;

      // Mint reserve tokens
      deal(address(reserveToken), governance, calcTestCases[i].TotalUnderlyingAssets);
      reserveToken.approve(address(poolFactory), calcTestCases[i].TotalUnderlyingAssets);

      // Create salt to create the pool at a different address
      string memory salt = i.toString();

      // Create pool and approve deposit amount
      Pool _pool = Pool(
        poolFactory.createPool(
          params,
          calcTestCases[i].TotalUnderlyingAssets,
          calcTestCases[i].DebtAssets,
          calcTestCases[i].LeverageAssets,
          "",
          salt,
          "",
          "",
          false
        )
      );

      uint256 startBalance = reserveToken.balanceOf(governance);
      uint256 startBondBalance = BondToken(_pool.bondToken()).balanceOf(governance);
      uint256 startLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);

      vm.expectEmit(true, true, true, true);
      emit Pool.TokensRedeemed(
        governance, governance, calcTestCases[i].assetType, calcTestCases[i].inAmount, calcTestCases[i].expectedRedeem
      );

      // Call create and assert minted tokens
      uint256 amount = _pool.redeem(calcTestCases[i].assetType, calcTestCases[i].inAmount, 0);
      assertEq(amount, calcTestCases[i].expectedRedeem);

      uint256 endBalance = reserveToken.balanceOf(governance);
      uint256 endBondBalance = BondToken(_pool.bondToken()).balanceOf(governance);
      uint256 endLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);
      assertEq(amount, endBalance - startBalance);

      if (calcTestCases[i].assetType == Pool.TokenType.BOND) {
        assertEq(calcTestCases[i].inAmount, startBondBalance - endBondBalance);
        assertEq(0, endLevBalance - startLevBalance);
      } else {
        assertEq(0, endBondBalance - startBondBalance);
        assertEq(calcTestCases[i].inAmount, startLevBalance - endLevBalance);
      }
    }
  }

  function testRedeemOnBehalfOf() public {
    _mockReservePrice(3000);
    vm.startPrank(governance);

    for (uint256 i = 0; i < calcTestCases.length; i++) {
      if (calcTestCases[i].inAmount == 0) continue;

      // Mint reserve tokens
      deal(address(reserveToken), governance, calcTestCases[i].TotalUnderlyingAssets);
      reserveToken.approve(address(poolFactory), calcTestCases[i].TotalUnderlyingAssets);

      // Create salt to create the pool at a different address
      string memory salt = i.toString();

      // Create pool and approve deposit amount
      Pool _pool = Pool(
        poolFactory.createPool(
          params,
          calcTestCases[i].TotalUnderlyingAssets,
          calcTestCases[i].DebtAssets,
          calcTestCases[i].LeverageAssets,
          "",
          salt,
          "",
          "",
          false
        )
      );

      uint256 startBalance = reserveToken.balanceOf(user2);
      uint256 startBondBalance = BondToken(_pool.bondToken()).balanceOf(user2);
      uint256 startLevBalance = LeverageToken(_pool.lToken()).balanceOf(user2);

      // Call create and assert minted tokens
      uint256 amount = _pool.redeem(calcTestCases[i].assetType, calcTestCases[i].inAmount, 0, block.timestamp, user2);
      assertEq(amount, calcTestCases[i].expectedRedeem);

      uint256 endBalance = reserveToken.balanceOf(user2);
      uint256 endBondBalance = BondToken(_pool.bondToken()).balanceOf(user2);
      uint256 endLevBalance = LeverageToken(_pool.lToken()).balanceOf(user2);
      assertEq(amount, endBalance - startBalance);

      if (calcTestCases[i].assetType == Pool.TokenType.BOND) {
        assertEq(calcTestCases[i].inAmount, startBondBalance - endBondBalance);
        assertEq(0, endLevBalance - startLevBalance);
      } else {
        assertEq(0, endBondBalance - startBondBalance);
        assertEq(calcTestCases[i].inAmount, startLevBalance - endLevBalance);
      }
    }
  }

  function testRedeemMinAmountExactSuccess() public {
    vm.startPrank(governance);

    // Mint reserve tokens
    deal(address(reserveToken), governance, 10_000_001_000);
    reserveToken.approve(address(poolFactory), 10_000_000_000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(poolFactory.createPool(params, 10_000_000_000, 10_000, 10_000, "", "", "", "", false));
    reserveToken.approve(address(_pool), 1000);

    // Call create and assert minted tokens
    _mockReservePrice(3000);
    uint256 amount = _pool.redeem(Pool.TokenType.BOND, 1000, 33);
    assertEq(amount, 33);
  }

  function testRedeemMinAmountError() public {
    vm.startPrank(governance);

    // Mint reserve tokens
    deal(address(reserveToken), governance, 10_000_001_000);
    reserveToken.approve(address(poolFactory), 10_000_000_000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(poolFactory.createPool(params, 10_000_000_000, 10_000, 10_000, "", "", "", "", false));
    reserveToken.approve(address(_pool), 1000);

    // Call create and expect error
    vm.expectRevert(Pool.MinAmount.selector);
    _mockReservePrice(3000);
    _pool.redeem(Pool.TokenType.BOND, 1000, 34);
  }

  function testGetPoolInfo() public {
    vm.startPrank(governance);

    // Mint reserve tokens
    deal(address(reserveToken), governance, 10_000_000_000);
    reserveToken.approve(address(poolFactory), 10_000_000_000);

    // Create pool and approve deposit amount
    Pool _pool = Pool(poolFactory.createPool(params, 10_000_000_000, 10_000, 10_000, "", "", "", "", false));

    Pool.PoolInfo memory info = _pool.getPoolInfo();
    assertEq(info.reserve, 10_000_000_000);
    assertEq(info.bondSupply, 10_000);
    assertEq(info.levSupply, 10_000);
  }

  function testSetDistributionPeriod() public {
    vm.startPrank(governance);

    pool.setDistributionPeriod(100);

    Pool.PoolInfo memory info = pool.getPoolInfo();
    assertEq(info.distributionPeriod, 100);
  }

  function testSetDistributionPeriodErrorUnauthorized() public {
    vm.startPrank(user1);

    vm.expectRevert();
    pool.setDistributionPeriod(100);
  }

  function testSetFee() public {
    vm.startPrank(governance);

    pool.setFee(100);

    Pool.PoolInfo memory info = pool.getPoolInfo();
    assertEq(info.fee, 100);
  }

  function testSetFeeErrorUnauthorized() public {
    vm.startPrank(user1);

    vm.expectRevert(bytes4(keccak256("AccessDenied()")));
    pool.setFee(100);
  }

  function testPause() public {
    vm.startPrank(securityCouncil);
    pool.pause();

    vm.startPrank(governance);
    vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
    pool.create(Pool.TokenType.BOND, 0, 0);

    vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
    pool.redeem(Pool.TokenType.BOND, 0, 0);

    vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
    pool.startAuction();

    vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
    pool.distribute();

    vm.startPrank(securityCouncil);
    pool.unpause();

    vm.startPrank(governance);
    pool.setFee(100);

    Pool.PoolInfo memory info = pool.getPoolInfo();
    assertEq(info.fee, 100);
  }

  function testDistribute() public {
    Auction auction = Auction(doAuction());

    pool.distribute();

    address distributor = poolFactory.distributors(address(pool));

    assertEq(couponToken.balanceOf(address(distributor)), auction.totalBuyCouponAmount());
  }

  function testDistributeFailedPoolSaleLimit() public {
    vm.startPrank(user1);
    Pool.PoolInfo memory info = pool.getPoolInfo();
    vm.warp(info.lastDistribution + DISTRIBUTION_PERIOD + 1);

    pool.startAuction();
    (uint256 currentPeriod,) = bondToken.globalPool();
    Auction auction = Auction(pool.auctions(currentPeriod - 1));

    deal(address(couponToken), user1, auction.totalBuyCouponAmount());
    couponToken.approve(address(auction), auction.totalBuyCouponAmount());
    uint256 reserveAmount = reserveToken.balanceOf(address(pool));
    auction.bid(reserveAmount, auction.totalBuyCouponAmount());

    vm.warp(block.timestamp + AUCTION_PERIOD + 1 days);
    auction.endAuction();

    vm.expectEmit(true, true, true, true);
    emit Pool.DistributionRollOver(0, auction.totalBuyCouponAmount());
    pool.distribute();

    info = pool.getPoolInfo();
    assertEq(info.currentPeriod, 1);
    assertEq(couponToken.balanceOf(address(distributor)), 0);
    assert(auction.state() == Auction.State.FAILED_POOL_SALE_LIMIT);
  }

  function testDistributeFailedUndersold() public {
    vm.startPrank(user1);
    Pool.PoolInfo memory info = pool.getPoolInfo();
    vm.warp(info.lastDistribution + DISTRIBUTION_PERIOD + 1);

    pool.startAuction();
    (uint256 currentPeriod,) = bondToken.globalPool();
    Auction auction = Auction(pool.auctions(currentPeriod - 1));

    deal(address(couponToken), user1, auction.totalBuyCouponAmount());
    couponToken.approve(address(auction), auction.totalBuyCouponAmount());
    auction.bid(1, auction.slotSize());

    vm.warp(block.timestamp + AUCTION_PERIOD + 1 days);
    auction.endAuction();

    vm.expectEmit(true, true, true, true);
    emit Pool.DistributionRollOver(0, auction.totalBuyCouponAmount());
    pool.distribute();

    info = pool.getPoolInfo();
    assertEq(info.currentPeriod, 1);
    assertEq(couponToken.balanceOf(address(distributor)), 0);
    assert(auction.state() == Auction.State.FAILED_UNDERSOLD);
  }

  function testDistributeNoPeriodZero() public {
    vm.startPrank(governance);
    vm.expectRevert(bytes4(keccak256("AccessDenied()")));
    pool.distribute();
  }

  function testCreateRealistic() public {
    initializeRealisticTestCases();
    vm.startPrank(governance);

    for (uint256 i = 0; i < calcTestCases.length; i++) {
      if (calcTestCases[i].inAmount == 0) continue;

      // Mint reserve tokens
      deal(address(reserveToken), governance, calcTestCases[i].TotalUnderlyingAssets + calcTestCases[i].inAmount);
      reserveToken.approve(address(poolFactory), calcTestCases[i].TotalUnderlyingAssets);

      _mockReservePrice(calcTestCases[i].ethPrice / 10 ** 8); // remove decimals as its set in
        // _mockReservePrice

      // Create salt to create the pool at a different address
      string memory salt = i.toString();

      // Create pool and approve deposit amount
      Pool _pool = Pool(
        poolFactory.createPool(
          params,
          calcTestCases[i].TotalUnderlyingAssets,
          calcTestCases[i].DebtAssets,
          calcTestCases[i].LeverageAssets,
          "",
          salt,
          "",
          "",
          false
        )
      );
      reserveToken.approve(address(_pool), calcTestCases[i].inAmount);

      uint256 startBondBalance = BondToken(_pool.bondToken()).balanceOf(governance);
      uint256 startLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);
      uint256 startReserveBalance = reserveToken.balanceOf(governance);

      // Call create and assert minted tokens
      uint256 amount = _pool.create(calcTestCases[i].assetType, calcTestCases[i].inAmount, 0);
      assertEq(amount, calcTestCases[i].expectedCreate);

      uint256 endBondBalance = BondToken(_pool.bondToken()).balanceOf(governance);
      uint256 endLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);
      uint256 endReserveBalance = reserveToken.balanceOf(governance);
      assertEq(calcTestCases[i].inAmount, startReserveBalance - endReserveBalance);

      if (calcTestCases[i].assetType == Pool.TokenType.BOND) {
        assertEq(amount, endBondBalance - startBondBalance);
        assertEq(0, endLevBalance - startLevBalance);
      } else {
        assertEq(0, endBondBalance - startBondBalance);
        assertEq(amount, endLevBalance - startLevBalance);
      }
    }
  }

  function testRedeemRealistic() public {
    initializeRealisticTestCases();

    vm.startPrank(governance);

    for (uint256 i = 0; i < calcTestCases.length; i++) {
      if (calcTestCases[i].inAmount == 0) continue;

      // Mint reserve tokens
      deal(address(reserveToken), governance, calcTestCases[i].TotalUnderlyingAssets);
      reserveToken.approve(address(poolFactory), calcTestCases[i].TotalUnderlyingAssets);

      _mockReservePrice(calcTestCases[i].ethPrice / 10 ** 8); // remove decimals as its set in
        // _mockReservePrice

      // Create salt to create the pool at a different address
      string memory salt = i.toString();

      // Create pool and approve deposit amount
      Pool _pool = Pool(
        poolFactory.createPool(
          params,
          calcTestCases[i].TotalUnderlyingAssets,
          calcTestCases[i].DebtAssets,
          calcTestCases[i].LeverageAssets,
          "",
          salt,
          "",
          "",
          false
        )
      );

      uint256 startBalance = reserveToken.balanceOf(governance);
      uint256 startBondBalance = BondToken(_pool.bondToken()).balanceOf(governance);
      uint256 startLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);

      // Call create and assert minted tokens
      uint256 amount = _pool.redeem(calcTestCases[i].assetType, calcTestCases[i].inAmount, 0);
      assertEq(amount, calcTestCases[i].expectedRedeem);

      uint256 endBalance = reserveToken.balanceOf(governance);
      uint256 endBondBalance = BondToken(_pool.bondToken()).balanceOf(governance);
      uint256 endLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);
      assertEq(amount, endBalance - startBalance);

      if (calcTestCases[i].assetType == Pool.TokenType.BOND) {
        assertEq(calcTestCases[i].inAmount, startBondBalance - endBondBalance);
        assertEq(0, endLevBalance - startLevBalance);
      } else {
        assertEq(0, endBondBalance - startBondBalance);
        assertEq(calcTestCases[i].inAmount, startLevBalance - endLevBalance);
      }
    }
  }

  function testCreateTokensWithDifferentDecimals() public {
    vm.startPrank(deployer);
    PoolFactory.PoolParams memory _params;
    _params.fee = 0;
    _params.reserveToken = address(new Token("Wrapped ETH", "WETH", false));
    _params.sharesPerToken = 50 * 10 ** 18;
    _params.distributionPeriod = 0;
    _params.couponToken = address(new Token("USDC", "USDC", false));

    vm.stopPrank();
    vm.startPrank(governance);

    uint8 reserveDecimals = 6;
    Token(_params.reserveToken).setDecimals(reserveDecimals);

    initializeRealisticTestCases();

    Token rToken = Token(_params.reserveToken);

    for (uint256 i = 0; i < calcTestCases.length; i++) {
      if (calcTestCases[i].inAmount == 0) continue;

      // Mint reserve tokens
      rToken.mint(
        governance,
        calcTestCases[i].TotalUnderlyingAssets.normalizeAmount(18, reserveDecimals)
          + calcTestCases[i].inAmount.normalizeAmount(18, reserveDecimals)
      );
      rToken.approve(address(poolFactory), calcTestCases[i].TotalUnderlyingAssets.normalizeAmount(18, reserveDecimals));

      _mockReservePrice(calcTestCases[i].ethPrice / 10 ** 8); // remove decimals as its set in
        // _mockReservePrice
      oracleFeeds.setPriceFeed(_params.reserveToken, address(0), address(balancerOracleAdapter), 1 days);

      // Create salt to create the pool at a different address
      string memory salt = i.toString();

      // Create pool and approve deposit amount
      Pool _pool = Pool(
        poolFactory.createPool(
          _params,
          calcTestCases[i].TotalUnderlyingAssets.normalizeAmount(18, reserveDecimals),
          calcTestCases[i].DebtAssets,
          calcTestCases[i].LeverageAssets,
          "",
          salt,
          "",
          "",
          false
        )
      );
      rToken.approve(address(_pool), calcTestCases[i].inAmount.normalizeAmount(18, reserveDecimals));

      uint256 startBondBalance = BondToken(_pool.bondToken()).balanceOf(governance);
      uint256 startLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);
      uint256 startReserveBalance = rToken.balanceOf(governance);

      // Call create and assert minted tokens
      uint256 amount =
        _pool.create(calcTestCases[i].assetType, calcTestCases[i].inAmount.normalizeAmount(18, reserveDecimals), 0);
      assertEq(amount, calcTestCases[i].expectedCreate);

      uint256 endBondBalance = BondToken(_pool.bondToken()).balanceOf(governance);
      uint256 endLevBalance = LeverageToken(_pool.lToken()).balanceOf(governance);
      uint256 endReserveBalance = rToken.balanceOf(governance);
      assertEq(calcTestCases[i].inAmount.normalizeAmount(18, reserveDecimals), startReserveBalance - endReserveBalance);

      if (calcTestCases[i].assetType == Pool.TokenType.BOND) {
        assertEq(amount, endBondBalance - startBondBalance);
        assertEq(0, endLevBalance - startLevBalance);
      } else {
        assertEq(0, endBondBalance - startBondBalance);
        assertEq(amount, endLevBalance - startLevBalance);
      }

      // Reset reserve state
      rToken.burn(governance, rToken.balanceOf(governance));
      rToken.burn(address(_pool), rToken.balanceOf(address(_pool)));
    }
  }

  function testClaimFees() public {
    vm.startPrank(governance);

    address feeBeneficiary = user1;
    pool.setFeeBeneficiary(feeBeneficiary);
    pool.setFee(20_000);

    vm.warp(block.timestamp + 365 days);

    // Calculate expected fee
    uint256 expectedFee = (reserveToken.balanceOf(address(pool)) * 20_000) / 1_000_000; // 2% of
      // 1000 ether

    // Check initial balance of fee beneficiary
    uint256 initialBalance = reserveToken.balanceOf(feeBeneficiary);

    vm.stopPrank();

    // Claim fees
    vm.startPrank(feeBeneficiary);
    pool.claimFees();

    vm.stopPrank();

    // Check final balance of fee beneficiary
    uint256 finalBalance = reserveToken.balanceOf(feeBeneficiary);

    // Assert that the claimed fee is correct
    assertEq(finalBalance - initialBalance, expectedFee);
  }

  function testClaimFeesNothingToClaim() public {
    vm.startPrank(governance);

    address feeBeneficiary = user1;
    pool.setFeeBeneficiary(feeBeneficiary);
    pool.setFee(20_000);

    // Claim fees
    vm.startPrank(feeBeneficiary);
    vm.expectEmit(true, true, true, true, address(pool));
    emit Pool.NoFeesToClaim();
    pool.claimFees();
    vm.stopPrank();
  }

  function testCreateRedeemWithFees() public {
    vm.startPrank(governance);
    _mockReservePrice(3000);

    uint256 fee = 20_000;
    address feeBeneficiary = user1;
    pool.setFeeBeneficiary(feeBeneficiary);
    pool.setFee(fee);

    // User creates leverage tokens
    vm.startPrank(user2);

    uint256 depositAmount = 10 ether;
    deal(address(reserveToken), user2, depositAmount);
    reserveToken.approve(address(pool), depositAmount);
    uint256 levAmount = pool.create(Pool.TokenType.LEVERAGE, depositAmount, 0);
    // Advance time by 30 days
    vm.warp(block.timestamp + 30 days);
    _mockReservePrice(3000); // Mock again to prevent StalePrice

    // Calculate expected fee
    uint256 expectedFee = (depositAmount * fee * 30 days) / (1_000_000 * 365 days);

    // User redeems leverage tokens
    pool.bondToken().approve(address(pool), levAmount);
    uint256 redeemedAmount = pool.redeem(Pool.TokenType.LEVERAGE, levAmount, 0);

    // User should get back less than initial deposit due to fees
    assertLt(redeemedAmount, depositAmount);

    // Verify fee amount is correct
    uint256 expectedRedeemAmount = depositAmount - expectedFee;
    assertApproxEqRel(redeemedAmount, expectedRedeemAmount, 0.0005e18); // 0.05% tolerance

    vm.stopPrank();
  }

  function testCreateStaleOraclePrice() public {
    vm.startPrank(governance);
    _mockReservePrice(3000);
    vm.warp(block.timestamp + 10 days);

    // Expect revert due to stale oracle price
    vm.expectRevert(OracleReader.StalePrice.selector);
    pool.create(Pool.TokenType.BOND, 1000, 30_000, block.timestamp, governance);
  }

  function testOracleInvertedPrice() public view {
    uint256 price = pool.getOraclePrice(address(reserveToken), pool.USD());
    uint256 invertedPrice = pool.getOraclePrice(pool.USD(), address(reserveToken));
    uint256 decimals = pool.getOracleDecimals(address(reserveToken), pool.USD());

    assertEq(invertedPrice, 10 ** decimals * 10 ** decimals / price);
  }

  function testCannotCreateSoonAfterAuctionStart() public {
    vm.startPrank(governance);

    pool.setAuctionPeriod(1 days);
    vm.stopPrank();

    vm.warp(block.timestamp + DISTRIBUTION_PERIOD + 1);
    pool.startAuction();

    vm.startPrank(user1);
    vm.expectRevert(Pool.AuctionRecentlyStarted.selector);
    pool.create(Pool.TokenType.BOND, 1000, 0);
    vm.stopPrank();
  }

  function testDoubleDistributionWithPeriodChange() public {
    uint256 userBalance = 1e18;
    deal(address(bondToken), user1, userBalance);
    vm.startPrank(user1);
    bondToken.transfer(user2, userBalance); // Do manual transfer for checkpointing
    uint256 amountPerDistribution = bondToken.totalSupply() * params.sharesPerToken / 10 ** bondToken.decimals();

    doAuction();
    pool.distribute();
    assertEq(couponToken.balanceOf(address(distributor)), amountPerDistribution);

    // second distribution
    doAuction();
    pool.distribute();
    vm.stopPrank();

    assertEq(couponToken.balanceOf(address(distributor)), amountPerDistribution * 2);

    // Claim coupon tokens by user
    vm.startPrank(user2);

    uint256 expectedClaimAmount = userBalance * 2 * params.sharesPerToken / 10 ** pool.bondToken().decimals();
    uint256 currentPeriod = 2;
    vm.expectEmit(true, true, true, true);
    emit Distributor.ClaimedShares(user2, currentPeriod, expectedClaimAmount);

    distributor.claim();
    assertEq(couponToken.balanceOf(user2), expectedClaimAmount);
    vm.stopPrank();
  }

  function testLevEthPriceAtLowCR() public {
    uint256 price = 1010;
    _mockReservePrice(price);
    console2.log("cr", _cr(price));
    console2.log("levEthPrice", _levEthPrice(price));

    vm.startPrank(user1);
    pool.redeem(Pool.TokenType.LEVERAGE, 1 ether, 0);

    for (uint256 i = 0; i < 10; i++) {
      console2.log("\ncr", _cr(price));
      console2.log("levEthPrice", _levEthPrice(price));
      uint256 redeemAmount = leverageToken.totalSupply() / 100;
      pool.redeem(Pool.TokenType.LEVERAGE, redeemAmount, 0);
    }
  }

  function _cr(uint256 price) internal view returns (uint256) {
    uint256 tvl = price * reserveToken.balanceOf(address(pool));
    uint256 cr = tvl * 1000 / (bondToken.totalSupply() * 100);
    return cr;
  }

  function _levEthPrice(uint256 price) internal view returns (uint256) {
    if (_cr(price) < 1200) {
      uint256 tvl = price * reserveToken.balanceOf(address(pool));
      return tvl * 200 / leverageToken.totalSupply();
    } else {
      uint256 tvl = price * reserveToken.balanceOf(address(pool));
      uint256 levEthPrice = (tvl - (bondToken.totalSupply() * 100)) * 1000 / leverageToken.totalSupply();
      return levEthPrice;
    }
  }

  function _mockReservePrice(uint256 price) public {
    vm.mockCall(
      address(balancerOracleAdapter),
      abi.encodeWithSelector(balancerOracleAdapter.latestRoundData.selector),
      abi.encode(0, price * CHAINLINK_DECIMAL_PRECISION, block.timestamp, block.timestamp, 0)
    );
  }
}
