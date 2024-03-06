// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency} from "src/types/Currency.sol";
import {SafeCast} from "./SafeCast.sol";
import {SwapMath} from "./SwapMath.sol";
import {TickBitmap} from "./TickBitmap.sol";
import {TickMath} from "./TickMath.sol";

/// @title UniswapV3Library

library UniswapV3Library {
	using SafeCast for uint256;

	function swap(
		address pool,
		address recipient,
		bool zeroForOne,
		int256 amountSpecified,
		uint160 sqrtPriceLimitX96,
		bytes memory data
	) internal returns (int256 amount0, int256 amount1) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x128acb0800000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(recipient, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(zeroForOne, 0xff))
			mstore(add(ptr, 0x44), amountSpecified)
			mstore(add(ptr, 0x64), sqrtPriceLimitX96)
			mstore(add(ptr, 0x84), 0xa0)
			mstore(add(ptr, 0xa4), mload(data))

			let offset := add(ptr, 0xc4)
			let guard := add(offset, mload(data))

			for {
				let i := add(data, 0x20)
			} lt(offset, guard) {
				offset := add(offset, 0x20)
				i := add(i, 0x20)
			} {
				mstore(offset, mload(i))
			}

			mstore(0x40, and(add(guard, 0x1f), not(0x1f)))

			if iszero(call(gas(), pool, 0x00, ptr, add(0xc4, mload(data)), 0x00, 0x40)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			amount0 := mload(0x00)
			amount1 := mload(0x20)
		}
	}

	struct SwapState {
		int256 amountSpecifiedRemaining;
		int256 amountCalculated;
		uint160 sqrtPriceX96;
		int24 tick;
		uint128 liquidity;
	}

	struct StepComputations {
		uint160 sqrtPriceStartX96;
		int24 tickNext;
		bool initialized;
		uint160 sqrtPriceNextX96;
		uint256 amountIn;
		uint256 amountOut;
		uint256 feeAmount;
	}

	function computeDeltaAmounts(
		address pool,
		uint24 fee,
		bool zeroForOne,
		int256 amountSpecified
	) internal view returns (int256 amount0Delta, int256 amount1Delta) {
		require(amountSpecified != 0);

		uint160 sqrtPriceLimitX96 = zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;

		bool exactInput = amountSpecified > 0;

		int24 tickSpacing = int24(fee != 100 ? fee / 60 : 1);

		(uint160 sqrtPriceX96, int24 tick, , , , ) = slot0(pool);

		require(
			zeroForOne
				? sqrtPriceLimitX96 < sqrtPriceX96 && sqrtPriceLimitX96 > TickMath.MIN_SQRT_RATIO
				: sqrtPriceLimitX96 > sqrtPriceX96 && sqrtPriceLimitX96 < TickMath.MAX_SQRT_RATIO
		);

		SwapState memory state = SwapState({
			amountSpecifiedRemaining: amountSpecified,
			amountCalculated: 0,
			sqrtPriceX96: sqrtPriceX96,
			tick: tick,
			liquidity: getPoolLiquidity(pool)
		});

		while (state.amountSpecifiedRemaining != 0 && state.sqrtPriceX96 != sqrtPriceLimitX96) {
			StepComputations memory step;
			step.sqrtPriceStartX96 = state.sqrtPriceX96;

			(step.tickNext, step.initialized) = TickBitmap.nextInitializedTickWithinOneWord(
				pool,
				state.tick,
				tickSpacing,
				zeroForOne
			);

			if (step.tickNext < TickMath.MIN_TICK) {
				step.tickNext = TickMath.MIN_TICK;
			} else if (step.tickNext > TickMath.MAX_TICK) {
				step.tickNext = TickMath.MAX_TICK;
			}

			step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.tickNext);

			(state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
				state.sqrtPriceX96,
				(
					zeroForOne
						? step.sqrtPriceNextX96 < sqrtPriceLimitX96
						: step.sqrtPriceNextX96 > sqrtPriceLimitX96
				)
					? sqrtPriceLimitX96
					: step.sqrtPriceNextX96,
				state.liquidity,
				state.amountSpecifiedRemaining,
				fee
			);

			if (exactInput) {
				unchecked {
					state.amountSpecifiedRemaining =
						state.amountSpecifiedRemaining -
						(step.amountIn + step.feeAmount).toInt256();
				}

				state.amountCalculated = state.amountCalculated - step.amountOut.toInt256();
			} else {
				unchecked {
					state.amountSpecifiedRemaining =
						state.amountSpecifiedRemaining +
						step.amountOut.toInt256();
				}

				state.amountCalculated = state.amountCalculated + (step.amountIn + step.feeAmount).toInt256();
			}

			if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
				if (step.initialized) {
					(, int128 liquidityNet, , , , , , ) = ticks(pool, tick);

					unchecked {
						if (zeroForOne) liquidityNet = -liquidityNet;
					}

					state.liquidity = liquidityNet < 0
						? state.liquidity - uint128(-liquidityNet)
						: state.liquidity + uint128(liquidityNet);
				}

				unchecked {
					state.tick = zeroForOne ? step.tickNext - 1 : step.tickNext;
				}
			} else if (state.sqrtPriceX96 != step.sqrtPriceStartX96) {
				state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
			}
		}

		unchecked {
			(amount0Delta, amount1Delta) = zeroForOne == exactInput
				? (amountSpecified - state.amountSpecifiedRemaining, state.amountCalculated)
				: (state.amountCalculated, amountSpecified - state.amountSpecifiedRemaining);
		}
	}

	function getPoolLiquidity(address pool) internal view returns (uint128 liquidity) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x1a68650200000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), pool, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			liquidity := mload(0x00)
		}
	}

	function getPoolKey(
		address pool
	) internal view returns (Currency currency0, Currency currency1, uint24 fee) {
		assembly ("memory-safe") {
			function reRevert() {
				returndatacopy(0x00, 0x00, returndatasize())
				revert(0x00, returndatasize())
			}

			let ptr := mload(0x40)
			let res := add(ptr, 0x0c)

			mstore(ptr, 0x0dfe1681d21220a7ddca3f430000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), pool, ptr, 0x04, res, 0x20)) {
				reRevert()
			}

			if iszero(staticcall(gas(), pool, add(ptr, 0x04), 0x04, add(res, 0x20), 0x20)) {
				reRevert()
			}

			if iszero(staticcall(gas(), pool, add(ptr, 0x08), 0x04, add(res, 0x40), 0x20)) {
				reRevert()
			}

			currency0 := mload(res)
			currency1 := mload(add(res, 0x20))
			fee := mload(add(res, 0x40))
		}
	}

	function slot0(
		address pool
	)
		internal
		view
		returns (
			uint160 sqrtPriceX96,
			int24 tick,
			uint16 observationIndex,
			uint16 observationCardinality,
			uint16 observationCardinalityNext,
			uint8 feeProtocol
		)
	{
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x04)

			mstore(ptr, 0x3850c7bd00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), pool, ptr, 0x04, res, 0xc0)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			sqrtPriceX96 := mload(res)
			tick := mload(add(res, 0x20))
			observationIndex := mload(add(res, 0x40))
			observationCardinality := mload(add(res, 0x60))
			observationCardinalityNext := mload(add(res, 0x80))
			feeProtocol := mload(add(res, 0xa0))
		}
	}

	function ticks(
		address pool,
		int24 tick
	)
		internal
		view
		returns (
			uint128 liquidityGross,
			int128 liquidityNet,
			uint256 feeGrowthOutside0X128,
			uint256 feeGrowthOutside1X128,
			int56 tickCumulativeOutside,
			uint160 secondsPerLiquidityOutsideX128,
			uint32 secondsOutside,
			bool initialized
		)
	{
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xf30dba9300000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), tick)

			if iszero(staticcall(gas(), pool, ptr, 0x24, add(ptr, 0x24), 0x100)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			liquidityGross := mload(add(ptr, 0x24))
			liquidityNet := mload(add(ptr, 0x44))
			feeGrowthOutside0X128 := mload(add(ptr, 0x64))
			feeGrowthOutside1X128 := mload(add(ptr, 0x84))
			tickCumulativeOutside := mload(add(ptr, 0xa4))
			secondsPerLiquidityOutsideX128 := mload(add(ptr, 0xc4))
			secondsOutside := mload(add(ptr, 0xe4))
			initialized := mload(add(ptr, 0x104))
		}
	}
}
