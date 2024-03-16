// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DoDoV2Adapter} from "src/adapters/DoDoV2Adapter.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseTest} from "test/shared/BaseTest.t.sol";

contract DoDoV2AdapterTest is BaseTest {
	using CurrencyLibrary for Currency;

	uint256 ethAmount = 20 ether;

	DoDoV2Adapter adapter;

	function setUp() public {
		fork();

		adapter = DoDoV2Adapter(
			deployAdapter(
				"DODO_V2_ADAPTER",
				abi.encodePacked(type(DoDoV2Adapter).creationCode, abi.encode(DODO_V2_ID, WETH))
			)
		);
	}

	function testSellBaseOnDoDoV2() public {
		Currency currencyIn = base();
		Currency currencyOut = quote();

		uint256 amountIn = feed() != address(0)
			? computeAmountIn(currencyIn, feed(), ethAmount)
			: querySellQuote(pool(), ethAmount);

		deal(currencyIn, address(adapter), amountIn);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn);

		(bytes32 queryPath, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(toPool(queryPath), pool());
		assertGt(queryAmount, 0);

		uint256 quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		uint256 amountOut = adapter.dodoV2Swap(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	function testWrapETHThenSellBaseOnDoDoV2() public {
		Currency currencyIn = ETH;
		Currency currencyOut = quote();

		uint256 amountIn = computeAmountIn(currencyIn, feed(), ethAmount);

		deal(ETH, address(adapter), amountIn);
		assertEq(getBalance(ETH, address(adapter)), amountIn);

		(bytes32 queryPath, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(toPool(queryPath), pool());
		assertGt(queryAmount, 0);

		uint256 quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		uint256 amountOut = adapter.dodoV2Swap(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	function testSellQuoteOnDoDoV2() public {
		Currency currencyIn = quote();
		Currency currencyOut = base();

		uint256 amountIn = feed() != address(0)
			? computeAmountIn(currencyIn, feed(), ethAmount)
			: querySellBase(pool(), ethAmount);

		deal(currencyIn, address(adapter), amountIn);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn);

		(bytes32 queryPath, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(toPool(queryPath), pool());
		assertGt(queryAmount, 0);

		uint256 quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		uint256 amountOut = adapter.dodoV2Swap(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	function testSellQuoteThenUnwrapWETHOnDoDoV2() public {
		Currency currencyIn = quote();
		Currency currencyOut = ETH;

		uint256 amountIn = feed() != address(0)
			? computeAmountIn(currencyIn, feed(), ethAmount)
			: querySellBase(pool(), ethAmount);

		deal(currencyIn, address(adapter), amountIn);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn);

		(bytes32 queryPath, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(toPool(queryPath), pool());
		assertGt(queryAmount, 0);

		uint256 quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		uint256 amountOut = adapter.dodoV2Swap(queryPath);
		assertEq(amountOut, quoteAmount);
		assertEq(address(adapter).balance, amountOut);
	}

	function sync(address dodoPool) internal {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xfff6cae900000000000000000000000000000000000000000000000000000000) // sync()

			if iszero(call(gas(), dodoPool, 0x00, ptr, 0x04, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function getPools(
		address factory,
		Currency currencyIn,
		Currency currencyOut
	) internal view returns (address[] memory) {
		bytes memory returndata;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x57a281dc00000000000000000000000000000000000000000000000000000000) // getDODOPool(address,address)
			mstore(add(ptr, 0x04), and(currencyIn, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(currencyOut, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), factory, ptr, 0x44, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x40, add(returndata, add(returndatasize(), 0x20)))
			mstore(returndata, returndatasize())
			returndatacopy(add(returndata, 0x20), 0x00, returndatasize())
		}

		return abi.decode(returndata, (address[]));
	}

	function querySellBase(address dodoPool, uint256 amount) internal view returns (uint256 value) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x79a0487600000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), amount)

			if iszero(staticcall(gas(), dodoPool, ptr, 0x44, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			value := mload(0x00)
		}
	}

	function querySellQuote(address dodoPool, uint256 amount) internal view returns (uint256 value) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x66410a2100000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), amount)

			if iszero(staticcall(gas(), dodoPool, ptr, 0x44, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			value := mload(0x00)
		}
	}

	function isBase(address dodoPool, Currency currency) internal view returns (bool res) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x4a248d2a00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), dodoPool, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			res := eq(currency, mload(0x00))
		}
	}

	// WETH-NEAR DVM
	function pool() internal pure returns (address) {
		return 0x983dfBa1c0724786598Af0E63a9a6f94aAbd24A1;
	}

	function base() internal pure returns (Currency) {
		return WETH;
	}

	function quote() internal pure returns (Currency) {
		return NEAR;
	}

	function feed() internal pure returns (address) {
		return address(0);
	}
}
