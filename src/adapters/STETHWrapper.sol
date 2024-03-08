// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Errors} from "src/libraries/Errors.sol";
import {PathDecoder} from "src/libraries/PathDecoder.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseAdapter} from "./BaseAdapter.sol";

/// @title STETHWrapper
/// @notice Performs wrapping and unwrapping for stETH and wstETH

contract STETHWrapper is BaseAdapter {
	using CurrencyLibrary for Currency;
	using PathDecoder for bytes32;

	Currency internal immutable STETH;
	Currency internal immutable WSTETH;

	uint8 internal constant ETH_IDX = 0;
	uint8 internal constant STETH_IDX = 1;
	uint8 internal constant WSTETH_IDX = 2;

	constructor(uint256 _id, Currency _weth, Currency _steth, Currency _wsteth) BaseAdapter(_id, _weth) {
		STETH = _steth;
		WSTETH = _wsteth;
	}

	function wrapSTETH(uint256 amount, bool fromWETH, bool toWSTETH) external payable returns (uint256) {
		if (fromWETH) unwrapWETH(WETH, WETH.balanceOfSelf());

		if (address(this).balance < amount) revert Errors.InsufficientBalance();

		if (!toWSTETH) {
			return invoke(STETH, ETH_IDX, amount);
		} else {
			return invoke(WSTETH, STETH_IDX, invoke(STETH, ETH_IDX, amount));
		}
	}

	function wrapWSTETH(uint256 amount) external payable returns (uint256) {
		if (sharesOf(STETH) < amount) revert Errors.InsufficientBalance();

		return invoke(WSTETH, STETH_IDX, amount);
	}

	function unwrapWSTETH(uint256 amount) external payable returns (uint256) {
		if (WSTETH.balanceOfSelf() < amount) revert Errors.InsufficientBalance();

		return invoke(WSTETH, WSTETH_IDX, amount);
	}

	function _exchange(bytes32 path) internal virtual override returns (uint256 amountOut) {
		(, uint8 i, uint8 j, uint8 wrapIn, ) = path.decode();

		if (i == ETH_IDX && j == STETH_IDX) {
			if (wrapIn == UNWRAP_ETH) unwrapWETH(WETH, WETH.balanceOfSelf());

			return invoke(STETH, ETH_IDX, address(this).balance);
		} else if (i == ETH_IDX && j == WSTETH_IDX) {
			if (wrapIn == UNWRAP_ETH) unwrapWETH(WETH, WETH.balanceOfSelf());

			return invoke(WSTETH, STETH_IDX, invoke(STETH, ETH_IDX, address(this).balance));
		} else if (i == STETH_IDX && j == WSTETH_IDX) {
			return invoke(WSTETH, STETH_IDX, sharesOf(STETH));
		} else if (i == WSTETH_IDX && j == STETH_IDX) {
			return invoke(WSTETH, WSTETH_IDX, WSTETH.balanceOfSelf());
		} else {
			revert Errors.InvalidCurrencyId();
		}
	}

	function invoke(Currency target, uint8 i, uint256 amountIn) internal returns (uint256 amountOut) {
		if (amountIn == 0) revert Errors.InsufficientAmountIn();

		if (i == STETH_IDX) STETH.approve(WSTETH.toAddress(), amountIn);

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			switch i
			case 0x00 {
				mstore(ptr, 0xa1903eab00000000000000000000000000000000000000000000000000000000) // submit(address)
			}
			case 0x01 {
				mstore(ptr, 0xea598cb000000000000000000000000000000000000000000000000000000000) // wrap(uint256)
			}
			case 0x02 {
				mstore(ptr, 0xde0e9a3e00000000000000000000000000000000000000000000000000000000) // unwrap(uint256)
			}
			default {
				invalid()
			}

			mstore(add(ptr, 0x04), mul(amountIn, gt(i, 0x00)))

			if iszero(call(gas(), target, mul(amountIn, iszero(i)), ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			amountOut := mload(0x00)
		}
	}

	function _quote(bytes32 path, uint256 amountIn) internal view virtual override returns (uint256) {
		(, uint8 i, uint8 j, , ) = path.decode();

		if (i == ETH_IDX && j == STETH_IDX) {
			return _quote(STETH, ETH_IDX, amountIn);
		} else if (i == ETH_IDX && j == WSTETH_IDX) {
			return _quote(WSTETH, STETH_IDX, _quote(STETH, ETH_IDX, amountIn));
		} else if (i == STETH_IDX && j == WSTETH_IDX) {
			return _quote(WSTETH, STETH_IDX, amountIn);
		} else if (i == WSTETH_IDX && j == STETH_IDX) {
			return _quote(WSTETH, WSTETH_IDX, amountIn);
		} else revert Errors.InvalidCurrencyId();
	}

	function _query(
		Currency currencyIn,
		Currency currencyOut,
		uint256 amountIn
	) internal view virtual override returns (address, uint256) {
		Currency steth = STETH;
		Currency wsteth = WSTETH;

		if (currencyIn.isNative() || currencyIn == WETH) {
			if (currencyOut == steth) {
				return (steth.toAddress(), _quote(steth, ETH_IDX, amountIn));
			} else if (currencyOut == wsteth) {
				return (wsteth.toAddress(), _quote(wsteth, STETH_IDX, _quote(steth, ETH_IDX, amountIn)));
			}
		} else if (currencyIn == steth && currencyOut == wsteth) {
			return (wsteth.toAddress(), _quote(wsteth, STETH_IDX, amountIn));
		} else if (currencyIn == wsteth && currencyOut == steth) {
			return (wsteth.toAddress(), _quote(wsteth, WSTETH_IDX, amountIn));
		}

		return (address(0), 0);
	}

	function _quote(Currency target, uint8 i, uint256 amountIn) internal view returns (uint256 amountOut) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			switch i
			case 0x00 {
				mstore(ptr, 0x1920845100000000000000000000000000000000000000000000000000000000) // getSharesByPooledEth(uint256)
			}
			case 0x01 {
				mstore(ptr, 0xb0e3890000000000000000000000000000000000000000000000000000000000) // getWstETHByStETH(uint256)
			}
			case 0x02 {
				mstore(ptr, 0xbb2952fc00000000000000000000000000000000000000000000000000000000) // getStETHByWstETH(uint256)
			}
			default {
				invalid()
			}

			mstore(add(ptr, 0x04), amountIn)

			if iszero(staticcall(gas(), target, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			amountOut := mload(0x00)
		}
	}

	function sharesOf(Currency steth) internal view returns (uint256 shares) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xf5eb42dc00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), steth, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			shares := mload(0x00)
		}
	}

	function maxCurrencyId() internal pure virtual override returns (uint256) {
		return WSTETH_IDX;
	}
}
