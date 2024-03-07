// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UniswapV3Adapter} from "src/adapters/UniswapV3Adapter.sol";
import {Create3} from "src/libraries/Create3.sol";
import {FullMath} from "src/libraries/FullMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {V3SwapTest} from "./V3Swap.t.sol";

// forge test -vvv --match-path test/v3/UniswapV3Adapter.t.sol

contract UniswapV3AdapterTest is V3SwapTest {
	using CurrencyLibrary for Currency;

	address constant WBTC_ETH_3000_POOL = 0xCBCdF9626bC03E24f779434178A73a0B4bad62eD;

	UniswapV3Adapter adapter;

	function setUp() public virtual override {
		super.setUp();

		adapter = UniswapV3Adapter(
			payable(
				Create3.create3(
					keccak256(abi.encodePacked("UNISWAP_V3_ADAPTER", address(this))),
					abi.encodePacked(type(UniswapV3Adapter).creationCode, abi.encode(WETH, UNISWAP_V3_ID))
				)
			)
		);
	}

	function testSwap0For1OnUniswapV3() public {
		uint256 amountIn = FullMath.mulDiv(ethAmount, 10 ** currency0().decimals(), latestAnswer(feed()));

		deal(currency0(), address(adapter), amountIn);
		assertEq(currency0().balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currency0(), currency1(), amountIn);
		assertEq(pool, WBTC_ETH_3000_POOL);

		bytes32 data = pack(pool, 0, 1, NO_ACTION, NO_ACTION);

		uint256 amountOut = adapter.uniswapV3Swap(data);
		assertEq(amountOut, expected);

		uint256 balance0 = currency0().balanceOf(address(adapter));
		uint256 balance1 = currency1().balanceOf(address(adapter));

		assertEq(balance0, 0);
		assertEq(balance1, amountOut);
	}

	function testSwap1For0OnUniswapV3() public {
		uint256 amountIn = ethAmount;

		deal(currency1(), address(adapter), amountIn);
		assertEq(currency1().balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currency1(), currency0(), amountIn);
		assertEq(pool, WBTC_ETH_3000_POOL);

		bytes32 data = pack(pool, 1, 0, NO_ACTION, NO_ACTION);

		uint256 amountOut = adapter.uniswapV3Swap(data);
		assertEq(amountOut, expected);

		uint256 balance0 = currency0().balanceOf(address(adapter));
		uint256 balance1 = currency1().balanceOf(address(adapter));

		assertEq(balance0, amountOut);
		assertEq(balance1, 0);
	}

	function testSwap0For1UnwrapETHAfterOnUniswapV3() public {
		uint256 amountIn = FullMath.mulDiv(ethAmount, 10 ** currency0().decimals(), latestAnswer(feed()));

		deal(currency0(), address(adapter), amountIn);
		assertEq(currency0().balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currency0(), currency1(), amountIn);
		assertEq(pool, WBTC_ETH_3000_POOL);

		bytes32 data = pack(pool, 0, 1, NO_ACTION, UNWRAP_ETH);

		uint256 amountOut = adapter.uniswapV3Swap(data);
		assertEq(amountOut, expected);

		uint256 balance0 = currency0().balanceOf(address(adapter));
		uint256 balance1 = address(adapter).balance;

		assertEq(balance0, 0);
		assertEq(balance1, amountOut);
	}

	function testSwap0For1WrapETHBeforeOnUniswapV3() public {
		uint256 amountIn = ethAmount;

		deal(address(adapter), amountIn);
		assertEq(address(adapter).balance, amountIn);

		(address pool, uint256 expected) = adapter.query(currency1(), currency0(), amountIn);
		assertEq(pool, WBTC_ETH_3000_POOL);

		bytes32 data = pack(pool, 1, 0, WRAP_ETH, NO_ACTION);

		uint256 amountOut = adapter.uniswapV3Swap(data);
		assertEq(amountOut, expected);
	}

	function currency0() internal pure virtual override returns (Currency) {
		return WBTC;
	}

	function currency1() internal pure virtual override returns (Currency) {
		return WETH;
	}

	function feed() internal pure virtual override returns (address) {
		return 0xdeb288F737066589598e9214E782fa5A8eD689e8;
	}
}
