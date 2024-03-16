// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PancakeV3Adapter} from "src/adapters/PancakeV3Adapter.sol";
import {PercentageMath} from "src/libraries/PercentageMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseTest} from "test/shared/BaseTest.t.sol";

contract PancakeV3AdapterTest is BaseTest {
	using CurrencyLibrary for Currency;
	using PercentageMath for uint256;

	uint256 ethAmount = 20 ether;

	PancakeV3Adapter adapter;

	function setUp() public {
		fork();

		adapter = PancakeV3Adapter(
			deployAdapter(
				"PANCAKESWAP_V3_ADAPTER",
				abi.encodePacked(type(PancakeV3Adapter).creationCode, abi.encode(PANCAKE_V3_ID, WETH))
			)
		);
	}

	function testSwap0For1OnPancakeSwapV3() public {
		Currency currencyIn = currency0();
		Currency currencyOut = currency1();

		uint256 amountIn = ethAmount;

		deal(currencyIn, address(adapter), amountIn);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn);

		(bytes32 queryPath, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(toPool(queryPath), pool());
		assertGt(queryAmount, 0);

		uint256 quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		uint256 amountOut = adapter.pancakeV3Swap(queryPath);
		assertApproxEqAbs(amountOut, quoteAmount, quoteAmount.percentMul(1));
	}

	function testSwap1For0OnPancakeSwapV3() public {
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

		uint256 amountOut = adapter.pancakeV3Swap(queryPath);
		assertApproxEqAbs(amountOut, quoteAmount, quoteAmount.percentMul(1));
	}

	function testWrapETHAndSwap0For1OnPancakeSwapV3() public {
		Currency currencyIn = ETH;
		Currency currencyOut = currency1();

		uint256 amountIn = ethAmount;

		deal(address(adapter), amountIn);
		assertEq(address(adapter).balance, amountIn);

		(bytes32 queryPath, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(toPool(queryPath), pool());
		assertGt(queryAmount, 0);

		uint256 quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		uint256 amountOut = adapter.pancakeV3Swap(queryPath);
		assertApproxEqAbs(amountOut, quoteAmount, quoteAmount.percentMul(1));
	}

	function testSwap1For0AndUnwrapWETHOnPancakeSwapV3() public {
		Currency currencyIn = currency1();
		Currency currencyOut = ETH;

		uint256 amountIn = computeAmountIn(currencyIn, feed(), ethAmount);

		deal(currencyIn, address(adapter), amountIn);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn);

		(bytes32 queryPath, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(toPool(queryPath), pool());
		assertGt(queryAmount, 0);

		uint256 quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		uint256 amountOut = adapter.pancakeV3Swap(queryPath);
		assertApproxEqAbs(amountOut, quoteAmount, quoteAmount.percentMul(1));
		assertEq(address(adapter).balance, amountOut);
	}

	// WETH-USDT/500
	function pool() internal pure returns (address) {
		return 0x6CA298D2983aB03Aa1dA7679389D955A4eFEE15C;
	}

	function currency0() internal pure returns (Currency) {
		return WETH;
	}

	function currency1() internal pure returns (Currency) {
		return USDT;
	}

	function feed() internal pure returns (address) {
		return USDT_ETH_FEED;
	}
}
