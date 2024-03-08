// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Errors} from "src/libraries/Errors.sol";
import {PathDecoder} from "src/libraries/PathDecoder.sol";
import {UniswapV2Library} from "src/libraries/UniswapV2Library.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseAdapter} from "./BaseAdapter.sol";

/// @title SushiV2Adapter
/// @notice Performs swaps to be handled on SushiSwap V2 pools

contract SushiV2Adapter is BaseAdapter {
	using CurrencyLibrary for Currency;
	using PathDecoder for bytes32;
	using UniswapV2Library for address;

	address constant SUSHI_V2_FACTORY = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;

	bytes32 constant SUSHI_V2_PAIR_INIT_CODE_HASH =
		0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303;

	constructor(uint256 _id, Currency _weth) BaseAdapter(_id, _weth) {}

	function sushiV2Swap(bytes32 path) external payable returns (uint256 amountOut) {
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

			mstore(ptr, add(hex"ff", shl(0x58, SUSHI_V2_FACTORY)))
			mstore(add(ptr, 0x15), salt)
			mstore(add(ptr, 0x35), SUSHI_V2_PAIR_INIT_CODE_HASH)

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
