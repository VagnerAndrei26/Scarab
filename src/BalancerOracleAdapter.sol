// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Decimals} from "./lib/Decimals.sol";
import {OracleReader} from "./OracleReader.sol";
import {FixedPoint} from "./lib/balancer/FixedPoint.sol";
import {VaultReentrancyLib} from "./lib/balancer/VaultReentrancyLib.sol";
import {IVault} from "@balancer/contracts/interfaces/contracts/vault/IVault.sol";
import {IBalancerV2ManagedPool} from "./lib/balancer/IBalancerV2ManagedPool.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "@balancer/contracts/interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract BalancerOracleAdapter is
  Initializable,
  OwnableUpgradeable,
  UUPSUpgradeable,
  ReentrancyGuardUpgradeable,
  AggregatorV3Interface,
  OracleReader
{
  using Decimals for uint256;
  using FixedPoint for uint256;

  address public poolAddress;
  uint8 public decimals;

  error NotImplemented();
  error PriceTooLargeForIntConversion();
  error ZeroInvariant();

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Initializes the BalancerOracleAdapter.
   * This function is called once during deployment or upgrading to initialize state variables.
   * @param _poolAddress Address of the BALANCER Pool used for the oracle.
   * @param _decimals Number of decimals returned by the oracle.
   * @param _oracleFeeds Address of the OracleReader feeds contract, containing the Chainlink price
   * feeds for each asset in the pool.
   */
  function initialize(address _poolAddress, uint8 _decimals, address _oracleFeeds, address _owner) external initializer {
    __Ownable_init(_owner);
    __OracleReader_init(_oracleFeeds);
    __ReentrancyGuard_init();
    poolAddress = _poolAddress;
    decimals = _decimals;
  }

  /**
   * @dev Returns the number of decimals used by the oracle.
   * @return uint8 The number of decimals.
   */
  // function decimals() external view returns (uint8){
  //   return DECIMALS;
  // }

  /**
   * @dev Returns the description of the oracle.
   * @return string The description.
   */
  function description() external pure returns (string memory) {
    return "Balancer Pool Chainlink Adapter";
  }

  /**
   * @dev Returns the version of the oracle.
   * @return uint256 The version.
   */
  function version() external pure returns (uint256) {
    return 1;
  }

  /**
   * @dev Not implemented.
   */
  function getRoundData(uint80 /*_roundId*/ ) public pure returns (uint80, int256, uint256, uint256, uint80) {
    revert NotImplemented();
  }

  /**
   * @dev Returns the latest round data. Calls getRoundData with round ID 0.
   * @return roundId The round ID. Always 0 for this oracle.
   * @return answer The price.
   * @return startedAt The timestamp of the round.
   * @return updatedAt The timestamp of the round.
   * @return answeredInRound The round ID. Always 0 for this oracle.
   */
  function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
    IBalancerV2ManagedPool pool = IBalancerV2ManagedPool(poolAddress);
    VaultReentrancyLib.ensureNotInVaultContext(IVault(pool.getVault()));
    (IERC20[] memory tokens, uint256[] memory balances,) = IVault(pool.getVault()).getPoolTokens(pool.getPoolId());
    uint256[] memory scalingFactors = pool.getScalingFactors();

    //get weights
    uint256[] memory weights = pool.getNormalizedWeights(); // 18 dec fractions
    uint256[] memory prices = new uint256[](tokens.length - 1);
    uint8 oracleDecimals;

    for (uint8 i = 1; i < tokens.length; i++) {
      oracleDecimals = getOracleDecimals(address(tokens[i]), ETH);
      prices[i - 1] = getOraclePrice(address(tokens[i]), ETH).normalizeAmount(oracleDecimals, decimals);
    }

    // Scale up balances for invariant calculation
    balances = _removeFirstElement(balances);
    for (uint256 i = 0; i < balances.length; i++) {
      balances[i] = FixedPoint.mulDown(balances[i], scalingFactors[i]);
    }

    // Calculate invariant using WeightedMath
    uint256 invariant = _calculateInvariant(weights, balances);

    uint256 fairUintETHPrice = _calculateFairUintPrice(prices, weights, invariant, pool.getActualSupply());
    uint256 ethPrice = getOraclePrice(ETH, USD);

    uint256 fairUintUSDPrice = fairUintETHPrice * ethPrice / 10 ** getOracleDecimals(ETH, USD);

    if (fairUintUSDPrice > uint256(type(int256).max)) revert PriceTooLargeForIntConversion();

    return (uint80(0), int256(fairUintUSDPrice), block.timestamp, block.timestamp, uint80(0));
  }

  function getSingleAssetPrice(address quote, address base) public view returns (uint256) {
    return super.getOraclePrice(quote, base);
  }

  /**
   * @dev Calculates the fair price of the pool in USD using the Balancer invariant formula:
   * https://docs.balancer.fi/concepts/advanced/valuing-bpt/valuing-bpt.html#on-chain-price-evaluation.
   * @param prices Array of prices of the assets in the pool.
   * @param weights Array of weights of the assets in the pool.
   * @param invariant The invariant of the pool.
   * @param totalBPTSupply The total supply of BPT in the pool.
   * @return uint256 The fair price of the pool in USD.
   */
  function _calculateFairUintPrice(
    uint256[] memory prices,
    uint256[] memory weights,
    uint256 invariant,
    uint256 totalBPTSupply
  ) internal pure returns (uint256) {
    uint256 priceWeightPower = FixedPoint.ONE;
    for (uint8 i = 0; i < prices.length; i++) {
      priceWeightPower = priceWeightPower.mulDown(prices[i].divDown(weights[i]).powDown(weights[i]));
    }
    return invariant.mulDown(priceWeightPower).divDown(totalBPTSupply);
  }

  function _calculateInvariant(uint256[] memory normalizedWeights, uint256[] memory balances)
    internal
    pure
    returns (uint256 invariant)
  {
    invariant = FixedPoint.ONE;
    for (uint256 i = 0; i < normalizedWeights.length; i++) {
      invariant = invariant.mulDown(balances[i].powDown(normalizedWeights[i]));
    }

    if (invariant == 0) revert ZeroInvariant();

    return invariant;
  }

  function _removeFirstElement(uint256[] memory arr) public pure returns (uint256[] memory) {
    uint256[] memory newArr = new uint256[](arr.length - 1);
    for (uint256 i = 1; i < arr.length; i++) {
      newArr[i - 1] = arr[i];
    }
    return newArr;
  }

  function setBalancerPoolAddress(address _balancerPoolAddress) external onlyOwner {
    poolAddress = _balancerPoolAddress;
  }

  /**
   * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract.
   * Called by
   * {upgradeTo} and {upgradeToAndCall}.
   * @param newImplementation Address of the new implementation contract
   */
  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
