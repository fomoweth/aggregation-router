// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FRXETH_MINTER} from "src/libraries/Constants.sol";
import {Errors} from "src/libraries/Errors.sol";
import {PathDecoder} from "src/libraries/PathDecoder.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseWrapper} from "./BaseWrapper.sol";

/// @title FRXETHWrapper
/// @notice Performs wrapping and unwrapping for frxETH and sfrxETH

contract FRXETHWrapper is BaseWrapper {
	using CurrencyLibrary for Currency;
	using PathDecoder for bytes32;

	Currency internal immutable FRXETH;
	Currency internal immutable SFRXETH;

	uint8 internal constant ETH_IDX = 0;
	uint8 internal constant FRXETH_IDX = 1;
	uint8 internal constant SFRXETH_IDX = 2;

	constructor(uint256 _id, Currency _weth, Currency _frxeth, Currency _sfrxeth) BaseWrapper(_id, _weth) {
		FRXETH = _frxeth;
		SFRXETH = _sfrxeth;
	}

	function wrapFRXETH(bytes32 path) external payable returns (uint256) {
		return invoke(path);
	}

	function wrapSFRXETH(bytes32 path) external payable returns (uint256) {
		return invoke(path);
	}

	function unwrapSFRXETH(bytes32 path) external payable returns (uint256) {
		return invoke(path);
	}

	function invoke(bytes32 path) internal virtual override returns (uint256 amountOut) {
		(, uint8 i, uint8 j, uint8 wrapIn, ) = path.decode();

		if (i > maxCurrencyId() || (j != FRXETH_IDX && j != SFRXETH_IDX)) revert Errors.InvalidCurrencyId();
		if (i == j) revert Errors.IdenticalCurrencyIds();

		uint256 amountIn;

		if (i == ETH_IDX) {
			if (wrapIn == UNWRAP_WETH) unwrapWETH(WETH, WETH.balanceOfSelf());

			amountIn = address(this).balance;
		} else if (i == FRXETH_IDX) {
			FRXETH.approve(SFRXETH.toAddress(), (amountIn = FRXETH.balanceOfSelf()));
		} else if (i == SFRXETH_IDX) {
			amountIn = SFRXETH.balanceOfSelf();
		}

		if (amountIn == 0) revert Errors.InsufficientAmountIn();

		return _invoke(i, j, amountIn);
	}

	function _invoke(uint8 i, uint8 j, uint256 amountIn) internal returns (uint256 amountOut) {
		Currency sfrxeth = SFRXETH;

		assembly ("memory-safe") {
			function execute(p, t, v, s) -> r {
				if iszero(call(gas(), t, v, p, s, 0x00, 0x20)) {
					returndatacopy(p, 0x00, returndatasize())
					revert(p, returndatasize())
				}

				r := mload(0x00)
			}

			let ptr := mload(0x40)

			switch and(eq(i, 0x00), eq(j, 0x01))
			case 0x00 {
				switch j
				case 0x01 {
					// sfrxETH -> frxETH
					if eq(i, 0x02) {
						mstore(ptr, 0xba08765200000000000000000000000000000000000000000000000000000000) // redeem(uint256,address,address)
						mstore(add(ptr, 0x04), amountIn)
						mstore(add(ptr, 0x24), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
						mstore(add(ptr, 0x44), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

						amountOut := execute(ptr, sfrxeth, 0x00, 0x64)
					}
				}
				case 0x02 {
					switch i
					// ETH -> sfrxETH
					case 0x00 {
						mstore(ptr, 0x4dcd454700000000000000000000000000000000000000000000000000000000) // submitAndDeposit(address)
						mstore(add(ptr, 0x04), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

						amountOut := execute(ptr, FRXETH_MINTER, amountIn, 0x24)
					}
					// frxETH -> sfrxETH
					case 0x01 {
						mstore(ptr, 0x6e553f6500000000000000000000000000000000000000000000000000000000) // deposit(uint256,address)
						mstore(add(ptr, 0x04), amountIn)
						mstore(add(ptr, 0x24), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

						amountOut := execute(ptr, sfrxeth, 0x00, 0x44)
					}
				}
			}
			// ETH -> frxETH
			default {
				// ETH can be staked for frxETH via Minter by executing submit() or sending ETH which is cheaper
				if iszero(call(gas(), FRXETH_MINTER, amountIn, 0x00, 0x00, 0x00, 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}

				amountOut := amountIn
			}
		}
	}

	function _query(
		Currency currencyIn,
		Currency currencyOut,
		uint256 amountIn,
		bool
	) internal view virtual override returns (bytes32 path, uint256 amountOut) {
		Currency pool;
		uint8 i;
		uint8 j;
		uint8 wrapIn;

		if (currencyIn == WETH) {
			wrapIn = UNWRAP_WETH;
			currencyIn = CurrencyLibrary.NATIVE;
		}

		if (currencyIn.isNative() && currencyOut == FRXETH) {
			pool = FRXETH;
			i = ETH_IDX;
			j = FRXETH_IDX;
		} else if (currencyIn.isNative() && currencyOut == SFRXETH) {
			pool = SFRXETH;
			i = ETH_IDX;
			j = SFRXETH_IDX;
		} else if (currencyIn == FRXETH && currencyOut == SFRXETH) {
			pool = SFRXETH;
			i = FRXETH_IDX;
			j = SFRXETH_IDX;
		} else if (currencyIn == SFRXETH && currencyOut == FRXETH) {
			pool = SFRXETH;
			i = SFRXETH_IDX;
			j = FRXETH_IDX;
		}

		if ((amountOut = convert(SFRXETH, i, j, amountIn)) != 0) {
			assembly ("memory-safe") {
				path := add(
					pool,
					add(shl(160, i), add(shl(168, j), add(shl(176, wrapIn), shl(184, NO_ACTION))))
				)
			}
		}
	}

	function _quote(
		bytes32 path,
		uint256 amountIn
	) internal view virtual override returns (uint256 amountOut) {
		(, uint8 i, uint8 j, , ) = path.decode();

		if (i > maxCurrencyId() || (j != FRXETH_IDX && j != SFRXETH_IDX)) revert Errors.InvalidCurrencyId();
		if (i == j) revert Errors.IdenticalCurrencyIds();

		return convert(SFRXETH, i, j, amountIn);
	}

	function convert(
		Currency sfrxeth,
		uint8 i,
		uint8 j,
		uint256 amountIn
	) internal view returns (uint256 amountOut) {
		assembly ("memory-safe") {
			switch and(eq(i, ETH_IDX), eq(j, FRXETH_IDX))
			case 0x00 {
				let ptr := mload(0x40)

				switch j
				// sfrxETH -> frxETH
				case 0x01 {
					mstore(ptr, 0x07a2d13a00000000000000000000000000000000000000000000000000000000) // convertToAssets(uint256)
				}
				// ETH || frxETH -> sfrxETH
				case 0x02 {
					mstore(ptr, 0xc6e6f59200000000000000000000000000000000000000000000000000000000) // convertToShares(uint256)
				}

				mstore(add(ptr, 0x04), amountIn)

				if iszero(staticcall(gas(), sfrxeth, ptr, 0x24, 0x00, 0x20)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}

				amountOut := mload(0x00)
			}
			// ETH -> frxETH
			default {
				amountOut := amountIn
			}
		}
	}

	function maxCurrencyId() internal pure virtual override returns (uint256) {
		return SFRXETH_IDX;
	}
}
