// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SushiV3Adapter} from "src/adapters/SushiV3Adapter.sol";
import {Create3} from "src/libraries/Create3.sol";
import {FullMath} from "src/libraries/FullMath.sol";
import {PercentageMath} from "src/libraries/PercentageMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {V3SwapTest} from "./V3Swap.t.sol";

// forge test -vvv --match-path test/v3/SushiV3Adapter.t.sol

contract SushiV3AdapterTest is V3SwapTest {
	using CurrencyLibrary for Currency;
	using PercentageMath for uint256;

	address constant SUSHI_ETH_3000_POOL = 0x87C7056BBE6084f03304196Be51c6B90B6d85Aa2;

	SushiV3Adapter adapter;

	function setUp() public virtual override {
		super.setUp();

		adapter = SushiV3Adapter(
			payable(
				Create3.create3(
					keccak256(abi.encodePacked("SUSHI_V3_ADAPTER", address(this))),
					abi.encodePacked(type(SushiV3Adapter).creationCode, abi.encode(WETH, UNISWAP_V3_ID))
				)
			)
		);
	}

	function testSwap0For1OnSushiSwapV3() public {
		uint256 amountIn = FullMath.mulDiv(ethAmount, 10 ** currency0().decimals(), latestAnswer(feed()));

		deal(currency0(), address(adapter), amountIn);
		assertEq(currency0().balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currency0(), currency1(), amountIn);
		assertEq(pool, SUSHI_ETH_3000_POOL);

		bytes32 data = pack(pool, 0, 1, NO_ACTION, NO_ACTION);

		uint256 amountOut = adapter.sushiV3Swap(data);
		assertApproxEqAbs(amountOut, expected, expected.percentMul(1));

		uint256 balance0 = currency0().balanceOf(address(adapter));
		uint256 balance1 = currency1().balanceOf(address(adapter));

		assertEq(balance0, 0);
		assertEq(balance1, amountOut);
	}

	function testSwap1For0OnSushiSwapV3() public {
		uint256 amountIn = ethAmount;

		deal(currency1(), address(adapter), amountIn);
		assertEq(currency1().balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currency1(), currency0(), amountIn);
		assertEq(pool, SUSHI_ETH_3000_POOL);

		bytes32 data = pack(pool, 1, 0, NO_ACTION, NO_ACTION);

		uint256 amountOut = adapter.sushiV3Swap(data);
		assertApproxEqAbs(amountOut, expected, expected.percentMul(1));

		uint256 balance0 = currency0().balanceOf(address(adapter));
		uint256 balance1 = currency1().balanceOf(address(adapter));

		assertEq(balance0, amountOut);
		assertEq(balance1, 0);
	}

	function testSwap0For1UnwrapETHAfterOnSushiSwapV3() public {
		uint256 amountIn = FullMath.mulDiv(ethAmount, 10 ** currency0().decimals(), latestAnswer(feed()));

		deal(currency0(), address(adapter), amountIn);
		assertEq(currency0().balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currency0(), currency1(), amountIn);
		assertEq(pool, SUSHI_ETH_3000_POOL);

		bytes32 data = pack(pool, 0, 1, NO_ACTION, UNWRAP_ETH);

		uint256 amountOut = adapter.sushiV3Swap(data);
		assertApproxEqAbs(amountOut, expected, expected.percentMul(1));

		uint256 balance0 = currency0().balanceOf(address(adapter));
		uint256 balance1 = address(adapter).balance;

		assertEq(balance0, 0);
		assertEq(balance1, amountOut);
	}

	function testSwap1For0WrapETHBeforeOnSushiSwapV3() public {
		uint256 amountIn = ethAmount;

		deal(address(adapter), amountIn);
		assertEq(address(adapter).balance, amountIn);

		(address pool, uint256 expected) = adapter.query(currency1(), currency0(), amountIn);
		assertEq(pool, SUSHI_ETH_3000_POOL);

		bytes32 data = pack(pool, 1, 0, WRAP_ETH, NO_ACTION);

		uint256 amountOut = adapter.sushiV3Swap(data);
		assertApproxEqAbs(amountOut, expected, expected.percentMul(1));

		uint256 balance0 = currency0().balanceOf(address(adapter));
		uint256 balance1 = currency1().balanceOf(address(adapter));

		assertEq(balance0, amountOut);
		assertEq(balance1, 0);
	}

	function currency0() internal pure virtual override returns (Currency) {
		return SUSHI;
	}

	function currency1() internal pure virtual override returns (Currency) {
		return WETH;
	}

	function feed() internal pure virtual override returns (address) {
		return SUSHI_ETH_FEED;
	}
}
