// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title FixedPoint
/// @notice A library for handling binary fixed point numbers, see https://en.wikipedia.org/wiki/Q_(number_format)

library FixedPoint {
	uint8 internal constant RESOLUTION = 96;
	uint256 internal constant Q96 = 0x1000000000000000000000000;
	uint256 internal constant Q128 = 0x100000000000000000000000000000000;
}
