// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import {Pool} from "../../src/Pool.sol";
import {Token} from "../mocks/Token.sol";
import {Utils} from "../../src/lib/Utils.sol";
import {BondToken} from "../../src/BondToken.sol";
import {PreDeposit} from "../../src/PreDeposit.sol";
import {Distributor} from "../../src/Distributor.sol";
import {DistributorAdapter} from "../../src/DistributorAdapter.sol";
import {PoolFactory} from "../../src/PoolFactory.sol";
import {Deployer} from "../../src/utils/Deployer.sol";
import {LeverageToken} from "../../src/LeverageToken.sol";
import {BalancerOracleAdapter} from "../../src/BalancerOracleAdapter.sol";

import {MockBalancerPoolFactory} from "../mocks/MockBalancerPoolFactory.sol";
import {MockBalancerVault} from "../mocks/MockBalancerVault.sol";

import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PreDepositTest is Test {
  address public constant ETH = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
  address public constant ethPriceFeed = address(0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70);

  PreDeposit public preDeposit;
  Token public couponToken;

  address user1 = address(2);
  address user2 = address(3);
  address nonOwner = address(4);

  Token token1;
  Token token2;
  Token token3;
  Token token4;
  address[] allowedTokens;

  uint256 depositStartTime;
  uint256 depositEndTime;

  PoolFactory private poolFactory;
  PoolFactory.PoolParams private params;
  Distributor private distributor;
  BalancerOracleAdapter balancerOracleAdapter;
  address balancerVault;
  address balancerPoolFactory;

  address private deployer = address(0x5);
  address private minter = address(0x6);
  address private governance = address(0x7);

  uint256 constant INITIAL_BALANCE = 1000 ether;
  uint256 constant DEPOSIT_CAP = 1000 ether;
  uint256 constant DEPOSIT_AMOUNT = 10 ether;
  uint256 constant BOND_AMOUNT = 50 ether;
  uint256 constant LEVERAGE_AMOUNT = 50 ether;

  uint256 constant TOKEN1_PRICE = 1.234 ether;
  uint256 constant TOKEN2_PRICE = 1.111 ether;
  uint256 constant TOKEN3_PRICE = 1.001 ether;
  uint256 constant TOKEN4_PRICE = 2.222 ether;

  function setUp() public {
    // Set block time to 10 days in the future to avoid block.timestamp to start from 0
    vm.warp(block.timestamp + 10 days);
    setUp_PoolFactory();

    vm.startPrank(governance);
    couponToken = new Token("USDC", "USDC", false);
    token1 = new Token("Pool Token 1", "PT1", false);
    token2 = new Token("Pool Token 2", "PT2", false);
    token3 = new Token("Pool Token 3", "PT3", false);
    token4 = new Token("Pool Token 4", "PT4", false);
    allowedTokens.push(address(token1));
    allowedTokens.push(address(token2));
    allowedTokens.push(address(token3));
    allowedTokens.push(address(token4));

    params = PoolFactory.PoolParams({
      fee: 0,
      reserveToken: address(0),
      couponToken: address(couponToken),
      distributionPeriod: 90 days,
      sharesPerToken: 2 * 10 ** 6,
      feeBeneficiary: address(0)
    });

    balancerVault = address(new MockBalancerVault());
    balancerPoolFactory = address(new MockBalancerPoolFactory(balancerVault));
    balancerOracleAdapter = new BalancerOracleAdapter(); // mock the prices

    depositStartTime = block.timestamp;
    depositEndTime = block.timestamp + 7 days;

    _deployPreDeposit();
    _mintDepositTokens();
    _mockPrices();

    vm.stopPrank();
  }

  function setUp_PoolFactory() internal {
    vm.startPrank(deployer);

    address contractDeployer = address(new Deployer());

    address poolBeacon = address(new UpgradeableBeacon(address(new Pool()), governance));
    address bondBeacon = address(new UpgradeableBeacon(address(new BondToken()), governance));
    address levBeacon = address(new UpgradeableBeacon(address(new LeverageToken()), governance));
    address distributorBeacon = address(new UpgradeableBeacon(address(new Distributor()), governance));
    address distributorAdapterBeacon = address(new UpgradeableBeacon(address(new DistributorAdapter()), governance));

    poolFactory = PoolFactory(
      Utils.deploy(
        address(new PoolFactory()),
        abi.encodeCall(
          PoolFactory.initialize,
          (governance, contractDeployer, ethPriceFeed, poolBeacon, bondBeacon, levBeacon, distributorBeacon)
        )
      )
    );

    poolFactory.setDistributorAdapterBeacon(distributorAdapterBeacon);

    vm.stopPrank();

    vm.startPrank(governance);
    poolFactory.grantRole(poolFactory.SECURITY_COUNCIL_ROLE(), governance);
    vm.stopPrank();
  }

  function deployFakePool() public returns (address, address, address) {
    BondToken bondToken = BondToken(
      Utils.deploy(
        address(new BondToken()),
        abi.encodeCall(BondToken.initialize, ("", "", governance, governance, address(poolFactory), 0))
      )
    );

    LeverageToken lToken = LeverageToken(
      Utils.deploy(
        address(new LeverageToken()),
        abi.encodeCall(LeverageToken.initialize, ("", "", governance, governance, address(poolFactory)))
      )
    );

    Pool pool = Pool(
      Utils.deploy(
        address(new Pool()),
        abi.encodeCall(
          Pool.initialize,
          (
            address(poolFactory),
            0,
            address(token1),
            address(bondToken),
            address(lToken),
            address(couponToken),
            0,
            0,
            address(0),
            address(0),
            false
          )
        )
      )
    );

    // Adds fake pool to preDeposit contract
    uint256 poolSlot = 0;
    vm.store(address(preDeposit), bytes32(poolSlot), bytes32(uint256(uint160(address(pool)))));
    return (address(pool), address(bondToken), address(lToken));
  }

  function resetReentrancy(address contractAddress) public {
    // Reset `_status` to allow the next call
    vm.store(
      contractAddress,
      bytes32(0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00), // Storage slot
        // for `_status`
      bytes32(uint256(1)) // Reset to `_NOT_ENTERED`
    );
  }

  // Deposit Tests
  function testDeposit() public {
    vm.startPrank(user1);
    token1.approve(address(preDeposit), DEPOSIT_AMOUNT);

    address[] memory tokens = new address[](1);
    tokens[0] = address(token1);
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = DEPOSIT_AMOUNT;
    preDeposit.deposit(tokens, amounts);

    assertEq(preDeposit.balances(user1, address(token1)), DEPOSIT_AMOUNT);
    assertEq(IERC20(address(token1)).balanceOf(address(preDeposit)), DEPOSIT_AMOUNT);
    assertEq(preDeposit.currentPredepositTotal(), TOKEN1_PRICE * DEPOSIT_AMOUNT / 1e18);
    vm.stopPrank();
  }

  function testDepositBeforeStart() public {
    // Setup new predeposit with future start time
    vm.startPrank(governance);
    depositStartTime = block.timestamp + 1 days;
    depositEndTime = block.timestamp + 7 days;
    _deployPreDeposit();
    vm.stopPrank();

    vm.startPrank(user1);
    address[] memory tokens = new address[](1);
    tokens[0] = address(token1);
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = DEPOSIT_AMOUNT;
    token1.approve(address(preDeposit), DEPOSIT_AMOUNT);

    vm.expectRevert(PreDeposit.DepositNotYetStarted.selector);
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();
  }

  function testDepositAfterEnd() public {
    vm.startPrank(user1);
    address[] memory tokens = new address[](1);
    tokens[0] = address(token1);
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = DEPOSIT_AMOUNT;

    vm.warp(depositEndTime + 1 days); // After deposit period

    token1.approve(address(preDeposit), DEPOSIT_AMOUNT);
    vm.expectRevert(PreDeposit.DepositEnded.selector);
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();
  }

  function testMultipleAssetDeposit() public {
    vm.startPrank(user1);
    token1.approve(address(preDeposit), DEPOSIT_AMOUNT);
    token2.approve(address(preDeposit), DEPOSIT_AMOUNT * 2);
    token3.approve(address(preDeposit), DEPOSIT_AMOUNT * 3);

    address[] memory tokens = new address[](3);
    tokens[0] = address(token1);
    tokens[1] = address(token2);
    tokens[2] = address(token3);
    uint256[] memory amounts = new uint256[](3);
    amounts[0] = DEPOSIT_AMOUNT;
    amounts[1] = DEPOSIT_AMOUNT * 2;
    amounts[2] = DEPOSIT_AMOUNT * 3;
    preDeposit.deposit(tokens, amounts);

    assertEq(preDeposit.balances(user1, address(token1)), DEPOSIT_AMOUNT);
    assertEq(preDeposit.balances(user1, address(token2)), DEPOSIT_AMOUNT * 2);
    assertEq(preDeposit.balances(user1, address(token3)), DEPOSIT_AMOUNT * 3);

    uint256 predepositTotal = (
      TOKEN1_PRICE * DEPOSIT_AMOUNT / 1e18 + TOKEN2_PRICE * DEPOSIT_AMOUNT * 2 / 1e18
        + TOKEN3_PRICE * DEPOSIT_AMOUNT * 3 / 1e18
    );
    assertEq(preDeposit.currentPredepositTotal(), predepositTotal);
    vm.stopPrank();
  }

  function testDepositExceedingCap() public {
    vm.startPrank(user1);
    token1.approve(address(preDeposit), DEPOSIT_AMOUNT);
    address[] memory tokens = new address[](1);
    tokens[0] = address(token1);
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = DEPOSIT_AMOUNT;

    vm.mockCall(
      address(balancerOracleAdapter),
      abi.encodeWithSelector(balancerOracleAdapter.getOraclePrice.selector, address(token1), ETH),
      abi.encode(TOKEN1_PRICE * 1000) // Inflate price to exceed cap
    );

    vm.expectRevert(PreDeposit.DepositCapReached.selector);
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();
  }

  // Withdraw Tests
  function testWithdraw() public {
    vm.startPrank(user1);
    token1.approve(address(preDeposit), DEPOSIT_AMOUNT);
    address[] memory tokens = new address[](1);
    tokens[0] = address(token1);
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = DEPOSIT_AMOUNT;
    preDeposit.deposit(tokens, amounts);

    uint256 balanceBefore = token1.balanceOf(user1);
    preDeposit.withdraw(tokens, amounts);
    uint256 balanceAfter = token1.balanceOf(user1);

    assertEq(balanceAfter, balanceBefore + DEPOSIT_AMOUNT);
    assertEq(preDeposit.balances(user1, address(token1)), 0);
    assertEq(preDeposit.currentPredepositTotal(), 0);
    vm.stopPrank();
  }

  function testWithdrawMultipleAssets() public {
    vm.startPrank(user1);
    token1.approve(address(preDeposit), DEPOSIT_AMOUNT);
    token2.approve(address(preDeposit), DEPOSIT_AMOUNT);
    token3.approve(address(preDeposit), DEPOSIT_AMOUNT);
    address[] memory tokens = new address[](3);
    tokens[0] = address(token1);
    tokens[1] = address(token2);
    tokens[2] = address(token3);
    uint256[] memory amounts = new uint256[](3);
    amounts[0] = DEPOSIT_AMOUNT;
    amounts[1] = DEPOSIT_AMOUNT;
    amounts[2] = DEPOSIT_AMOUNT;
    preDeposit.deposit(tokens, amounts);

    uint256 balanceBeforeToken1 = token1.balanceOf(user1);
    uint256 balanceBeforeToken2 = token2.balanceOf(user1);
    uint256 balanceBeforeToken3 = token3.balanceOf(user1);
    preDeposit.withdraw(tokens, amounts);
    uint256 balanceAfterToken1 = token1.balanceOf(user1);
    uint256 balanceAfterToken2 = token2.balanceOf(user1);
    uint256 balanceAfterToken3 = token3.balanceOf(user1);

    assertEq(balanceAfterToken1, balanceBeforeToken1 + DEPOSIT_AMOUNT);
    assertEq(balanceAfterToken2, balanceBeforeToken2 + DEPOSIT_AMOUNT);
    assertEq(balanceAfterToken3, balanceBeforeToken3 + DEPOSIT_AMOUNT);
    assertEq(preDeposit.balances(user1, address(token1)), 0);
    assertEq(preDeposit.balances(user1, address(token2)), 0);
    assertEq(preDeposit.balances(user1, address(token3)), 0);
    assertEq(preDeposit.currentPredepositTotal(), 0);
    vm.stopPrank();
  }

  // Pool Creation Tests
  function testCreatePool() public {
    vm.startPrank(user1);
    token1.approve(address(preDeposit), DEPOSIT_AMOUNT);
    address[] memory tokens = new address[](1);
    tokens[0] = address(token1);
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = DEPOSIT_AMOUNT;
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    vm.startPrank(governance);
    vm.warp(depositEndTime + 1 days); // After deposit period
    preDeposit.setBondAndLeverageAmount(BOND_AMOUNT, LEVERAGE_AMOUNT);

    poolFactory.grantRole(poolFactory.POOL_ROLE(), address(preDeposit));

    bytes32 salt = bytes32("salt");
    vm.recordLogs();
    preDeposit.createPool(salt);

    assertNotEq(preDeposit.pool(), address(0));
    assertEq(preDeposit.poolCreated(), true);
    assertEq(token1.balanceOf(address(preDeposit)), 0);

    Vm.Log[] memory entries = vm.getRecordedLogs();
    Vm.Log memory log = entries[entries.length - 2]; // second to last log is the balancer lp
    address balancerLp = address(uint160(uint256(log.topics[1])));
    address reserveToken = Pool(preDeposit.pool()).reserveToken();
    assertEq(reserveToken, balancerLp);
    vm.stopPrank();
  }

  function testCreatePoolWithMultipleTokens() public {
    vm.startPrank(user1);
    token1.approve(address(preDeposit), type(uint256).max);
    token2.approve(address(preDeposit), type(uint256).max);
    token3.approve(address(preDeposit), type(uint256).max);
    token4.approve(address(preDeposit), type(uint256).max);

    address[] memory tokens = new address[](4);
    tokens[0] = address(token1);
    tokens[1] = address(token2);
    tokens[2] = address(token3);
    tokens[3] = address(token4);

    uint256[] memory prices = new uint256[](4);
    prices[0] = TOKEN1_PRICE;
    prices[1] = TOKEN2_PRICE;
    prices[2] = TOKEN3_PRICE;
    prices[3] = TOKEN4_PRICE;

    /// SORT!
    (tokens, prices) = _sortAddressesAndPrices(tokens, prices);

    uint256[] memory amounts = new uint256[](4);
    amounts[0] = DEPOSIT_AMOUNT;
    amounts[1] = DEPOSIT_AMOUNT * 2;
    amounts[2] = DEPOSIT_AMOUNT * 3;
    amounts[3] = DEPOSIT_AMOUNT * 4;
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    vm.startPrank(governance);
    vm.warp(depositEndTime + 1 days); // After deposit period
    preDeposit.setBondAndLeverageAmount(BOND_AMOUNT, LEVERAGE_AMOUNT);

    poolFactory.grantRole(poolFactory.POOL_ROLE(), address(preDeposit));

    bytes32 salt = bytes32("salt");
    vm.recordLogs();
    preDeposit.createPool(salt);

    Vm.Log[] memory entries = vm.getRecordedLogs();
    Vm.Log memory log = entries[entries.length - 3];
    uint256[] memory actualWeights = abi.decode(log.data, (uint256[]));

    uint256 snapshotCapValue = preDeposit.snapshotCapValue();

    uint256[] memory expectedWeights = new uint256[](4);
    expectedWeights[0] = DEPOSIT_AMOUNT * prices[0] / snapshotCapValue;
    expectedWeights[1] = DEPOSIT_AMOUNT * 2 * prices[1] / snapshotCapValue;
    expectedWeights[2] = DEPOSIT_AMOUNT * 3 * prices[2] / snapshotCapValue;
    expectedWeights[3] = DEPOSIT_AMOUNT * 4 * prices[3] / snapshotCapValue;

    expectedWeights = _validateNormalizedWeights(expectedWeights);

    assertEq(actualWeights[0], expectedWeights[0]);
    assertEq(actualWeights[1], expectedWeights[1]);
    assertEq(actualWeights[2], expectedWeights[2]);
    assertEq(actualWeights[3], expectedWeights[3]);
    vm.stopPrank();
  }

  function testCreatePoolNoReserveAmount() public {
    vm.startPrank(governance);
    vm.warp(depositEndTime + 1 days);
    preDeposit.setBondAndLeverageAmount(BOND_AMOUNT, LEVERAGE_AMOUNT);

    vm.expectRevert(PreDeposit.NoReserveAmount.selector);
    bytes32 salt = bytes32("salt");
    preDeposit.createPool(salt);
    vm.stopPrank();
  }

  function testCreatePoolInvalidBondOrLeverageAmount() public {
    vm.startPrank(user1);
    token1.approve(address(preDeposit), DEPOSIT_AMOUNT);
    address[] memory tokens = new address[](1);
    tokens[0] = address(token1);
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = DEPOSIT_AMOUNT;
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    vm.startPrank(governance);
    vm.warp(depositEndTime + 1 days); // After deposit period

    vm.expectRevert(PreDeposit.InvalidBondOrLeverageAmount.selector);
    bytes32 salt = bytes32("salt");
    preDeposit.createPool(salt);
    vm.stopPrank();
  }

  function testCreatePoolBeforeDepositEnd() public {
    vm.startPrank(user1);
    token1.approve(address(preDeposit), DEPOSIT_AMOUNT);
    address[] memory tokens = new address[](1);
    tokens[0] = address(token1);
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = DEPOSIT_AMOUNT;
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    vm.startPrank(governance);

    // Check that the deposit end time is still in the future
    assertGt(preDeposit.depositEndTime(), block.timestamp, "Deposit period has ended");

    vm.expectRevert(PreDeposit.DepositNotEnded.selector);
    bytes32 salt = bytes32("salt");
    preDeposit.createPool(salt);
  }

  function testCreatePoolAfterCreation() public {
    vm.startPrank(user1);
    token1.approve(address(preDeposit), DEPOSIT_AMOUNT);
    address[] memory tokens = new address[](1);
    tokens[0] = address(token1);
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = DEPOSIT_AMOUNT;
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    vm.startPrank(governance);
    vm.warp(depositEndTime + 1 days); // After deposit period
    preDeposit.setBondAndLeverageAmount(BOND_AMOUNT, LEVERAGE_AMOUNT);

    poolFactory.grantRole(poolFactory.POOL_ROLE(), address(preDeposit));

    bytes32 salt = bytes32("salt");
    preDeposit.createPool(salt);

    // Try to create pool again
    token1.transfer(address(preDeposit), 1 ether); // send some tokens to pass tvl check
    vm.expectRevert(PreDeposit.PoolAlreadyCreated.selector);
    preDeposit.createPool(salt);
    vm.stopPrank();
  }

  function testClaim() public {
    // Setup initial deposit
    vm.startPrank(user1);
    token1.approve(address(preDeposit), DEPOSIT_AMOUNT);
    address[] memory tokens = new address[](1);
    tokens[0] = address(token1);
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = DEPOSIT_AMOUNT;
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    vm.startPrank(governance);
    vm.warp(depositEndTime + 1 days); // After deposit period
    preDeposit.setBondAndLeverageAmount(BOND_AMOUNT, LEVERAGE_AMOUNT);

    poolFactory.grantRole(poolFactory.POOL_ROLE(), address(preDeposit));

    bytes32 salt = bytes32("salt");
    preDeposit.createPool(salt);

    vm.stopPrank();

    // Claim tokens
    address bondToken = address(Pool(preDeposit.pool()).bondToken());
    address lToken = address(Pool(preDeposit.pool()).lToken());
    uint256 totalBondBalance = BondToken(bondToken).balanceOf(address(preDeposit));
    uint256 totalLeverageBalance = LeverageToken(lToken).balanceOf(address(preDeposit));

    vm.startPrank(user1);
    uint256 balanceBefore = preDeposit.balances(user1, address(token1));
    preDeposit.claim();
    uint256 balanceAfter = preDeposit.balances(user1, address(token1));

    // Verify balances were updated
    assertEq(balanceAfter, 0);
    assertLt(balanceAfter, balanceBefore);

    // Single user, so all bond/lev tokens are claimed by user1
    assertEq(BondToken(bondToken).balanceOf(user1), totalBondBalance);
    assertEq(LeverageToken(lToken).balanceOf(user1), totalLeverageBalance);
    vm.stopPrank();
  }

  function testClaimBeforeDepositEnd() public {
    vm.startPrank(user1);
    token1.approve(address(preDeposit), DEPOSIT_AMOUNT);
    address[] memory tokens = new address[](1);
    tokens[0] = address(token1);
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = DEPOSIT_AMOUNT;
    preDeposit.deposit(tokens, amounts);

    vm.expectRevert(PreDeposit.DepositNotEnded.selector);
    preDeposit.claim();
    vm.stopPrank();
  }

  function testClaimBeforePoolCreation() public {
    vm.startPrank(user1);
    token1.approve(address(preDeposit), DEPOSIT_AMOUNT);
    address[] memory tokens = new address[](1);
    tokens[0] = address(token1);
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = DEPOSIT_AMOUNT;
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    vm.warp(depositEndTime + 1 days); // After deposit period

    vm.startPrank(user1);
    vm.expectRevert(PreDeposit.ClaimPeriodNotStarted.selector);
    preDeposit.claim();
    vm.stopPrank();
  }

  function testClaimWithZeroBalance() public {
    // Create pool first
    vm.startPrank(user1);
    token1.approve(address(preDeposit), DEPOSIT_AMOUNT);
    address[] memory tokens = new address[](1);
    tokens[0] = address(token1);
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = DEPOSIT_AMOUNT;
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    vm.startPrank(governance);
    vm.warp(block.timestamp + 8 days);
    preDeposit.setBondAndLeverageAmount(BOND_AMOUNT, LEVERAGE_AMOUNT);

    poolFactory.grantRole(poolFactory.POOL_ROLE(), address(preDeposit));

    bytes32 salt = bytes32("salt");
    preDeposit.createPool(salt);
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
    token1.approve(address(preDeposit), DEPOSIT_AMOUNT);
    address[] memory tokens = new address[](1);
    tokens[0] = address(token1);
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = DEPOSIT_AMOUNT;
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    vm.startPrank(governance);
    vm.warp(depositEndTime + 1 days); // After deposit period
    preDeposit.setBondAndLeverageAmount(BOND_AMOUNT, LEVERAGE_AMOUNT);

    poolFactory.grantRole(poolFactory.POOL_ROLE(), address(preDeposit));

    bytes32 salt = bytes32("salt");
    preDeposit.createPool(salt);

    vm.stopPrank();

    vm.startPrank(user1);
    preDeposit.claim();

    // Second claim should fail
    vm.expectRevert(PreDeposit.NothingToClaim.selector);
    preDeposit.claim();
    vm.stopPrank();
  }

  // Admin Function Tests
  function testSetParams() public {
    vm.startPrank(governance);
    PoolFactory.PoolParams memory newParams = PoolFactory.PoolParams({
      fee: 0,
      reserveToken: address(token1), // Doesn't matter which address, as reserveToken is set in
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
    vm.startPrank(nonOwner);
    PoolFactory.PoolParams memory newParams = PoolFactory.PoolParams({
      fee: 0,
      reserveToken: address(token1),
      couponToken: address(couponToken),
      distributionPeriod: 180 days,
      sharesPerToken: 3 * 10 ** 6,
      feeBeneficiary: address(0)
    });

    vm.expectRevert(PreDeposit.AccessDenied.selector);
    preDeposit.setParams(newParams);
    vm.stopPrank();
  }

  function testIncreaseDepositCap() public {
    vm.prank(governance);
    preDeposit.increaseDepositCap(DEPOSIT_CAP * 2);
    assertEq(preDeposit.depositCap(), DEPOSIT_CAP * 2);
  }

  function testIncreaseDepositCapDecrease() public {
    vm.prank(governance);
    vm.expectRevert(PreDeposit.CapMustIncrease.selector);
    preDeposit.increaseDepositCap(DEPOSIT_CAP / 2);
  }

  // Time-related Tests
  function testSetDepositStartTime() public {
    // Move time to before deposit start time
    vm.warp(block.timestamp - 1 days);

    uint256 newStartTime = preDeposit.depositStartTime() + 10 hours;
    vm.prank(governance);
    preDeposit.setDepositStartTime(newStartTime);
    assertEq(preDeposit.depositStartTime(), newStartTime);
  }

  function testSetDepositEndTime() public {
    uint256 newEndTime = block.timestamp + 14 days;
    vm.prank(governance);
    preDeposit.setDepositEndTime(newEndTime);
    assertEq(preDeposit.depositEndTime(), newEndTime);
  }

  // Pause/Unpause Tests
  function testPauseUnpause() public {
    vm.startPrank(governance);
    preDeposit.pause();

    vm.startPrank(user1);
    token1.approve(address(preDeposit), DEPOSIT_AMOUNT);
    address[] memory tokens = new address[](1);
    tokens[0] = address(token1);
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = DEPOSIT_AMOUNT;
    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    preDeposit.deposit(tokens, amounts);

    vm.startPrank(governance);
    preDeposit.unpause();

    vm.startPrank(user1);
    preDeposit.deposit(tokens, amounts);
    assertEq(preDeposit.balances(user1, address(token1)), DEPOSIT_AMOUNT);
  }

  function testClaimTwoUsersSameBondShare() public {
    // Setup initial deposit
    address[] memory tokens = new address[](1);
    tokens[0] = address(token1);
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = DEPOSIT_AMOUNT;

    vm.startPrank(user1);
    token1.approve(address(preDeposit), DEPOSIT_AMOUNT);
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    vm.startPrank(user2);
    token1.approve(address(preDeposit), DEPOSIT_AMOUNT);
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    // Create pool
    vm.startPrank(governance);
    vm.warp(depositEndTime + 1 days); // After deposit period
    preDeposit.setBondAndLeverageAmount(BOND_AMOUNT, LEVERAGE_AMOUNT);

    poolFactory.grantRole(poolFactory.POOL_ROLE(), address(preDeposit));

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
    assertEq(user1_bond_share, 25 ether);
  }

  function testTimingAttack() public {
    // Setup initial deposit
    address[] memory tokens = new address[](1);
    tokens[0] = address(token1);
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = DEPOSIT_AMOUNT;

    vm.startPrank(user1);
    token1.approve(address(preDeposit), DEPOSIT_AMOUNT);
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    vm.startPrank(user2);
    token1.approve(address(preDeposit), DEPOSIT_AMOUNT);
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    // Create pool
    vm.startPrank(governance);
    vm.warp(block.timestamp + 7 days); // depositEndTime
    preDeposit.setBondAndLeverageAmount(BOND_AMOUNT, LEVERAGE_AMOUNT);

    poolFactory.grantRole(poolFactory.POOL_ROLE(), address(preDeposit));

    // Start timing attack
    vm.startPrank(user1);

    // user1 trigger createPool, it's allowed because it's not onlyOwner
    preDeposit.createPool(bytes32("salt"));

    // user1 trigger claim
    preDeposit.claim();

    token1.approve(address(preDeposit), 10);

    // deposit not possible at the same block as createPool
    vm.expectRevert(PreDeposit.DepositEnded.selector);
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();
  }

  function testExtendStartTimeAfterStartReverts() public {
    // user can deposit
    vm.startPrank(user1);
    token1.approve(address(preDeposit), DEPOSIT_AMOUNT);
    address[] memory tokens = new address[](1);
    tokens[0] = address(token1);
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = DEPOSIT_AMOUNT;
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    // Extend start time
    vm.prank(governance);
    vm.expectRevert(PreDeposit.DepositAlreadyStarted.selector);
    preDeposit.setDepositStartTime(block.timestamp + 1 days);
  }

  function testPoolPausedOnCreation() public {
    vm.startPrank(user1);
    token1.approve(address(preDeposit), DEPOSIT_AMOUNT);
    address[] memory tokens = new address[](1);
    tokens[0] = address(token1);
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = DEPOSIT_AMOUNT;
    preDeposit.deposit(tokens, amounts);
    vm.stopPrank();

    vm.startPrank(governance);
    vm.warp(depositEndTime + 1 days); // After deposit period
    preDeposit.setBondAndLeverageAmount(BOND_AMOUNT, LEVERAGE_AMOUNT);
    poolFactory.grantRole(poolFactory.POOL_ROLE(), address(preDeposit));

    vm.recordLogs();
    preDeposit.createPool(bytes32("salt"));
    Vm.Log[] memory entries = vm.getRecordedLogs();
    Vm.Log memory log = entries[entries.length - 1]; // second to last log is the pool created
      // address
    Pool pool = Pool(address(uint160(uint256(log.topics[1]))));
    assertEq(pool.paused(), true);
    vm.stopPrank();
  }

  function _deployPreDeposit() private {
    preDeposit = PreDeposit(
      Utils.deploy(
        address(new PreDeposit()),
        abi.encodeCall(
          PreDeposit.initialize,
          (
            params,
            address(poolFactory),
            address(balancerPoolFactory),
            address(balancerVault),
            address(balancerOracleAdapter),
            depositStartTime,
            depositEndTime,
            DEPOSIT_CAP,
            allowedTokens,
            "",
            "",
            "",
            ""
          )
        )
      )
    );
  }

  function _mintDepositTokens() private {
    token1.mint(address(user1), 10_000 ether);
    token1.mint(address(user2), 10_000 ether);
    token1.mint(address(governance), 10_000 ether);
    token2.mint(address(user1), 10_000 ether);
    token2.mint(address(user2), 10_000 ether);
    token3.mint(address(user1), 10_000 ether);
    token3.mint(address(user2), 10_000 ether);
    token4.mint(address(user1), 10_000 ether);
    token4.mint(address(user2), 10_000 ether);
  }

  function _mockPrices() private {
    vm.mockCall(
      address(balancerOracleAdapter),
      abi.encodeWithSelector(balancerOracleAdapter.getOraclePrice.selector, address(token1), ETH),
      abi.encode(TOKEN1_PRICE)
    );

    vm.mockCall(
      address(balancerOracleAdapter),
      abi.encodeWithSelector(balancerOracleAdapter.getOraclePrice.selector, address(token2), ETH),
      abi.encode(TOKEN2_PRICE)
    );

    vm.mockCall(
      address(balancerOracleAdapter),
      abi.encodeWithSelector(balancerOracleAdapter.getOraclePrice.selector, address(token3), ETH),
      abi.encode(TOKEN3_PRICE)
    );

    vm.mockCall(
      address(balancerOracleAdapter),
      abi.encodeWithSelector(balancerOracleAdapter.getOraclePrice.selector, address(token4), ETH),
      abi.encode(TOKEN4_PRICE)
    );
  }

  function _sortAddressesAndPrices(address[] memory addresses, uint256[] memory prices)
    private
    pure
    returns (address[] memory, uint256[] memory)
  {
    for (uint256 i = 0; i < addresses.length; i++) {
      for (uint256 j = i + 1; j < addresses.length; j++) {
        if (addresses[i] > addresses[j]) {
          (addresses[i], addresses[j]) = (addresses[j], addresses[i]);
          (prices[i], prices[j]) = (prices[j], prices[i]);
        }
      }
    }
    return (addresses, prices);
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
