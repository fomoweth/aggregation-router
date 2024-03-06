// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FixedPoint} from "./FixedPoint.sol";
import {FullMath} from "./FullMath.sol";
import {SafeCast} from "./SafeCast.sol";

/// @title SqrtPriceMath
/// @notice Contains the math that uses square root of price as a Q64.96 and liquidity to compute deltas
/// @dev implementation from https://github.com/Uniswap/v3-core/blob/0.8/contracts/libraries/SqrtPriceMath.sol

library SqrtPriceMath {
	using SafeCast for uint256;

	function getNextSqrtPriceFromAmount0RoundingUp(
		uint160 sqrtPX96,
		uint128 liquidity,
		uint256 amount,
		bool add
	) internal pure returns (uint160) {
		// we short circuit amount == 0 because the result is otherwise not guaranteed to equal the input price
		if (amount == 0) return sqrtPX96;
		uint256 numerator1 = uint256(liquidity) << FixedPoint.RESOLUTION;

		if (add) {
			unchecked {
				uint256 product;
				if ((product = amount * sqrtPX96) / amount == sqrtPX96) {
					uint256 denominator = numerator1 + product;
					if (denominator >= numerator1)
						// always fits in 160 bits
						return uint160(FullMath.mulDivRoundingUp(numerator1, sqrtPX96, denominator));
				}
			}
			// denominator is checked for overflow
			return uint160(FullMath.divRoundingUp(numerator1, (numerator1 / sqrtPX96) + amount));
		} else {
			unchecked {
				uint256 product;
				// if the product overflows, we know the denominator underflows
				// in addition, we must check that the denominator does not underflow
				require((product = amount * sqrtPX96) / amount == sqrtPX96 && numerator1 > product);
				uint256 denominator = numerator1 - product;
				return FullMath.mulDivRoundingUp(numerator1, sqrtPX96, denominator).toUint160();
			}
		}
	}

	function getNextSqrtPriceFromAmount1RoundingDown(
		uint160 sqrtPX96,
		uint128 liquidity,
		uint256 amount,
		bool add
	) internal pure returns (uint160) {
		// if we're adding (subtracting), rounding down requires rounding the quotient down (up)
		// in both cases, avoid a mulDiv for most inputs
		if (add) {
			uint256 quotient = (
				amount <= type(uint160).max
					? (amount << FixedPoint.RESOLUTION) / liquidity
					: FullMath.mulDiv(amount, FixedPoint.Q96, liquidity)
			);

			return (uint256(sqrtPX96) + quotient).toUint160();
		} else {
			uint256 quotient = (
				amount <= type(uint160).max
					? FullMath.divRoundingUp(amount << FixedPoint.RESOLUTION, liquidity)
					: FullMath.mulDivRoundingUp(amount, FixedPoint.Q96, liquidity)
			);

			require(sqrtPX96 > quotient);
			// always fits 160 bits
			unchecked {
				return uint160(sqrtPX96 - quotient);
			}
		}
	}

	function getNextSqrtPriceFromInput(
		uint160 sqrtPX96,
		uint128 liquidity,
		uint256 amountIn,
		bool zeroForOne
	) internal pure returns (uint160 sqrtQX96) {
		require(sqrtPX96 > 0);
		require(liquidity > 0);

		// round to make sure that we don't pass the target price
		return
			zeroForOne
				? getNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountIn, true)
				: getNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountIn, true);
	}

	function getNextSqrtPriceFromOutput(
		uint160 sqrtPX96,
		uint128 liquidity,
		uint256 amountOut,
		bool zeroForOne
	) internal pure returns (uint160 sqrtQX96) {
		require(sqrtPX96 > 0);
		require(liquidity > 0);

		// round to make sure that we pass the target price
		return
			zeroForOne
				? getNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountOut, false)
				: getNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountOut, false);
	}

	function getAmount0Delta(
		uint160 sqrtRatioAX96,
		uint160 sqrtRatioBX96,
		uint128 liquidity,
		bool roundUp
	) internal pure returns (uint256 amount0) {
		unchecked {
			if (sqrtRatioAX96 > sqrtRatioBX96)
				(sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

			uint256 numerator1 = uint256(liquidity) << FixedPoint.RESOLUTION;
			uint256 numerator2 = sqrtRatioBX96 - sqrtRatioAX96;

			require(sqrtRatioAX96 > 0);

			return
				roundUp
					? FullMath.divRoundingUp(
						FullMath.mulDivRoundingUp(numerator1, numerator2, sqrtRatioBX96),
						sqrtRatioAX96
					)
					: FullMath.mulDiv(numerator1, numerator2, sqrtRatioBX96) / sqrtRatioAX96;
		}
	}

	function getAmount1Delta(
		uint160 sqrtRatioAX96,
		uint160 sqrtRatioBX96,
		uint128 liquidity,
		bool roundUp
	) internal pure returns (uint256 amount1) {
		unchecked {
			if (sqrtRatioAX96 > sqrtRatioBX96)
				(sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

			return
				roundUp
					? FullMath.mulDivRoundingUp(liquidity, sqrtRatioBX96 - sqrtRatioAX96, FixedPoint.Q96)
					: FullMath.mulDiv(liquidity, sqrtRatioBX96 - sqrtRatioAX96, FixedPoint.Q96);
		}
	}

	function getAmount0Delta(
		uint160 sqrtRatioAX96,
		uint160 sqrtRatioBX96,
		int128 liquidity
	) internal pure returns (int256 amount0) {
		unchecked {
			return
				liquidity < 0
					? -getAmount0Delta(sqrtRatioAX96, sqrtRatioBX96, uint128(-liquidity), false).toInt256()
					: getAmount0Delta(sqrtRatioAX96, sqrtRatioBX96, uint128(liquidity), true).toInt256();
		}
	}

	function getAmount1Delta(
		uint160 sqrtRatioAX96,
		uint160 sqrtRatioBX96,
		int128 liquidity
	) internal pure returns (int256 amount1) {
		unchecked {
			return
				liquidity < 0
					? -getAmount1Delta(sqrtRatioAX96, sqrtRatioBX96, uint128(-liquidity), false).toInt256()
					: getAmount1Delta(sqrtRatioAX96, sqrtRatioBX96, uint128(liquidity), true).toInt256();
		}
	}
}
