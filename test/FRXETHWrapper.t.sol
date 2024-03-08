// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2 as console} from "forge-std/Test.sol";
import {FRXETHWrapper} from "src/adapters/FRXETHWrapper.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseTest} from "test/BaseTest.t.sol";

// forge test -vvv --match-path test/FRXETHWrapper.t.sol

contract FRXETHWrapperTest is BaseTest {
	using CurrencyLibrary for Currency;

	uint256 ethAmount = 20 ether;

	FRXETHWrapper adapter;

	function setUp() public {
		fork();

		adapter = FRXETHWrapper(
			deployAdapter(
				"FRXETH_WRAPPER",
				abi.encodePacked(
					type(FRXETHWrapper).creationCode,
					abi.encode(FRXETH_WRAPPER_ID, WETH, FRXETH, SFRXETH)
				)
			)
		);
	}

	function testStakeETH() public {
		// console.log("adapter:", address(adapter)); 0x15399DCC4d61206c6C55f0223F302F00E751Ef89
		// console.log("wrapFRXETH:"); 0xb8fd5ba0
		// console.logBytes4(adapter.wrapFRXETH.selector);
		// console.log("wrapSFRXETH:"); 0x41132c7e
		// console.logBytes4(adapter.wrapSFRXETH.selector);
		// console.log("unwrapSFRXETH:"); 0x254da26c
		// console.logBytes4(adapter.unwrapSFRXETH.selector);

		Currency currencyIn = ETH;
		Currency currencyOut = FRXETH;

		uint8 i = 0;
		uint8 j = 1;

		uint256 amountIn = ethAmount;
		deal(currencyIn, address(adapter), amountIn);
		assertEq(currencyIn.balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(pool, FRXETH.toAddress());
		assertEq(expected, amountIn);

		bytes32 data = pack(pool, i, j, NO_ACTION, NO_ACTION, false);

		uint256 amountOut = adapter.exchange(data);
		assertEq(amountOut, expected);

		uint256 balanceIn = currencyIn.balanceOf(address(adapter));
		uint256 balanceOut = currencyOut.balanceOf(address(adapter));

		assertEq(balanceIn, 0);
		assertEq(balanceOut, amountOut);
	}

	function testUnwrapWETHThenStakeETH() public {
		Currency currencyIn = WETH;
		Currency currencyOut = FRXETH;

		uint8 i = 0;
		uint8 j = 1;

		uint256 amountIn = ethAmount;

		deal(currencyIn, address(adapter), amountIn);
		assertEq(currencyIn.balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(pool, FRXETH.toAddress());
		assertEq(expected, amountIn);

		bytes32 data = pack(pool, i, j, UNWRAP_ETH, NO_ACTION, false);

		uint256 amountOut = adapter.exchange(data);
		assertEq(amountOut, expected);

		uint256 balanceIn = currencyIn.balanceOf(address(adapter));
		uint256 balanceOut = currencyOut.balanceOf(address(adapter));

		assertEq(balanceIn, 0);
		assertEq(balanceOut, amountOut);
	}

	function testStakeETHThenWrapFRXETH() public {
		Currency currencyIn = ETH;
		Currency currencyOut = SFRXETH;

		uint8 i = 0;
		uint8 j = 2;

		uint256 amountIn = ethAmount;

		deal(currencyIn, address(adapter), amountIn);
		assertEq(currencyIn.balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(pool, SFRXETH.toAddress());
		assertGt(expected, 0);

		bytes32 data = pack(pool, i, j, NO_ACTION, NO_ACTION, false);

		uint256 amountOut = adapter.exchange(data);
		assertEq(amountOut, expected);

		uint256 balanceIn = currencyIn.balanceOf(address(adapter));
		uint256 balanceOut = currencyOut.balanceOf(address(adapter));

		assertEq(balanceIn, 0);
		assertEq(balanceOut, amountOut);
	}

	function testWrapFRXETH() public {
		Currency currencyIn = FRXETH;
		Currency currencyOut = SFRXETH;

		uint8 i = 1;
		uint8 j = 2;

		uint256 amountIn = ethAmount;

		deal(currencyIn, address(adapter), amountIn);
		assertEq(currencyIn.balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(pool, SFRXETH.toAddress());
		assertGt(expected, 0);

		bytes32 data = pack(pool, i, j, NO_ACTION, NO_ACTION, false);

		uint256 amountOut = adapter.exchange(data);
		// uint256 amountOut = adapter.wrapSFRXETH(amountIn);
		assertEq(amountOut, expected);

		uint256 balanceIn = currencyIn.balanceOf(address(adapter));
		uint256 balanceOut = currencyOut.balanceOf(address(adapter));

		assertEq(balanceIn, 0);
		assertEq(balanceOut, amountOut);
	}

	function testUnwrapSFRXETH() public {
		Currency currencyIn = SFRXETH;
		Currency currencyOut = FRXETH;

		uint8 i = 2;
		uint8 j = 1;

		uint256 amountIn = ethAmount;

		deal(currencyIn, address(adapter), amountIn);
		assertEq(currencyIn.balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(pool, SFRXETH.toAddress());
		assertGt(expected, 0);

		bytes32 data = pack(pool, i, j, NO_ACTION, NO_ACTION, false);

		uint256 amountOut = adapter.exchange(data);
		assertEq(amountOut, expected);

		uint256 balanceIn = currencyIn.balanceOf(address(adapter));
		uint256 balanceOut = currencyOut.balanceOf(address(adapter));

		assertEq(balanceIn, 0);
		assertEq(balanceOut, amountOut);
	}
}
