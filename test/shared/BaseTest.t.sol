// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Create3} from "src/libraries/Create3.sol";
import {FullMath} from "src/libraries/FullMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {Constants} from "./Constants.sol";

abstract contract BaseTest is Test, Constants {
	using CurrencyLibrary for Currency;

	uint256 ethAmount = 20 ether;

	function deployAdapter(
		bytes32 salt,
		bytes memory creationCode
	) internal returns (address payable adapter) {
		return payable(Create3.create3(keccak256(abi.encodePacked(salt, address(this))), creationCode));
	}

	function fork() internal virtual {
		vm.createSelectFork(vm.envString("RPC_ETHEREUM"), FORK_BLOCK);
	}

	function deal(Currency currency, address account, uint256 amount) internal returns (uint256) {
		if (currency == STETH) {
			return dealSTETH(currency, account, amount);
		} else if (currency == USDC) {
			return dealUSDC(currency, account, amount);
		} else {
			if (currency.isNative()) deal(account, amount);
			else deal(currency.toAddress(), account, amount);

			return currency.balanceOf(account);
		}
	}

	function dealUSDC(Currency usdc, address account, uint256 amount) internal returns (uint256) {
		vm.prank(USDC_MASTER_MINTER);

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x4e44d95600000000000000000000000000000000000000000000000000000000) // configureMinter(address,uint256)
			mstore(add(ptr, 0x04), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), sub(exp(0x02, 0x100), 0x01))

			if iszero(call(gas(), usdc, 0x00, ptr, 0x44, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x40c10f1900000000000000000000000000000000000000000000000000000000) // mint(address,uint256)
			mstore(add(ptr, 0x04), and(account, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), amount)

			if iszero(call(gas(), usdc, 0x00, ptr, 0x44, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}

		return usdc.balanceOf(account);
	}

	function dealSTETH(Currency steth, address account, uint256 amount) internal returns (uint256 staked) {
		deal(account, amount);

		vm.prank(account);

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xa1903eab00000000000000000000000000000000000000000000000000000000) // submit(address)
			mstore(add(ptr, 0x04), and(0x00, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(call(gas(), steth, amount, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			staked := mload(0x00)
		}
	}

	function getBalance(Currency currency, address account) internal view returns (uint256) {
		if (currency != STETH) return currency.balanceOf(account);
		else return sharesOf(currency, account);
	}

	function sharesOf(Currency steth, address account) internal view returns (uint256 shares) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xf5eb42dc00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(account, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), steth, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			shares := mload(0x00)
		}
	}

	function latestAnswer(address aggregator) internal view returns (uint256 answer) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x50d25bcd00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), aggregator, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			if iszero(slt(mload(0x00), 0x00)) {
				answer := mload(0x00)
			}
		}
	}

	function computeAmountIn(
		Currency currencyIn,
		address feed,
		uint256 amount
	) internal view returns (uint256) {
		if (currencyIn.isNative() || currencyIn == WETH) return amount;

		return FullMath.mulDiv(amount, 10 ** currencyIn.decimals(), latestAnswer(feed));
	}

	function convertFromETH(uint256 amount, uint256 price, uint256 unit) internal pure returns (uint256) {
		return FullMath.mulDiv(amount, 10 ** unit, price);
	}

	function convertToETH(uint256 amount, uint256 price, uint256 unit) internal pure returns (uint256) {
		return FullMath.mulDiv(amount, price, 10 ** unit);
	}

	function derivePrice(
		uint256 basePrice,
		uint256 quotePrice,
		uint8 baseDecimals,
		uint8 quoteDecimals,
		uint8 assetDecimals
	) internal pure returns (uint256 derived) {
		if (basePrice != 0 && quotePrice != 0) {
			derived = FullMath.mulDiv(
				scalePrice(basePrice, baseDecimals, assetDecimals),
				10 ** assetDecimals,
				scalePrice(quotePrice, quoteDecimals, assetDecimals)
			);
		}
	}

	function scalePrice(
		uint256 price,
		uint8 feedDecimals,
		uint8 assetDecimals
	) internal pure returns (uint256 scaled) {
		assembly ("memory-safe") {
			switch or(iszero(price), eq(feedDecimals, assetDecimals))
			case 0x00 {
				switch gt(feedDecimals, assetDecimals)
				case 0x00 {
					scaled := mul(price, exp(10, sub(assetDecimals, feedDecimals)))
				}
				default {
					scaled := div(price, exp(10, sub(feedDecimals, assetDecimals)))
				}
			}
			default {
				scaled := price
			}
		}
	}

	function pack(
		address pool,
		uint8 i,
		uint8 j,
		uint8 wrapIn,
		uint8 wrapOut,
		bool isUnderlying
	) internal pure returns (bytes32 path) {
		assembly ("memory-safe") {
			path := add(
				pool,
				add(
					shl(160, i),
					add(shl(168, j), add(shl(176, wrapIn), add(shl(184, wrapOut), shl(192, isUnderlying))))
				)
			)
		}
	}

	function unpack(
		bytes32 path
	)
		internal
		pure
		returns (address pool, uint8 i, uint8 j, uint8 wrapIn, uint8 wrapOut, bool pullIn, bool isUnderlying)
	{
		assembly ("memory-safe") {
			pool := and(path, 0xffffffffffffffffffffffffffffffffffffffff)
			i := and(shr(160, path), 0xff)
			j := and(shr(168, path), 0xff)
			wrapIn := and(shr(176, path), 0xff)
			wrapOut := and(shr(184, path), 0xff)
			pullIn := and(shr(192, path), 0xff)
			isUnderlying := and(shr(200, path), 0xff)
		}
	}

	function toPool(bytes32 path) internal pure returns (address) {
		return address(uint160(uint256(path)));
	}

	receive() external payable {}
}
