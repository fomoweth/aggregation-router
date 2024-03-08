// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Errors} from "src/libraries/Errors.sol";
import {PathDecoder} from "src/libraries/PathDecoder.sol";
import {UniswapV2Library} from "src/libraries/UniswapV2Library.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseAdapter} from "./BaseAdapter.sol";

/// @title PancakeV2Adapter
/// @notice Performs swaps to be handled on PancakeSwap V2 pools

contract PancakeV2Adapter is BaseAdapter {
	using CurrencyLibrary for Currency;
	using PathDecoder for bytes32;
	using UniswapV2Library for address;

	address internal constant PANCAKE_V2_FACTORY = 0x1097053Fd2ea711dad45caCcc45EfF7548fCB362;

	bytes32 internal constant PANCAKE_V2_PAIR_INIT_CODE_HASH =
		0x57224589c67f3f30a6b0d7a1b54cf3153ab84563bc609ef41dfb34f8b2974d2d;

	constructor(uint256 _id, Currency _weth) BaseAdapter(_id, _weth) {}

	function pancakeV2Swap(bytes32 path) external payable returns (uint256 amountOut) {
		return _exchange(path);
	}

	function _exchange(bytes32 path) internal virtual override returns (uint256 amountOut) {
		(address pool, uint8 i, uint8 j, uint8 wrapIn, uint8 wrapOut) = path.decode();
		if (i > maxCurrencyId() || j > maxCurrencyId()) revert Errors.InvalidCurrencyId();

		bool zeroForOne = i == 0;

		(Currency currencyIn, Currency currencyOut) = pool.getPairAssets(zeroForOne);

		if (wrapIn == 1) wrapETH(currencyIn, address(this).balance);

		uint256 amountIn = currencyIn.balanceOfSelf();
		if (amountIn == 0) revert Errors.InsufficientAmountIn();

		if (wrapIn == 2) unwrapWETH(currencyIn, amountIn);

		if ((amountOut = pool.getAmountOut(amountIn, zeroForOne)) == 0) {
			revert Errors.InsufficientReserves();
		}

		(uint256 amount0Out, uint256 amount1Out) = zeroForOne
			? (uint256(0), amountOut)
			: (amountOut, uint256(0));

		currencyIn.transfer(pool, amountIn);

		pool.swap(amount0Out, amount1Out, address(this));

		if (wrapOut == 1) wrapETH(currencyOut, amountOut);
		else if (wrapOut == 2) unwrapWETH(currencyOut, amountOut);
	}

	function _quote(bytes32 path, uint256 amountIn) internal view virtual override returns (uint256) {
		(address pool, uint8 i, uint8 j, , ) = path.decode();
		if (i > maxCurrencyId() || j > maxCurrencyId()) revert Errors.InvalidCurrencyId();

		return pool.getAmountOut(amountIn, i == 0);
	}

	function _query(
		Currency currencyIn,
		Currency currencyOut,
		uint256 amountIn
	) internal view virtual override returns (address pool, uint256 amountOut) {
		if ((pool = computePairAddress(currencyIn, currencyOut)) != address(0)) {
			amountOut = pool.getAmountOut(amountIn, currencyIn < currencyOut);
		}
	}

	function computePairAddress(Currency currency0, Currency currency1) internal pure returns (address pair) {
		assembly ("memory-safe") {
			if gt(currency0, currency1) {
				let temp := currency0
				currency0 := currency1
				currency1 := temp
			}

			let ptr := mload(0x40)

			mstore(ptr, shl(0x60, currency0))
			mstore(add(ptr, 0x14), shl(0x60, currency1))

			let salt := keccak256(ptr, 0x28)

			mstore(ptr, add(hex"ff", shl(0x58, PANCAKE_V2_FACTORY)))
			mstore(add(ptr, 0x15), salt)
			mstore(add(ptr, 0x35), PANCAKE_V2_PAIR_INIT_CODE_HASH)

			pair := and(
				keccak256(ptr, 0x55),
				0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff
			)
		}
	}

	function maxCurrencyId() internal pure virtual override returns (uint256) {
		return 1;
	}
}
