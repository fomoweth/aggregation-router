// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PancakeV3Adapter} from "src/adapters/PancakeV3Adapter.sol";
import {Create3} from "src/libraries/Create3.sol";
import {FullMath} from "src/libraries/FullMath.sol";
import {PercentageMath} from "src/libraries/PercentageMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {V3SwapTest} from "./V3Swap.t.sol";

// forge test -vvv --match-path test/v3/PancakeV3Adapter.t.sol

contract PancakeV3AdapterTest is V3SwapTest {
	using CurrencyLibrary for Currency;
	using PercentageMath for uint256;

	address constant ETH_USDT_500_POOL = 0x6CA298D2983aB03Aa1dA7679389D955A4eFEE15C;

	PancakeV3Adapter adapter;

	function setUp() public virtual override {
		super.setUp();

		adapter = PancakeV3Adapter(
			payable(
				Create3.create3(
					keccak256(abi.encodePacked("PANCAKESWAP_V3_ADAPTER", address(this))),
					abi.encodePacked(type(PancakeV3Adapter).creationCode, abi.encode(WETH, PANCAKE_V3_ID))
				)
			)
		);
	}

	function testSwap0For1OnPancakeSwapV3() public {
		uint256 amountIn = ethAmount;

		deal(currency0(), address(adapter), amountIn);
		assertEq(currency0().balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currency0(), currency1(), amountIn);
		assertEq(pool, ETH_USDT_500_POOL);

		bytes32 data = pack(pool, 0, 1, NO_ACTION, NO_ACTION);

		uint256 amountOut = adapter.pancakeV3Swap(data);
		assertApproxEqAbs(amountOut, expected, expected.percentMul(1));

		uint256 balance0 = currency0().balanceOf(address(adapter));
		uint256 balance1 = currency1().balanceOf(address(adapter));

		assertEq(balance0, 0);
		assertEq(balance1, amountOut);
	}

	function testSwap1For0OnPancakeSwapV3() public {
		uint256 amountIn = FullMath.mulDiv(ethAmount, 10 ** currency1().decimals(), latestAnswer(feed()));

		deal(currency1(), address(adapter), amountIn);
		assertEq(currency1().balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currency1(), currency0(), amountIn);
		assertEq(pool, ETH_USDT_500_POOL);

		bytes32 data = pack(pool, 1, 0, NO_ACTION, NO_ACTION);

		uint256 amountOut = adapter.pancakeV3Swap(data);
		assertApproxEqAbs(amountOut, expected, expected.percentMul(1));

		uint256 balance0 = currency0().balanceOf(address(adapter));
		uint256 balance1 = currency1().balanceOf(address(adapter));

		assertEq(balance0, amountOut);
		assertEq(balance1, 0);
	}

	function testSwap0For1WrapETHBeforeOnPancakeSwapV3() public {
		uint256 amountIn = ethAmount;

		deal(address(adapter), amountIn);
		assertEq(address(adapter).balance, amountIn);

		(address pool, uint256 expected) = adapter.query(currency0(), currency1(), amountIn);
		assertEq(pool, ETH_USDT_500_POOL);

		bytes32 data = pack(pool, 0, 1, WRAP_ETH, NO_ACTION);

		uint256 amountOut = adapter.pancakeV3Swap(data);
		assertApproxEqAbs(amountOut, expected, expected.percentMul(1));

		uint256 balance0 = currency0().balanceOf(address(adapter));
		uint256 balance1 = currency1().balanceOf(address(adapter));

		assertEq(balance0, 0);
		assertEq(balance1, amountOut);
	}

	function testSwap1For0UnwrapETHAfterOnPancakeSwapV3() public {
		uint256 amountIn = FullMath.mulDiv(ethAmount, 10 ** currency1().decimals(), latestAnswer(feed()));

		deal(currency1(), address(adapter), amountIn);
		assertEq(currency1().balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currency1(), currency0(), amountIn);
		assertEq(pool, ETH_USDT_500_POOL);

		bytes32 data = pack(pool, 1, 0, NO_ACTION, UNWRAP_ETH);

		uint256 amountOut = adapter.pancakeV3Swap(data);
		assertApproxEqAbs(amountOut, expected, expected.percentMul(1));

		uint256 balance0 = address(adapter).balance;
		uint256 balance1 = currency1().balanceOf(address(adapter));

		assertEq(balance0, amountOut);
		assertEq(balance1, 0);
	}

	function currency0() internal pure virtual override returns (Currency) {
		return WETH;
	}

	function currency1() internal pure virtual override returns (Currency) {
		return USDT;
	}

	function feed() internal pure virtual override returns (address) {
		return USDT_ETH_FEED;
	}
}
