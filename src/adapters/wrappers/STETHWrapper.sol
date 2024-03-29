// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Errors} from "src/libraries/Errors.sol";
import {PathDecoder} from "src/libraries/PathDecoder.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseAdapter} from "../BaseAdapter.sol";
import {BaseWrapper} from "./BaseWrapper.sol";

/// @title STETHWrapper
/// @notice Performs wrapping and unwrapping for stETH and wstETH

contract STETHWrapper is BaseWrapper {
	using CurrencyLibrary for Currency;
	using PathDecoder for bytes32;

	Currency internal immutable STETH;
	Currency internal immutable WSTETH;

	uint8 internal constant ETH_IDX = 0;
	uint8 internal constant STETH_IDX = 1;
	uint8 internal constant WSTETH_IDX = 2;

	constructor(uint256 _id, Currency _weth, Currency _steth, Currency _wsteth) BaseWrapper(_id, _weth) {
		STETH = _steth;
		WSTETH = _wsteth;
	}

	function wrapSTETH(bytes32 path) external payable returns (uint256) {
		return invoke(path);
	}

	function wrapWSTETH(bytes32 path) external payable returns (uint256) {
		return invoke(path);
	}

	function unwrapWSTETH(bytes32 path) external payable returns (uint256) {
		return invoke(path);
	}

	function invoke(bytes32 path) internal virtual override returns (uint256 amountOut) {
		(, uint8 i, uint8 j, uint8 wrapIn, ) = path.decode();

		if (i > maxCurrencyId() || (j != STETH_IDX && j != WSTETH_IDX)) revert Errors.InvalidCurrencyId();
		if (i == j) revert Errors.IdenticalCurrencyIds();

		// wstETH -> stETH
		if (i == WSTETH_IDX && j == STETH_IDX) {
			amountOut = _invoke(WSTETH, i, WSTETH.balanceOfSelf());
		} else {
			// ETH -> stETH
			if (i == ETH_IDX) {
				if (wrapIn == UNWRAP_WETH) unwrapWETH(WETH, WETH.balanceOfSelf());

				amountOut = _invoke(STETH, i, address(this).balance);
			}

			// stETH -> wstETH
			if (j == WSTETH_IDX) {
				uint256 amountIn = sharesOf(STETH);

				STETH.approve(WSTETH.toAddress(), amountIn);

				amountOut = _invoke(WSTETH, STETH_IDX, amountIn);
			}
		}
	}

	function _invoke(Currency target, uint8 i, uint256 amountIn) internal returns (uint256 amountOut) {
		if (amountIn == 0) revert Errors.InsufficientAmountIn();

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			switch i
			// ETH -> stETH
			case 0x00 {
				mstore(ptr, 0xa1903eab00000000000000000000000000000000000000000000000000000000) // submit(address)
			}
			// stETH -> wstETH
			case 0x01 {
				mstore(ptr, 0xea598cb000000000000000000000000000000000000000000000000000000000) // wrap(uint256)
			}
			// wstETH -> stETH
			case 0x02 {
				mstore(ptr, 0xde0e9a3e00000000000000000000000000000000000000000000000000000000) // unwrap(uint256)
			}

			mstore(add(ptr, 0x04), mul(amountIn, gt(i, 0x00)))

			if iszero(call(gas(), target, mul(amountIn, iszero(i)), ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			amountOut := mload(0x00)
		}
	}

	function _query(
		Currency currencyIn,
		Currency currencyOut,
		uint256 amountIn,
		bool
	) internal view virtual override returns (bytes32 path, uint256 amountOut) {
		Currency pool;
		uint8 wrapIn;
		uint8 i;
		uint8 j;

		if (currencyIn == WETH) {
			wrapIn = UNWRAP_WETH;
			currencyIn = CurrencyLibrary.NATIVE;
		}

		if (currencyIn.isNative() && currencyOut == STETH) {
			pool = STETH;
			i = ETH_IDX;
			j = STETH_IDX;

			amountOut = convert(STETH, ETH_IDX, amountIn);
		} else if (currencyIn.isNative() && currencyOut == WSTETH) {
			pool = WSTETH;
			i = ETH_IDX;
			j = WSTETH_IDX;

			amountOut = convert(WSTETH, STETH_IDX, convert(STETH, ETH_IDX, amountIn));
		} else if (currencyIn == STETH && currencyOut == WSTETH) {
			pool = WSTETH;
			i = STETH_IDX;
			j = WSTETH_IDX;

			amountOut = convert(WSTETH, STETH_IDX, amountIn);
		} else if (currencyIn == WSTETH && currencyOut == STETH) {
			pool = WSTETH;
			i = WSTETH_IDX;
			j = STETH_IDX;

			amountOut = convert(WSTETH, WSTETH_IDX, amountIn);
		}

		if (amountOut != 0) {
			assembly ("memory-safe") {
				path := add(
					pool,
					add(shl(160, i), add(shl(168, j), add(shl(176, wrapIn), shl(184, NO_ACTION))))
				)
			}
		}
	}

	function _quote(
		bytes32 path,
		uint256 amountIn
	) internal view virtual override returns (uint256 amountOut) {
		(, uint8 i, uint8 j, , ) = path.decode();

		if (i > maxCurrencyId() || (j != STETH_IDX && j != WSTETH_IDX)) revert Errors.InvalidCurrencyId();
		if (i == j) revert Errors.IdenticalCurrencyIds();

		if (j == STETH_IDX) {
			// ETH -> stETH
			if (i == ETH_IDX) return convert(STETH, i, amountIn);
			// wstETH -> stETH
			else return convert(WSTETH, i, amountIn);
		} else {
			// stETH -> wstETH
			if (i == STETH_IDX) return convert(WSTETH, i, amountIn);
			// ETH -> stETH -> wstETH
			else return convert(WSTETH, STETH_IDX, convert(STETH, i, amountIn));
		}
	}

	function convert(Currency target, uint8 i, uint256 amountIn) internal view returns (uint256 amountOut) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			switch i
			// ETH -> stETH
			case 0x00 {
				mstore(ptr, 0x1920845100000000000000000000000000000000000000000000000000000000) // getSharesByPooledEth(uint256)
			}
			// stETH -> wstETH
			case 0x01 {
				mstore(ptr, 0xb0e3890000000000000000000000000000000000000000000000000000000000) // getWstETHByStETH(uint256)
			}
			// wstETH -> stETH
			case 0x02 {
				mstore(ptr, 0xbb2952fc00000000000000000000000000000000000000000000000000000000) // getStETHByWstETH(uint256)
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
