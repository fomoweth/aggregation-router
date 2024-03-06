// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

type Currency is address;

using {
    eq as ==,
    noteq as !=,
    gt as >,
    lt as <,
    CurrencyLibrary.isNative,
    CurrencyLibrary.isZero,
    CurrencyLibrary.toAddress,
    CurrencyLibrary.toId
} for Currency global;

function eq(Currency currency, Currency other) pure returns (bool) {
	return Currency.unwrap(currency) == Currency.unwrap(other);
}

function noteq(Currency currency, Currency other) pure returns (bool) {
	return Currency.unwrap(currency) != Currency.unwrap(other);
}

function gt(Currency currency, Currency other) pure returns (bool) {
	return Currency.unwrap(currency) > Currency.unwrap(other);
}

function lt(Currency currency, Currency other) pure returns (bool) {
	return Currency.unwrap(currency) < Currency.unwrap(other);
}

/// @title CurrencyLibrary
/// @notice This library allows for transferring and holding native tokens and ERC20 tokens
/// @dev modified from: https://github.com/Uniswap/v4-core/blob/main/src/types/Currency.sol

library CurrencyLibrary {
	error ApprovalFailed();
	error TransferFailed();
	error TransferFromFailed();

	address internal constant NATIVE_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

	function approve(Currency currency, address spender, uint256 amount) internal {
		if (!_approve(currency, spender, amount)) {
			if (!_approve(currency, spender, 0) || !_approve(currency, spender, amount)) {
				revert ApprovalFailed();
			}
		}
	}

	function _approve(Currency currency, address spender, uint256 amount) private returns (bool success) {
		assembly ("memory-safe") {
			switch eq(currency, NATIVE_ADDRESS)
			case 0x00 {
				let ptr := mload(0x40)

				mstore(ptr, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
				mstore(add(ptr, 0x04), and(spender, 0xffffffffffffffffffffffffffffffffffffffff))
				mstore(add(ptr, 0x24), amount)

				success := and(
					or(and(eq(mload(0x00), 0x01), gt(returndatasize(), 0x1f)), iszero(returndatasize())),
					call(gas(), currency, 0x00, ptr, 0x44, 0x00, 0x20)
				)
			}
			default {
				success := 0x01
			}
		}
	}

	function transfer(Currency currency, address recipient, uint256 amount) internal {
		bool success;

		assembly ("memory-safe") {
			switch eq(currency, NATIVE_ADDRESS)
			case 0x00 {
				let ptr := mload(0x40)

				mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
				mstore(add(ptr, 0x04), and(recipient, 0xffffffffffffffffffffffffffffffffffffffff))
				mstore(add(ptr, 0x24), amount)

				success := and(
					or(and(eq(mload(0x00), 0x01), gt(returndatasize(), 0x1f)), iszero(returndatasize())),
					call(gas(), currency, 0x00, ptr, 0x44, 0x00, 0x20)
				)
			}
			default {
				success := call(gas(), recipient, amount, 0x00, 0x00, 0x00, 0x00)
			}
		}

		if (!success) revert TransferFailed();
	}

	function transferFrom(Currency currency, address sender, address recipient, uint256 amount) internal {
		if (!currency.isNative()) {
			bool success;

			assembly ("memory-safe") {
				let ptr := mload(0x40)

				mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
				mstore(add(ptr, 0x04), and(sender, 0xffffffffffffffffffffffffffffffffffffffff))
				mstore(add(ptr, 0x24), and(recipient, 0xffffffffffffffffffffffffffffffffffffffff))
				mstore(add(ptr, 0x44), amount)

				success := and(
					or(and(eq(mload(0x00), 0x01), gt(returndatasize(), 0x1f)), iszero(returndatasize())),
					call(gas(), currency, 0x00, ptr, 0x64, 0x00, 0x20)
				)
			}

			if (!success) revert TransferFromFailed();
		}
	}

	function allowance(
		Currency currency,
		address owner,
		address spender
	) internal view returns (uint256 value) {
		assembly ("memory-safe") {
			switch eq(currency, NATIVE_ADDRESS)
			case 0x00 {
				let ptr := mload(0x40)

				mstore(ptr, 0xdd62ed3e00000000000000000000000000000000000000000000000000000000)
				mstore(add(ptr, 0x04), and(owner, 0xffffffffffffffffffffffffffffffffffffffff))
				mstore(add(ptr, 0x24), and(spender, 0xffffffffffffffffffffffffffffffffffffffff))

				let success := staticcall(gas(), currency, ptr, 0x44, 0x00, 0x20)

				value := mload(0x00)

				if or(iszero(success), lt(returndatasize(), 0x20)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
			default {
				value := sub(exp(0x02, 0x100), 0x01) // type(uint256).max
			}
		}
	}

	function balanceOf(Currency currency, address account) internal view returns (uint256 value) {
		assembly ("memory-safe") {
			switch eq(currency, NATIVE_ADDRESS)
			case 0x00 {
				let ptr := mload(0x40)

				mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
				mstore(add(ptr, 0x04), and(account, 0xffffffffffffffffffffffffffffffffffffffff))

				let success := staticcall(gas(), currency, ptr, 0x24, 0x00, 0x20)

				value := mload(0x00)

				if or(iszero(success), lt(returndatasize(), 0x20)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
			default {
				value := balance(account)
			}
		}
	}

	function balanceOfSelf(Currency currency) internal view returns (uint256 value) {
		assembly ("memory-safe") {
			switch eq(currency, NATIVE_ADDRESS)
			case 0x00 {
				let ptr := mload(0x40)

				mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
				mstore(add(ptr, 0x04), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

				let success := staticcall(gas(), currency, ptr, 0x24, 0x00, 0x20)

				value := mload(0x00)

				if or(iszero(success), lt(returndatasize(), 0x20)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
			default {
				value := selfbalance()
			}
		}
	}

	function decimals(Currency currency) internal view returns (uint8 value) {
		assembly ("memory-safe") {
			switch eq(currency, NATIVE_ADDRESS)
			case 0x00 {
				let ptr := mload(0x40)

				mstore(ptr, 0x313ce56700000000000000000000000000000000000000000000000000000000)

				let success := staticcall(gas(), currency, ptr, 0x04, 0x00, 0x20)

				value := mload(0x00)

				if or(iszero(success), lt(returndatasize(), 0x20)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
			default {
				value := 18
			}
		}
	}

	function totalSupply(Currency currency) internal view returns (uint256 value) {
		if (!currency.isNative()) {
			assembly ("memory-safe") {
				let ptr := mload(0x40)

				mstore(ptr, 0x18160ddd00000000000000000000000000000000000000000000000000000000)

				let success := staticcall(gas(), currency, ptr, 0x04, 0x00, 0x20)

				value := mload(0x00)

				if or(iszero(success), lt(returndatasize(), 0x20)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
		}
	}

	function isNative(Currency currency) internal pure returns (bool res) {
		assembly ("memory-safe") {
			res := eq(currency, NATIVE_ADDRESS)
		}
	}

	function isZero(Currency currency) internal pure returns (bool res) {
		assembly ("memory-safe") {
			res := iszero(currency)
		}
	}

	function toAddress(Currency currency) internal pure returns (address) {
		return Currency.unwrap(currency);
	}

	function toId(Currency currency) internal pure returns (uint256) {
		return uint160(Currency.unwrap(currency));
	}

	function fromId(uint256 id) internal pure returns (Currency) {
		return Currency.wrap(address(uint160(id)));
	}
}
