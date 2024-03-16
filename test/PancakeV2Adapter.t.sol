// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PancakeV2Adapter} from "src/adapters/PancakeV2Adapter.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseTest} from "test/BaseTest.t.sol";

contract PancakeV2AdapterTest is BaseTest {
	using CurrencyLibrary for Currency;

	uint256 ethAmount = 20 ether;

	PancakeV2Adapter adapter;

	function setUp() public {
		fork();

		adapter = PancakeV2Adapter(
			deployAdapter(
				"PANCAKESWAP_V2_ADAPTER",
				abi.encodePacked(type(PancakeV2Adapter).creationCode, abi.encode(PANCAKE_V2_ID, WETH))
			)
		);
	}

	function testSwap0For1OnPancakeSwapV2() public {
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

		uint256 amountOut = adapter.pancakeV2Swap(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	function testSwap1For0OnPancakeSwapV2() public {
		Currency currencyIn = currency1();
		Currency currencyOut = currency0();

		uint256 amountIn = deal(currencyIn, address(adapter), ethAmount);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn);

		(bytes32 queryPath, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(toPool(queryPath), pool());
		assertGt(queryAmount, 0);

		uint256 quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		uint256 amountOut = adapter.pancakeV2Swap(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	function testSwap0For1AndUnwrapWETHOnPancakeSwapV2() public {
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

		uint256 amountOut = adapter.pancakeV2Swap(queryPath);
		assertEq(amountOut, quoteAmount);
		assertEq(address(adapter).balance, amountOut);
	}

	function testWrapETHAndSwap1For0OnPancakeSwapV2() public {
		Currency currencyIn = ETH;
		Currency currencyOut = currency0();

		uint256 amountIn = ethAmount;

		deal(address(adapter), amountIn);
		assertEq(address(adapter).balance, amountIn);

		(bytes32 queryPath, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(toPool(queryPath), pool());
		assertGt(queryAmount, 0);

		uint256 quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		uint256 amountOut = adapter.pancakeV2Swap(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	// WBTC-WETH
	function pool() internal pure returns (address) {
		return 0x4AB6702B3Ed3877e9b1f203f90cbEF13d663B0e8;
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
