// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SushiV2Adapter} from "src/adapters/SushiV2Adapter.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseTest} from "test/shared/BaseTest.t.sol";

contract SushiV2AdapterTest is BaseTest {
	using CurrencyLibrary for Currency;

	SushiV2Adapter adapter;

	function setUp() public {
		fork();

		adapter = SushiV2Adapter(
			deployAdapter(
				"SUSHI_V2_ADAPTER",
				abi.encodePacked(type(SushiV2Adapter).creationCode, abi.encode(SUSHI_V2_ID, WETH))
			)
		);
	}

	function testSwap0For1OnSushiSwapV2() public {
		Currency currencyIn = currency0();
		Currency currencyOut = currency1();

		uint256 amountIn = computeAmountIn(currencyIn, feed(), ethAmount);
		deal(currencyIn, address(adapter), amountIn);

		(bytes32 queryPath, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(toPool(queryPath), pool());
		assertGt(queryAmount, 0);

		uint256 quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		uint256 amountOut = adapter.sushiV2Swap(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	function testSwap1For0OnSushiSwapV2() public {
		Currency currencyIn = currency1();
		Currency currencyOut = currency0();

		uint256 amountIn = deal(currencyIn, address(adapter), ethAmount);

		(bytes32 queryPath, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(toPool(queryPath), pool());
		assertGt(queryAmount, 0);

		uint256 quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		uint256 amountOut = adapter.sushiV2Swap(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	function testSwap0For1AndUnwrapWETHOnSushiSwapV2() public {
		Currency currencyIn = currency0();
		Currency currencyOut = ETH;

		uint256 amountIn = computeAmountIn(currencyIn, feed(), ethAmount);
		deal(currencyIn, address(adapter), amountIn);

		(bytes32 queryPath, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(toPool(queryPath), pool());
		assertGt(queryAmount, 0);

		uint256 quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		uint256 amountOut = adapter.sushiV2Swap(queryPath);
		assertEq(amountOut, quoteAmount);
		assertEq(address(adapter).balance, amountOut);
	}

	function testWrapETHAndSwap1For0OnSushiSwapV2() public {
		Currency currencyIn = ETH;
		Currency currencyOut = currency0();

		uint256 amountIn = deal(currencyIn, address(adapter), ethAmount);

		(bytes32 queryPath, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(toPool(queryPath), pool());
		assertGt(queryAmount, 0);

		uint256 quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		uint256 amountOut = adapter.sushiV2Swap(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	// SUSHI-WETH
	function pool() internal pure returns (address) {
		return 0x795065dCc9f64b5614C407a6EFDC400DA6221FB0;
	}

	function currency0() internal pure returns (Currency) {
		return SUSHI;
	}

	function currency1() internal pure returns (Currency) {
		return WETH;
	}

	function feed() internal pure returns (address) {
		return SUSHI_ETH_FEED;
	}
}
