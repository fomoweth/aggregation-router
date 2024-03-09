// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2 as console} from "forge-std/Test.sol";
import {CurveAdapter} from "src/adapters/CurveAdapter.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseTest} from "./BaseTest.t.sol";

// forge test -vvv --match-path test/CurveAdapter.t.sol

contract CurveAdapterTest is BaseTest {
	using CurrencyLibrary for Currency;

	uint256 ethAmount = 20 ether;

	CurveAdapter adapter;

	function setUp() public {
		fork();

		adapter = CurveAdapter(
			deployAdapter(
				"CURVE_ADAPTER",
				abi.encodePacked(type(CurveAdapter).creationCode, abi.encode(CURVE_ID, WETH))
			)
		);
	}

	function testSwapWETHForWBTCOnCurve() public {
		Currency currencyIn = WETH;
		Currency currencyOut = WBTC;

		uint256 amountIn = deal(currencyIn, address(adapter), computeAmountIn(currencyIn, feed(), ethAmount));
		assertEq(getBalance(currencyIn, address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, pool());
		assertGt(queryAmount, 0);

		(uint8 i, uint8 j, bool isUnderlying) = adapter.getCoinIndices(queryPool, currencyIn, currencyOut);

		bytes32 path = pack(queryPool, i, j, NO_ACTION, NO_ACTION, isUnderlying);

		uint256 amountOut = adapter.curveSwap(path);
		assertEq(amountOut, queryAmount);
	}

	function testSwapWETHForWBTCWrapETHBeforeOnCurve() public {
		Currency currencyIn = WETH;
		Currency currencyOut = WBTC;

		uint256 amountIn = computeAmountIn(currencyIn, feed(), ethAmount);

		deal(address(adapter), amountIn);
		assertEq(address(adapter).balance, amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, pool());
		assertGt(queryAmount, 0);

		(uint8 i, uint8 j, bool isUnderlying) = adapter.getCoinIndices(queryPool, currencyIn, currencyOut);

		bytes32 path = pack(queryPool, i, j, WRAP_ETH, NO_ACTION, isUnderlying);

		uint256 amountOut = adapter.curveSwap(path);
		assertEq(amountOut, queryAmount);
	}

	function testSwapWBTCForWETHOnCurve() public {
		Currency currencyIn = WBTC;
		Currency currencyOut = WETH;

		uint256 amountIn = deal(currencyIn, address(adapter), computeAmountIn(currencyIn, feed(), ethAmount));
		assertEq(currencyIn.balanceOf(address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, pool());
		assertGt(queryAmount, 0);

		(uint8 i, uint8 j, bool isUnderlying) = adapter.getCoinIndices(queryPool, currencyIn, currencyOut);

		bytes32 path = pack(queryPool, i, j, NO_ACTION, NO_ACTION, isUnderlying);

		uint256 amountOut = adapter.curveSwap(path);
		assertEq(amountOut, queryAmount);
	}

	function testSwapWBTCForWETHunwrapWETHAfterOnCurve() public {
		Currency currencyIn = WBTC;
		Currency currencyOut = WETH;

		uint256 amountIn = deal(currencyIn, address(adapter), computeAmountIn(currencyIn, feed(), ethAmount));
		assertEq(currencyIn.balanceOf(address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, pool());
		assertGt(queryAmount, 0);

		(uint8 i, uint8 j, bool isUnderlying) = adapter.getCoinIndices(queryPool, currencyIn, currencyOut);

		bytes32 path = pack(queryPool, i, j, NO_ACTION, UNWRAP_ETH, isUnderlying);

		uint256 amountOut = adapter.curveSwap(path);
		assertEq(amountOut, queryAmount);
	}

	function pool() internal pure returns (address) {
		return TRICRYPTO_POOL;
	}

	function feed() internal pure returns (address) {
		return BTC_ETH_FEED;
	}
}
