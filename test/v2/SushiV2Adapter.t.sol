// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2 as console} from "forge-std/Test.sol";
import {SushiV2Adapter} from "src/adapters/SushiV2Adapter.sol";
import {Create3} from "src/libraries/Create3.sol";
import {FullMath} from "src/libraries/FullMath.sol";
import {PercentageMath} from "src/libraries/PercentageMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {V2SwapTest} from "./V2Swap.t.sol";

// forge test -vvv --match-path test/v2/SushiV2Adapter.t.sol

contract SushiV2AdapterTest is V2SwapTest {
	using CurrencyLibrary for Currency;

	address constant SUSHI_ETH_POOL = 0x795065dCc9f64b5614C407a6EFDC400DA6221FB0;

	SushiV2Adapter adapter;

	function setUp() public virtual override {
		super.setUp();

		adapter = SushiV2Adapter(
			payable(
				Create3.create3(
					keccak256(abi.encodePacked("SUSHI_V2_ADAPTER", address(this))),
					abi.encodePacked(type(SushiV2Adapter).creationCode, abi.encode(WETH, SUSHI_V2_ID))
				)
			)
		);
	}

	function testSwap0For1OnSushiV2() public {
		uint256 amountIn = FullMath.mulDiv(ethAmount, 10 ** currency0().decimals(), latestAnswer(feed()));

		deal(currency0(), address(adapter), amountIn);
		assertEq(currency0().balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currency0(), currency1(), amountIn);
		assertEq(pool, SUSHI_ETH_POOL);

		bytes32 data = pack(pool, 0, 1, NO_ACTION, NO_ACTION);

		uint256 amountOut = adapter.sushiV2Swap(data);
		assertEq(amountOut, expected);

		uint256 balance0 = currency0().balanceOf(address(adapter));
		uint256 balance1 = currency1().balanceOf(address(adapter));

		assertEq(balance0, 0);
		assertEq(balance1, amountOut);
	}

	function testSwap1For0OnSushiV2() public {
		uint256 amountIn = ethAmount;

		deal(currency1(), address(adapter), amountIn);
		assertEq(currency1().balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currency1(), currency0(), amountIn);
		assertEq(pool, SUSHI_ETH_POOL);

		bytes32 data = pack(pool, 1, 0, NO_ACTION, NO_ACTION);

		uint256 amountOut = adapter.sushiV2Swap(data);
		assertEq(amountOut, expected);

		uint256 balance0 = currency0().balanceOf(address(adapter));
		uint256 balance1 = currency1().balanceOf(address(adapter));

		assertEq(balance0, amountOut);
		assertEq(balance1, 0);
	}

	function testSwap0For1UnwrapETHAfterOnSushiV2() public {
		uint256 amountIn = FullMath.mulDiv(ethAmount, 10 ** currency0().decimals(), latestAnswer(feed()));

		deal(currency0(), address(adapter), amountIn);
		assertEq(currency0().balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currency0(), currency1(), amountIn);
		assertEq(pool, SUSHI_ETH_POOL);

		bytes32 data = pack(pool, 0, 1, NO_ACTION, UNWRAP_ETH);

		uint256 amountOut = adapter.sushiV2Swap(data);
		assertEq(amountOut, expected);

		uint256 balance0 = currency0().balanceOf(address(adapter));
		uint256 balance1 = address(adapter).balance;

		assertEq(balance0, 0);
		assertEq(balance1, amountOut);
	}

	function testSwap0For1WrapETHBeforeOnSushiV2() public {
		uint256 amountIn = ethAmount;

		deal(address(adapter), amountIn);
		assertEq(address(adapter).balance, amountIn);

		(address pool, uint256 expected) = adapter.query(currency1(), currency0(), amountIn);
		assertEq(pool, SUSHI_ETH_POOL);

		bytes32 data = pack(pool, 1, 0, WRAP_ETH, NO_ACTION);

		uint256 amountOut = adapter.sushiV2Swap(data);
		assertEq(amountOut, expected);
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
