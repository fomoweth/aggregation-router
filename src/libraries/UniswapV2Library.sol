// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency} from "src/types/Currency.sol";

/// @title UniswapV2Library

library UniswapV2Library {
	function swap(address pair, uint256 amount0Out, uint256 amount1Out, address recipient) internal {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x022c0d9f00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), amount0Out)
			mstore(add(ptr, 0x24), amount1Out)
			mstore(add(ptr, 0x44), and(recipient, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x64), 0x80)
			mstore(add(ptr, 0x84), 0x00)

			if iszero(call(gas(), pair, 0x00, ptr, 0xa4, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function getAmountIn(address pair, uint256 amountOut, bool zeroForOne) internal view returns (uint256) {
		(uint256 reserveIn, uint256 reserveOut) = getReserves(pair, zeroForOne);

		return computeAmountIn(reserveIn, reserveOut, amountOut);
	}

	function getAmountOut(address pair, uint256 amountIn, bool zeroForOne) internal view returns (uint256) {
		(uint256 reserveIn, uint256 reserveOut) = getReserves(pair, zeroForOne);

		return computeAmountOut(reserveIn, reserveOut, amountIn);
	}

	function getReserves(
		address pair,
		bool zeroForOne
	) internal view returns (uint256 reserveIn, uint256 reserveOut) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x04)

			mstore(ptr, 0x0902f1ac00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), pair, ptr, 0x04, res, 0x60)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			switch zeroForOne
			case 0x00 {
				reserveOut := mload(res)
				reserveIn := mload(add(res, 0x20))
			}
			default {
				reserveIn := mload(res)
				reserveOut := mload(add(res, 0x20))
			}
		}
	}

	function getPairAssets(
		address pair,
		bool zeroForOne
	) internal view returns (Currency currencyA, Currency currencyB) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x0dfe1681d21220a7000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), pair, ptr, 0x04, add(ptr, 0x08), 0x20)) {
				revert(ptr, 0x04)
			}

			if iszero(staticcall(gas(), pair, add(ptr, 0x04), 0x04, add(ptr, 0x28), 0x20)) {
				revert(add(ptr, 0x04), 0x04)
			}

			switch zeroForOne
			case 0x00 {
				currencyB := mload(add(ptr, 0x08))
				currencyA := mload(add(ptr, 0x28))
			}
			default {
				currencyA := mload(add(ptr, 0x08))
				currencyB := mload(add(ptr, 0x28))
			}
		}
	}

	function computeAmountIn(
		uint256 reserveIn,
		uint256 reserveOut,
		uint256 amountOut
	) internal pure returns (uint256 amountIn) {
		assembly ("memory-safe") {
			if iszero(or(iszero(reserveIn), iszero(reserveOut))) {
				amountIn := add(
					div(mul(mul(reserveIn, amountOut), 1000), mul(sub(reserveOut, amountOut), 997)),
					1
				)
			}
		}
	}

	function computeAmountOut(
		uint256 reserveIn,
		uint256 reserveOut,
		uint256 amountIn
	) internal pure returns (uint256 amountOut) {
		assembly ("memory-safe") {
			if iszero(or(iszero(reserveIn), iszero(reserveOut))) {
				amountOut := div(
					mul(mul(amountIn, 997), reserveOut),
					add(mul(reserveIn, 1000), mul(amountIn, 997))
				)
			}
		}
	}
}
