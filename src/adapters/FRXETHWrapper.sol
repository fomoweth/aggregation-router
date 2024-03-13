// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FRXETH_MINTER} from "src/libraries/Constants.sol";
import {Errors} from "src/libraries/Errors.sol";
import {PathDecoder} from "src/libraries/PathDecoder.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseAdapter} from "./BaseAdapter.sol";

/// @title FRXETHWrapper
/// @notice Performs wrapping and unwrapping for frxETH and sfrxETH

contract FRXETHWrapper is BaseAdapter {
	using CurrencyLibrary for Currency;
	using PathDecoder for bytes32;

	Currency internal immutable FRXETH;
	Currency internal immutable SFRXETH;

	uint8 internal constant ETH_IDX = 0;
	uint8 internal constant FRXETH_IDX = 1;
	uint8 internal constant SFRXETH_IDX = 2;

	constructor(uint256 _id, Currency _weth, Currency _frxeth, Currency _sfrxeth) BaseAdapter(_id, _weth) {
		FRXETH = _frxeth;
		SFRXETH = _sfrxeth;
	}

	function wrapFRXETH(bytes32 path) external payable returns (uint256) {
		(, uint8 i, uint8 j, uint8 wrapIn, ) = path.decode();
		if (i != ETH_IDX || j != FRXETH_IDX) revert Errors.InvalidCurrencyId();

		if (wrapIn == UNWRAP_ETH) unwrapWETH(WETH, WETH.balanceOfSelf());

		uint256 amountIn = address(this).balance;
		if (amountIn == 0) revert Errors.InsufficientAmountIn();

		return invoke(i, j, address(this).balance);
	}

	function wrapSFRXETH(bytes32 path) external payable returns (uint256) {
		(, uint8 i, uint8 j, uint8 wrapIn, ) = path.decode();
		if ((i != ETH_IDX && i != FRXETH_IDX) || j != SFRXETH_IDX) revert Errors.InvalidCurrencyId();

		uint256 amountIn;

		if (i == ETH_IDX) {
			if (wrapIn == UNWRAP_ETH) unwrapWETH(WETH, WETH.balanceOfSelf());
			if ((amountIn = address(this).balance) == 0) revert Errors.InsufficientAmountIn();
			amountIn = address(this).balance;
		} else {
			if ((amountIn = FRXETH.balanceOfSelf()) == 0) revert Errors.InsufficientAmountIn();
			amountIn = FRXETH.balanceOfSelf();
			FRXETH.approve(SFRXETH.toAddress(), amountIn);
		}

		return invoke(i, j, amountIn);
	}

	function unwrapSFRXETH(bytes32 path) external payable returns (uint256) {
		(, uint8 i, uint8 j, , ) = path.decode();
		if (i != SFRXETH_IDX || j != FRXETH_IDX) revert Errors.InvalidCurrencyId();

		uint256 amountIn = SFRXETH.balanceOfSelf();
		if (amountIn == 0) revert Errors.InsufficientAmountIn();

		return invoke(i, j, amountIn);
	}

	function _exchange(bytes32 path) internal virtual override returns (uint256 amountOut) {
		(, uint8 i, uint8 j, uint8 wrapIn, ) = path.decode();
		if (i > maxCurrencyId() || (j != FRXETH_IDX && j != SFRXETH_IDX)) revert Errors.InvalidCurrencyId();

		uint256 amountIn;

		if (i == ETH_IDX) {
			if (wrapIn == UNWRAP_ETH) unwrapWETH(WETH, WETH.balanceOfSelf());

			amountIn = address(this).balance;
		} else if (i == FRXETH_IDX) {
			FRXETH.approve(SFRXETH.toAddress(), (amountIn = FRXETH.balanceOfSelf()));
		} else if (i == SFRXETH_IDX) {
			amountIn = SFRXETH.balanceOfSelf();
		}

		if (amountIn == 0) revert Errors.InsufficientAmountIn();

		return invoke(i, j, amountIn);
	}

	function invoke(uint8 i, uint8 j, uint256 amountIn) internal returns (uint256 amountOut) {
		if (amountIn == 0) revert Errors.InsufficientAmountIn();

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
					if eq(i, 0x02) {
						// sfrxETH -> frxETH
						mstore(ptr, 0xba08765200000000000000000000000000000000000000000000000000000000) // redeem(uint256,address,address)
						mstore(add(ptr, 0x04), amountIn)
						mstore(add(ptr, 0x24), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
						mstore(add(ptr, 0x44), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

						amountOut := execute(ptr, sfrxeth, 0x00, 0x64)
					}
				}
				case 0x02 {
					switch i
					case 0x00 {
						// ETH -> sfrxETH
						mstore(ptr, 0x4dcd454700000000000000000000000000000000000000000000000000000000) // submitAndDeposit(address)
						mstore(add(ptr, 0x04), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

						amountOut := execute(ptr, FRXETH_MINTER, amountIn, 0x24)
					}
					case 0x01 {
						// frxETH -> sfrxETH
						mstore(ptr, 0x6e553f6500000000000000000000000000000000000000000000000000000000) // deposit(uint256,address)
						mstore(add(ptr, 0x04), amountIn)
						mstore(add(ptr, 0x24), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))

						amountOut := execute(ptr, sfrxeth, 0x00, 0x44)
					}
				}
			}
			default {
				// ETH -> frxETH

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
		uint256 amountIn
	) internal view virtual override returns (bytes32 path, uint256 amountOut) {
		Currency weth = WETH;
		Currency frxeth = FRXETH;
		Currency sfrxeth = SFRXETH;

		Currency pool = sfrxeth;
		uint8 wrapIn = currencyIn == weth ? UNWRAP_ETH : NO_ACTION;
		uint8 i;
		uint8 j;

		if ((currencyIn.isNative() || currencyIn == weth) && currencyOut == frxeth) {
			amountOut = amountIn;
			pool = frxeth;
			i = ETH_IDX;
			j = FRXETH_IDX;
		} else if ((currencyIn.isNative() || currencyIn == weth) && currencyOut == sfrxeth) {
			amountOut = convert(sfrxeth, amountIn, true);

			i = ETH_IDX;
			j = SFRXETH_IDX;
		} else if (currencyIn == frxeth && currencyOut == sfrxeth) {
			amountOut = convert(sfrxeth, amountIn, true);

			i = FRXETH_IDX;
			j = SFRXETH_IDX;
		} else if (currencyIn == sfrxeth && currencyOut == frxeth) {
			amountOut = convert(sfrxeth, amountIn, false);

			i = SFRXETH_IDX;
			j = FRXETH_IDX;
		}

		if (amountOut == 0) return (bytes32(0), 0);

		assembly ("memory-safe") {
			path := add(pool, add(shl(160, i), add(shl(168, j), add(shl(176, wrapIn), shl(184, NO_ACTION)))))
		}
	}

	function _quote(
		Currency currencyIn,
		Currency currencyOut,
		uint256 amountIn
	) internal view virtual override returns (address pool, uint256 amountOut) {
		Currency weth = WETH;
		Currency frxeth = FRXETH;
		Currency sfrxeth = SFRXETH;

		if (currencyOut == frxeth) {
			if (currencyIn.isNative() || currencyIn == weth) {
				return (frxeth.toAddress(), amountIn);
			} else if (currencyIn == sfrxeth) {
				return (sfrxeth.toAddress(), convert(sfrxeth, amountIn, false));
			}
		} else if (currencyOut == sfrxeth) {
			if (currencyIn.isNative() || currencyIn == weth || currencyIn == frxeth) {
				return (sfrxeth.toAddress(), convert(sfrxeth, amountIn, true));
			}
		} else {
			return (address(0), 0);
		}
	}

	function convert(
		Currency sfrxeth,
		uint256 amountIn,
		bool direction
	) internal view returns (uint256 amountOut) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			switch direction
			case 0x00 {
				// sfrxETH -> frxETH
				mstore(ptr, 0x07a2d13a00000000000000000000000000000000000000000000000000000000) // convertToAssets(uint256)
			}
			default {
				// frxETH -> sfrxETH
				mstore(ptr, 0xc6e6f59200000000000000000000000000000000000000000000000000000000) // convertToShares(uint256)
			}

			mstore(add(ptr, 0x04), amountIn)

			if iszero(staticcall(gas(), sfrxeth, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			amountOut := mload(0x00)
		}
	}

	function maxCurrencyId() internal pure virtual override returns (uint256) {
		return SFRXETH_IDX;
	}
}
