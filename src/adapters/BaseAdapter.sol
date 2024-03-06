// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Errors} from "src/libraries/Errors.sol";
import {PathDecoder} from "src/libraries/PathDecoder.sol";
import {Currency} from "src/types/Currency.sol";

/// @title BaseAdapter

abstract contract BaseAdapter {
	using PathDecoder for bytes32;

	uint256 public immutable id;

	Currency internal immutable WRAPPED_NATIVE;

	constructor(Currency _wrappedNative, uint256 _id) {
		WRAPPED_NATIVE = _wrappedNative;
		id = _id;
	}

	function query(
		Currency currencyIn,
		Currency currencyOut,
		uint256 amountIn
	) external view returns (address pool, uint256 amountOut) {
		if (currencyIn == currencyOut || amountIn == 0) return (address(0), 0);
		return _query(currencyIn, currencyOut, amountIn);
	}

	function wrapNative(Currency currency, uint256 amount) internal {
		if (currency.isNative()) currency = WRAPPED_NATIVE;
		if (currency != WRAPPED_NATIVE) revert Errors.InvalidCurrency();

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xd0e30db000000000000000000000000000000000000000000000000000000000) // deposit()

			if iszero(call(gas(), currency, amount, ptr, 0x04, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function unwrapNative(Currency currency, uint256 amount) internal {
		if (currency.isNative()) currency = WRAPPED_NATIVE;
		if (currency != WRAPPED_NATIVE) revert Errors.InvalidCurrency();

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x2e1a7d4d00000000000000000000000000000000000000000000000000000000) // withdraw(uint256)
			mstore(add(ptr, 0x04), amount)

			if iszero(call(gas(), currency, 0x00, ptr, 0x24, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function _query(
		Currency currencyIn,
		Currency currencyOut,
		uint256 amountIn
	) internal view virtual returns (address pool, uint256 amountOut);

	function maxCurrencyId() internal pure virtual returns (uint256);
}
