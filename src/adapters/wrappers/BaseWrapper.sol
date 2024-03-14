// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IWrapper} from "src/interfaces/IWrapper.sol";
import {Errors} from "src/libraries/Errors.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {Context} from "@openzeppelin/utils/Context.sol";

/// @title BaseWrapper

abstract contract BaseWrapper is IWrapper, Context {
	using CurrencyLibrary for Currency;

	uint256 public immutable id;

	Currency internal immutable WETH;

	uint8 internal constant NO_ACTION = 0;
	uint8 internal constant WRAP_ETH = 1;
	uint8 internal constant UNWRAP_WETH = 2;

	constructor(uint256 _id, Currency _weth) {
		id = _id;
		WETH = _weth;
	}

	function wrap(bytes32 path) external payable returns (uint256) {
		return invoke(path);
	}

	function unwrap(bytes32 path) external payable returns (uint256) {
		return invoke(path);
	}

	function query(
		Currency wrapped,
		Currency underlying,
		uint256 amountIn,
		bool direction
	) external view returns (bytes32 path, uint256 amountOut) {
		if (wrapped != underlying && amountIn != 0) {
			(path, amountOut) = _query(wrapped, underlying, amountIn, direction);
		}
	}

	function quote(bytes32 path, uint256 amountIn) external view returns (uint256 amountOut) {
		if (amountIn != 0) amountOut = _quote(path, amountIn);
	}

	function wrapETH(Currency currency, uint256 amount) internal {
		if (currency.isNative()) currency = WETH;

		if (currency != WETH) revert Errors.InvalidCurrency();
		if (amount == 0) revert Errors.ZeroAmount();

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xd0e30db000000000000000000000000000000000000000000000000000000000) // deposit()

			if iszero(call(gas(), currency, amount, ptr, 0x04, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function unwrapWETH(Currency currency, uint256 amount) internal {
		if (currency.isNative()) currency = WETH;

		if (currency != WETH) revert Errors.InvalidCurrency();
		if (amount == 0) revert Errors.ZeroAmount();

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

	function invoke(bytes32 path) internal virtual returns (uint256 amountOut);

	function _query(
		Currency wrapped,
		Currency underlying,
		uint256 amountIn,
		bool direction
	) internal view virtual returns (bytes32 path, uint256 amountOut);

	function _quote(bytes32 path, uint256 amountIn) internal view virtual returns (uint256 amountOut);

	function maxCurrencyId() internal pure virtual returns (uint256);

	receive() external payable {}
}
