// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Errors} from "./Errors.sol";

/// @title PathDecoder

library PathDecoder {
	uint256 internal constant MAX_FLAGS = 8;

	function decode(
		bytes32 data
	) internal pure returns (address pool, uint8 i, uint8 j, uint8 wrapIn, uint8 wrapOut) {
		assembly ("memory-safe") {
			pool := and(data, 0xffffffffffffffffffffffffffffffffffffffff)
			i := and(shr(160, data), 0xff)
			j := and(shr(168, data), 0xff)
			wrapIn := and(shr(176, data), 0xff)
			wrapOut := and(shr(184, data), 0xff)
		}
	}

	function get(bytes32 data, uint256 offset) internal pure returns (uint8 option) {
		if (offset >= MAX_FLAGS) revert Errors.OutOfBound();

		assembly ("memory-safe") {
			option := and(shr(add(192, mul(offset, 8)), data), 0xff)
		}
	}

	function getFlag(bytes32 data, uint256 offset) internal pure returns (bool flag) {
		if (offset >= MAX_FLAGS) revert Errors.OutOfBound();

		assembly ("memory-safe") {
			flag := and(shr(add(192, mul(offset, 8)), data), 0xff)
		}
	}
}
