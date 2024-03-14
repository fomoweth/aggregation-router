// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Errors} from "./Errors.sol";

/// @title PathDecoder

library PathDecoder {
	uint256 internal constant MAX_FLAGS = 8;

	function decode(
		bytes32 path
	) internal pure returns (address pool, uint8 i, uint8 j, uint8 wrapIn, uint8 wrapOut) {
		if (path == bytes32(0)) revert Errors.ZeroBytes32();

		assembly ("memory-safe") {
			pool := and(path, 0xffffffffffffffffffffffffffffffffffffffff)
			i := and(shr(160, path), 0xff)
			j := and(shr(168, path), 0xff)
			wrapIn := and(shr(176, path), 0xff)
			wrapOut := and(shr(184, path), 0xff)
		}
	}

	function get(bytes32 path, uint256 offset) internal pure returns (uint8 option) {
		if (path == bytes32(0)) revert Errors.ZeroBytes32();
		if (offset >= MAX_FLAGS) revert Errors.OutOfBound();

		assembly ("memory-safe") {
			option := and(shr(add(192, mul(offset, 8)), path), 0xff)
		}
	}

	function getFlag(bytes32 path, uint256 offset) internal pure returns (bool flag) {
		if (path == bytes32(0)) revert Errors.ZeroBytes32();
		if (offset >= MAX_FLAGS) revert Errors.OutOfBound();

		assembly ("memory-safe") {
			flag := and(shr(add(192, mul(offset, 8)), path), 0xff)
		}
	}
}
