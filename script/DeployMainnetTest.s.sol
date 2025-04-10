// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import "forge-std/Test.sol";

import {Auction} from "../src/Auction.sol";
import {Pool} from "../src/Pool.sol";
import {Utils} from "../src/lib/Utils.sol";
import {Token} from "../test/mocks/Token.sol";
import {BondToken} from "../src/BondToken.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {Distributor} from "../src/Distributor.sol";
import {OracleFeeds} from "../src/OracleFeeds.sol";
import {LeverageToken} from "../src/LeverageToken.sol";
import {Deployer} from "../src/utils/Deployer.sol";
import {PreDeposit} from "../src/PreDeposit.sol";
import {BalancerOracleAdapter} from "../src/BalancerOracleAdapter.sol";
import {BalancerRouter} from "../src/BalancerRouter.sol";
import {BondOracleAdapter} from "../src/BondOracleAdapter.sol";
import {WethPriceFeed} from "../src/WethPriceFeed.sol";
import {UnderlyingsOracleAdapter} from "../src/UnderlyingsOracleAdapter.sol";
import {MainnetConstants} from "./utils/MainnetConstants.sol";
import {IManagedPool} from "../src/lib/balancer/IManagedPool.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract MainnetScript is Script, MainnetConstants, Test {
  IERC20 public reserveToken;

  address[] public allowedTokens =
    [address(weEth), address(ezEth), address(cbEth), address(weth), address(rEth), address(wstEth), address(wrsEth)];

  uint256 public numAllowedTokens = allowedTokens.length;
  IManagedPool public balancerPool;
  address public wethPriceFeed; // A dummy returning 1e18 needs to be deployed

  // Protocol contracts
  PoolFactory public poolFactory;
  Pool public pool;
  BondToken public bondToken;
  LeverageToken public leverageToken;
  Distributor public distributor;
  OracleFeeds public oracleFeeds;
  BalancerOracleAdapter public balancerOracleAdapter;
  BalancerRouter public balancerRouter;
  BondOracleAdapter public bondOracleAdapter;
  PreDeposit public preDeposit;

  // Accounts
  address public deployer;

  PoolFactory.PoolParams public params;

  function run() public {
    uint256 nAllowedTokens = allowedTokens.length;

    vm.createSelectFork(vm.envString("BASE_MAINNET_RPC"));
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
    deployer = vm.addr(vm.envUint("PRIVATE_KEY"));

    // ============================
    // REMOVE FROM MAINNET DEPLOYMENT
    // ============================
    governance = deployer;
    securityCouncil = deployer;
    // ============================

    // Deploy protocol contracts
    address contractDeployer = address(new Deployer());
    oracleFeeds = new OracleFeeds();
    wethPriceFeed = address(new WethPriceFeed());

    // Deploy beacons
    address poolBeacon = address(new UpgradeableBeacon(address(new Pool()), governance));
    address bondBeacon = address(new UpgradeableBeacon(address(new BondToken()), governance));
    address levBeacon = address(new UpgradeableBeacon(address(new LeverageToken()), governance));
    address distributorBeacon = address(new UpgradeableBeacon(address(new Distributor()), governance));

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

    params = PoolFactory.PoolParams({
      fee: FEE_PERCENTAGE,
      reserveToken: address(0),
      couponToken: address(couponToken),
      distributionPeriod: DISTRIBUTION_PERIOD,
      sharesPerToken: SHARES_PER_TOKEN,
      feeBeneficiary: feeBeneficiary
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
            block.timestamp + 70 minutes,
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

    // Setup price feeds
    oracleFeeds.setPriceFeed(ETH, USD, ethUsdPriceFeed, 1 days);
    oracleFeeds.setPriceFeed(address(wstEth), ETH, wstEthPriceFeed, 1 days);
    oracleFeeds.setPriceFeed(address(cbEth), ETH, cbEthPriceFeed, 1 days);
    oracleFeeds.setPriceFeed(address(weEth), ETH, weEthPriceFeed, 1 days);
    oracleFeeds.setPriceFeed(address(ezEth), ETH, ezEthPriceFeed, 1 days);
    oracleFeeds.setPriceFeed(address(weth), ETH, wethPriceFeed, 1 days);
    oracleFeeds.setPriceFeed(address(rEth), ETH, rEthPriceFeed, 1 days);
    oracleFeeds.setPriceFeed(address(wrsEth), ETH, wrsEthPriceFeed, 1 days);

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
        1 days
      );
    }

    vm.stopPrank();

    // Setup roles
    poolFactory.grantRole(poolFactory.POOL_ROLE(), address(preDeposit));
    poolFactory.grantRole(poolFactory.POOL_ROLE(), address(governance));
    poolFactory.grantRole(poolFactory.SECURITY_COUNCIL_ROLE(), securityCouncil);

    console.log("preDeposit", address(preDeposit));
    console.log("poolFactory", address(poolFactory));
    console.log("balancerOracleAdapter", address(balancerOracleAdapter));
    console.log("oracleFeeds", address(oracleFeeds));
  }
}
