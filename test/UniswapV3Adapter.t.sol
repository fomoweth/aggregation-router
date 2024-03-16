// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UniswapV3Adapter} from "src/adapters/UniswapV3Adapter.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseTest} from "test/BaseTest.t.sol";

contract UniswapV3AdapterTest is BaseTest {
	using CurrencyLibrary for Currency;

	uint256 ethAmount = 20 ether;

	UniswapV3Adapter adapter;

	function setUp() public {
		fork();

		adapter = UniswapV3Adapter(
			deployAdapter(
				"UNISWAP_V3_ADAPTER",
				abi.encodePacked(type(UniswapV3Adapter).creationCode, abi.encode(UNISWAP_V3_ID, WETH))
			)
		);
	}

	function testSwap0For1OnUniswapV3() public {
		Currency currencyIn = currency0();
		Currency currencyOut = currency1();

		uint256 amountIn = computeAmountIn(currencyIn, feed(), ethAmount);

		deal(currencyIn, address(adapter), amountIn);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn);

		(bytes32 queryPath, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(toPool(queryPath), pool());
		assertGt(queryAmount, 0);

		uint256 quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		uint256 amountOut = adapter.uniswapV3Swap(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	function testSwap1For0OnUniswapV3() public {
		Currency currencyIn = currency1();
		Currency currencyOut = currency0();

		uint256 amountIn = computeAmountIn(currencyIn, feed(), ethAmount);

		deal(currencyIn, address(adapter), amountIn);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn);

		(bytes32 queryPath, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(toPool(queryPath), pool());
		assertGt(queryAmount, 0);

		uint256 quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		uint256 amountOut = adapter.uniswapV3Swap(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	function testSwap0For1AndUnwrapWETHOnUniswapV3() public {
		Currency currencyIn = currency0();
		Currency currencyOut = ETH;

		uint256 amountIn = computeAmountIn(currencyIn, feed(), ethAmount);

		deal(currencyIn, address(adapter), amountIn);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn);

		(bytes32 queryPath, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(toPool(queryPath), pool());
		assertGt(queryAmount, 0);

		uint256 quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		uint256 amountOut = adapter.uniswapV3Swap(queryPath);
		assertEq(amountOut, quoteAmount);
		assertEq(address(adapter).balance, amountOut);
	}

	function testWrapETHAndSwap1For0OnUniswapV3() public {
		Currency currencyIn = ETH;
		Currency currencyOut = currency0();

		uint256 amountIn = computeAmountIn(currencyIn, feed(), ethAmount);

		deal(address(adapter), amountIn);
		assertEq(address(adapter).balance, amountIn);

		(bytes32 queryPath, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(toPool(queryPath), pool());
		assertGt(queryAmount, 0);

		uint256 quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		uint256 amountOut = adapter.uniswapV3Swap(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	// WBTC-WETH/3000
	function pool() internal pure returns (address) {
		return 0xCBCdF9626bC03E24f779434178A73a0B4bad62eD;
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
