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
	using UniswapV3Library for uint256;

	constructor(uint256 _id, Currency _weth) BaseAdapter(_id, _weth) {}

	function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
		uint256 protocolId;
		Currency currencyIn;
		Currency currencyOut;
		uint24 fee;

		assembly ("memory-safe") {
			if and(iszero(sgt(amount0Delta, 0)), iszero(sgt(amount1Delta, 0))) {
				invalid()
			}

			let firstWord := calldataload(data.offset)
			protocolId := shr(248, firstWord)
			currencyIn := and(shr(88, firstWord), 0xffffffffffffffffffffffffffffffffffffffff)
			fee := and(shr(64, firstWord), 0xffffff)
			currencyOut := shr(96, calldataload(add(data.offset, 24)))
		}

		address pool = protocolId.computePoolAddress(currencyIn, currencyOut, fee);

		if (pool != _msgSender()) revert Errors.InvalidPool();

		(bool isExactInput, uint256 amountToPay) = amount0Delta > 0
			? (currencyIn < currencyOut, uint256(amount0Delta))
			: (currencyOut < currencyIn, uint256(amount1Delta));

		if (!isExactInput) revert Errors.InvalidDirection();

		currencyIn.transfer(pool, amountToPay);
	}

	function sushiV3Swap(bytes32 path) external payable returns (uint256 amountOut) {
		return _swap(path);
	}

	function _swap(bytes32 path) internal virtual override returns (uint256 amountOut) {
		(address pool, uint8 i, uint8 j, uint8 wrapIn, uint8 wrapOut) = path.decode();

		if (i > maxCurrencyId() || j > maxCurrencyId()) revert Errors.InvalidCurrencyId();
		if (i == j) revert Errors.IdenticalCurrencyIds();

		(Currency currencyIn, Currency currencyOut, uint24 fee) = pool.getPoolKey();
		if (i != 0) (currencyIn, currencyOut) = (currencyOut, currencyIn);

		if (wrapIn == WRAP_ETH) wrapETH(currencyIn, address(this).balance);

		uint256 amountIn = currencyIn.balanceOfSelf();
		if (amountIn == 0) revert Errors.InsufficientAmountIn();

		if (wrapIn == UNWRAP_WETH) unwrapWETH(currencyIn, amountIn);

		bool zeroForOne = currencyIn < currencyOut;

		(int256 amount0Delta, int256 amount1Delta) = pool.swap(
			address(this),
			zeroForOne,
			amountIn.toInt256(),
			(zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1),
			abi.encodePacked(uint8(id), currencyIn, fee, currencyOut)
		);

		amountOut = uint256(-(zeroForOne ? amount1Delta : amount0Delta));

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

		(address pool, uint24 fee) = getPoolWithMostLiquidity(currencyIn, currencyOut);

		if (pool != address(0)) {
			bool zeroForOne = currencyIn < currencyOut;

			(int256 amount0Delta, int256 amount1Delta) = pool.computeDeltaAmounts(
				fee,
				zeroForOne,
				amountIn.toInt256()
			);

			if ((amountOut = uint256(-(zeroForOne ? amount1Delta : amount0Delta))) != 0) {
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

	function _quote(
		bytes32 path,
		uint256 amountIn
	) internal view virtual override returns (uint256 amountOut) {
		(address pool, uint8 i, uint8 j, , ) = path.decode();

		if (i > maxCurrencyId() || j > maxCurrencyId()) revert Errors.InvalidCurrencyId();
		if (i == j) revert Errors.IdenticalCurrencyIds();

		bool zeroForOne = i == 0;

		(int256 amount0Delta, int256 amount1Delta) = pool.computeDeltaAmounts(
			pool.getFee(),
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

		uint256 protocolId = id;
		address poolCurrent;
		uint128 liquidityCurrent;
		uint128 liquidityMost;
		uint256 i;

		while (i < 4) {
			poolCurrent = protocolId.computePoolAddress(currencyA, currencyB, feeAmounts[i]);

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

	function maxCurrencyId() internal pure virtual override returns (uint256) {
		return 1;
	}
}
