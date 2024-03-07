// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Errors} from "src/libraries/Errors.sol";
import {PathDecoder} from "src/libraries/PathDecoder.sol";
import {SafeCast} from "src/libraries/SafeCast.sol";
import {TickMath} from "src/libraries/TickMath.sol";
import {UniswapV3Library} from "src/libraries/UniswapV3Library.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseAdapter} from "./BaseAdapter.sol";

/// @title PancakeV3Adapter
/// @notice Performs swaps to be handled on PancakeSwap V3 pools

contract PancakeV3Adapter is BaseAdapter {
	using CurrencyLibrary for Currency;
	using PathDecoder for bytes32;
	using SafeCast for uint256;
	using UniswapV3Library for address;

	address constant PANCAKE_V3_POOL_DEPLOYER = 0x41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c9;

	address constant PANCAKE_V3_FACTORY = 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;

	bytes32 constant PANCAKE_V3_POOL_INIT_CODE_HASH =
		0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2;

	constructor(Currency _wrappedNative, uint256 _id) BaseAdapter(_wrappedNative, _id) {}

	// 0x23a69e75
	function pancakeV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
		Currency currencyIn;
		Currency currencyOut;
		uint24 fee;

		assembly ("memory-safe") {
			if and(iszero(sgt(amount0Delta, 0)), iszero(sgt(amount1Delta, 0))) {
				invalid()
			}

			let firstWord := calldataload(data.offset)
			currencyIn := shr(96, firstWord)
			fee := and(shr(72, firstWord), 0xffffff)
			currencyOut := shr(96, calldataload(add(data.offset, 23)))
		}

		address pool = computePoolAddress(currencyIn, currencyOut, fee);
		if (pool != msg.sender) revert Errors.InvalidPool();

		currencyIn.transfer(pool, amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta));
	}

	function pancakeV3Swap(bytes32 data) external payable returns (uint256 amountOut) {
		(address pool, uint8 i, uint8 j, uint8 wrapIn, uint8 wrapOut) = data.decode();

		if (i > maxCurrencyId() || j > maxCurrencyId()) revert Errors.InvalidCurrencyId();
		if (i == j) revert Errors.IdenticalCurrencyIds();

		(Currency currencyIn, Currency currencyOut, uint24 fee) = pool.getPoolKey();
		if (i != 0) (currencyIn, currencyOut) = (currencyOut, currencyIn);

		if (wrapIn == 1) wrapNative(currencyIn, address(this).balance);

		uint256 amountIn = currencyIn.balanceOfSelf();
		if (amountIn == 0) revert Errors.InsufficientAmountIn();

		if (wrapIn == 2) unwrapNative(currencyIn, amountIn);

		bool zeroForOne = currencyIn < currencyOut;

		(int256 amount0Delta, int256 amount1Delta) = pool.swap(
			address(this),
			zeroForOne,
			amountIn.toInt256(),
			(zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1),
			abi.encodePacked(currencyIn, fee, currencyOut)
		);

		amountOut = uint256(-(zeroForOne ? amount1Delta : amount0Delta));

		if (wrapOut == 1) wrapNative(currencyOut, amountOut);
		else if (wrapOut == 2) unwrapNative(currencyOut, amountOut);
	}

	function _query(
		Currency currencyIn,
		Currency currencyOut,
		uint256 amountIn
	) internal view virtual override returns (address pool, uint256 amountOut) {
		uint24 fee;
		(pool, fee) = getPoolWithMostLiquidity(currencyIn, currencyOut);

		if (pool != address(0)) {
			bool zeroForOne = currencyIn < currencyOut;

			(int256 amount0Delta, int256 amount1Delta) = pool.computeDeltaAmounts(
				fee,
				zeroForOne,
				amountIn.toInt256()
			);

			amountOut = uint256(-(zeroForOne ? amount1Delta : amount0Delta));
		}
	}

	function getPoolWithMostLiquidity(
		Currency currencyA,
		Currency currencyB
	) internal view returns (address pool, uint24 fee) {
		uint24[] memory feeAmounts = new uint24[](4);
		feeAmounts[0] = 100;
		feeAmounts[1] = 500;
		feeAmounts[2] = 3000;
		feeAmounts[3] = 10000;

		address poolCurrent;
		uint128 liquidityCurrent;
		uint128 liquidityMost;
		uint256 i;

		while (i < 4) {
			poolCurrent = computePoolAddress(currencyA, currencyB, feeAmounts[i]);

			liquidityCurrent = poolCurrent.getPoolLiquidity();

			if (liquidityCurrent > liquidityMost) {
				liquidityMost = liquidityCurrent;
				pool = poolCurrent;
				fee = feeAmounts[i];
			}

			unchecked {
				i = i + 1;
			}
		}
	}

	function computePoolAddress(
		Currency currency0,
		Currency currency1,
		uint24 fee
	) internal pure returns (address pool) {
		assembly ("memory-safe") {
			if gt(currency0, currency1) {
				let temp := currency0
				currency0 := currency1
				currency1 := temp
			}

			let ptr := mload(0x40)

			mstore(add(ptr, 0x15), currency0)
			mstore(add(ptr, 0x35), currency1)
			mstore(add(ptr, 0x55), fee)

			mstore(ptr, add(hex"ff", shl(0x58, PANCAKE_V3_POOL_DEPLOYER)))
			mstore(add(ptr, 0x15), keccak256(add(ptr, 0x15), 0x60))
			mstore(add(ptr, 0x35), PANCAKE_V3_POOL_INIT_CODE_HASH)

			pool := and(
				keccak256(ptr, 0x55),
				0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff
			)
		}
	}

	function maxCurrencyId() internal pure virtual override returns (uint256) {
		return 1;
	}
}
