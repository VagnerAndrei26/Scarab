// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {TestSetup, Pool} from "./TestSetup.sol";
import {IManagedPool} from "../../src/lib/balancer/IManagedPool.sol";
import {IAsset} from "@balancer/contracts/interfaces/contracts/vault/IAsset.sol";
import {IVault} from "@balancer/contracts/interfaces/contracts/vault/IVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BalancerRouterTest is Test, TestSetup {
  function setUp() public override {
    super.setUp();
    createPool();
  }

  function testJoinBalancerAndPlazaSingleAsset() public {
    vm.startPrank(user1);

    IAsset[] memory assets = _getAssets();
    uint256[] memory maxAmountsIn = new uint256[](allowedTokens.length + 1);
    maxAmountsIn[1] = 1 ether;

    // Calculate slippages
    bytes memory userData = abi.encode(1, _removeFirstElement(maxAmountsIn), 0);
    IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest({
      assets: assets,
      maxAmountsIn: maxAmountsIn,
      userData: userData,
      fromInternalBalance: false
    });

    // Quote for both steps, no slippage assumed
    (uint256 bptOut,) = balancerQueries.queryJoin(
      IManagedPool(balancerPool).getPoolId(), address(balancerRouter), address(balancerRouter), request
    );
    uint256 levOut = pool.simulateCreate(Pool.TokenType.LEVERAGE, bptOut);

    // Apply slippage
    userData = abi.encode(1, _removeFirstElement(maxAmountsIn), bptOut * 98 / 100);

    uint256 levAmountBefore = leverageToken.balanceOf(user1);
    balancerRouter.joinBalancerAndPlaza(
      IManagedPool(balancerPool).getPoolId(),
      address(pool),
      assets,
      maxAmountsIn,
      userData,
      Pool.TokenType.LEVERAGE,
      levOut * 98 / 100,
      block.timestamp + 3600
    );
    uint256 levAmountAfter = leverageToken.balanceOf(user1);
    assertApproxEqRel(levAmountAfter - levAmountBefore, levOut, 0.02e18);

    vm.stopPrank();
  }

  function testJoinBalancerAndPlazaSomeAssets() public {
    vm.startPrank(user1);

    IAsset[] memory assets = _getAssets();
    uint256[] memory maxAmountsIn = new uint256[](allowedTokens.length + 1);
    maxAmountsIn[1] = 1 ether;
    maxAmountsIn[2] = 1 ether;

    // Calculate slippages
    bytes memory userData = abi.encode(1, _removeFirstElement(maxAmountsIn), 0);
    IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest({
      assets: assets,
      maxAmountsIn: maxAmountsIn,
      userData: userData,
      fromInternalBalance: false
    });

    // Quote for both steps, no slippage assumed
    (uint256 bptOut,) = balancerQueries.queryJoin(
      IManagedPool(balancerPool).getPoolId(), address(balancerRouter), address(balancerRouter), request
    );
    uint256 levOut = pool.simulateCreate(Pool.TokenType.LEVERAGE, bptOut);

    // Apply slippage
    userData = abi.encode(1, _removeFirstElement(maxAmountsIn), bptOut * 98 / 100);

    uint256 levAmountBefore = leverageToken.balanceOf(user1);
    balancerRouter.joinBalancerAndPlaza(
      IManagedPool(balancerPool).getPoolId(),
      address(pool),
      assets,
      maxAmountsIn,
      userData,
      Pool.TokenType.LEVERAGE,
      levOut * 98 / 100,
      block.timestamp + 3600
    );
    uint256 levAmountAfter = leverageToken.balanceOf(user1);
    assertApproxEqRel(levAmountAfter - levAmountBefore, levOut, 0.02e18);

    vm.stopPrank();
  }

  function testJoinBalancerAndPlazaAllAssets() public {
    vm.startPrank(user1);

    IAsset[] memory assets = _getAssets();
    uint256[] memory maxAmountsIn = new uint256[](allowedTokens.length + 1);
    for (uint256 i = 1; i < allowedTokens.length; i++) {
      maxAmountsIn[i] = 1 ether;
    }

    // Calculate slippages
    bytes memory userData = abi.encode(1, _removeFirstElement(maxAmountsIn), 0);
    IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest({
      assets: assets,
      maxAmountsIn: maxAmountsIn,
      userData: userData,
      fromInternalBalance: false
    });

    // Quote for both steps, no slippage assumed
    (uint256 bptOut,) = balancerQueries.queryJoin(
      IManagedPool(balancerPool).getPoolId(), address(balancerRouter), address(balancerRouter), request
    );
    uint256 levOut = pool.simulateCreate(Pool.TokenType.LEVERAGE, bptOut);

    // Apply slippage
    userData = abi.encode(1, _removeFirstElement(maxAmountsIn), bptOut * 98 / 100);

    uint256 levAmountBefore = leverageToken.balanceOf(user1);
    balancerRouter.joinBalancerAndPlaza(
      IManagedPool(balancerPool).getPoolId(),
      address(pool),
      assets,
      maxAmountsIn,
      userData,
      Pool.TokenType.LEVERAGE,
      levOut * 98 / 100,
      block.timestamp + 3600
    );
    uint256 levAmountAfter = leverageToken.balanceOf(user1);
    assertApproxEqRel(levAmountAfter - levAmountBefore, levOut, 0.02e18);

    vm.stopPrank();
  }

  function testExitPlazaAndBalancerSingleAsset() public {
    vm.startPrank(user1);

    IAsset[] memory assets = _getAssets();
    uint256 chosenAssetIndex = 1;
    address chosenAsset = address(assets[chosenAssetIndex]);
    uint256 plazaTokenToRedeem = 1 ether;

    // Calculate slippages
    uint256 bptOut = pool.simulateRedeem(Pool.TokenType.LEVERAGE, plazaTokenToRedeem);
    bytes memory userData = abi.encode(0, bptOut, chosenAssetIndex - 1); // Single asset exit,
      // requesting cbEth

    IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest({
      assets: assets,
      minAmountsOut: new uint256[](3),
      userData: userData,
      toInternalBalance: false
    });

    (, uint256[] memory amountsOut) =
      balancerQueries.queryExit(balancerPool.getPoolId(), address(balancerRouter), address(balancerRouter), request);

    // Apply slippage
    bptOut = bptOut * 98 / 100;
    uint256[] memory minAmountsOut = new uint256[](assets.length);
    minAmountsOut[chosenAssetIndex] = amountsOut[chosenAssetIndex] * 98 / 100; // amountsOut[0] and
      // amountsOut[2] are 0

    leverageToken.approve(address(balancerRouter), type(uint256).max);
    uint256 chosenAssetAmountBefore = IERC20(chosenAsset).balanceOf(user1);
    balancerRouter.exitPlazaAndBalancer(
      balancerPool.getPoolId(),
      address(pool),
      assets,
      plazaTokenToRedeem,
      minAmountsOut,
      userData,
      Pool.TokenType.LEVERAGE,
      bptOut
    );
    uint256 chosenAssetAmountAfter = IERC20(chosenAsset).balanceOf(user1);
    assertApproxEqRel(chosenAssetAmountAfter - chosenAssetAmountBefore, amountsOut[chosenAssetIndex], 0.02e18);
  }

  /// forge-config: default.fuzz.runs = 10
  function testDeposit(uint256 tokenIndex) public {
    tokenIndex = bound(tokenIndex, 0, allowedTokens.length - 1);
    vm.startPrank(user1);

    IERC20 token = IERC20(allowedTokens[tokenIndex]);
    token.approve(address(balancerRouter), type(uint256).max);
    uint256 amount = 2 ether;
    Pool.TokenType tokenType = Pool.TokenType.BOND;

    vm.expectEmit(true, true, true, false); // We haven't calculated the expected amountOut of plaza tokens, so skip
      // checking event data
    emit Pool.TokensCreated(address(balancerRouter), address(user1), tokenType, amount, 0);
    balancerRouter.deposit(address(pool), address(token), amount, tokenType, 0);

    tokenType = Pool.TokenType.LEVERAGE;
    vm.expectEmit(true, true, true, false);
    emit Pool.TokensCreated(address(balancerRouter), address(user1), tokenType, amount, 0);
    balancerRouter.deposit(address(pool), address(token), amount, tokenType, 0);
  }

  /// forge-config: default.fuzz.runs = 10
  function testWithdraw(uint256 tokenIndex) public {
    tokenIndex = bound(tokenIndex, 0, allowedTokens.length - 1);
    address token = allowedTokens[tokenIndex];

    vm.startPrank(user1);

    Pool.TokenType tokenType = Pool.TokenType.BOND;
    IERC20 plazaToken = pool.bondToken();
    plazaToken.approve(address(balancerRouter), type(uint256).max);
    uint256 amount = plazaToken.balanceOf(user1) / 100; // 1% of balance

    vm.expectEmit(true, true, true, false);
    emit Pool.TokensRedeemed(address(balancerRouter), address(balancerRouter), tokenType, amount, 0);
    balancerRouter.withdraw(address(pool), tokenType, amount, token, 0);

    tokenType = Pool.TokenType.LEVERAGE;
    plazaToken = pool.lToken();
    plazaToken.approve(address(balancerRouter), type(uint256).max);
    amount = plazaToken.balanceOf(user1) / 100; // 1% of balance

    vm.expectEmit(true, true, true, false);
    emit Pool.TokensRedeemed(address(balancerRouter), address(balancerRouter), tokenType, amount, 0);
    balancerRouter.withdraw(address(pool), tokenType, amount, token, 0);
  }

  /// forge-config: default.fuzz.runs = 10
  function testDepositWithCalculatedSlippage(uint256 tokenIndex) public {
    vm.startPrank(user1);
    tokenIndex = bound(tokenIndex, 0, allowedTokens.length - 1);
    IERC20 token = IERC20(allowedTokens[tokenIndex]);
    token.approve(address(balancerRouter), type(uint256).max);

    Pool.TokenType tokenType = Pool.TokenType.BOND;
    IAsset[] memory assets = _getAssets();
    uint256[] memory maxAmountsIn = new uint256[](allowedTokens.length + 1);
    uint256 amount = 2 ether;
    maxAmountsIn[tokenIndex + 1] = amount; // tokenIndex+1 as array includes the balancer pool token

    // Calculate slippages
    bytes memory userData = abi.encode(1, _removeFirstElement(maxAmountsIn), 0);
    IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest({
      assets: assets,
      maxAmountsIn: maxAmountsIn,
      userData: userData,
      fromInternalBalance: false
    });

    // Quote for both steps
    (uint256 bptOut,) = balancerQueries.queryJoin(
      IManagedPool(balancerPool).getPoolId(), address(balancerRouter), address(balancerRouter), request
    );

    uint256 bondOut = pool.simulateCreate(Pool.TokenType.BOND, bptOut);

    uint256 bondBalanceBefore = IERC20(pool.bondToken()).balanceOf(user1);
    balancerRouter.deposit(address(pool), address(token), amount, tokenType, bondOut * 999 / 1000); // Allow 0.1%
      // slippage due to eth price change between simulateCreate and deposit
    uint256 bondBalanceAfter = IERC20(pool.bondToken()).balanceOf(user1);
    assertApproxEqRel(bondBalanceAfter - bondBalanceBefore, bondOut, 0.001e18); // Allow 0.1% difference in actual
      // amount
      // due to eth price change between simulateCreate and deposit
    console.log("bondBalance: %s", bondBalanceAfter - bondBalanceBefore);
    vm.stopPrank();
  }

  function testWithdrawWithCalculatedSlippage() public {
    uint256 tokenIndex = 2;
    tokenIndex = bound(tokenIndex, 0, allowedTokens.length - 1);
    vm.startPrank(user1);

    address token = allowedTokens[tokenIndex];
    uint256 plazaTokensToRedeem = pool.lToken().balanceOf(user1) / 100; // 1% of balance

    // Calculate slippages
    uint256 bptOut = pool.simulateRedeem(Pool.TokenType.LEVERAGE, plazaTokensToRedeem);
    bytes memory userData = abi.encode(0, bptOut, tokenIndex);

    IAsset[] memory assets = _getAssets();
    IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest({
      assets: assets,
      minAmountsOut: new uint256[](allowedTokens.length + 1),
      userData: userData,
      toInternalBalance: false
    });

    (, uint256[] memory amountsOut) =
      balancerQueries.queryExit(balancerPool.getPoolId(), address(balancerRouter), address(balancerRouter), request);

    console.log("amountsOut length: %s", amountsOut.length);
    for (uint256 i = 0; i < amountsOut.length; i++) {
      console.log("amountsOut[%s]: %s", i, amountsOut[i]);
    }
    uint256 minTokenOut = amountsOut[tokenIndex + 1];
    console.log("minTokenOut: %s", minTokenOut);

    uint256 tokenBalanceBefore = IERC20(token).balanceOf(user1);
    pool.lToken().approve(address(balancerRouter), type(uint256).max);
    balancerRouter.withdraw(
      address(pool), Pool.TokenType.LEVERAGE, plazaTokensToRedeem, token, minTokenOut * 999 / 1000
    ); // Allow 0.1% difference as before
    uint256 tokenBalanceAfter = IERC20(token).balanceOf(user1);
    console.log("tokenBalanceAfter: %s", tokenBalanceAfter);
    console.log("tokenBalanceBefore: %s", tokenBalanceBefore);
    assertApproxEqRel(tokenBalanceAfter - tokenBalanceBefore, minTokenOut, 0.001e18);
  }

  function _getAssets() internal returns (IAsset[] memory) {
    IAsset[] memory assets = new IAsset[](allowedTokens.length + 1);
    assets[0] = IAsset(address(balancerPool));
    for (uint256 i = 0; i < allowedTokens.length; i++) {
      assets[i + 1] = IAsset(allowedTokens[i]);
      IERC20(allowedTokens[i]).approve(address(balancerRouter), type(uint256).max);
    }
    return assets;
  }

  function _removeFirstElement(uint256[] memory array) internal pure returns (uint256[] memory) {
    uint256[] memory newArray = new uint256[](array.length - 1);
    for (uint256 i = 1; i < array.length; i++) {
      newArray[i - 1] = array[i];
    }
    return newArray;
  }
}
