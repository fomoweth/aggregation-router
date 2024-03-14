// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency} from "src/types/Currency.sol";
import {PANCAKE_V3_POOL_DEPLOYER, PANCAKE_V3_POOL_INIT_CODE_HASH, SUSHI_V3_FACTORY, UNISWAP_V3_FACTORY, UNISWAP_V3_POOL_INIT_CODE_HASH} from "./Constants.sol";
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

		int24 tickSpacing;
		uint160 sqrtPriceX96;
		int24 tick;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x3850c7bd00000000000000000000000000000000000000000000000000000000) // slot()

			if iszero(staticcall(gas(), pool, ptr, 0x04, add(ptr, 0x04), 0xc0)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			sqrtPriceX96 := mload(add(ptr, 0x04))
			tick := mload(add(ptr, 0x24))

			switch eq(fee, 100)
			case 0x00 {
				tickSpacing := div(fee, 0x32)
			}
			default {
				tickSpacing := 0x01
			}
		}

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
					int128 liquidityNet;

					assembly ("memory-safe") {
						let ptr := mload(0x40)

						mstore(ptr, 0xf30dba9300000000000000000000000000000000000000000000000000000000) // ticks(int24)
						mstore(add(ptr, 0x04), tick)

						if iszero(staticcall(gas(), pool, ptr, 0x24, add(ptr, 0x24), 0x100)) {
							returndatacopy(ptr, 0x00, returndatasize())
							revert(ptr, returndatasize())
						}

						liquidityNet := mload(add(ptr, 0x44))
					}

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
			let ptr := mload(0x40)
			let res := add(ptr, 0x0c)

			mstore(ptr, 0x0dfe1681d21220a7ddca3f430000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), pool, ptr, 0x04, res, 0x20)) {
				revert(ptr, 0x04)
			}

			if iszero(staticcall(gas(), pool, add(ptr, 0x04), 0x04, add(res, 0x20), 0x20)) {
				revert(add(ptr, 0x04), 0x04)
			}

			if iszero(staticcall(gas(), pool, add(ptr, 0x08), 0x04, add(res, 0x40), 0x20)) {
				revert(add(ptr, 0x08), 0x04)
			}

			currency0 := mload(res)
			currency1 := mload(add(res, 0x20))
			fee := mload(add(res, 0x40))
		}
	}

	function getFee(address pool) internal view returns (uint24 fee) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xddca3f4300000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), pool, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			fee := mload(0x00)
		}
	}

	function computePoolAddress(
		uint256 protocolId,
		Currency currency0,
		Currency currency1,
		uint24 fee
	) internal pure returns (address pool) {
		assembly ("memory-safe") {
			if gt(currency0, currency1) {
				let temp := currency0
				currency0 := currency1
				currency1 := temp
			}

			let ptr := mload(0x40)

			mstore(add(ptr, 0x15), currency0)
			mstore(add(ptr, 0x35), currency1)
			mstore(add(ptr, 0x55), fee)

			switch protocolId
			case 0x00 {
				mstore(ptr, add(hex"ff", shl(0x58, UNISWAP_V3_FACTORY)))
				mstore(add(ptr, 0x15), keccak256(add(ptr, 0x15), 0x60))
				mstore(add(ptr, 0x35), UNISWAP_V3_POOL_INIT_CODE_HASH)
			}
			case 0x02 {
				mstore(ptr, add(hex"ff", shl(0x58, SUSHI_V3_FACTORY)))
				mstore(add(ptr, 0x15), keccak256(add(ptr, 0x15), 0x60))
				mstore(add(ptr, 0x35), UNISWAP_V3_POOL_INIT_CODE_HASH)
			}
			case 0x05 {
				mstore(ptr, add(hex"ff", shl(0x58, PANCAKE_V3_POOL_DEPLOYER)))
				mstore(add(ptr, 0x15), keccak256(add(ptr, 0x15), 0x60))
				mstore(add(ptr, 0x35), PANCAKE_V3_POOL_INIT_CODE_HASH)
			}
			default {
				invalid()
			}

			pool := and(
				keccak256(ptr, 0x55),
				0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff
			)
		}
	}
}
