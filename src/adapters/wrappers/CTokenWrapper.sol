// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Errors} from "src/libraries/Errors.sol";
import {PathDecoder} from "src/libraries/PathDecoder.sol";
import {WadRayMath} from "src/libraries/WadRayMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseAdapter} from "../BaseAdapter.sol";
import {BaseWrapper} from "./BaseWrapper.sol";

/// @title CTokenWrapper
/// @notice Performs wrapping and unwrapping for cTokens

contract CTokenWrapper is BaseWrapper {
	using CurrencyLibrary for Currency;
	using PathDecoder for bytes32;
	using WadRayMath for uint256;

	address internal immutable COMPTROLLER;

	Currency internal immutable cNATIVE;
	Currency internal immutable CETH;

	bytes4 internal constant CTOKEN_MINT_SELECTOR = 0xa0712d68;
	bytes4 internal constant CTOKEN_MINT_NATIVE_SELECTOR = 0x1249c58b;
	bytes4 internal constant CTOKEN_REDEEM_SELECTOR = 0xdb006a75;

	uint8 internal constant UNDERLYING_IDX = 0;
	uint8 internal constant CTOKEN_IDX = 1;

	uint256 internal constant MAX_BORROW_RATE = 0.0005e16;

	constructor(
		uint256 _id,
		Currency _weth,
		address _comptroller,
		Currency _cNative,
		Currency _ceth
	) BaseWrapper(_id, _weth) {
		COMPTROLLER = _comptroller;
		cNATIVE = _cNative;
		CETH = _ceth;
	}

	function wrapCToken(bytes32 path) external payable returns (uint256) {
		return invoke(path);
	}

	function unwrapCToken(bytes32 path) external payable returns (uint256 amountOut) {
		return invoke(path);
	}

	function invoke(bytes32 path) internal virtual override returns (uint256 amountOut) {
		(address pool, uint8 i, uint8 j, uint8 wrapIn, uint8 wrapOut) = path.decode();

		Currency cToken = Currency.wrap(pool);
		Currency asset = cTokenToUnderlying(cToken);

		if (i == UNDERLYING_IDX && j == CTOKEN_IDX) {
			bool isCNative = cToken == cNATIVE;

			if (!isCNative) {
				if (wrapIn == WRAP_ETH) wrapETH(WETH, address(this).balance);

				uint256 amountIn = asset.balanceOfSelf();

				asset.approve(pool, amountIn);

				_invoke(cToken, CTOKEN_MINT_SELECTOR, amountIn, isCNative);
			} else {
				if (wrapIn == UNWRAP_WETH) unwrapWETH(WETH, WETH.balanceOfSelf());

				_invoke(cToken, CTOKEN_MINT_NATIVE_SELECTOR, address(this).balance, isCNative);
			}

			amountOut = cToken.balanceOfSelf();
		} else if (i == CTOKEN_IDX && j == UNDERLYING_IDX) {
			_invoke(cToken, CTOKEN_REDEEM_SELECTOR, cToken.balanceOfSelf(), false);

			amountOut = asset.balanceOfSelf();

			if (wrapOut == WRAP_ETH) wrapETH(asset, amountOut);
			else if (wrapOut == UNWRAP_WETH) unwrapWETH(asset, amountOut);
		} else {
			revert Errors.InvalidCurrencyId();
		}
	}

	function _invoke(Currency cToken, bytes4 selector, uint256 amountIn, bool isCNative) internal {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			switch isCNative
			case 0x00 {
				mstore(ptr, selector)
				mstore(add(ptr, 0x04), amountIn)

				if iszero(
					and(
						or(and(iszero(mload(0x00)), gt(returndatasize(), 0x1f)), iszero(returndatasize())),
						call(gas(), cToken, 0x00, ptr, 0x24, 0x00, 0x20)
					)
				) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
			default {
				mstore(ptr, selector)

				if iszero(call(gas(), cToken, amountIn, ptr, 0x04, 0x00, 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}
		}
	}

	function _query(
		Currency currencyIn,
		Currency currencyOut,
		uint256 amountIn,
		bool direction
	) internal view virtual override returns (bytes32 path, uint256 amountOut) {
		(Currency cToken, Currency asset) = !direction
			? (currencyIn, currencyOut)
			: (currencyOut, currencyIn);

		uint8 wrapIn;
		uint8 wrapOut;

		if (asset == WETH) {
			if (direction) wrapIn = UNWRAP_WETH;
			else wrapOut = WRAP_ETH;
			asset = CurrencyLibrary.NATIVE;
		}

		if (!isDeprecated(COMPTROLLER, cToken) && cTokenToUnderlying(cToken) == asset) {
			if (
				(amountOut = !direction
					? amountIn.wadMul(getExchangeRate(cToken))
					: amountIn.wadDiv(getExchangeRate(cToken))) != 0
			) {
				assembly ("memory-safe") {
					path := add(
						cToken,
						add(
							shl(160, iszero(direction)),
							add(shl(168, direction), add(shl(176, wrapIn), shl(184, wrapOut)))
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

		if (i == UNDERLYING_IDX && j == CTOKEN_IDX) {
			return amountIn.wadDiv(getExchangeRate(Currency.wrap(pool)));
		} else if (i == CTOKEN_IDX && j == UNDERLYING_IDX) {
			return amountIn.wadMul(getExchangeRate(Currency.wrap(pool)));
		} else {
			revert Errors.InvalidCurrencyId();
		}
	}

	function getExchangeRate(Currency cToken) internal view returns (uint256 exchangeRate) {
		address irm = interestRateModel(cToken);

		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x84)

			// accrualBlockNumber(), getCash(), totalBorrows(), totalReserves(), reserveFactorMantissa(), totalSupply(), borrowIndex(), exchangeRateStored()
			mstore(ptr, 0x6c540baf3b1d21a247bd37188f840ddd173b990418160dddaa5af0fd182df0f5)

			// cToken.accrualBlockNumber()
			if iszero(staticcall(gas(), cToken, ptr, 0x04, res, 0x20)) {
				revert(ptr, 0x04)
			}

			let blockDelta := sub(number(), mload(res))
			res := add(res, 0x20)

			switch iszero(blockDelta)
			case 0x00 {
				// cToken.getCash()
				if iszero(staticcall(gas(), cToken, add(ptr, 0x04), 0x04, res, 0x20)) {
					revert(add(ptr, 0x04), 0x04)
				}

				let cash := mload(res)
				res := add(res, 0x20)

				// cToken.totalBorrows()
				if iszero(staticcall(gas(), cToken, add(ptr, 0x08), 0x04, res, 0x20)) {
					revert(add(ptr, 0x08), 0x04)
				}

				let borrows := mload(res)
				res := add(res, 0x20)

				// cToken.totalReserves()
				if iszero(staticcall(gas(), cToken, add(ptr, 0x0c), 0x04, res, 0x20)) {
					revert(add(ptr, 0x0c), 0x04)
				}

				let reserves := mload(res)
				res := add(res, 0x20)

				// cToken.reserveFactorMantissa()
				if iszero(staticcall(gas(), cToken, add(ptr, 0x10), 0x04, res, 0x20)) {
					revert(add(ptr, 0x10), 0x04)
				}

				let reserveFactor := mload(res)
				res := add(res, 0x20)

				// cToken.totalSupply()
				if iszero(staticcall(gas(), cToken, add(ptr, 0x14), 0x04, res, 0x20)) {
					revert(add(ptr, 0x14), 0x04)
				}

				let supplies := mload(res)
				res := add(res, 0x20)

				// cToken.borrowIndex()
				if iszero(staticcall(gas(), cToken, add(ptr, 0x18), 0x04, res, 0x20)) {
					revert(add(ptr, 0x18), 0x04)
				}

				let indexPrior := mload(res)
				res := add(res, 0x20)

				mstore(add(ptr, 0x20), 0x15f2405300000000000000000000000000000000000000000000000000000000) // irm.getBorrowRate(uint256,uint256,uint256)
				mstore(add(ptr, 0x24), cash)
				mstore(add(ptr, 0x44), borrows)
				mstore(add(ptr, 0x64), reserves)

				if iszero(staticcall(gas(), irm, add(ptr, 0x20), 0x64, res, 0x40)) {
					revert(add(ptr, 0x20), 0x04)
				}

				let borrowRate

				switch returndatasize()
				case 0x20 {
					borrowRate := mload(res)
				}
				case 0x40 {
					borrowRate := mload(add(res, 0x20))
				}

				if gt(borrowRate, MAX_BORROW_RATE) {
					invalid()
				}

				let interestAccumulated := div(mul(mul(borrowRate, blockDelta), borrows), exp(10, 18))

				borrows := add(borrows, interestAccumulated)
				reserves := add(reserves, div(mul(reserveFactor, interestAccumulated), exp(10, 18)))
				exchangeRate := div(mul(sub(add(cash, borrows), reserves), exp(10, 18)), supplies)
			}
			default {
				// cToken.exchangeRateStored()
				if iszero(staticcall(gas(), cToken, add(ptr, 0x1c), 0x04, res, 0x20)) {
					revert(add(ptr, 0x1c), 0x04)
				}

				exchangeRate := mload(res)
			}
		}
	}

	function cTokenToUnderlying(Currency cToken) internal view returns (Currency underlying) {
		if (cToken == cNATIVE) return CurrencyLibrary.NATIVE;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x6f307dc300000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), cToken, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			underlying := mload(0x00)
		}
	}

	function interestRateModel(Currency cToken) internal view returns (address irm) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xf3fdb15a00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), cToken, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			irm := mload(0x00)
		}
	}

	function isDeprecated(
		address comptroller,
		Currency cToken
	) internal view virtual returns (bool deprecated) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x94543c1500000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(cToken, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), comptroller, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			deprecated := mload(0x00)
		}
	}

	function maxCurrencyId() internal pure virtual override returns (uint256) {
		return CTOKEN_IDX;
	}
}
