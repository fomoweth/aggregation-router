// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2 as console} from "forge-std/Test.sol";
import {UniswapV2Adapter} from "src/adapters/UniswapV2Adapter.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseTest} from "test/BaseTest.t.sol";

// forge test -vvv --match-path test/UniswapV2Adapter.t.sol

contract UniswapV2AdapterTest is BaseTest {
	using CurrencyLibrary for Currency;

	uint256 ethAmount = 20 ether;

	UniswapV2Adapter adapter;

	function setUp() public {
		fork();

		adapter = UniswapV2Adapter(
			deployAdapter(
				"UNISWAP_V2_ADAPTER",
				abi.encodePacked(type(UniswapV2Adapter).creationCode, abi.encode(UNISWAP_V2_ID, WETH))
			)
		);
	}

	function testSwap0For1OnUniswapV2() public {
		Currency currencyIn = currency0();
		Currency currencyOut = currency1();

		uint8 i = 0;
		uint8 j = 1;

		uint256 amountIn = computeAmountIn(currencyIn, feed(), ethAmount);

		deal(currencyIn, address(adapter), amountIn);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, pool());
		assertGt(queryAmount, 0);

		bytes32 path = pack(queryPool, i, j, NO_ACTION, NO_ACTION, false);

		uint256 amountOut = adapter.uniswapV2Swap(path);
		assertEq(amountOut, queryAmount);
	}

	function testSwap1For0OnUniswapV2() public {
		Currency currencyIn = currency1();
		Currency currencyOut = currency0();

		uint8 i = 1;
		uint8 j = 0;

		uint256 amountIn = computeAmountIn(currencyIn, feed(), ethAmount);

		deal(currencyIn, address(adapter), amountIn);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, pool());
		assertGt(queryAmount, 0);

		bytes32 path = pack(queryPool, i, j, NO_ACTION, NO_ACTION, false);

		uint256 amountOut = adapter.uniswapV2Swap(path);
		assertEq(amountOut, queryAmount);
	}

	function testSwap0For1UnwrapWETHAfterOnUniswapV2() public {
		Currency currencyIn = currency0();
		Currency currencyOut = currency1();

		uint8 i = 0;
		uint8 j = 1;

		uint256 amountIn = computeAmountIn(currencyIn, feed(), ethAmount);

		deal(currencyIn, address(adapter), amountIn);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, pool());
		assertGt(queryAmount, 0);

		bytes32 path = pack(queryPool, i, j, NO_ACTION, UNWRAP_ETH, false);

		uint256 amountOut = adapter.uniswapV2Swap(path);
		assertEq(amountOut, queryAmount);
	}

	function testSwap1For0WrapETHBeforeOnUniswapV2() public {
		Currency currencyIn = currency1();
		Currency currencyOut = currency0();

		uint8 i = 1;
		uint8 j = 0;

		uint256 amountIn = computeAmountIn(currencyIn, feed(), ethAmount);

		deal(address(adapter), amountIn);
		assertEq(address(adapter).balance, amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, pool());
		assertGt(queryAmount, 0);

		bytes32 path = pack(queryPool, i, j, WRAP_ETH, NO_ACTION, false);

		uint256 amountOut = adapter.uniswapV2Swap(path);
		assertEq(amountOut, queryAmount);
	}

	function pool() internal pure returns (address) {
		return UNI_V2_WBTC_ETH_POOL;
	}

	function currency0() internal pure returns (Currency) {
		return WBTC;
	}

	function currency1() internal pure returns (Currency) {
		return WETH;
	}

	function feed() internal pure returns (address) {
		return BTC_ETH_FEED;
	}
}
