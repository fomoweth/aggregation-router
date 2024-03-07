// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title PercentageMath
/// @dev implementation from: https://github.com/aave/aave-v3-core/blob/master/contracts/protocol/libraries/math/PercentageMath.sol

library PercentageMath {
	uint256 internal constant PERCENTAGE_FACTOR = 1e4;
	uint256 internal constant HALF_PERCENTAGE_FACTOR = 0.5e4;

	function percentMul(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
		assembly ("memory-safe") {
			if iszero(
				or(
					iszero(percentage),
					iszero(gt(value, div(sub(not(0), HALF_PERCENTAGE_FACTOR), percentage)))
				)
			) {
				invalid()
			}

			result := div(add(mul(value, percentage), HALF_PERCENTAGE_FACTOR), PERCENTAGE_FACTOR)
		}
	}

	function percentDiv(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
		assembly ("memory-safe") {
			if or(
				iszero(percentage),
				iszero(iszero(gt(value, div(sub(not(0), div(percentage, 2)), PERCENTAGE_FACTOR))))
			) {
				invalid()
			}

			result := div(add(mul(value, PERCENTAGE_FACTOR), div(percentage, 2)), percentage)
		}
	}
}
