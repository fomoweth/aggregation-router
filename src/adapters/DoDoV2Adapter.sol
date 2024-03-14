// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DPP_FACTORY, DSP_FACTORY, DVM_FACTORY} from "src/libraries/Constants.sol";
import {Errors} from "src/libraries/Errors.sol";
import {PathDecoder} from "src/libraries/PathDecoder.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseAdapter} from "./BaseAdapter.sol";

/// @title DoDoV2Adapter
/// @notice Performs swaps to be handled on DODO V2 pools

contract DoDoV2Adapter is BaseAdapter {
	using CurrencyLibrary for Currency;
	using PathDecoder for bytes32;

	constructor(uint256 _id, Currency _weth) BaseAdapter(_id, _weth) {}

	function dodoV2Swap(bytes32 path) external payable returns (uint256) {
		return _exchange(path);
	}

	function _exchange(bytes32 path) internal virtual override returns (uint256 amountOut) {
		(address pool, uint8 i, uint8 j, uint8 wrapIn, uint8 wrapOut) = path.decode();

		if (i > maxCurrencyId() || j > maxCurrencyId()) revert Errors.InvalidCurrencyId();
		if (i == j) revert Errors.IdenticalCurrencyIds();

		(Currency currencyIn, Currency currencyOut) = getPoolAssets(pool);
		if (i != 0) (currencyIn, currencyOut) = (currencyOut, currencyIn);

		if (wrapIn == WRAP_ETH) wrapETH(currencyIn, address(this).balance);

		uint256 amountIn = currencyIn.balanceOfSelf();
		if (amountIn == 0) revert Errors.InsufficientAmountIn();

		if (wrapIn == UNWRAP_WETH) unwrapWETH(currencyIn, amountIn);

		currencyIn.transfer(pool, amountIn);

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			switch i
			case 0x00 {
				mstore(ptr, 0xbd6015b400000000000000000000000000000000000000000000000000000000) // sellBase(address)
			}
			case 0x01 {
				mstore(ptr, 0xdd93f59a00000000000000000000000000000000000000000000000000000000) // sellQuote(address)
			}

			mstore(add(ptr, 0x04), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(call(gas(), pool, 0x00, ptr, 0x24, 0x00, 0x20)) {
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

		address pool;
		(pool, amountOut) = queryFor(DVM_FACTORY, currencyIn, currencyOut, amountIn);

		{
			(address poolCurrent, uint256 quotedCurrent) = queryFor(
				DSP_FACTORY,
				currencyIn,
				currencyOut,
				amountIn
			);

			if (poolCurrent != address(0) && quotedCurrent > amountOut) {
				pool = poolCurrent;
				amountOut = quotedCurrent;
			}
		}

		{
			(address poolCurrent, uint256 quotedCurrent) = queryFor(
				DPP_FACTORY,
				currencyIn,
				currencyOut,
				amountIn
			);

			if (poolCurrent != address(0) && quotedCurrent > amountOut) {
				pool = poolCurrent;
				amountOut = quotedCurrent;
			}
		}

		if (pool != address(0) && amountOut != 0) {
			bool baseForQuote = isBase(pool, currencyIn);

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

	function _quote(bytes32 path, uint256 amountIn) internal view virtual override returns (uint256) {
		(address pool, uint8 i, uint8 j, , ) = path.decode();

		if (i > maxCurrencyId() || j > maxCurrencyId()) revert Errors.InvalidCurrencyId();
		if (i == j) revert Errors.IdenticalCurrencyIds();

		return quoteFor(pool, amountIn, i == 0);
	}

	function queryFor(
		address factory,
		Currency currencyIn,
		Currency currencyOut,
		uint256 amountIn
	) internal view returns (address pool, uint256 amountOut) {
		{
			address[] memory pools = getPools(factory, currencyIn, currencyOut);

			uint256 length = pools.length;
			uint256 i;

			while (i < length) {
				address poolCurrent = pools[i];

				if (poolCurrent != address(0)) {
					uint256 quotedCurrent = quoteFor(poolCurrent, amountIn, isBase(poolCurrent, currencyIn));

					if (quotedCurrent > amountOut) {
						pool = poolCurrent;
						amountOut = quotedCurrent;
					}
				}

				unchecked {
					i = i + 1;
				}
			}
		}

		{
			address[] memory pools = getPools(factory, currencyOut, currencyIn);

			uint256 length = pools.length;
			uint256 i;

			while (i < length) {
				address poolCurrent = pools[i];

				if (poolCurrent != address(0)) {
					uint256 quotedCurrent = quoteFor(poolCurrent, amountIn, isBase(poolCurrent, currencyIn));

					if (quotedCurrent > amountOut) {
						pool = poolCurrent;
						amountOut = quotedCurrent;
					}
				}

				unchecked {
					i = i + 1;
				}
			}
		}
	}

	function quoteFor(
		address pool,
		uint256 amountIn,
		bool sellBase
	) internal view returns (uint256 amountOut) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			switch sellBase
			case 0x00 {
				mstore(ptr, 0x66410a2100000000000000000000000000000000000000000000000000000000) // querySellQuote(address,uint256)
			}
			default {
				mstore(ptr, 0x79a0487600000000000000000000000000000000000000000000000000000000) // querySellBase(address,uint256)
			}

			mstore(add(ptr, 0x04), and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), amountIn)

			if iszero(staticcall(gas(), pool, ptr, 0x44, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			amountOut := mload(0x00)
		}
	}

	function getPools(
		address factory,
		Currency baseCurrency,
		Currency quoteCurrency
	) internal view returns (address[] memory) {
		bytes memory returndata;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x57a281dc00000000000000000000000000000000000000000000000000000000) // getDODOPool(address,address)
			mstore(add(ptr, 0x04), and(baseCurrency, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(quoteCurrency, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), factory, ptr, 0x44, 0x00, 0x00)) {
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

	function getFactories() internal pure returns (address[] memory factories) {
		factories = new address[](3);

		factories[0] = DVM_FACTORY;
		factories[1] = DSP_FACTORY;
		factories[2] = DPP_FACTORY;
	}

	function maxCurrencyId() internal pure virtual override returns (uint256) {
		return 1;
	}
}
