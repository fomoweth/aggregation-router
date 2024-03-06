// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SafeCast
/// @notice Contains methods for safely casting between types
/// @dev implementation from https://github.com/Uniswap/v4-core/blob/main/src/libraries/SafeCast.sol

library SafeCast {
	error SafeCastOverflow();

	function toUint128(uint256 value) internal pure returns (uint128 downcasted) {
		if (((downcasted = uint128(value)) != value)) revert SafeCastOverflow();
	}

	function toUint160(uint256 value) internal pure returns (uint160 downcasted) {
		if (((downcasted = uint160(value)) != value)) revert SafeCastOverflow();
	}

	function toUint256(int256 value) internal pure returns (uint256) {
		if (value < 0) revert SafeCastOverflow();
		return uint256(value);
	}

	function toInt128(int256 value) internal pure returns (int128 downcasted) {
		if (((downcasted = int128(value)) != value)) revert SafeCastOverflow();
	}

	function toInt128(uint256 value) internal pure returns (int128 downcasted) {
		if (value > uint128(type(int128).max)) revert SafeCastOverflow();
		downcasted = int128(int256(value));
	}

	function toInt256(uint256 value) internal pure returns (int256) {
		if (value > uint256(type(int256).max)) revert SafeCastOverflow();
		return int256(value);
	}
}
