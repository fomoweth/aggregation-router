// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Errors} from "src/libraries/Errors.sol";
import {PathDecoder} from "src/libraries/PathDecoder.sol";
import {UniswapV2Library} from "src/libraries/UniswapV2Library.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseAdapter} from "./BaseAdapter.sol";

/// @title UniswapV2Adapter
/// @notice Performs swaps on Uniswap V2 pools

contract UniswapV2Adapter is BaseAdapter {
	using CurrencyLibrary for Currency;
	using PathDecoder for bytes32;
	using UniswapV2Library for address;
	using UniswapV2Library for uint256;

	constructor(uint256 _id, Currency _weth) BaseAdapter(_id, _weth) {}

	function uniswapV2Swap(bytes32 path) external payable returns (uint256) {
		return _swap(path);
	}

	function _swap(bytes32 path) internal virtual override returns (uint256 amountOut) {
		(address pool, uint8 i, uint8 j, uint8 wrapIn, uint8 wrapOut) = path.decode();

		if (i > maxCurrencyId() || j > maxCurrencyId()) revert Errors.InvalidCurrencyId();
		if (i == j) revert Errors.IdenticalCurrencyIds();

		bool zeroForOne = i == 0;

		(Currency currencyIn, Currency currencyOut) = pool.getPairAssets(zeroForOne);

		if (wrapIn == WRAP_ETH) wrapETH(currencyIn, address(this).balance);

		uint256 amountIn = currencyIn.balanceOfSelf();
		if (amountIn == 0) revert Errors.InsufficientAmountIn();

		if (wrapIn == UNWRAP_WETH) unwrapWETH(currencyIn, amountIn);

		if ((amountOut = pool.getAmountOut(amountIn, zeroForOne)) == 0) {
			revert Errors.InsufficientReserves();
		}

		(uint256 amount0Out, uint256 amount1Out) = zeroForOne
			? (uint256(0), amountOut)
			: (amountOut, uint256(0));

		currencyIn.transfer(pool, amountIn);

		pool.swap(amount0Out, amount1Out, address(this));

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

		address pool = id.computePairAddress(currencyIn, currencyOut);

		if (pool != address(0)) {
			bool zeroForOne = currencyIn < currencyOut;

			if ((amountOut = pool.getAmountOut(amountIn, zeroForOne)) != 0) {
				assembly ("memory-safe") {
					path := add(
						pool,
						add(
							shl(160, iszero(zeroForOne)),
							add(shl(168, zeroForOne), add(shl(176, wrapIn), shl(184, wrapOut)))
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

		return pool.getAmountOut(amountIn, i == 0);
	}

	function maxCurrencyId() internal pure virtual override returns (uint256) {
		return 1;
	}
}
