// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {Auction} from "../../src/Auction.sol";
import {Pool} from "../../src/Pool.sol";
import {Utils} from "../../src/lib/Utils.sol";
import {Token} from "../../test/mocks/Token.sol";
import {BondToken} from "../../src/BondToken.sol";
import {PoolFactory} from "../../src/PoolFactory.sol";
import {Distributor} from "../../src/Distributor.sol";
import {DistributorAdapter} from "../../src/DistributorAdapter.sol";
import {OracleFeeds} from "../../src/OracleFeeds.sol";
import {LeverageToken} from "../../src/LeverageToken.sol";
import {Deployer} from "../../src/utils/Deployer.sol";
import {PreDeposit} from "../../src/PreDeposit.sol";
import {BalancerOracleAdapter} from "../../src/BalancerOracleAdapter.sol";
import {BalancerRouter} from "../../src/BalancerRouter.sol";
import {BondOracleAdapter} from "../../src/BondOracleAdapter.sol";
import {WethPriceFeed} from "../../src/WethPriceFeed.sol";
import {UnderlyingsOracleAdapter} from "../../src/UnderlyingsOracleAdapter.sol";
import {RoycoHelper} from "../../src/RoycoHelper.sol";

import {IManagedPoolFactory} from "../../src/lib/balancer/IManagedPoolFactory.sol";
import {IBalancerQueries} from "../../src/lib/balancer/IBalancerQueries.sol";
import {IManagedPool} from "../../src/lib/balancer/IManagedPool.sol";
import {IVault} from "@balancer/contracts/interfaces/contracts/vault/IVault.sol";
import {ICLFactory} from "../../src/lib/concentrated-liquidity/ICLFactory.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract TestSetup is Test {
  // Constants
  uint256 public constant INITIAL_BOND = 50 ether;
  uint256 public constant INITIAL_LEVERAGE = 50 ether;
  uint256 public constant SHARES_PER_TOKEN = 2_500_000;
  uint256 public constant DISTRIBUTION_PERIOD = 90 days;
  uint256 public constant AUCTION_PERIOD = 10 days;
  uint256 public constant PRE_DEPOSIT_PERIOD = 30 days;
  uint256 public constant PRE_DEPOSIT_CAP = 10 ether;
  uint256 public constant CHAINLINK_DECIMAL_PRECISION = 10 ** 8;
  uint8 public constant CHAINLINK_DECIMAL = 8;
  uint8 public constant COUPON_DECIMALS = 6; // USDC decimals

  // Tokens
  address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
  address public constant USD = 0x0000000000000000000000000000000000000000;
  IERC20 public weEth = IERC20(0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A);
  IERC20 public ezEth = IERC20(0x2416092f143378750bb29b79eD961ab195CcEea5);
  IERC20 public cbEth = IERC20(0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22);
  IERC20 public weth = IERC20(0x4200000000000000000000000000000000000006);
  IERC20 public rEth = IERC20(0xB6fe221Fe9EeF5aBa221c348bA20A1Bf5e73624c);
  IERC20 public wstEth = IERC20(0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452);
  IERC20 public couponToken = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913); // USDC
  IERC20 public reserveToken;

  address[] public allowedTokens =
    [address(weEth), address(ezEth), address(cbEth), address(weth), address(rEth), address(wstEth)];

  uint256 public numAllowedTokens = allowedTokens.length;

  // Balancer contracts
  IVault public balancerVault = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
  IManagedPoolFactory public balancerManagedPoolFactory =
    IManagedPoolFactory(0x9a62C91626d39D0216b3959112f9D4678E20134d);
  IBalancerQueries public balancerQueries = IBalancerQueries(0x300Ab2038EAc391f26D9F895dc61F8F66a548833);
  IManagedPool public balancerPool;

  // Aerodrome contracts
  address public aerodromeCLFactory = 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A;
  address public aerodromePositionManager = 0x827922686190790b37229fd06084350E74485b72;
  address public aerodromeCLPool;

  // Chainlink price feeds
  address public ethUsdPriceFeed = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70; // The only feed with
    // USD as quote asset. Remaining are ETH quoted
  address public wstEthPriceFeed = 0x43a5C292A453A3bF3606fa856197f09D7B74251a;
  address public cbEthPriceFeed = 0x806b4Ac04501c29769051e42783cF04dCE41440b;
  address public rEthPriceFeed = 0xf397bF97280B488cA19ee3093E81C0a77F02e9a5;
  address public weEthPriceFeed = 0xFC1415403EbB0c693f9a7844b92aD2Ff24775C65;
  address public ezEthPriceFeed = 0x960BDD1dFD20d7c98fa482D793C3dedD73A113a3;
  address public wethPriceFeed; // A dummy returning 1e18 needs to be deployed

  // Protocol contracts
  PoolFactory public poolFactory;
  Pool public pool;
  BondToken public bondToken;
  LeverageToken public leverageToken;
  Distributor public distributor;
  DistributorAdapter public distributorAdapter;
  OracleFeeds public oracleFeeds;
  BalancerOracleAdapter public balancerOracleAdapter;
  BalancerRouter public balancerRouter;
  BondOracleAdapter public bondOracleAdapter;
  PreDeposit public preDeposit;

  // Test addresses
  address public deployer;
  address public governance = address(0x1);
  address public securityCouncil = address(0x2);
  address public user1 = address(0x4);
  address public user2 = address(0x5);
  address public user3 = address(0x6);
  address public user4 = address(0x7);
  PoolFactory.PoolParams public params;

  uint256 internal testStartTime;

  function setUp() public virtual {
    uint256 nAllowedTokens = allowedTokens.length;

    // Fork Base Mainnet
    vm.createSelectFork(vm.envString("BASE_MAINNET_RPC"));
    deployer = vm.addr(0xdeafbeef);
    vm.startPrank(deployer);

    // Deploy protocol contracts
    address contractDeployer = address(new Deployer());
    oracleFeeds = new OracleFeeds();
    wethPriceFeed = address(new WethPriceFeed());

    // Deploy beacons
    address poolBeacon = address(new UpgradeableBeacon(address(new Pool()), governance));
    address bondBeacon = address(new UpgradeableBeacon(address(new BondToken()), governance));
    address levBeacon = address(new UpgradeableBeacon(address(new LeverageToken()), governance));
    address distributorBeacon = address(new UpgradeableBeacon(address(new Distributor()), governance));
    address distributorAdapterBeacon = address(new UpgradeableBeacon(address(new DistributorAdapter()), governance));

    // Deploy factory
    poolFactory = PoolFactory(
      Utils.deploy(
        address(new PoolFactory()),
        abi.encodeCall(
          PoolFactory.initialize,
          (governance, contractDeployer, address(oracleFeeds), poolBeacon, bondBeacon, levBeacon, distributorBeacon)
        )
      )
    );
    poolFactory.setDistributorAdapterBeacon(distributorAdapterBeacon);

    params = PoolFactory.PoolParams({
      fee: 0,
      reserveToken: address(0),
      couponToken: address(couponToken),
      distributionPeriod: DISTRIBUTION_PERIOD,
      sharesPerToken: SHARES_PER_TOKEN,
      feeBeneficiary: address(0)
    });

    balancerRouter = BalancerRouter(address(new BalancerRouter(address(balancerVault))));
    balancerOracleAdapter = BalancerOracleAdapter(
      Utils.deploy(
        address(new BalancerOracleAdapter()),
        abi.encodeCall(BalancerOracleAdapter.initialize, (address(0), 8, address(oracleFeeds), deployer))
      )
    );

    preDeposit = PreDeposit(
      Utils.deploy(
        address(new PreDeposit()),
        abi.encodeCall(
          PreDeposit.initialize,
          (
            params,
            address(poolFactory),
            address(balancerManagedPoolFactory),
            address(balancerVault),
            address(balancerOracleAdapter),
            block.timestamp,
            block.timestamp + PRE_DEPOSIT_PERIOD,
            PRE_DEPOSIT_CAP,
            allowedTokens,
            "Bond ETH",
            "BondETH",
            "Leverage ETH",
            "LevETH"
          )
        )
      )
    );

    // Setup price feeds and approve spend on PreDeposit
    // Heartbeat set to 100 days to avoid stale prices when doing vm.warp() in tests
    oracleFeeds.setPriceFeed(ETH, USD, ethUsdPriceFeed, 100 days);
    oracleFeeds.setPriceFeed(address(wstEth), ETH, wstEthPriceFeed, 100 days);
    oracleFeeds.setPriceFeed(address(cbEth), ETH, cbEthPriceFeed, 100 days);
    oracleFeeds.setPriceFeed(address(rEth), ETH, rEthPriceFeed, 100 days);
    oracleFeeds.setPriceFeed(address(weEth), ETH, weEthPriceFeed, 100 days);
    oracleFeeds.setPriceFeed(address(ezEth), ETH, ezEthPriceFeed, 100 days);
    oracleFeeds.setPriceFeed(address(weth), ETH, wethPriceFeed, 100 days);

    for (uint256 i = 0; i < nAllowedTokens; i++) {
      oracleFeeds.setPriceFeed(
        address(allowedTokens[i]),
        USD,
        address(
          Utils.deploy(
            address(new UnderlyingsOracleAdapter()),
            abi.encodeCall(UnderlyingsOracleAdapter.initialize, (address(allowedTokens[i]), 8, address(oracleFeeds)))
          )
        ),
        100 days
      );

      deal(allowedTokens[i], deployer, 1000 ether);
      deal(allowedTokens[i], user1, 1000 ether);
      deal(allowedTokens[i], user2, 1000 ether);
      deal(allowedTokens[i], user3, 1000 ether);
    }

    vm.stopPrank();

    // Setup roles
    vm.startPrank(deployer);
    balancerOracleAdapter.transferOwnership(governance);
    oracleFeeds.grantRole(oracleFeeds.GOV_ROLE(), governance);
    oracleFeeds.revokeRole(oracleFeeds.GOV_ROLE(), deployer);
    vm.stopPrank();

    vm.startPrank(governance);
    poolFactory.grantRole(poolFactory.POOL_ROLE(), address(preDeposit));
    poolFactory.grantRole(poolFactory.POOL_ROLE(), address(governance));
    poolFactory.grantRole(poolFactory.SECURITY_COUNCIL_ROLE(), securityCouncil);
    vm.stopPrank();

    testStartTime = block.timestamp;
  }

  function createPool() public returns (Pool) {
    vm.startPrank(user1);
    wstEth.approve(address(preDeposit), type(uint256).max);
    cbEth.approve(address(preDeposit), type(uint256).max);
    rEth.approve(address(preDeposit), type(uint256).max);
    weEth.approve(address(preDeposit), type(uint256).max);
    ezEth.approve(address(preDeposit), type(uint256).max);
    weth.approve(address(preDeposit), type(uint256).max);
    address[] memory selectedTokens = new address[](6);
    selectedTokens[0] = address(weEth);
    selectedTokens[1] = address(ezEth);
    selectedTokens[2] = address(cbEth);
    selectedTokens[3] = address(weth);
    selectedTokens[4] = address(rEth);
    selectedTokens[5] = address(wstEth);

    uint256[] memory amounts = new uint256[](6);
    amounts[0] = 1 ether;
    amounts[1] = 1 ether;
    amounts[2] = 1 ether;
    amounts[3] = 1 ether;
    amounts[4] = 1 ether;
    amounts[5] = 1 ether;
    preDeposit.deposit(selectedTokens, amounts);
    vm.stopPrank();

    vm.startPrank(governance);
    vm.warp(testStartTime + PRE_DEPOSIT_PERIOD + 1 days); // After deposit period
    preDeposit.setBondAndLeverageAmount(INITIAL_BOND, INITIAL_LEVERAGE);

    bytes32 salt = bytes32("salt");
    vm.recordLogs();
    preDeposit.createPool(salt);

    Vm.Log[] memory entries = vm.getRecordedLogs();
    Vm.Log memory log = entries[entries.length - 1]; // last log is the pool created address
    pool = Pool(address(uint160(uint256(log.topics[1]))));

    log = entries[entries.length - 2]; // second to last log is the balancer pool address
    balancerPool = IManagedPool(address(uint160(uint256(log.topics[1]))));

    reserveToken = IERC20(address(pool.reserveToken()));
    params.reserveToken = address(reserveToken);
    bondToken = BondToken(address(pool.bondToken()));
    leverageToken = LeverageToken(address(pool.lToken()));

    oracleFeeds.setPriceFeed(address(reserveToken), USD, address(balancerOracleAdapter), 1 days);
    balancerOracleAdapter.setBalancerPoolAddress(address(balancerPool));
    pool.setAuctionPeriod(AUCTION_PERIOD);
    distributor = Distributor(poolFactory.distributors(address(pool)));
    distributorAdapter = DistributorAdapter(poolFactory.distributorAdapters(address(pool)));

    vm.startPrank(securityCouncil);
    pool.unpause();
    vm.stopPrank();

    vm.startPrank(user1);
    preDeposit.claim();
    vm.stopPrank();

    return pool;
  }

  function doAuction() public returns (address) {
    vm.startPrank(governance);
    Pool.PoolInfo memory info = pool.getPoolInfo();
    vm.warp(info.lastDistribution + DISTRIBUTION_PERIOD + 1);

    pool.startAuction();
    (uint256 currentPeriod,) = bondToken.globalPool();
    Auction auction = Auction(pool.auctions(currentPeriod - 1));
    uint256 amount = auction.totalBuyCouponAmount();
    deal(address(couponToken), governance, amount);
    couponToken.transfer(user1, amount);
    vm.stopPrank();

    vm.startPrank(user1);
    couponToken.approve(address(auction), amount);
    auction.bid(1, amount);

    vm.warp(block.timestamp + AUCTION_PERIOD + 1 days);
    auction.endAuction();

    return address(auction);
  }

  function doFailedAuction() public returns (address) {
    vm.startPrank(governance);
    Pool.PoolInfo memory info = pool.getPoolInfo();
    vm.warp(info.lastDistribution + DISTRIBUTION_PERIOD + 1);

    pool.startAuction();
    (uint256 currentPeriod,) = bondToken.globalPool();
    Auction auction = Auction(pool.auctions(currentPeriod - 1));
    uint256 amount = auction.totalBuyCouponAmount() / 2;
    deal(address(couponToken), governance, amount);
    couponToken.transfer(user1, amount);
    vm.stopPrank();

    vm.startPrank(user1);
    couponToken.approve(address(auction), amount);
    auction.bid(1, amount);

    vm.warp(block.timestamp + AUCTION_PERIOD + 1 days);
    auction.endAuction();

    return address(auction);
  }
}
