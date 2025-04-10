// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import {Pool} from "../../src/Pool.sol";
import {Token} from "../mocks/Token.sol";
import {Auction} from "../../src/Auction.sol";
import {Utils} from "../../src/lib/Utils.sol";
import {BondToken} from "../../src/BondToken.sol";
import {LeverageToken} from "../../src/LeverageToken.sol";
import {Distributor} from "../../src/Distributor.sol";
import {DistributorAdapter} from "../../src/DistributorAdapter.sol";
import {PoolFactory} from "../../src/PoolFactory.sol";
import {Deployer} from "../../src/utils/Deployer.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract DistributorAdapterTest is Test {
  DistributorAdapter public adapter;
  Pool public pool;
  PoolFactory public poolFactory;
  PoolFactory.PoolParams private params;
  Token public couponToken;
  Token public reserveToken;

  address public user1 = address(0x1111);
  address public user2 = address(0x2222);
  address public user3 = address(0x3333);
  address public user4 = address(0x4444);
  address private deployer = address(0x2);
  address private governance = address(0x3);
  address private securityCouncil = address(0x4);
  address public constant ethPriceFeed = address(0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70);

  bytes32 public constant merkleRoot = bytes32(uint256(1));
  string public constant ipfsHash = "some-ipfs-hash";

  uint256 public constant reserveAmount = 10_000 ether;
  uint256 public constant bondAmount = 5000 ether;
  uint256 public constant levAmount = 5000 ether;
  uint256 public constant auctionPeriod = 10 days;

  function setUp() public {
    vm.startPrank(deployer);

    // Deploy contracts
    address contractDeployer = address(new Deployer());

    // Deploy beacons
    address poolBeacon = address(new UpgradeableBeacon(address(new Pool()), governance));
    address bondBeacon = address(new UpgradeableBeacon(address(new BondToken()), governance));
    address levBeacon = address(new UpgradeableBeacon(address(new LeverageToken()), governance));
    address distributorBeacon = address(new UpgradeableBeacon(address(new Distributor()), governance));
    address adapterBeacon = address(new UpgradeableBeacon(address(new DistributorAdapter()), governance));

    // Deploy PoolFactory
    poolFactory = PoolFactory(
      Utils.deploy(
        address(new PoolFactory()),
        abi.encodeCall(
          PoolFactory.initialize,
          (governance, contractDeployer, ethPriceFeed, poolBeacon, bondBeacon, levBeacon, distributorBeacon)
        )
      )
    );

    poolFactory.setDistributorAdapterBeacon(adapterBeacon);

    vm.stopPrank();

    // Setup pool parameters
    vm.startPrank(governance);
    poolFactory.grantRole(poolFactory.POOL_ROLE(), governance);

    params.fee = 0;
    params.sharesPerToken = 2_500_000;
    reserveToken = new Token("Wrapped ETH", "WETH", false);
    params.reserveToken = address(reserveToken);
    params.distributionPeriod = 0;
    couponToken = new Token("Circle USD", "USDC", false);
    params.couponToken = address(couponToken);

    // Create pool
    reserveToken.mint(governance, reserveAmount);
    reserveToken.approve(address(poolFactory), reserveAmount);

    pool = Pool(poolFactory.createPool(params, reserveAmount, bondAmount, levAmount, "", "", "", "", false));

    adapter = DistributorAdapter(poolFactory.distributorAdapters(address(pool)));
    pool.setAuctionPeriod(auctionPeriod);
    vm.stopPrank();

    vm.startPrank(address(pool));
    Pool.PoolInfo memory info = pool.getPoolInfo();
    vm.warp(info.lastDistribution + info.distributionPeriod + 1);
    vm.stopPrank();
  }

  function testSubmitMerkleRoot() public {
    // Start auction to enter bidding phase
    vm.startPrank(address(pool));
    pool.startAuction();
    vm.stopPrank();

    vm.startPrank(user1);
    bytes32 root = bytes32(uint256(1234));
    adapter.submitMerkleRoot(root, ipfsHash);

    (bytes32 submittedRoot,) = adapter.submittedRoots(0, 0);
    assertEq(submittedRoot, root);
    vm.stopPrank();
  }

  function testSubmitMerkleRootNotInBiddingPhase() public {
    vm.startPrank(user1);
    pool.startAuction();
    Pool.PoolInfo memory info = pool.getPoolInfo();
    vm.warp(info.lastDistribution + auctionPeriod + 1);
    Auction auction = Auction(pool.auctions(0));
    auction.endAuction();
    vm.expectRevert(DistributorAdapter.NotInBiddingPhase.selector);
    adapter.submitMerkleRoot(merkleRoot, ipfsHash);
    vm.stopPrank();
  }

  function testSelectMerkleRoot() public {
    // Start auction and submit a root
    vm.startPrank(address(pool));
    pool.startAuction();
    vm.stopPrank();

    vm.startPrank(user1);
    adapter.submitMerkleRoot(merkleRoot, ipfsHash);
    vm.stopPrank();

    // Select the root as governance
    vm.startPrank(governance);
    adapter.selectMerkleRoot(0);
    vm.stopPrank();

    // Verify selection
    (bytes32 selectedRoot, string memory selectedHash) = adapter.selectedRoots(0);
    assertEq(selectedRoot, merkleRoot);
    assertEq(selectedHash, ipfsHash);
  }

  function testSelectMerkleRootNotGovernance() public {
    vm.startPrank(user1);
    vm.expectRevert(DistributorAdapter.AccessDenied.selector);
    adapter.selectMerkleRoot(0);
    vm.stopPrank();
  }

  function testAddAndRemoveIntegratingContracts() public {
    address testContract = address(0x123);

    // Add contract
    vm.startPrank(governance);
    adapter.addIntegratingContract(testContract);

    // Verify addition
    assertEq(adapter.integratingContracts(0), testContract);

    // Remove contract
    adapter.removeIntegratingContract(testContract);

    // Verify removal
    vm.expectRevert();
    adapter.integratingContracts(0);
    vm.stopPrank();
  }

  function testRemoveNonExistentContract() public {
    vm.startPrank(governance);
    vm.expectRevert(DistributorAdapter.AddressNotFound.selector);
    adapter.removeIntegratingContract(address(0x123));
    vm.stopPrank();
  }

  function testClaim() public {
    // Create 4 leaves
    bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(user1, uint256(100 ether)))));
    bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(user2, uint256(200 ether)))));
    bytes32 leaf3 = keccak256(bytes.concat(keccak256(abi.encode(user3, uint256(300 ether)))));
    bytes32 leaf4 = keccak256(bytes.concat(keccak256(abi.encode(user4, uint256(400 ether)))));

    // Hash pairs of leaves to get intermediate nodes
    bytes32 node1 = leaf1 < leaf2 ? keccak256(abi.encode(leaf1, leaf2)) : keccak256(abi.encode(leaf2, leaf1));

    bytes32 node2 = leaf3 < leaf4 ? keccak256(abi.encode(leaf3, leaf4)) : keccak256(abi.encode(leaf4, leaf3));

    // Hash the intermediate nodes to get root
    bytes32 root = node1 < node2 ? keccak256(abi.encode(node1, node2)) : keccak256(abi.encode(node2, node1));

    // Create proof for leaf1 (will need leaf2 and node2)
    bytes32[] memory proof = new bytes32[](2);
    proof[0] = leaf2; // Sibling at leaf level
    proof[1] = node2; // Sibling at intermediate level

    // Start auction and submit root
    vm.startPrank(address(pool));
    pool.startAuction();
    vm.stopPrank();

    vm.startPrank(user1);
    adapter.submitMerkleRoot(root, ipfsHash);
    vm.stopPrank();

    // Select root as governance
    vm.startPrank(governance);
    adapter.selectMerkleRoot(0);
    vm.stopPrank();

    _doAuction();

    // Activate root via pool
    vm.startPrank(address(pool));

    // Fund the adapter with USDC
    couponToken.mint(address(adapter), 1000 ether);
    vm.stopPrank();

    // Claim as user
    vm.startPrank(user1);
    adapter.claim(0, 100 ether, proof);

    // Verify claim
    assertEq(couponToken.balanceOf(user1), 100 ether);
    assertTrue(adapter.hasClaimed(user1, 0));
    vm.stopPrank();
  }

  function testClaimInvalidProof() public {
    // Create 4 leaves
    bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(user1, uint256(100 ether)))));
    bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(user2, uint256(200 ether)))));
    bytes32 leaf3 = keccak256(bytes.concat(keccak256(abi.encode(user3, uint256(300 ether)))));
    bytes32 leaf4 = keccak256(bytes.concat(keccak256(abi.encode(user4, uint256(400 ether)))));

    // Hash pairs of leaves to get intermediate nodes
    bytes32 node1 = leaf1 < leaf2 ? keccak256(abi.encode(leaf1, leaf2)) : keccak256(abi.encode(leaf2, leaf1));

    bytes32 node2 = leaf3 < leaf4 ? keccak256(abi.encode(leaf3, leaf4)) : keccak256(abi.encode(leaf4, leaf3));

    // Hash the intermediate nodes to get root
    bytes32 root = node1 < node2 ? keccak256(abi.encode(node1, node2)) : keccak256(abi.encode(node2, node1));

    // Create invalid proof
    bytes32[] memory proof = new bytes32[](2);
    proof[0] = bytes32(uint256(1)); // Wrong sibling
    proof[1] = bytes32(uint256(2)); // Wrong intermediate node

    vm.startPrank(address(pool));
    pool.startAuction();
    vm.stopPrank();

    vm.startPrank(user1);
    adapter.submitMerkleRoot(root, ipfsHash);
    vm.stopPrank();

    vm.startPrank(governance);
    adapter.selectMerkleRoot(0);
    vm.stopPrank();

    _doAuction();

    vm.startPrank(address(pool));
    couponToken.mint(address(adapter), 1000 ether);
    vm.stopPrank();

    vm.startPrank(user1);
    vm.expectRevert(DistributorAdapter.InvalidMerkleProof.selector);
    adapter.claim(0, 100 ether, proof);
    vm.stopPrank();
  }

  function testGetDistributionAmount() public {
    // Add users as integrating contracts
    vm.startPrank(governance);
    adapter.addIntegratingContract(user1);
    adapter.addIntegratingContract(user2);
    adapter.addIntegratingContract(user3);
    adapter.addIntegratingContract(user4);

    // Transfer bond tokens to users
    BondToken bondToken = pool.bondToken();

    bondToken.transfer(user1, 100 ether);
    bondToken.transfer(user2, 200 ether);
    bondToken.transfer(user3, 300 ether);
    bondToken.transfer(user4, 400 ether);
    vm.stopPrank();

    // Start auction
    vm.startPrank(address(pool));
    pool.startAuction();
    vm.stopPrank();

    // Complete successful auction
    _doAuction();

    uint256 totalBondsByIntengratingContracts = 100 ether + 200 ether + 300 ether + 400 ether;
    uint256 expectedAmount = totalBondsByIntengratingContracts * params.sharesPerToken / 1e18;

    uint256 distributionAmount = adapter.getDistributionAmount();
    assertEq(distributionAmount, expectedAmount);
  }

  function _doAuction() internal {
    Auction auction = Auction(pool.auctions(0));
    vm.startPrank(governance);
    uint256 totalBuyCouponAmount = auction.totalBuyCouponAmount();
    couponToken.mint(governance, totalBuyCouponAmount);
    couponToken.approve(address(auction), totalBuyCouponAmount);
    auction.bid(1, totalBuyCouponAmount);
    vm.warp(block.timestamp + auctionPeriod);
    auction.endAuction();
  }
}
