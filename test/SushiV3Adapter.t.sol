// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2 as console} from "forge-std/Test.sol";
import {SushiV3Adapter} from "src/adapters/SushiV3Adapter.sol";
import {PercentageMath} from "src/libraries/PercentageMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseTest} from "test/BaseTest.t.sol";

// forge test -vvv --match-path test/SushiV3Adapter.t.sol

contract SushiV3AdapterTest is BaseTest {
	using CurrencyLibrary for Currency;
	using PercentageMath for uint256;

	uint256 ethAmount = 20 ether;

	SushiV3Adapter adapter;

	function setUp() public {
		fork();

		adapter = SushiV3Adapter(
			deployAdapter(
				"SUSHI_V3_ADAPTER",
				abi.encodePacked(type(SushiV3Adapter).creationCode, abi.encode(SUSHI_V3_ID, WETH))
			)
		);
	}

	function testSwap0For1OnSushiSwapV3() public {
		Currency currencyIn = currency0();
		Currency currencyOut = currency1();

		uint8 i = 0;
		uint8 j = 1;

		uint256 amountIn = computeAmountIn(currencyIn, feed(), ethAmount);

		deal(currencyIn, address(adapter), amountIn);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn, "!amountIn");

		(address pool, uint256 expected) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(pool, SUSHI_V3_SUSHI_ETH_3000_POOL, "!pool");
		assertGt(expected, 0, "!expected");

		bytes32 data = pack(pool, i, j, NO_ACTION, NO_ACTION);

		uint256 amountOut = adapter.sushiV3Swap(data);
		assertApproxEqAbs(amountOut, expected, expected.percentMul(1), "!amountOut");
	}

	function testSwap1For0OnSushiSwapV3() public {
		Currency currencyIn = currency1();
		Currency currencyOut = currency0();

		uint8 i = 1;
		uint8 j = 0;

		uint256 amountIn = computeAmountIn(currencyIn, feed(), ethAmount);

		deal(currencyIn, address(adapter), amountIn);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn, "!amountIn");

		(address pool, uint256 expected) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(pool, SUSHI_V3_SUSHI_ETH_3000_POOL, "!pool");
		assertGt(expected, 0, "!expected");

		bytes32 data = pack(pool, i, j, NO_ACTION, NO_ACTION);

		uint256 amountOut = adapter.sushiV3Swap(data);
		assertApproxEqAbs(amountOut, expected, expected.percentMul(1), "!amountOut");
	}

	function testSwap0For1unwrapWETHAfterOnSushiSwapV3() public {
		Currency currencyIn = currency0();
		Currency currencyOut = currency1();

		uint8 i = 0;
		uint8 j = 1;

		uint256 amountIn = computeAmountIn(currency0(), feed(), ethAmount);

		deal(currencyIn, address(adapter), amountIn);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn, "!amountIn");

		(address pool, uint256 expected) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(pool, SUSHI_V3_SUSHI_ETH_3000_POOL, "!pool");
		assertGt(expected, 0, "!expected");

		bytes32 data = pack(pool, i, j, NO_ACTION, UNWRAP_ETH);

		uint256 amountOut = adapter.sushiV3Swap(data);
		assertApproxEqAbs(amountOut, expected, expected.percentMul(1), "!amountOut");
	}

	function testSwap1For0WrapETHBeforeOnSushiSwapV3() public {
		Currency currencyIn = currency1();
		Currency currencyOut = currency0();

		uint8 i = 1;
		uint8 j = 0;

		uint256 amountIn = computeAmountIn(currencyIn, feed(), ethAmount);

		deal(address(adapter), amountIn);
		assertEq(address(adapter).balance, amountIn, "!amountIn");

		(address pool, uint256 expected) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(pool, SUSHI_V3_SUSHI_ETH_3000_POOL, "!pool");
		assertGt(expected, 0, "!expected");

		bytes32 data = pack(pool, i, j, WRAP_ETH, NO_ACTION);

		uint256 amountOut = adapter.sushiV3Swap(data);
		assertApproxEqAbs(amountOut, expected, expected.percentMul(1), "!amountOut");
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