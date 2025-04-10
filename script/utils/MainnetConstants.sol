// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVault} from "@balancer/contracts/interfaces/contracts/vault/IVault.sol";
import {IManagedPoolFactory} from "../../src/lib/balancer/IManagedPoolFactory.sol";

contract MainnetConstants {
  // Constants
  uint256 public constant SHARES_PER_TOKEN = 2_500_000;
  uint256 public constant DISTRIBUTION_PERIOD = 90 days;
  uint256 public constant AUCTION_PERIOD = 10 days;
  uint256 public constant PRE_DEPOSIT_PERIOD = 14 days;
  uint256 public constant PRE_DEPOSIT_CAP = 5000 ether;
  uint256 public constant FEE_PERCENTAGE = 20_000; // Base 1e6
  uint256 public constant PREDEPOSIT_START_TIME = 1_742_839_200; // Monday 24th March 6pm UTC / 2pm
    // ET

  // Admin addresses
  address public governance = 0xdEF79F57b6be1DCeF06410C9Eb09537493cE52DC;
  address public securityCouncil = 0xb79AA9D27464dfb40200f24cDdCD230d2840e549;
  address public feeBeneficiary = 0xaE238D3acaBB8782c5D21d9952270fc0e7e44193;

  // Tokens
  address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
  address public constant USD = 0x0000000000000000000000000000000000000000;
  IERC20 public constant weEth = IERC20(0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A);
  IERC20 public constant ezEth = IERC20(0x2416092f143378750bb29b79eD961ab195CcEea5);
  IERC20 public constant cbEth = IERC20(0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22);
  IERC20 public constant weth = IERC20(0x4200000000000000000000000000000000000006);
  IERC20 public constant rEth = IERC20(0xB6fe221Fe9EeF5aBa221c348bA20A1Bf5e73624c);
  IERC20 public constant wstEth = IERC20(0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452);
  IERC20 public constant wrsEth = IERC20(0xEDfa23602D0EC14714057867A78d01e94176BEA0);
  IERC20 public constant couponToken = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913); // USDC

  // Chainlink price feeds
  address public constant ethUsdPriceFeed = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70; // The only
    // feed with USD as quote asset. Remaining are ETH quoted
  address public constant weEthPriceFeed = 0xFC1415403EbB0c693f9a7844b92aD2Ff24775C65;
  address public constant ezEthPriceFeed = 0x960BDD1dFD20d7c98fa482D793C3dedD73A113a3;
  address public constant cbEthPriceFeed = 0x806b4Ac04501c29769051e42783cF04dCE41440b;
  address public constant wstEthPriceFeed = 0x43a5C292A453A3bF3606fa856197f09D7B74251a;
  address public constant rEthPriceFeed = 0xf397bF97280B488cA19ee3093E81C0a77F02e9a5;
  address public constant wrsEthPriceFeed = 0xe8dD07CCf5BC4922424140E44Eb970F5950725ef;

  // Balancer contracts
  IVault public balancerVault = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
  IManagedPoolFactory public balancerManagedPoolFactory =
    IManagedPoolFactory(0x9a62C91626d39D0216b3959112f9D4678E20134d);

  // Aerodrome contracts
  address public constant aerodromeCLFactory = 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A;
  address public constant aerodromePositionManager = 0x827922686190790b37229fd06084350E74485b72;
}
