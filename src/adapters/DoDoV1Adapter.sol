// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {APPROVE_PROXY, DODO_ZOO, SELL_HELPER} from "src/libraries/Constants.sol";
import {Errors} from "src/libraries/Errors.sol";
import {PathDecoder} from "src/libraries/PathDecoder.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseAdapter} from "./BaseAdapter.sol";

/// @title DoDoV1Adapter
/// @notice Performs swaps to be handled on DODO V1 pools

contract DoDoV1Adapter is BaseAdapter {
	using CurrencyLibrary for Currency;
	using PathDecoder for bytes32;

	constructor(uint256 _id, Currency _weth) BaseAdapter(_id, _weth) {}

	function dodoV1Swap(bytes32 path) external payable returns (uint256) {
		return _swap(path);
	}

	function _swap(bytes32 path) internal virtual override returns (uint256 amountOut) {
		(address pool, uint8 i, uint8 j, uint8 wrapIn, uint8 wrapOut) = path.decode();

		if (i > maxCurrencyId() || j > maxCurrencyId()) revert Errors.InvalidCurrencyId();
		if (i == j) revert Errors.IdenticalCurrencyIds();

		bool zeroForOne = i == 0;

		(Currency currencyIn, Currency currencyOut) = getPoolAssets(pool);
		if (!zeroForOne) (currencyIn, currencyOut) = (currencyOut, currencyIn);

		if (wrapIn == WRAP_ETH) wrapETH(currencyIn, address(this).balance);

		uint256 amountIn = currencyIn.balanceOfSelf();
		if (amountIn == 0) revert Errors.InsufficientAmountIn();

		if (wrapIn == UNWRAP_WETH) unwrapWETH(currencyIn, amountIn);

		uint256 maxPayQuote = quoteFor(pool, amountIn, zeroForOne, false);

		if (currencyIn.allowance(address(this), pool) < amountIn) {
			currencyIn.approve(pool, amountIn);
		}

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			switch zeroForOne
			case 0x00 {
				mstore(ptr, 0xe67ce70600000000000000000000000000000000000000000000000000000000) // buyBaseToken(uint256,uint256,bytes)
				mstore(add(ptr, 0x04), amountIn)
				mstore(add(ptr, 0x24), maxPayQuote)
				mstore(add(ptr, 0x44), 0x60)
				mstore(add(ptr, 0x64), 0x00)
			}
			default {
				mstore(ptr, 0x8dae733300000000000000000000000000000000000000000000000000000000) // sellBaseToken(uint256,uint256,bytes)
				mstore(add(ptr, 0x04), amountIn)
				mstore(add(ptr, 0x24), 0x00)
				mstore(add(ptr, 0x44), 0x60)
				mstore(add(ptr, 0x64), 0x00)
			}

			if iszero(call(gas(), pool, 0x00, ptr, 0x84, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			amountOut := mload(0x00)
		}

		if (wrapOut == UNWRAP_WETH) unwrapWETH(currencyOut, amountOut);
	}

	function _query(
		Currency currencyIn,
		Currency currencyOut,
		uint256 amountIn
	) internal view virtual override returns (bytes32 path, uint256 amountOut) {
		uint8 wrapIn;
		uint8 wrapOut;

		if (currencyIn.isNative()) {
			currencyIn = WETH;
			wrapIn = WRAP_ETH;
		}

		if (currencyOut.isNative()) {
			currencyOut = WETH;
			wrapOut = UNWRAP_WETH;
		}

		if (isRegistered(currencyIn, currencyOut)) {
			address pool = getPool(currencyIn, currencyOut);
			if (pool == address(0)) pool = getPool(currencyOut, currencyIn);

			bool baseForQuote = isBase(pool, currencyIn);

			if ((amountOut = quoteFor(pool, amountIn, baseForQuote, true)) != 0) {
				assembly ("memory-safe") {
					path := add(
						pool,
						add(
							shl(160, iszero(baseForQuote)),
							add(shl(168, baseForQuote), add(shl(176, wrapIn), shl(184, wrapOut)))
						)
					)
				}
			}
		}
	}

	function _quote(bytes32 path, uint256 amountIn) internal view virtual override returns (uint256) {
		(address pool, uint8 i, uint8 j, , ) = path.decode();

		if (i > maxCurrencyId() || j > maxCurrencyId()) revert Errors.InvalidCurrencyId();
		if (i == j) revert Errors.IdenticalCurrencyIds();

		return quoteFor(pool, amountIn, i == 0, true);
	}

	function quoteFor(
		address pool,
		uint256 amountIn,
		bool sellBase,
		bool direction
	) internal view returns (uint256 amountOut) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			switch direction
			case 0x00 {
				switch sellBase
				case 0x00 {
					mstore(ptr, 0xca19ebd900000000000000000000000000000000000000000000000000000000) // querySellQuoteToken(address,uint256)
					mstore(add(ptr, 0x04), and(pool, 0xffffffffffffffffffffffffffffffffffffffff))
					mstore(add(ptr, 0x24), amountIn)
				}
				default {
					mstore(ptr, 0xef4a83f800000000000000000000000000000000000000000000000000000000) // querySellBaseToken(address,uint256)
					mstore(add(ptr, 0x04), and(pool, 0xffffffffffffffffffffffffffffffffffffffff))
					mstore(add(ptr, 0x24), amountIn)
				}

				if iszero(staticcall(gas(), SELL_HELPER, ptr, 0x44, 0x00, 0x20)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
			default {
				switch sellBase
				case 0x00 {
					mstore(ptr, 0x18c0bbe400000000000000000000000000000000000000000000000000000000) // queryBuyBaseToken(uint256)
					mstore(add(ptr, 0x04), amountIn)
				}
				default {
					mstore(ptr, 0xa2801e1600000000000000000000000000000000000000000000000000000000) // querySellBaseToken(uint256)
					mstore(add(ptr, 0x04), amountIn)
				}

				if iszero(staticcall(gas(), pool, ptr, 0x24, 0x00, 0x20)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}

			amountOut := mload(0x00)
		}
	}

	function getPools() internal view returns (address[] memory) {
		bytes memory returndata;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x5249121700000000000000000000000000000000000000000000000000000000) // getDODOs()

			if iszero(staticcall(gas(), DODO_ZOO, ptr, 0x04, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x40, add(returndata, add(returndatasize(), 0x20)))
			mstore(returndata, returndatasize())
			returndatacopy(add(returndata, 0x20), 0x00, returndatasize())
		}

		return abi.decode(returndata, (address[]));
	}

	function getPoolAssets(
		address pool
	) internal view returns (Currency baseCurrency, Currency quoteCurrency) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x4a248d2ad4b97046000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), pool, ptr, 0x04, add(ptr, 0x08), 0x20)) {
				revert(ptr, 0x04)
			}

			if iszero(staticcall(gas(), pool, add(ptr, 0x04), 0x04, add(ptr, 0x28), 0x20)) {
				revert(add(ptr, 0x04), 0x04)
			}

			baseCurrency := mload(add(ptr, 0x08))
			quoteCurrency := mload(add(ptr, 0x28))
		}
	}

	function getPool(Currency baseCurrency, Currency quoteCurrency) internal view returns (address pool) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x1273b0c600000000000000000000000000000000000000000000000000000000) // getDODO(address,address)
			mstore(add(ptr, 0x04), and(baseCurrency, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(quoteCurrency, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), DODO_ZOO, ptr, 0x44, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			pool := mload(0x00)
		}
	}

	function isRegistered(Currency baseCurrency, Currency quoteCurrency) internal view returns (bool res) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xa0b0a4d100000000000000000000000000000000000000000000000000000000) // isDODORegistered(address,address)
			mstore(add(ptr, 0x04), and(baseCurrency, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(quoteCurrency, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), DODO_ZOO, ptr, 0x44, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			res := mload(0x00)
		}
	}

	function isBase(address pool, Currency currency) internal view returns (bool res) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x4a248d2a00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), pool, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			res := eq(currency, mload(0x00))
		}
	}

	function maxCurrencyId() internal pure virtual override returns (uint256) {
		return 1;
	}
}
