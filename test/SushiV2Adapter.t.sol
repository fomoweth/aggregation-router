// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SushiV2Adapter} from "src/adapters/SushiV2Adapter.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseTest} from "test/BaseTest.t.sol";

// forge test -vvv --match-path test/SushiV2Adapter.t.sol

contract SushiV2AdapterTest is BaseTest {
	using CurrencyLibrary for Currency;

	uint256 ethAmount = 20 ether;

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

		uint8 i = 0;
		uint8 j = 1;

		uint256 amountIn = computeAmountIn(currencyIn, feed(), ethAmount);
		deal(currencyIn, address(adapter), amountIn);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn, "!amountIn");

		(address pool, uint256 expected) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(pool, SUSHI_V2_SUSHI_ETH_POOL, "!pool");
		assertGt(expected, 0, "!expected");

		bytes32 data = pack(pool, i, j, NO_ACTION, NO_ACTION);

		uint256 amountOut = adapter.sushiV2Swap(data);
		assertEq(amountOut, expected, "!amountOut");
	}

	function testSwap1For0OnSushiSwapV2() public {
		Currency currencyIn = currency1();
		Currency currencyOut = currency0();

		uint8 i = 1;
		uint8 j = 0;

		uint256 amountIn = ethAmount;
		deal(currencyIn, address(adapter), amountIn);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn, "!amountIn");

		(address pool, uint256 expected) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(pool, SUSHI_V2_SUSHI_ETH_POOL, "!pool");
		assertGt(expected, 0, "!expected");

		bytes32 data = pack(pool, i, j, NO_ACTION, NO_ACTION);

		uint256 amountOut = adapter.sushiV2Swap(data);
		assertEq(amountOut, expected, "!amountOut");
	}

	function testSwap0For1unwrapWETHAfterOnSushiSwapV2() public {
		Currency currencyIn = currency0();
		Currency currencyOut = currency1();

		uint8 i = 0;
		uint8 j = 1;

		uint256 amountIn = computeAmountIn(currencyIn, feed(), ethAmount);
		deal(currencyIn, address(adapter), amountIn);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn, "!amountIn");

		(address pool, uint256 expected) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(pool, SUSHI_V2_SUSHI_ETH_POOL, "!pool");
		assertGt(expected, 0, "!expected");

		bytes32 data = pack(pool, i, j, NO_ACTION, UNWRAP_ETH);

		uint256 amountOut = adapter.sushiV2Swap(data);
		assertEq(amountOut, expected, "!amountOut");
	}

	function testSwap1For0WrapETHBeforeOnSushiSwapV2() public {
		Currency currencyIn = currency1();
		Currency currencyOut = currency0();

		uint8 i = 1;
		uint8 j = 0;

		uint256 amountIn = ethAmount;
		deal(address(adapter), amountIn);
		assertEq(address(adapter).balance, amountIn, "!amountIn");

		(address pool, uint256 expected) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(pool, SUSHI_V2_SUSHI_ETH_POOL, "!pool");
		assertGt(expected, 0, "!expected");

		bytes32 data = pack(pool, i, j, WRAP_ETH, NO_ACTION);

		uint256 amountOut = adapter.sushiV2Swap(data);
		assertEq(amountOut, expected, "!amountOut");
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