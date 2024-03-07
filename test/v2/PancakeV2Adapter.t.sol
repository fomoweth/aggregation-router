// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PancakeV2Adapter} from "src/adapters/PancakeV2Adapter.sol";
import {Create3} from "src/libraries/Create3.sol";
import {FullMath} from "src/libraries/FullMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {V2SwapTest} from "./V2Swap.t.sol";

// forge test -vvv --match-path test/v2/PancakeV2Adapter.t.sol

contract PancakeV2AdapterTest is V2SwapTest {
	using CurrencyLibrary for Currency;

	address constant WBTC_ETH_POOL = 0x4AB6702B3Ed3877e9b1f203f90cbEF13d663B0e8;

	PancakeV2Adapter adapter;

	function setUp() public virtual override {
		super.setUp();

		adapter = PancakeV2Adapter(
			payable(
				Create3.create3(
					keccak256(abi.encodePacked("PANCAKESWAP_V2_ADAPTER", address(this))),
					abi.encodePacked(type(PancakeV2Adapter).creationCode, abi.encode(WETH, PANCAKE_V2_ID))
				)
			)
		);
	}

	function testSwap0For1OnPancakeSwapV2() public {
		uint256 amountIn = FullMath.mulDiv(ethAmount, 10 ** currency0().decimals(), latestAnswer(feed()));

		deal(currency0(), address(adapter), amountIn);
		assertEq(currency0().balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currency0(), currency1(), amountIn);
		assertEq(pool, WBTC_ETH_POOL);

		bytes32 data = pack(pool, 0, 1, NO_ACTION, NO_ACTION);

		uint256 amountOut = adapter.pancakeV2Swap(data);
		assertEq(amountOut, expected);

		uint256 balance0 = currency0().balanceOf(address(adapter));
		uint256 balance1 = currency1().balanceOf(address(adapter));

		assertEq(balance0, 0);
		assertEq(balance1, amountOut);
	}

	function testSwap1For0OnPancakeSwapV2() public {
		uint256 amountIn = ethAmount;

		deal(currency1(), address(adapter), amountIn);
		assertEq(currency1().balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currency1(), currency0(), amountIn);
		assertEq(pool, WBTC_ETH_POOL);

		bytes32 data = pack(pool, 1, 0, NO_ACTION, NO_ACTION);

		uint256 amountOut = adapter.pancakeV2Swap(data);
		assertEq(amountOut, expected);

		uint256 balance0 = currency0().balanceOf(address(adapter));
		uint256 balance1 = currency1().balanceOf(address(adapter));

		assertEq(balance0, amountOut);
		assertEq(balance1, 0);
	}

	function testSwap0For1UnwrapETHAfterOnPancakeSwapV2() public {
		uint256 amountIn = FullMath.mulDiv(ethAmount, 10 ** currency0().decimals(), latestAnswer(feed()));

		deal(currency0(), address(adapter), amountIn);
		assertEq(currency0().balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currency0(), currency1(), amountIn);
		assertEq(pool, WBTC_ETH_POOL);

		bytes32 data = pack(pool, 0, 1, NO_ACTION, UNWRAP_ETH);

		uint256 amountOut = adapter.pancakeV2Swap(data);
		assertEq(amountOut, expected);

		uint256 balance0 = currency0().balanceOf(address(adapter));
		uint256 balance1 = address(adapter).balance;

		assertEq(balance0, 0);
		assertEq(balance1, amountOut);
	}

	function testSwap0For1WrapETHBeforeOnPancakeSwapV2() public {
		uint256 amountIn = ethAmount;

		deal(address(adapter), amountIn);
		assertEq(address(adapter).balance, amountIn);

		(address pool, uint256 expected) = adapter.query(currency1(), currency0(), amountIn);
		assertEq(pool, WBTC_ETH_POOL);

		bytes32 data = pack(pool, 1, 0, WRAP_ETH, NO_ACTION);

		uint256 amountOut = adapter.pancakeV2Swap(data);
		assertEq(amountOut, expected);
	}

	function currency0() internal pure virtual override returns (Currency) {
		return WBTC;
	}

	function currency1() internal pure virtual override returns (Currency) {
		return WETH;
	}

	function feed() internal pure virtual override returns (address) {
		return BTC_ETH_FEED;
	}
}
