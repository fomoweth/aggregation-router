// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Errors} from "src/libraries/Errors.sol";
import {PathDecoder} from "src/libraries/PathDecoder.sol";
import {UniswapV2Library} from "src/libraries/UniswapV2Library.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseAdapter} from "./BaseAdapter.sol";

/// @title FraxSwapV2Adapter
/// @notice Performs swaps to be handled on FraxSwap pools

contract FraxSwapV2Adapter is BaseAdapter {
	using CurrencyLibrary for Currency;
	using PathDecoder for bytes32;
	using UniswapV2Library for address;

	address internal constant FRAXSWAP_FACTORY = 0x43eC799eAdd63848443E2347C49f5f52e8Fe0F6f;

	bytes32 internal constant FRAXSWAP_PAIR_INIT_CODE_HASH =
		0x4ce0b4ab368f39e4bd03ec712dfc405eb5a36cdb0294b3887b441cd1c743ced3;

	constructor(Currency _wrappedNative, uint256 _id) BaseAdapter(_wrappedNative, _id) {}

	function fraxV2Swap(bytes32 data) external payable returns (uint256 amountOut) {
		(address pool, uint8 i, uint8 j, uint8 wrapIn, uint8 wrapOut) = data.decode();

		if (i > maxCurrencyId() || j > maxCurrencyId()) revert Errors.InvalidCurrencyId();
		if (i == j) revert Errors.IdenticalCurrencyIds();

		(Currency currencyIn, Currency currencyOut) = pool.getPairAssets();
		if (i != 0) (currencyIn, currencyOut) = (currencyOut, currencyIn);

		if (wrapIn == 1) wrapNative(currencyIn, address(this).balance);

		uint256 amountIn = currencyIn.balanceOfSelf();
		if (amountIn == 0) revert Errors.InsufficientAmountIn();

		if (wrapIn == 2) unwrapNative(currencyIn, amountIn);

		bool zeroForOne = currencyIn < currencyOut;

		if ((amountOut = pool.getAmountOut(amountIn, zeroForOne)) == 0) {
			revert Errors.InsufficientReserves();
		}

		(uint256 amount0Out, uint256 amount1Out) = zeroForOne
			? (uint256(0), amountOut)
			: (amountOut, uint256(0));

		currencyIn.transfer(pool, amountIn);

		pool.swap(amount0Out, amount1Out, address(this));

		if (wrapOut == 1) wrapNative(currencyOut, amountOut);
		else if (wrapOut == 2) unwrapNative(currencyOut, amountOut);
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

			mstore(ptr, add(hex"ff", shl(0x58, FRAXSWAP_FACTORY)))
			mstore(add(ptr, 0x15), salt)
			mstore(add(ptr, 0x35), FRAXSWAP_PAIR_INIT_CODE_HASH)

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
