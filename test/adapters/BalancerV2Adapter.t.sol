// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BalancerV2Adapter} from "src/adapters/BalancerV2Adapter.sol";
import {PercentageMath} from "src/libraries/PercentageMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseTest} from "test/shared/BaseTest.t.sol";

contract BalancerV2AdapterTest is BaseTest {
	using CurrencyLibrary for Currency;
	using PercentageMath for uint256;

	BalancerV2Adapter adapter;

	function setUp() public {
		fork();

		adapter = BalancerV2Adapter(
			deployAdapter(
				"BALANCER_V2_ADAPTER",
				abi.encodePacked(type(BalancerV2Adapter).creationCode, abi.encode(BALANCER_V2_ID, WETH))
			)
		);
	}

	function testSwap0For1OnBalancerV2() public {
		address pool = toPoolAddress(pid());

		// WBTC -> WETH

		Currency currencyIn = currency0();

		uint8 i = 0;
		uint8 j = 1;

		bytes32 path;
		uint256 amountIn;
		uint256 amountOut;
		uint256 quoteAmount;

		amountIn = computeAmountIn(currencyIn, feed(), ethAmount);

		deal(currencyIn, address(adapter), amountIn);

		uint256 snapshot = vm.snapshot();

		path = pack(pool, i, j, NO_ACTION, NO_ACTION, false);

		quoteAmount = adapter.quote(path, amountIn);
		assertGt(quoteAmount, 0);

		amountOut = adapter.balancerV2Swap(path);
		assertApproxEqAbs(amountOut, quoteAmount, quoteAmount.percentMul(1));

		vm.revertTo(snapshot);

		// WBTC -> ETH

		path = pack(pool, i, j, NO_ACTION, UNWRAP_WETH, false);

		quoteAmount = adapter.quote(path, amountIn);
		assertGt(quoteAmount, 0);

		amountOut = adapter.balancerV2Swap(path);
		assertApproxEqAbs(amountOut, quoteAmount, quoteAmount.percentMul(1));
		assertEq(address(adapter).balance, amountOut);
	}

	function testSwap1For0OnBalancerV2() public {
		address pool = toPoolAddress(pid());

		// WETH -> WBTC

		Currency currencyIn = currency1();

		uint8 i = 1;
		uint8 j = 0;

		bytes32 path;
		uint256 amountIn;
		uint256 amountOut;
		uint256 quoteAmount;

		amountIn = computeAmountIn(currencyIn, feed(), ethAmount);

		uint256 snapshot = vm.snapshot();

		deal(currencyIn, address(adapter), amountIn);

		path = pack(pool, i, j, NO_ACTION, NO_ACTION, false);

		quoteAmount = adapter.quote(path, amountIn);
		assertGt(quoteAmount, 0);

		amountOut = adapter.balancerV2Swap(path);
		assertApproxEqAbs(amountOut, quoteAmount, quoteAmount.percentMul(1));

		vm.revertTo(snapshot);

		// ETH -> WBTC

		deal(ETH, address(adapter), amountIn);
		assertEq(getBalance(ETH, address(adapter)), amountIn);

		path = pack(pool, i, j, WRAP_ETH, NO_ACTION, false);

		quoteAmount = adapter.quote(path, amountIn);
		assertGt(quoteAmount, 0);

		amountOut = adapter.balancerV2Swap(path);
		assertApproxEqAbs(amountOut, quoteAmount, quoteAmount.percentMul(1));
	}

	function currency0() internal pure returns (Currency) {
		return WBTC;
	}

	function currency1() internal pure returns (Currency) {
		return WETH;
	}

	function feed() internal pure returns (address) {
		return BTC_ETH_FEED;
	}

	// B-50WBTC-50WETH
	function pid() internal pure returns (bytes32) {
		return 0xa6f548df93de924d73be7d25dc02554c6bd66db500020000000000000000000e;
	}

	function toPoolAddress(bytes32 poolId) internal pure returns (address) {
		return address(uint160(uint256(poolId) >> (12 * 8)));
	}
}
