// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Errors} from "src/libraries/Errors.sol";
import {PathDecoder} from "src/libraries/PathDecoder.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseAdapter} from "./BaseAdapter.sol";

/// @title CurveAdapter

contract CurveAdapter is BaseAdapter {
	using CurrencyLibrary for Currency;
	using PathDecoder for bytes32;

	address internal constant META_REGISTRY = 0xF98B45FA17DE75FB1aD0e7aFD971b0ca00e379fC;

	uint8 internal constant IS_UNDERLYING_FLAG_IDX = 0;

	constructor(uint256 _id, Currency _weth) BaseAdapter(_id, _weth) {}

	function curveSwap(bytes32 path) external payable returns (uint256) {
		return _exchange(path);
	}

	function _exchange(bytes32 path) internal virtual override returns (uint256 amountOut) {
		(address pool, uint8 i, uint8 j, uint8 wrapIn, uint8 wrapOut) = path.decode();
		if (i > maxCurrencyId() || j > maxCurrencyId()) revert Errors.InvalidCurrencyId();

		bool isUnderlying = path.getFlag(IS_UNDERLYING_FLAG_IDX);

		Currency currencyIn = getPoolAsset(pool, i, isUnderlying);
		Currency currencyOut = getPoolAsset(pool, j, isUnderlying);

		if (wrapIn == 1) wrapETH(currencyIn, address(this).balance);

		uint256 amountIn = currencyIn.balanceOfSelf();
		if (amountIn == 0) revert Errors.InsufficientAmountIn();

		if (wrapIn == 2) unwrapWETH(currencyIn, amountIn);

		if (currencyIn.allowance(pool, address(this)) < amountIn) {
			currencyIn.approve(pool, amountIn);
		}

		exchange(pool, i, j, amountIn, 0, currencyIn.isNative() ? amountIn : 0, isUnderlying);

		amountOut = currencyOut.balanceOfSelf();

		if (wrapOut == 1) wrapETH(currencyOut, amountOut);
		else if (wrapOut == 2) unwrapWETH(currencyOut, amountOut);
	}

	function findPoolsFor(Currency currencyIn, Currency currencyOut) public view returns (address[] memory) {
		bytes memory returndata;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xa064072b00000000000000000000000000000000000000000000000000000000) // find_pools_for_coins(address,address)
			mstore(add(ptr, 0x04), and(currencyIn, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(currencyOut, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), META_REGISTRY, ptr, 0x64, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x40, add(returndata, add(returndatasize(), 0x20)))
			mstore(returndata, returndatasize())
			returndatacopy(add(returndata, 0x20), 0x00, returndatasize())
		}

		return abi.decode(returndata, (address[]));
	}

	function findPoolFor(Currency currencyIn, Currency currencyOut) public view returns (address pool) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xa87df06c00000000000000000000000000000000000000000000000000000000) // find_pool_for_coins(address,address)
			mstore(add(ptr, 0x04), and(currencyIn, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(currencyOut, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), META_REGISTRY, ptr, 0x64, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			pool := mload(0x00)
		}
	}

	function getCoinIndices(
		address pool,
		Currency currencyIn,
		Currency currencyOut
	) public view returns (uint8 i, uint8 j, bool isUnderlying) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x64)

			mstore(ptr, 0xeb85226d00000000000000000000000000000000000000000000000000000000) // get_coin_indices(address,address,address)
			mstore(add(ptr, 0x04), and(pool, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(currencyIn, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x44), and(currencyOut, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), META_REGISTRY, ptr, 0x64, res, 0x60)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			i := mload(res)
			j := mload(add(res, 0x20))
			isUnderlying := mload(add(res, 0x40))
		}
	}

	function getPoolAssets(address pool, bool isUnderlying) public view returns (Currency[] memory assets) {
		bytes memory returndata;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			switch isUnderlying
			case 0x00 {
				mstore(ptr, 0x9ac90d3d00000000000000000000000000000000000000000000000000000000) // get_coins(address)
			}
			default {
				mstore(ptr, 0xa77576ef00000000000000000000000000000000000000000000000000000000) // get_underlying_coins(address)
			}

			mstore(add(ptr, 0x04), and(pool, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), META_REGISTRY, ptr, 0x24, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x40, add(returndata, add(returndatasize(), 0x60)))
			mstore(returndata, add(returndatasize(), 0x40))
			mstore(add(returndata, 0x20), 0x20)
			mstore(add(returndata, 0x40), div(returndatasize(), 0x20))
			returndatacopy(add(returndata, 0x60), 0x00, returndatasize())
		}

		assets = abi.decode(returndata, (Currency[]));

		uint256 length = getNumAssets(pool, isUnderlying);

		assembly ("memory-safe") {
			mstore(assets, length)
		}
	}

	function getNumAssets(address pool, bool isUnderlying) public view returns (uint256 numAssets) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			switch isUnderlying
			case 0x00 {
				mstore(ptr, 0x940494f100000000000000000000000000000000000000000000000000000000) // get_n_coins(address)
			}
			default {
				mstore(ptr, 0xa77576ef00000000000000000000000000000000000000000000000000000000) // get_n_underlying_coins(address)
			}

			mstore(add(ptr, 0x04), and(pool, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), META_REGISTRY, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			numAssets := mload(0x00)
		}
	}

	function _quote(
		bytes32 path,
		uint256 amountIn
	) internal view virtual override returns (uint256 amountOut) {
		//
	}

	function _query(
		Currency currencyIn,
		Currency currencyOut,
		uint256 amountIn
	) internal view virtual override returns (address pool, uint256 amountOut) {
		pool = findPoolFor(currencyIn, currencyOut);

		(uint8 i, uint8 j, bool isUnderlying) = getCoinIndices(pool, currencyIn, currencyOut);

		amountOut = getDy(pool, i, j, amountIn, isUnderlying);
	}

	function exchange(
		address pool,
		uint256 i,
		uint256 j,
		uint256 dx,
		uint256 dyMin,
		uint256 value,
		bool isUnderlying
	) internal virtual returns (uint256 dy) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xb137392900000000000000000000000000000000000000000000000000000000) // gamma()

			switch staticcall(gas(), pool, ptr, 0x04, 0x00, 0x20)
			case 0x00 {
				switch isUnderlying
				case 0x00 {
					mstore(ptr, 0x3df0212400000000000000000000000000000000000000000000000000000000) // exchange(int128,int128,uint256,uint256)
				}
				default {
					mstore(ptr, 0xa6417ed600000000000000000000000000000000000000000000000000000000) // exchange_underlying(int128,int128,uint256,uint256)
				}
			}
			default {
				switch isUnderlying
				case 0x00 {
					mstore(ptr, 0x5b41b90800000000000000000000000000000000000000000000000000000000) // exchange(uint256,uint256,uint256,uint256)
				}
				default {
					mstore(ptr, 0x65b2489b00000000000000000000000000000000000000000000000000000000) // exchange_underlying(uint256,uint256,uint256,uint256)
				}
			}

			mstore(add(ptr, 0x04), i)
			mstore(add(ptr, 0x24), j)
			mstore(add(ptr, 0x44), dx)
			mstore(add(ptr, 0x64), dyMin)

			if iszero(call(gas(), pool, value, ptr, 0x84, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			dy := mload(0x00)
		}
	}

	function getDy(
		address pool,
		uint256 i,
		uint256 j,
		uint256 dx,
		bool isUnderlying
	) internal view returns (uint256 dy) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xb137392900000000000000000000000000000000000000000000000000000000) // gamma()

			switch iszero(staticcall(gas(), pool, ptr, 0x04, 0x00, 0x20))
			case 0x00 {
				switch isUnderlying
				case 0x00 {
					mstore(ptr, 0x556d6e9f00000000000000000000000000000000000000000000000000000000) // get_dy(uint256,uint256,uint256)
				}
				default {
					mstore(ptr, 0x85f11d1e00000000000000000000000000000000000000000000000000000000) // get_dy_underlying(uint256,uint256,uint256)
				}
			}
			default {
				switch isUnderlying
				case 0x00 {
					mstore(ptr, 0x5e0d443f00000000000000000000000000000000000000000000000000000000) // get_dy(int128,int128,uint256)
				}
				default {
					mstore(ptr, 0x07211ef700000000000000000000000000000000000000000000000000000000) // get_dy_underlying(int128,int128,uint256)
				}
			}

			mstore(add(ptr, 0x04), i)
			mstore(add(ptr, 0x24), j)
			mstore(add(ptr, 0x44), dx)

			if iszero(staticcall(gas(), pool, ptr, 0x64, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			dy := mload(0x00)
		}
	}

	function getPoolAsset(
		address pool,
		uint256 offset,
		bool isUnderlying
	) internal view returns (Currency asset) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			switch isUnderlying
			case 0x00 {
				mstore(ptr, 0xc661065700000000000000000000000000000000000000000000000000000000) // coins(uint256)
			}
			default {
				mstore(ptr, 0xb9947eb000000000000000000000000000000000000000000000000000000000) // underlying_coins(uint256)
			}

			mstore(add(ptr, 0x04), offset)

			if iszero(staticcall(gas(), pool, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			asset := mload(0x00)
		}
	}

	function isMetaPool(address pool) internal view returns (bool isMeta) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xe4d332a900000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(pool, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), META_REGISTRY, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			isMeta := mload(0x00)
		}
	}

	function maxCurrencyId() internal pure virtual override returns (uint256) {
		return 6;
	}
}
