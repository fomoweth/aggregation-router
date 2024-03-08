// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Create3} from "src/libraries/Create3.sol";
import {FullMath} from "src/libraries/FullMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {Constants} from "test/utils/Constants.sol";

abstract contract BaseTest is Test, Constants {
	using CurrencyLibrary for Currency;

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
		if (currency != STETH) {
			if (currency.isNative()) deal(account, amount);
			else deal(currency.toAddress(), account, amount);

			return amount;
		} else {
			return dealSTETH(currency, account, amount);
		}
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

	function getBalance(Currency currency, address account) internal view returns (uint256 value) {
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
		uint256 ethAmount
	) internal view returns (uint256) {
		if (currencyIn.isNative() || currencyIn == WETH) return ethAmount;

		return FullMath.mulDiv(ethAmount, 10 ** currencyIn.decimals(), latestAnswer(feed));
	}

	function convertFromETH(uint256 ethAmount, uint256 price, uint256 unit) internal pure returns (uint256) {
		return FullMath.mulDiv(ethAmount, 10 ** unit, price);
	}

	function convertToETH(uint256 ethAmount, uint256 price, uint256 unit) internal pure returns (uint256) {
		return FullMath.mulDiv(ethAmount, price, 10 ** unit);
	}

	function pack(
		address pool,
		uint8 i,
		uint8 j,
		uint8 wrapIn,
		uint8 wrapOut
	) internal pure returns (bytes32 data) {
		assembly ("memory-safe") {
			data := add(pool, add(shl(160, i), add(shl(168, j), add(shl(176, wrapIn), shl(184, wrapOut)))))
		}
	}

	// For Curve
	function pack(
		address pool,
		uint8 i,
		uint8 j,
		uint8 wrapIn,
		uint8 wrapOut,
		bool isUnderlying
	) internal pure returns (bytes32 data) {
		assembly ("memory-safe") {
			data := add(
				pool,
				add(
					shl(160, i),
					add(shl(168, j), add(shl(176, wrapIn), add(shl(184, wrapOut), shl(192, isUnderlying))))
				)
			)
		}
	}
}
