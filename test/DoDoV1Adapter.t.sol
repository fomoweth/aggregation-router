// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2 as console} from "forge-std/Test.sol";
import {DoDoV1Adapter} from "src/adapters/DoDoV1Adapter.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseTest} from "test/BaseTest.t.sol";

// forge test -vvv --match-path test/DoDoV1Adapter.t.sol

contract DoDoV1AdapterTest is BaseTest {
	using CurrencyLibrary for Currency;

	uint256 ethAmount = 20 ether;

	DoDoV1Adapter adapter;

	address constant SELL_HELPER = 0x533dA777aeDCE766CEAe696bf90f8541A4bA80Eb;

	function setUp() public {
		fork();

		adapter = DoDoV1Adapter(
			deployAdapter(
				"DODO_V1_ADAPTER",
				abi.encodePacked(type(DoDoV1Adapter).creationCode, abi.encode(DODO_V1_ID, WETH))
			)
		);
	}

	function testSellBaseOnDoDoV1() public {
		Currency currencyIn = base();
		Currency currencyOut = quote();

		uint8 i = 0;
		uint8 j = 1;

		uint256 amountIn = feed() != address(0)
			? computeAmountIn(currencyIn, feed(), ethAmount)
			: querySellBaseToken(pool(), ethAmount);

		deal(currencyIn, address(adapter), amountIn);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, pool());
		assertGt(queryAmount, 0);

		bytes32 path = pack(queryPool, i, j, NO_ACTION, NO_ACTION, false);

		uint256 amountOut = adapter.dodoV1Swap(path);
		assertEq(amountOut, queryAmount);
	}

	function testWrapETHThenSellBaseOnDoDoV1() public {
		Currency currencyIn = base();
		Currency currencyOut = quote();

		uint8 i = 0;
		uint8 j = 1;

		uint256 amountIn = deal(ETH, address(adapter), ethAmount);
		assertEq(getBalance(ETH, address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, pool());
		assertGt(queryAmount, 0);

		bytes32 path = pack(queryPool, i, j, WRAP_ETH, NO_ACTION, false);

		uint256 amountOut = adapter.dodoV1Swap(path);
		assertEq(amountOut, queryAmount);
	}

	function testSellQuoteOnDoDoV1() public {
		Currency currencyIn = quote();
		Currency currencyOut = base();

		uint8 i = 1;
		uint8 j = 0;

		uint256 amountIn = feed() != address(0)
			? computeAmountIn(currencyIn, feed(), ethAmount)
			: querySellBaseToken(pool(), ethAmount);

		deal(currencyIn, address(adapter), amountIn);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, pool());
		assertGt(queryAmount, 0);

		bytes32 path = pack(queryPool, i, j, NO_ACTION, NO_ACTION, false);

		uint256 amountOut = adapter.dodoV1Swap(path);
		assertEq(amountOut, queryAmount);
	}

	function testSellQuoteThenUnwrapWETHOnDoDoV1() public {
		Currency currencyIn = quote();
		Currency currencyOut = base();

		uint8 i = 1;
		uint8 j = 0;

		uint256 amountIn = feed() != address(0)
			? computeAmountIn(currencyIn, feed(), ethAmount)
			: querySellBaseToken(pool(), ethAmount);

		deal(currencyIn, address(adapter), amountIn);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, pool());
		assertGt(queryAmount, 0);

		bytes32 path = pack(queryPool, i, j, NO_ACTION, UNWRAP_ETH, false);

		uint256 amountOut = adapter.dodoV1Swap(path);
		assertEq(amountOut, queryAmount);
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

	function querySellBaseToken(address dodoPool, uint256 amount) internal view returns (uint256 value) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xef4a83f800000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), amount)

			if iszero(staticcall(gas(), dodoPool, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			value := mload(0x00)
		}
	}

	function queryBuyBaseToken(address dodoPool, uint256 amount) internal view returns (uint256 value) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xca19ebd900000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), amount)

			if iszero(staticcall(gas(), dodoPool, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			value := mload(0x00)
		}
	}

	function pool() internal pure returns (address) {
		return DODO_V1_WETH_USDC_POOL;
	}

	function base() internal pure returns (Currency) {
		return WETH;
	}

	function quote() internal pure returns (Currency) {
		return USDC;
	}

	function feed() internal pure returns (address) {
		return USDC_ETH_FEED;
	}
}