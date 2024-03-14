// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Errors} from "src/libraries/Errors.sol";
import {PathDecoder} from "src/libraries/PathDecoder.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseWrapper} from "./BaseWrapper.sol";

/// @title ATokenWrapper
/// @notice Performs wrapping and unwrapping for aTokens

contract ATokenWrapper is BaseWrapper {
	using CurrencyLibrary for Currency;
	using PathDecoder for bytes32;

	error InvalidLendingPool();

	address internal immutable POOL;
	address internal immutable LENDING_POOL;

	uint8 internal constant UNDERLYING_IDX = 0;
	uint8 internal constant ATOKEN_IDX = 1;

	constructor(uint256 _id, Currency _weth, address _pool, address _lendingPool) BaseWrapper(_id, _weth) {
		POOL = _pool;
		LENDING_POOL = _lendingPool;
	}

	function wrapAToken(bytes32 path) external payable returns (uint256) {
		return invoke(path);
	}

	function unwrapAToken(bytes32 path) external payable returns (uint256) {
		return invoke(path);
	}

	function invoke(bytes32 path) internal virtual override returns (uint256 amountOut) {
		(address pool, uint8 i, uint8 j, uint8 wrapIn, uint8 wrapOut) = path.decode();

		Currency aToken = Currency.wrap(pool);
		Currency asset = aTokenToUnderlying(aToken);

		(address lendingPool, bool isV3) = getLendingPool(aToken);

		if (i == UNDERLYING_IDX && j == ATOKEN_IDX) {
			if (wrapIn == WRAP_ETH) wrapETH(asset, address(this).balance);

			uint256 amountIn = asset.balanceOfSelf();

			asset.approve(lendingPool, amountIn);

			assembly ("memory-safe") {
				let ptr := mload(0x40)

				switch isV3
				case 0x00 {
					mstore(ptr, 0xe8eda9df00000000000000000000000000000000000000000000000000000000) // deposit(address,uint256,address,uint16)
				}
				default {
					mstore(ptr, 0x617ba03700000000000000000000000000000000000000000000000000000000) // supply(address,uint256,address,uint16)
				}

				mstore(add(ptr, 0x04), and(asset, 0xffffffffffffffffffffffffffffffffffffffff))
				mstore(add(ptr, 0x24), amountIn)
				mstore(add(ptr, 0x44), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
				mstore(add(ptr, 0x64), 0x00)

				if iszero(call(gas(), lendingPool, 0x00, ptr, 0x84, 0x00, 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}

			amountOut = aToken.balanceOfSelf();
		} else if (i == ATOKEN_IDX && j == UNDERLYING_IDX) {
			uint256 amountIn = aToken.balanceOfSelf();

			assembly ("memory-safe") {
				let ptr := mload(0x40)

				mstore(ptr, 0x69328dec00000000000000000000000000000000000000000000000000000000) // withdraw(address,uint256,address)
				mstore(add(ptr, 0x04), and(asset, 0xffffffffffffffffffffffffffffffffffffffff))
				mstore(add(ptr, 0x24), amountIn)
				mstore(add(ptr, 0x44), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

				if iszero(call(gas(), lendingPool, 0x00, ptr, 0x64, 0x00, 0x20)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}

				amountOut := mload(0x00)
			}

			if (wrapOut == WRAP_ETH) wrapETH(asset, amountOut);
			else if (wrapOut == UNWRAP_WETH) unwrapWETH(asset, amountOut);
		} else {
			revert Errors.InvalidCurrencyId();
		}
	}

	function _query(
		Currency currencyIn,
		Currency currencyOut,
		uint256 amountIn,
		bool direction
	) internal view virtual override returns (bytes32 path, uint256 amountOut) {
		(Currency aToken, Currency asset) = !direction
			? (currencyIn, currencyOut)
			: (currencyOut, currencyIn);

		uint8 wrapIn;
		uint8 wrapOut;

		if (asset.isNative()) {
			if (direction) wrapIn = WRAP_ETH;
			else wrapOut = UNWRAP_WETH;
			asset = WETH;
		}

		if (aTokenToUnderlying(aToken) == asset) {
			assembly ("memory-safe") {
				path := add(
					aToken,
					add(
						shl(160, iszero(direction)),
						add(shl(168, direction), add(shl(176, wrapIn), shl(184, wrapOut)))
					)
				)

				amountOut := amountIn
			}
		}
	}

	function _quote(bytes32 path, uint256 amountIn) internal view virtual override returns (uint256) {
		(address pool, uint8 i, uint8 j, , ) = path.decode();

		getLendingPool(Currency.wrap(pool));

		if ((i == UNDERLYING_IDX && j == ATOKEN_IDX) || (i == ATOKEN_IDX && j == UNDERLYING_IDX)) {
			return amountIn;
		} else {
			revert Errors.InvalidCurrencyId();
		}
	}

	function aTokenToUnderlying(Currency aToken) internal view returns (Currency underlying) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xb16a19de00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), aToken, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			underlying := mload(0x00)

			if iszero(underlying) {
				invalid()
			}
		}
	}

	function underlyingToAToken(
		address lendingPool,
		Currency asset,
		bool isV3
	) internal view returns (Currency aToken) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x24)

			mstore(ptr, 0x35ea6a7500000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(asset, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), lendingPool, ptr, 0x24, res, add(0x180, mul(isV3, 0x60)))) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			aToken := mload(add(add(res, 0xe0), mul(isV3, 0x20)))
		}
	}

	function getLiquidityIndex(
		address lendingPool,
		Currency asset,
		bool isV3
	) internal view returns (uint128 liquidityIndex) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x24)

			mstore(ptr, 0x35ea6a7500000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(asset, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), lendingPool, ptr, 0x24, res, add(0x180, mul(isV3, 0x60)))) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			liquidityIndex := mload(add(res, 0x20))
		}
	}

	function getLendingPool(Currency aToken) internal view returns (address lendingPool, bool isV3) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x7535d24600000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), aToken, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			lendingPool := mload(0x00)
		}

		if (lendingPool != POOL && lendingPool != LENDING_POOL) revert InvalidLendingPool();

		return (lendingPool, lendingPool == POOL);
	}

	function maxCurrencyId() internal pure virtual override returns (uint256) {
		return ATOKEN_IDX;
	}
}
