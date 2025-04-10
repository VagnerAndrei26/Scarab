// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Pool} from "./Pool.sol";
import {Auction} from "./Auction.sol";
import {BondToken} from "./BondToken.sol";
import {Decimals} from "./lib/Decimals.sol";
import {PoolFactory} from "./PoolFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract DistributorAdapter is Initializable, PausableUpgradeable, ReentrancyGuardUpgradeable {
  using SafeERC20 for IERC20;
  using Decimals for uint256;

  struct MerkleRootData {
    bytes32 merkleRoot;
    string ipfsHash;
  }

  // State variables
  PoolFactory public poolFactory;
  Pool public pool;
  mapping(uint256 => MerkleRootData[]) public submittedRoots;
  mapping(uint256 => MerkleRootData) public selectedRoots;
  mapping(address => mapping(uint256 => bool)) public hasClaimed; // user => period => claimed
  address[] public integratingContracts;

  // Events
  event MerkleRootSubmitted(address indexed submitter, uint256 indexed period, bytes32 merkleRoot, string ipfsHash);
  event MerkleRootSelected(uint256 indexed period, bytes32 merkleRoot, string ipfsHash);
  event IntegratingContractAdded(address indexed contractAddress, uint256 indexed period);
  event IntegratingContractRemoved(address indexed contractAddress, uint256 indexed period);
  event Claimed(address indexed user, uint256 indexed period, uint256 amount);

  // Errors
  error InvalidMerkleProof();
  error AlreadyClaimed();
  error AccessDenied();
  error InvalidPeriod();
  error NotEnoughBalance();
  error CallerIsNotPool();
  error AddressNotFound();
  error NotInBiddingPhase();
  error InvalidRootIndex();
  error RootAlreadySelected();
  error RootNotActive();
  error AuctionNotFinalized();

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(address _pool, address _poolFactory) public initializer {
    __ReentrancyGuard_init();
    __Pausable_init();

    pool = Pool(_pool);
    poolFactory = PoolFactory(_poolFactory);
  }

  /**
   * @dev Submit a merkle root for the latest completed period, where bond holders are incentivized to do so during the
   * bidding phase of the corresponding auction.
   * @param _merkleRoot The merkle root
   * @param _ipfsHash The ipfs hash containing full merkle tree
   */
  function submitMerkleRoot(bytes32 _merkleRoot, string calldata _ipfsHash) external whenNotPaused {
    // Posting lists only makes sense during bidding phase, so we enforce this
    uint256 lastPeriod = _currentPeriod() - 1;
    if (Auction(pool.auctions(lastPeriod)).state() != Auction.State.BIDDING) revert NotInBiddingPhase();

    submittedRoots[lastPeriod].push(MerkleRootData({merkleRoot: _merkleRoot, ipfsHash: _ipfsHash}));

    emit MerkleRootSubmitted(msg.sender, lastPeriod, _merkleRoot, _ipfsHash);
  }

  function selectMerkleRoot(uint256 rootIndex) external onlyGov whenNotPaused {
    uint256 lastPeriod = _currentPeriod() - 1;
    if (rootIndex >= submittedRoots[lastPeriod].length) revert InvalidRootIndex();

    MerkleRootData memory selectedRoot = submittedRoots[lastPeriod][rootIndex];
    selectedRoots[lastPeriod] = selectedRoot;

    emit MerkleRootSelected(lastPeriod, selectedRoot.merkleRoot, selectedRoot.ipfsHash);
  }

  function addIntegratingContract(address _address) external onlyGov {
    integratingContracts.push(_address);
    emit IntegratingContractAdded(_address, _currentPeriod());
  }

  function removeIntegratingContract(address _address) external onlyGov {
    for (uint256 i = 0; i < integratingContracts.length; i++) {
      if (integratingContracts[i] == _address) {
        integratingContracts[i] = integratingContracts[integratingContracts.length - 1];
        integratingContracts.pop();
        emit IntegratingContractRemoved(_address, _currentPeriod());
        return;
      }
    }
    revert AddressNotFound();
  }

  function claim(uint256 period, uint256 amount, bytes32[] calldata merkleProof)
    external
    nonReentrant
    whenNotPaused
    lastAuctionFinalized(period)
  {
    if (hasClaimed[msg.sender][period]) revert AlreadyClaimed();

    // Double hash as per OpenZeppelin guidelines
    bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, amount))));
    if (!MerkleProof.verify(merkleProof, selectedRoots[period].merkleRoot, leaf)) revert InvalidMerkleProof();

    if (IERC20(pool.couponToken()).balanceOf(address(this)) < amount) revert NotEnoughBalance();

    hasClaimed[msg.sender][period] = true;
    IERC20(pool.couponToken()).safeTransfer(msg.sender, amount);

    emit Claimed(msg.sender, amount, period);
  }

  function getDistributionAmount() external view returns (uint256 totalAmount) {
    BondToken bondToken = pool.bondToken();
    uint256 lastPeriod = _currentPeriod() - 1;

    for (uint256 i = 0; i < integratingContracts.length; i++) {
      address addr = integratingContracts[i];
      (, uint256 lastIndexedPeriodBalance) =
        bondToken.getIndexedUserAmount(addr, bondToken.balanceOf(addr), _currentPeriod());

      if (lastIndexedPeriodBalance > 0) {
        BondToken.PoolAmount[] memory poolAmount = bondToken.getPreviousPoolAmounts();
        totalAmount += (lastIndexedPeriodBalance * poolAmount[lastPeriod].sharesPerToken).normalizeAmount(
          bondToken.decimals() + bondToken.SHARES_DECIMALS(), bondToken.SHARES_DECIMALS()
        );
      }
    }
  }

  function _currentPeriod() internal view returns (uint256 currentPeriod) {
    (currentPeriod,) = pool.bondToken().globalPool();
  }

  function pause() external {
    if (!poolFactory.hasRole(poolFactory.SECURITY_COUNCIL_ROLE(), msg.sender)) revert AccessDenied();
    _pause();
  }

  function unpause() external {
    if (!poolFactory.hasRole(poolFactory.SECURITY_COUNCIL_ROLE(), msg.sender)) revert AccessDenied();
    _unpause();
  }

  modifier onlyGov() {
    if (!poolFactory.hasRole(poolFactory.GOV_ROLE(), msg.sender)) revert AccessDenied();
    _;
  }

  modifier lastAuctionFinalized(uint256 period) {
    uint256 lastPeriod = _currentPeriod() - 1;
    // If the period is the last period, we need to check if the auction is in bidding phase. Prior auctions are
    // guaranteed to be finalized
    if (period == lastPeriod && Auction(pool.auctions(lastPeriod)).state() == Auction.State.BIDDING) {
      revert AuctionNotFinalized();
    }
    _;
  }
}
