// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Pool} from "../../src/Pool.sol";

contract TestCases {
  struct CalcTestCase {
    Pool.TokenType assetType;
    uint256 inAmount;
    uint256 ethPrice;
    uint256 TotalUnderlyingAssets;
    uint256 DebtAssets;
    uint256 LeverageAssets;
    uint256 expectedCreate;
    uint256 expectedRedeem;
    uint256 expectedSwap;
  }

  CalcTestCase[] public calcTestCases;

  function initializeTestCases() public {
    // Reset test cases
    delete calcTestCases;

    // Debt - Below Threshold
    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 1000,
        ethPrice: 3000,
        TotalUnderlyingAssets: 1_000_000_000,
        DebtAssets: 25_000_000_000,
        LeverageAssets: 1_000_000_000,
        expectedCreate: 31_250,
        expectedRedeem: 32,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 2000,
        ethPrice: 4000,
        TotalUnderlyingAssets: 1_000_000_000,
        DebtAssets: 25_000_000_000,
        LeverageAssets: 1_000_000_000,
        expectedCreate: 80_000,
        expectedRedeem: 50,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 1500,
        ethPrice: 2500,
        TotalUnderlyingAssets: 1_000_000_000,
        DebtAssets: 25_000_000_000,
        LeverageAssets: 1_000_000_000,
        expectedCreate: 46_875,
        expectedRedeem: 48,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 500,
        ethPrice: 3500,
        TotalUnderlyingAssets: 1_000_000_000,
        DebtAssets: 25_000_000_000,
        LeverageAssets: 1_000_000_000,
        expectedCreate: 17_500,
        expectedRedeem: 14,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 3000,
        ethPrice: 1500,
        TotalUnderlyingAssets: 1_000_000_000,
        DebtAssets: 25_000_000_000,
        LeverageAssets: 1_000_000_000,
        expectedCreate: 93_750,
        expectedRedeem: 96,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 750,
        ethPrice: 4500,
        TotalUnderlyingAssets: 1_000_000_000,
        DebtAssets: 25_000_000_000,
        LeverageAssets: 1_000_000_000,
        expectedCreate: 33_750,
        expectedRedeem: 16,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 1200,
        ethPrice: 5000,
        TotalUnderlyingAssets: 1_000_000_000,
        DebtAssets: 25_000_000_000,
        LeverageAssets: 1_000_000_000,
        expectedCreate: 60_000,
        expectedRedeem: 24,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 800,
        ethPrice: 2600,
        TotalUnderlyingAssets: 1_000_000_000,
        DebtAssets: 25_000_000_000,
        LeverageAssets: 1_000_000_000,
        expectedCreate: 25_000,
        expectedRedeem: 25,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 2200,
        ethPrice: 3300,
        TotalUnderlyingAssets: 1_000_000_000,
        DebtAssets: 25_000_000_000,
        LeverageAssets: 1_000_000_000,
        expectedCreate: 72_600,
        expectedRedeem: 66,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 3500,
        ethPrice: 4200,
        TotalUnderlyingAssets: 1_000_000_000,
        DebtAssets: 25_000_000_000,
        LeverageAssets: 1_000_000_000,
        expectedCreate: 147_000,
        expectedRedeem: 83,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 2900,
        ethPrice: 2700,
        TotalUnderlyingAssets: 1_000_000_000,
        DebtAssets: 25_000_000_000,
        LeverageAssets: 1_000_000_000,
        expectedCreate: 90_625,
        expectedRedeem: 92,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 1800,
        ethPrice: 3800,
        TotalUnderlyingAssets: 1_000_000_000,
        DebtAssets: 25_000_000_000,
        LeverageAssets: 1_000_000_000,
        expectedCreate: 68_400,
        expectedRedeem: 47,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 100,
        ethPrice: 8000,
        TotalUnderlyingAssets: 1_000_000_000,
        DebtAssets: 25_000_000_000,
        LeverageAssets: 1_000_000_000,
        expectedCreate: 8000,
        expectedRedeem: 1,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 600,
        ethPrice: 3200,
        TotalUnderlyingAssets: 1_000_000_000,
        DebtAssets: 25_000_000_000,
        LeverageAssets: 1_000_000_000,
        expectedCreate: 19_200,
        expectedRedeem: 18,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 1600,
        ethPrice: 2900,
        TotalUnderlyingAssets: 1_000_000_000,
        DebtAssets: 25_000_000_000,
        LeverageAssets: 1_000_000_000,
        expectedCreate: 50_000,
        expectedRedeem: 51,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 4500,
        ethPrice: 2500,
        TotalUnderlyingAssets: 1_000_000_000,
        DebtAssets: 25_000_000_000,
        LeverageAssets: 1_000_000_000,
        expectedCreate: 140_625,
        expectedRedeem: 144,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 300,
        ethPrice: 7000,
        TotalUnderlyingAssets: 1_000_000_000,
        DebtAssets: 25_000_000_000,
        LeverageAssets: 1_000_000_000,
        expectedCreate: 21_000,
        expectedRedeem: 4,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 5000,
        ethPrice: 1200,
        TotalUnderlyingAssets: 1_000_000_000,
        DebtAssets: 25_000_000_000,
        LeverageAssets: 1_000_000_000,
        expectedCreate: 156_250,
        expectedRedeem: 160,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 400,
        ethPrice: 6500,
        TotalUnderlyingAssets: 1_000_000_000,
        DebtAssets: 25_000_000_000,
        LeverageAssets: 1_000_000_000,
        expectedCreate: 26_000,
        expectedRedeem: 6,
        expectedSwap: 0
      })
    );

    // Debt - Above Threshold
    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 1000,
        ethPrice: 3000,
        TotalUnderlyingAssets: 1_200_456_789_222,
        DebtAssets: 25_123_456_789,
        LeverageAssets: 1_321_654_987,
        expectedCreate: 30_000,
        expectedRedeem: 33,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 2000,
        ethPrice: 4000,
        TotalUnderlyingAssets: 1_200_456_789_222,
        DebtAssets: 25_123_456_789,
        LeverageAssets: 1_321_654_987,
        expectedCreate: 80_000,
        expectedRedeem: 50,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 1500,
        ethPrice: 2500,
        TotalUnderlyingAssets: 1_200_456_789_222,
        DebtAssets: 25_123_456_789,
        LeverageAssets: 1_321_654_987,
        expectedCreate: 37_500,
        expectedRedeem: 60,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 500,
        ethPrice: 3500,
        TotalUnderlyingAssets: 1_200_456_789_222,
        DebtAssets: 25_123_456_789,
        LeverageAssets: 1_321_654_987,
        expectedCreate: 17_500,
        expectedRedeem: 14,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 3000,
        ethPrice: 1500,
        TotalUnderlyingAssets: 1_200_456_789_222,
        DebtAssets: 25_123_456_789,
        LeverageAssets: 1_321_654_987,
        expectedCreate: 45_000,
        expectedRedeem: 200,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 750,
        ethPrice: 4500,
        TotalUnderlyingAssets: 1_200_456_789_222,
        DebtAssets: 25_123_456_789,
        LeverageAssets: 1_321_654_987,
        expectedCreate: 33_750,
        expectedRedeem: 16,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 1200,
        ethPrice: 5000,
        TotalUnderlyingAssets: 1_200_456_789_222,
        DebtAssets: 25_123_456_789,
        LeverageAssets: 1_321_654_987,
        expectedCreate: 60_000,
        expectedRedeem: 24,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 800,
        ethPrice: 2600,
        TotalUnderlyingAssets: 1_200_456_789_222,
        DebtAssets: 25_123_456_789,
        LeverageAssets: 1_321_654_987,
        expectedCreate: 20_800,
        expectedRedeem: 30,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 2200,
        ethPrice: 3300,
        TotalUnderlyingAssets: 1_200_456_789_222,
        DebtAssets: 25_123_456_789,
        LeverageAssets: 1_321_654_987,
        expectedCreate: 72_600,
        expectedRedeem: 66,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 3500,
        ethPrice: 4200,
        TotalUnderlyingAssets: 1_200_456_789_222,
        DebtAssets: 25_123_456_789,
        LeverageAssets: 1_321_654_987,
        expectedCreate: 147_000,
        expectedRedeem: 83,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 2900,
        ethPrice: 2700,
        TotalUnderlyingAssets: 1_200_456_789_222,
        DebtAssets: 25_123_456_789,
        LeverageAssets: 1_321_654_987,
        expectedCreate: 78_300,
        expectedRedeem: 107,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 1800,
        ethPrice: 3800,
        TotalUnderlyingAssets: 1_200_456_789_222,
        DebtAssets: 25_123_456_789,
        LeverageAssets: 1_321_654_987,
        expectedCreate: 68_400,
        expectedRedeem: 47,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 100,
        ethPrice: 8000,
        TotalUnderlyingAssets: 1_200_456_789_222,
        DebtAssets: 25_123_456_789,
        LeverageAssets: 1_321_654_987,
        expectedCreate: 8000,
        expectedRedeem: 1,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 600,
        ethPrice: 3200,
        TotalUnderlyingAssets: 1_200_456_789_222,
        DebtAssets: 25_123_456_789,
        LeverageAssets: 1_321_654_987,
        expectedCreate: 19_200,
        expectedRedeem: 18,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 1600,
        ethPrice: 2900,
        TotalUnderlyingAssets: 1_200_456_789_222,
        DebtAssets: 25_123_456_789,
        LeverageAssets: 1_321_654_987,
        expectedCreate: 46_400,
        expectedRedeem: 55,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 4500,
        ethPrice: 2500,
        TotalUnderlyingAssets: 1_200_456_789_222,
        DebtAssets: 25_123_456_789,
        LeverageAssets: 1_321_654_987,
        expectedCreate: 112_500,
        expectedRedeem: 180,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 300,
        ethPrice: 7000,
        TotalUnderlyingAssets: 1_200_456_789_222,
        DebtAssets: 25_123_456_789,
        LeverageAssets: 1_321_654_987,
        expectedCreate: 21_000,
        expectedRedeem: 4,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 5000,
        ethPrice: 1200,
        TotalUnderlyingAssets: 1_200_456_789_222,
        DebtAssets: 25_123_456_789,
        LeverageAssets: 1_321_654_987,
        expectedCreate: 60_000,
        expectedRedeem: 416,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 400,
        ethPrice: 6500,
        TotalUnderlyingAssets: 1_200_456_789_222,
        DebtAssets: 25_123_456_789,
        LeverageAssets: 1_321_654_987,
        expectedCreate: 26_000,
        expectedRedeem: 6,
        expectedSwap: 0
      })
    );

    // Leverage - Below Threshold
    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1000,
        ethPrice: 3000,
        TotalUnderlyingAssets: 35_000,
        DebtAssets: 2_500_000,
        LeverageAssets: 1_320_000,
        expectedCreate: 188_571,
        expectedRedeem: 5,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 2000,
        ethPrice: 4000,
        TotalUnderlyingAssets: 45_000,
        DebtAssets: 2_800_000,
        LeverageAssets: 1_600_000,
        expectedCreate: 355_555,
        expectedRedeem: 11,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1500,
        ethPrice: 2500,
        TotalUnderlyingAssets: 50_000,
        DebtAssets: 3_200_000,
        LeverageAssets: 1_700_000,
        expectedCreate: 255_000,
        expectedRedeem: 8,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 500,
        ethPrice: 3500,
        TotalUnderlyingAssets: 32_000,
        DebtAssets: 2_100_000,
        LeverageAssets: 1_200_000,
        expectedCreate: 93_750,
        expectedRedeem: 2,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3000,
        ethPrice: 1500,
        TotalUnderlyingAssets: 68_000,
        DebtAssets: 3_500_000,
        LeverageAssets: 1_450_000,
        expectedCreate: 319_852,
        expectedRedeem: 28,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 750,
        ethPrice: 4500,
        TotalUnderlyingAssets: 42_000,
        DebtAssets: 2_700_000,
        LeverageAssets: 1_800_000,
        expectedCreate: 160_714,
        expectedRedeem: 3,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1200,
        ethPrice: 5000,
        TotalUnderlyingAssets: 30_000,
        DebtAssets: 2_900_000,
        LeverageAssets: 1_350_000,
        expectedCreate: 270_000,
        expectedRedeem: 5,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 800,
        ethPrice: 2600,
        TotalUnderlyingAssets: 40_000,
        DebtAssets: 3_100_000,
        LeverageAssets: 1_500_000,
        expectedCreate: 150_000,
        expectedRedeem: 4,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 2200,
        ethPrice: 3300,
        TotalUnderlyingAssets: 53_000,
        DebtAssets: 2_400_000,
        LeverageAssets: 1_250_000,
        expectedCreate: 259_433,
        expectedRedeem: 18,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3500,
        ethPrice: 4200,
        TotalUnderlyingAssets: 48_000,
        DebtAssets: 2_700_000,
        LeverageAssets: 1_650_000,
        expectedCreate: 601_562,
        expectedRedeem: 20,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 2900,
        ethPrice: 2700,
        TotalUnderlyingAssets: 45_000,
        DebtAssets: 2_900_000,
        LeverageAssets: 1_600_000,
        expectedCreate: 515_555,
        expectedRedeem: 16,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1800,
        ethPrice: 3800,
        TotalUnderlyingAssets: 42_000,
        DebtAssets: 3_300_000,
        LeverageAssets: 1_400_000,
        expectedCreate: 300_000,
        expectedRedeem: 10,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 100,
        ethPrice: 8000,
        TotalUnderlyingAssets: 37_000,
        DebtAssets: 3_500_000,
        LeverageAssets: 1_500_000,
        expectedCreate: 20_270,
        expectedRedeem: 0,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 600,
        ethPrice: 3200,
        TotalUnderlyingAssets: 30_000,
        DebtAssets: 2_200_000,
        LeverageAssets: 1_000_000,
        expectedCreate: 100_000,
        expectedRedeem: 3,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1600,
        ethPrice: 2900,
        TotalUnderlyingAssets: 34_000,
        DebtAssets: 3_100_000,
        LeverageAssets: 1_800_000,
        expectedCreate: 423_529,
        expectedRedeem: 6,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 4500,
        ethPrice: 2500,
        TotalUnderlyingAssets: 68_000,
        DebtAssets: 2_700_000,
        LeverageAssets: 1_200_000,
        expectedCreate: 397_058,
        expectedRedeem: 50,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 300,
        ethPrice: 7000,
        TotalUnderlyingAssets: 30_000,
        DebtAssets: 2_900_000,
        LeverageAssets: 1_700_000,
        expectedCreate: 85_000,
        expectedRedeem: 1,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 5000,
        ethPrice: 1200,
        TotalUnderlyingAssets: 58_000,
        DebtAssets: 2_600_000,
        LeverageAssets: 1_100_000,
        expectedCreate: 474_137,
        expectedRedeem: 52,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 400,
        ethPrice: 6500,
        TotalUnderlyingAssets: 33_000,
        DebtAssets: 2_300_000,
        LeverageAssets: 1_400_000,
        expectedCreate: 84_848,
        expectedRedeem: 1,
        expectedSwap: 0
      })
    );

    // Leverage - Above Threshold
    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1500,
        ethPrice: 3000,
        TotalUnderlyingAssets: 6_000_000,
        DebtAssets: 900_000,
        LeverageAssets: 1_400_000,
        expectedCreate: 351,
        expectedRedeem: 6396,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 2000,
        ethPrice: 4000,
        TotalUnderlyingAssets: 7_500_000,
        DebtAssets: 900_000,
        LeverageAssets: 1_600_000,
        expectedCreate: 427,
        expectedRedeem: 9346,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3000,
        ethPrice: 2500,
        TotalUnderlyingAssets: 8_000_000,
        DebtAssets: 950_000,
        LeverageAssets: 1_700_000,
        expectedCreate: 640,
        expectedRedeem: 14_050,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1000,
        ethPrice: 3500,
        TotalUnderlyingAssets: 9_000_000,
        DebtAssets: 1_200_000,
        LeverageAssets: 1_200_000,
        expectedCreate: 133, // @todo solidity 133 - go 134
        expectedRedeem: 7471,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 2500,
        ethPrice: 4500,
        TotalUnderlyingAssets: 9_500_000,
        DebtAssets: 1_300_000,
        LeverageAssets: 1_500_000,
        expectedCreate: 395, // @todo solidity 395 - go 396
        expectedRedeem: 15_785,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1200,
        ethPrice: 5000,
        TotalUnderlyingAssets: 10_000_000,
        DebtAssets: 1_250_000,
        LeverageAssets: 1_450_000,
        expectedCreate: 174,
        expectedRedeem: 8255,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1800,
        ethPrice: 5500,
        TotalUnderlyingAssets: 10_500_000,
        DebtAssets: 1_350_000,
        LeverageAssets: 1_550_000,
        expectedCreate: 266,
        expectedRedeem: 12_165,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1600,
        ethPrice: 2700,
        TotalUnderlyingAssets: 7_000_000,
        DebtAssets: 850_000,
        LeverageAssets: 1_300_000,
        expectedCreate: 298,
        expectedRedeem: 8576,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3000,
        ethPrice: 3400,
        TotalUnderlyingAssets: 8_000_000,
        DebtAssets: 950_000,
        LeverageAssets: 1_700_000,
        expectedCreate: 639,
        expectedRedeem: 14_068,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 5000,
        ethPrice: 150_000,
        TotalUnderlyingAssets: 5_000_000_000_000,
        DebtAssets: 3_000_000_000_000,
        LeverageAssets: 1_000_000_000_000,
        expectedCreate: 1000,
        expectedRedeem: 24_990,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1000,
        ethPrice: 2500,
        TotalUnderlyingAssets: 8_000_000,
        DebtAssets: 1_000_000,
        LeverageAssets: 1_800_000,
        expectedCreate: 226,
        expectedRedeem: 4422,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3200,
        ethPrice: 4800,
        TotalUnderlyingAssets: 750_000_000_000,
        DebtAssets: 300_000_000_000,
        LeverageAssets: 50_000_000_000,
        expectedCreate: 215,
        expectedRedeem: 47_600,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 7000,
        ethPrice: 6000,
        TotalUnderlyingAssets: 3_000_000,
        DebtAssets: 1_200_000,
        LeverageAssets: 2_000_000,
        expectedCreate: 4697,
        expectedRedeem: 10_430,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 8500,
        ethPrice: 5000,
        TotalUnderlyingAssets: 20_000_000_000,
        DebtAssets: 8_000_000_000,
        LeverageAssets: 3_000_000_000,
        expectedCreate: 1285,
        expectedRedeem: 56_213,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 2400,
        ethPrice: 7500,
        TotalUnderlyingAssets: 100_000_000_000,
        DebtAssets: 30_000_000_000,
        LeverageAssets: 5_000_000_000,
        expectedCreate: 120,
        expectedRedeem: 47_808,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 4000,
        ethPrice: 2200,
        TotalUnderlyingAssets: 100_000_000,
        DebtAssets: 25_000_000,
        LeverageAssets: 5_000_000,
        expectedCreate: 202,
        expectedRedeem: 79_090,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3700,
        ethPrice: 4500,
        TotalUnderlyingAssets: 1_500_000_000_000,
        DebtAssets: 400_000_000_000,
        LeverageAssets: 200_000_000_000,
        expectedCreate: 496,
        expectedRedeem: 27_585,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1500,
        ethPrice: 3000,
        TotalUnderlyingAssets: 2_500_000,
        DebtAssets: 1_000_000,
        LeverageAssets: 1_500_000,
        expectedCreate: 912,
        expectedRedeem: 2466,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 2900,
        ethPrice: 12_000,
        TotalUnderlyingAssets: 10_000_000_000_000,
        DebtAssets: 4_000_000_000_000,
        LeverageAssets: 2_000_000_000_000,
        expectedCreate: 581,
        expectedRedeem: 14_451,
        expectedSwap: 0
      })
    );

    // Random Values but Leverage Level = 1.2
    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 5000,
        ethPrice: 7200,
        TotalUnderlyingAssets: 2_880_000_000,
        DebtAssets: 172_800_000_000,
        LeverageAssets: 1_400_000_000,
        expectedCreate: 12_152,
        expectedRedeem: 2057,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 1000,
        ethPrice: 3600,
        TotalUnderlyingAssets: 7_200_000,
        DebtAssets: 216_000_000,
        LeverageAssets: 1_800_000,
        expectedCreate: 37_500,
        expectedRedeem: 26,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3200,
        ethPrice: 4800,
        TotalUnderlyingAssets: 960_000_000,
        DebtAssets: 38_400_000_000,
        LeverageAssets: 500_000_000,
        expectedCreate: 8333,
        expectedRedeem: 1228,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 7000,
        ethPrice: 1200,
        TotalUnderlyingAssets: 144_000_000,
        DebtAssets: 1_440_000_000,
        LeverageAssets: 2_000_000,
        expectedCreate: 87_500,
        expectedRedeem: 560,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 8500,
        ethPrice: 9000,
        TotalUnderlyingAssets: 5_400_000_000,
        DebtAssets: 405_000_000_000,
        LeverageAssets: 3_000_000_000,
        expectedCreate: 23_611,
        expectedRedeem: 3060,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 2400,
        ethPrice: 6000,
        TotalUnderlyingAssets: 360_000_000,
        DebtAssets: 18_000_000_000,
        LeverageAssets: 500_000_000,
        expectedCreate: 150_000,
        expectedRedeem: 38,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 4000,
        ethPrice: 1800,
        TotalUnderlyingAssets: 432_000_000,
        DebtAssets: 6_480_000_000,
        LeverageAssets: 5_000_000,
        expectedCreate: 231,
        expectedRedeem: 69_120,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 3700,
        ethPrice: 1500,
        TotalUnderlyingAssets: 54_000_000,
        DebtAssets: 675_000_000,
        LeverageAssets: 200_000_000,
        expectedCreate: 57_812,
        expectedRedeem: 236,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1500,
        ethPrice: 4800,
        TotalUnderlyingAssets: 720_000_000,
        DebtAssets: 28_800_000_000,
        LeverageAssets: 500_000_000,
        expectedCreate: 5208,
        expectedRedeem: 432,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 2900,
        ethPrice: 3000,
        TotalUnderlyingAssets: 900_000_000,
        DebtAssets: 22_500_000_000,
        LeverageAssets: 4_000_000,
        expectedCreate: 90_625,
        expectedRedeem: 92,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1200,
        ethPrice: 6000,
        TotalUnderlyingAssets: 1_800_000_000,
        DebtAssets: 90_000_000_000,
        LeverageAssets: 500_000_000,
        expectedCreate: 1666,
        expectedRedeem: 864,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 4500,
        ethPrice: 15_000,
        TotalUnderlyingAssets: 18_000_000_000,
        DebtAssets: 2_250_000_000_000,
        LeverageAssets: 1_500_000_000,
        expectedCreate: 703_125,
        expectedRedeem: 28,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 5200,
        ethPrice: 2400,
        TotalUnderlyingAssets: 288_000_000,
        DebtAssets: 5_760_000_000,
        LeverageAssets: 500_000_000,
        expectedCreate: 45_138,
        expectedRedeem: 599,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 3000,
        ethPrice: 9000,
        TotalUnderlyingAssets: 5_400_000_000,
        DebtAssets: 405_000_000_000,
        LeverageAssets: 250_000_000,
        expectedCreate: 281_250,
        expectedRedeem: 32,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 6000,
        ethPrice: 7200,
        TotalUnderlyingAssets: 4_320_000_000,
        DebtAssets: 259_200_000_000,
        LeverageAssets: 3_000_000_000,
        expectedCreate: 20_833,
        expectedRedeem: 1728,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 7000,
        ethPrice: 4800,
        TotalUnderlyingAssets: 1_440_000_000,
        DebtAssets: 57_600_000_000,
        LeverageAssets: 600_000_000,
        expectedCreate: 350_000,
        expectedRedeem: 140,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 8000,
        ethPrice: 1500,
        TotalUnderlyingAssets: 900_000_000,
        DebtAssets: 11_250_000_000,
        LeverageAssets: 300_000_000,
        expectedCreate: 13_333,
        expectedRedeem: 4800,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 2500,
        ethPrice: 1200,
        TotalUnderlyingAssets: 36_000_000,
        DebtAssets: 360_000_000,
        LeverageAssets: 300_000_000,
        expectedCreate: 31_250,
        expectedRedeem: 200,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3200,
        ethPrice: 3600,
        TotalUnderlyingAssets: 108_000_000,
        DebtAssets: 3_240_000_000,
        LeverageAssets: 5_000_000,
        expectedCreate: 740,
        expectedRedeem: 13_824,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 4700,
        ethPrice: 6000,
        TotalUnderlyingAssets: 720_000_000,
        DebtAssets: 43_200_000_000,
        LeverageAssets: 300_000_000,
        expectedCreate: 352_500,
        expectedRedeem: 62,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1500,
        ethPrice: 2400,
        TotalUnderlyingAssets: 288_000_000,
        DebtAssets: 5_760_000_000,
        LeverageAssets: 2_000_000,
        expectedCreate: 52,
        expectedRedeem: 43_200,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 5500,
        ethPrice: 15_000,
        TotalUnderlyingAssets: 18_000_000_000,
        DebtAssets: 2_250_000_000_000,
        LeverageAssets: 1_500_000_000,
        expectedCreate: 859_375,
        expectedRedeem: 35,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 2700,
        ethPrice: 7200,
        TotalUnderlyingAssets: 432_000_000,
        DebtAssets: 25_920_000_000,
        LeverageAssets: 100_000_000,
        expectedCreate: 3125,
        expectedRedeem: 2332,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 4200,
        ethPrice: 9000,
        TotalUnderlyingAssets: 5_400_000_000,
        DebtAssets: 405_000_000_000,
        LeverageAssets: 200_000_000,
        expectedCreate: 393_750,
        expectedRedeem: 44,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3200,
        ethPrice: 4800,
        TotalUnderlyingAssets: 720_000_000,
        DebtAssets: 28_800_000_000,
        LeverageAssets: 300_000_000,
        expectedCreate: 6666,
        expectedRedeem: 1536,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 6800,
        ethPrice: 12_000,
        TotalUnderlyingAssets: 14_400_000_000,
        DebtAssets: 1_440_000_000_000,
        LeverageAssets: 500_000_000,
        expectedCreate: 850_000,
        expectedRedeem: 54,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 4500,
        ethPrice: 6000,
        TotalUnderlyingAssets: 720_000_000,
        DebtAssets: 43_200_000_000,
        LeverageAssets: 300_000_000,
        expectedCreate: 9375,
        expectedRedeem: 2160,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 7800,
        ethPrice: 15_000,
        TotalUnderlyingAssets: 18_000_000_000,
        DebtAssets: 2_250_000_000_000,
        LeverageAssets: 1_000_000_000,
        expectedCreate: 1_218_750,
        expectedRedeem: 49,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 5100,
        ethPrice: 3600,
        TotalUnderlyingAssets: 108_000_000,
        DebtAssets: 3_240_000_000,
        LeverageAssets: 100_000_000,
        expectedCreate: 23_611,
        expectedRedeem: 1101,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 3100,
        ethPrice: 1200,
        TotalUnderlyingAssets: 288_000_000,
        DebtAssets: 2_880_000_000,
        LeverageAssets: 500_000_000,
        expectedCreate: 38_750,
        expectedRedeem: 248,
        expectedSwap: 0
      })
    );
  }

  function initializeRealisticTestCases() public {
    // Reset test cases
    delete calcTestCases;

    // Debt - Below Threshold
    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 3 ether,
        ethPrice: 3000 * 10 ** 8,
        TotalUnderlyingAssets: 1_000_000 ether,
        DebtAssets: 30_000_000 ether,
        LeverageAssets: 1_000_000 ether,
        expectedCreate: 112_500_000_000_000_000_000,
        expectedRedeem: 80_000_000_000_000_000,
        expectedSwap: 400_000_032_000_002_560
      })
    );
    // Debt - Above Threshold
    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 3 ether,
        ethPrice: 3000 * 10 ** 8,
        TotalUnderlyingAssets: 1_000_000 ether,
        DebtAssets: 20_000_000 ether,
        LeverageAssets: 1_000_000 ether,
        expectedCreate: 90_000_000_000_000_000_000,
        expectedRedeem: 100_000_000_000_000_000,
        expectedSwap: 300_000_000_000_000_000
      })
    );

    // Leverage - Below Threshold
    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3 ether,
        ethPrice: 3000 * 10 ** 8,
        TotalUnderlyingAssets: 1_000_000 ether,
        DebtAssets: 30_000_000 ether,
        LeverageAssets: 1_000_000 ether,
        expectedCreate: 15_000_000_000_000_000_000,
        expectedRedeem: 600_000_000_000_000_000,
        expectedSwap: 22_500_013_500_008_100_004
      })
    );
    // Leverage - Above Threshold
    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3 ether,
        ethPrice: 3000 * 10 ** 8,
        TotalUnderlyingAssets: 1_000_000 ether,
        DebtAssets: 20_000_000 ether,
        LeverageAssets: 1_000_000 ether,
        expectedCreate: 9_000_000_000_000_000_000,
        expectedRedeem: 1_000_000_000_000_000_000,
        expectedSwap: 30_000_000_000_000_000_000
      })
    );
    // Random Values but Leverage Level = 1.2
    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 3 ether,
        ethPrice: 3000 * 10 ** 8,
        TotalUnderlyingAssets: 1_000_000 ether,
        DebtAssets: 25_000_000 ether,
        LeverageAssets: 1_000_000 ether,
        expectedCreate: 93_750_000_000_000_000_000,
        expectedRedeem: 96_000_000_000_000_000,
        expectedSwap: 480_000_046_400_004_485
      })
    );
    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3 ether,
        ethPrice: 3000 * 10 ** 8,
        TotalUnderlyingAssets: 1_000_000 ether,
        DebtAssets: 25_000_000 ether,
        LeverageAssets: 1_000_000 ether,
        expectedCreate: 15_000_000_000_000_000_000,
        expectedRedeem: 600_000_000_000_000_000,
        expectedSwap: 18_750_011_328_131_844_079
      })
    );
  }

  // eth comes from Pool constant (3000)
  function initializeTestCasesFixedEth() public {
    delete calcTestCases;
    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 1000,
        ethPrice: 0, // not used
        TotalUnderlyingAssets: 1_000_000_000,
        DebtAssets: 25_000_000_000,
        LeverageAssets: 1_000_000_000,
        expectedCreate: 31_250,
        expectedRedeem: 32,
        expectedSwap: 160
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 1250,
        ethPrice: 0, // not used
        TotalUnderlyingAssets: 1_200_456_789_222,
        DebtAssets: 25_123_456_789,
        LeverageAssets: 1_321_654_987,
        expectedCreate: 37_500,
        expectedRedeem: 41,
        expectedSwap: 0
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 500,
        ethPrice: 0, // not used
        TotalUnderlyingAssets: 32_000,
        DebtAssets: 2_100_000,
        LeverageAssets: 1_200_000,
        expectedCreate: 93_750,
        expectedRedeem: 2,
        expectedSwap: 164
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 1600,
        ethPrice: 0,
        TotalUnderlyingAssets: 7_000_000,
        DebtAssets: 850_000,
        LeverageAssets: 1_300_000,
        expectedCreate: 298,
        expectedRedeem: 8580,
        expectedSwap: 257_400
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.LEVERAGE,
        inAmount: 3200,
        ethPrice: 0, // not used
        TotalUnderlyingAssets: 960_000_000,
        DebtAssets: 38_400_000_000,
        LeverageAssets: 500_000_000,
        expectedCreate: 8333,
        expectedRedeem: 1228,
        expectedSwap: 61_400
      })
    );

    calcTestCases.push(
      CalcTestCase({
        assetType: Pool.TokenType.BOND,
        inAmount: 7000,
        ethPrice: 0, // not used
        TotalUnderlyingAssets: 144_000_000,
        DebtAssets: 1_440_000_000,
        LeverageAssets: 2_000_000,
        expectedCreate: 210_000,
        expectedRedeem: 233,
        expectedSwap: 4
      })
    );
  }
}
