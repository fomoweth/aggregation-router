// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Errors} from "src/libraries/Errors.sol";
import {PathDecoder} from "src/libraries/PathDecoder.sol";
import {SafeCast} from "src/libraries/SafeCast.sol";
import {SwapMath} from "src/libraries/SwapMath.sol";
import {TickBitmap} from "src/libraries/TickBitmap.sol";
import {TickMath} from "src/libraries/TickMath.sol";
import {UniswapV3Library} from "src/libraries/UniswapV3Library.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseAdapter} from "./BaseAdapter.sol";

/// @title SushiV3Adapter
/// @notice Performs swaps to be handled on SushiSwap V3 pools

contract SushiV3Adapter is BaseAdapter {
	using CurrencyLibrary for Currency;
	using PathDecoder for bytes32;
	using SafeCast for uint256;
	using UniswapV3Library for address;

	address internal constant SUSHI_V3_FACTORY = 0xbACEB8eC6b9355Dfc0269C18bac9d6E2Bdc29C4F;

	bytes32 internal constant SUSHI_V3_POOL_INIT_CODE_HASH =
		0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

	constructor(uint256 _id, Currency _weth) BaseAdapter(_id, _weth) {}

	function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
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

	function sushiV3Swap(bytes32 path) external payable returns (uint256 amountOut) {
		return _exchange(path);
	}

	function _exchange(bytes32 path) internal virtual override returns (uint256 amountOut) {
		(address pool, uint8 i, uint8 j, uint8 wrapIn, uint8 wrapOut) = path.decode();
		if (i > maxCurrencyId() || j > maxCurrencyId()) revert Errors.InvalidCurrencyId();

		(Currency currencyIn, Currency currencyOut, uint24 fee) = pool.getPoolKey();
		if (i != 0) (currencyIn, currencyOut) = (currencyOut, currencyIn);

		if (wrapIn == 1) wrapETH(currencyIn, address(this).balance);

		uint256 amountIn = currencyIn.balanceOfSelf();
		if (amountIn == 0) revert Errors.InsufficientAmountIn();

		if (wrapIn == 2) unwrapWETH(currencyIn, amountIn);

		bool zeroForOne = currencyIn < currencyOut;

		(int256 amount0Delta, int256 amount1Delta) = pool.swap(
			address(this),
			zeroForOne,
			amountIn.toInt256(),
			(zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1),
			abi.encodePacked(currencyIn, fee, currencyOut)
		);

		amountOut = uint256(-(zeroForOne ? amount1Delta : amount0Delta));

		if (wrapOut == 1) wrapETH(currencyOut, amountOut);
		else if (wrapOut == 2) unwrapWETH(currencyOut, amountOut);
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

	function _quote(bytes32 path, uint256 amountIn) internal view virtual override returns (uint256) {
		(address pool, uint8 i, uint8 j, , ) = path.decode();
		if (i > maxCurrencyId() || j > maxCurrencyId()) revert Errors.InvalidCurrencyId();

		bool zeroForOne = i == 0;

		(Currency currencyIn, Currency currencyOut, uint24 fee) = pool.getPoolKey();
		if (!zeroForOne) (currencyIn, currencyOut) = (currencyOut, currencyIn);

		(int256 amount0Delta, int256 amount1Delta) = pool.computeDeltaAmounts(
			fee,
			zeroForOne,
			amountIn.toInt256()
		);

		return uint256(-(zeroForOne ? amount1Delta : amount0Delta));
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

			mstore(ptr, add(hex"ff", shl(0x58, SUSHI_V3_FACTORY)))
			mstore(add(ptr, 0x15), keccak256(add(ptr, 0x15), 0x60))
			mstore(add(ptr, 0x35), SUSHI_V3_POOL_INIT_CODE_HASH)

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
