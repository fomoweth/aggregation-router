// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UniswapV2Adapter} from "src/adapters/UniswapV2Adapter.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseTest} from "test/shared/BaseTest.t.sol";

contract UniswapV2AdapterTest is BaseTest {
	using CurrencyLibrary for Currency;

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

		uint256 amountIn = deal(currencyIn, address(adapter), computeAmountIn(currencyIn, feed(), ethAmount));

		(bytes32 queryPath, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(toPool(queryPath), pool());
		assertGt(queryAmount, 0);

		uint256 quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		uint256 amountOut = adapter.uniswapV2Swap(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	function testSwap1For0OnUniswapV2() public {
		Currency currencyIn = currency1();
		Currency currencyOut = currency0();

		uint256 amountIn = deal(currencyIn, address(adapter), computeAmountIn(currencyIn, feed(), ethAmount));

		(bytes32 queryPath, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(toPool(queryPath), pool());
		assertGt(queryAmount, 0);

		uint256 quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		uint256 amountOut = adapter.uniswapV2Swap(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	function testSwap0For1AndUnwrapWETHOnUniswapV2() public {
		Currency currencyIn = currency0();
		Currency currencyOut = ETH;

		uint256 amountIn = deal(currencyIn, address(adapter), computeAmountIn(currencyIn, feed(), ethAmount));

		(bytes32 queryPath, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(toPool(queryPath), pool());
		assertGt(queryAmount, 0);

		uint256 quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		uint256 amountOut = adapter.uniswapV2Swap(queryPath);
		assertEq(amountOut, queryAmount);
		assertEq(address(adapter).balance, amountOut);
	}

	function testWrapETHAndSwap1For0OnUniswapV2() public {
		Currency currencyIn = ETH;
		Currency currencyOut = currency0();

		uint256 amountIn = deal(currencyIn, address(adapter), ethAmount);

		(bytes32 queryPath, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(toPool(queryPath), pool());
		assertGt(queryAmount, 0);

		uint256 quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		uint256 amountOut = adapter.uniswapV2Swap(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	// WBTC-WETH
	function pool() internal pure returns (address) {
		return 0xBb2b8038a1640196FbE3e38816F3e67Cba72D940;
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
