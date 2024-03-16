// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FraxSwapV2Adapter} from "src/adapters/FraxSwapV2Adapter.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseTest} from "test/shared/BaseTest.t.sol";

contract FraxSwapV2AdapterTest is BaseTest {
	using CurrencyLibrary for Currency;

	uint256 ethAmount = 20 ether;

	FraxSwapV2Adapter adapter;

	function setUp() public {
		fork();

		adapter = FraxSwapV2Adapter(
			deployAdapter(
				"FRAXSWAP_V2_ADAPTER",
				abi.encodePacked(type(FraxSwapV2Adapter).creationCode, abi.encode(FRAX_V2_ID, WETH))
			)
		);
	}

	function testSwap0For1OnFraxSwapV2() public {
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

		uint256 amountOut = adapter.fraxV2Swap(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	function testSwap1For0OnFraxSwapV2() public {
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

		uint256 amountOut = adapter.fraxV2Swap(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	function testSwap0For1AndUnwrapWETHOnFraxSwapV2() public {
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

		uint256 amountOut = adapter.fraxV2Swap(queryPath);
		assertEq(amountOut, quoteAmount);
		assertEq(address(adapter).balance, amountOut);
	}

	function testWrapETHAndSwap1For0OnFraxSwapV2() public {
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

		uint256 amountOut = adapter.fraxV2Swap(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	// FRAX-WETH
	function pool() internal pure returns (address) {
		return 0x31351Bf3fba544863FBff44DDC27bA880916A199;
	}

	function currency0() internal pure returns (Currency) {
		return FRAX;
	}

	function currency1() internal pure returns (Currency) {
		return WETH;
	}

	function feed() internal pure returns (address) {
		return FRAX_ETH_FEED;
	}
}
