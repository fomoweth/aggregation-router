// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2 as console} from "forge-std/Test.sol";
import {STETHWrapper} from "src/adapters/STETHWrapper.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseTest} from "test/BaseTest.t.sol";

// forge test -vvv --match-path test/STETHWrapper.t.sol

contract STETHWrapperTest is BaseTest {
	using CurrencyLibrary for Currency;

	uint256 ethAmount = 20 ether;

	STETHWrapper adapter;

	function setUp() public {
		fork();

		adapter = STETHWrapper(
			deployAdapter(
				"STETH_WRAPPER",
				abi.encodePacked(
					type(STETHWrapper).creationCode,
					abi.encode(STETH_WRAPPER_ID, WETH, STETH, WSTETH)
				)
			)
		);
	}

	function test_wrapSTETH() public {
		uint256 amountIn;
		uint256 amountOut;
		uint256 expected;
		address pool;

		uint256 snapshot = vm.snapshot();

		amountIn = deal(ETH, address(adapter), ethAmount);
		assertEq(ETH.balanceOf(address(adapter)), amountIn, "!amountIn");

		(pool, expected) = adapter.query(ETH, STETH, amountIn);
		assertEq(pool, STETH.toAddress());

		amountOut = adapter.wrapSTETH(amountIn, false, false);
		assertEq(amountOut, expected, "!amountOut");

		vm.revertTo(snapshot);

		amountIn = deal(WETH, address(adapter), ethAmount);
		assertEq(WETH.balanceOf(address(adapter)), amountIn, "!amountIn");

		(pool, expected) = adapter.query(WETH, STETH, amountIn);
		assertEq(pool, STETH.toAddress());

		amountOut = adapter.wrapSTETH(amountIn, true, false);
		assertEq(amountOut, expected, "!amountOut");

		vm.revertTo(snapshot);

		amountIn = deal(ETH, address(adapter), ethAmount);
		assertEq(ETH.balanceOf(address(adapter)), amountIn, "!amountIn");

		(pool, expected) = adapter.query(ETH, WSTETH, amountIn);
		assertEq(pool, WSTETH.toAddress());

		amountOut = adapter.wrapSTETH(amountIn, false, true);
		assertEq(amountOut, expected, "!amountOut");

		vm.revertTo(snapshot);

		amountIn = deal(WETH, address(adapter), ethAmount);
		assertEq(WETH.balanceOf(address(adapter)), amountIn, "!amountIn");

		(pool, expected) = adapter.query(WETH, WSTETH, amountIn);
		assertEq(pool, WSTETH.toAddress());

		amountOut = adapter.wrapSTETH(amountIn, true, true);
		assertEq(amountOut, expected, "!amountOut");
	}

	function test_wrapWSTETH() public {
		uint256 amountIn = deal(STETH, address(adapter), ethAmount);
		assertEq(getBalance(STETH, address(adapter)), amountIn, "!amountIn");

		(address pool, uint256 expected) = adapter.query(STETH, WSTETH, amountIn);
		assertEq(pool, WSTETH.toAddress());
		assertGt(expected, 0, "!expected");

		uint256 amountOut = adapter.wrapWSTETH(amountIn);
		assertEq(amountOut, expected, "!amountOut");
	}

	function test_unwrapWSTETH() public {
		uint256 amountIn = deal(WSTETH, address(adapter), ethAmount);
		assertEq(getBalance(WSTETH, address(adapter)), amountIn, "!amountIn");

		(address pool, uint256 expected) = adapter.query(WSTETH, STETH, amountIn);
		assertEq(pool, WSTETH.toAddress());
		assertGt(expected, 0, "!expected");

		uint256 amountOut = adapter.unwrapWSTETH(amountIn);
		assertEq(amountOut, expected, "!amountOut");
	}

	function testStakeETH() public {
		// console.log("adapter:", address(adapter)); 0x41A0d6641e9cd7a699715e11875132F4E042453A
		// console.log("wrapSTETH:"); 0xc9f0540a
		// console.logBytes4(adapter.wrapSTETH.selector);
		// console.log("wrapWSTETH:"); 0x5ce65ed6
		// console.logBytes4(adapter.wrapWSTETH.selector);
		// console.log("unwrapWSTETH:"); 0xd3b64fbc
		// console.logBytes4(adapter.unwrapWSTETH.selector);

		Currency currencyIn = ETH;
		Currency currencyOut = STETH;

		uint8 i = 0;
		uint8 j = 1;

		uint256 amountIn = deal(currencyIn, address(adapter), ethAmount);
		assertEq(currencyIn.balanceOf(address(adapter)), amountIn, "!amountIn");

		(address pool, uint256 expected) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(pool, STETH.toAddress());
		assertGt(expected, 0, "!expected");

		bytes32 data = pack(pool, i, j, NO_ACTION, NO_ACTION, false);

		uint256 amountOut = adapter.exchange(data);
		assertEq(amountOut, expected, "!amountOut");
	}

	function testUnwrapWETHThenStakeETH() public {
		Currency currencyIn = WETH;
		Currency currencyOut = STETH;

		uint8 i = 0;
		uint8 j = 1;

		uint256 amountIn = ethAmount;
		deal(currencyIn, address(adapter), amountIn);
		assertEq(currencyIn.balanceOf(address(adapter)), amountIn, "!amountIn");

		(address pool, uint256 expected) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(pool, STETH.toAddress(), "!pool");
		assertGt(expected, 0, "!expected");

		bytes32 data = pack(pool, i, j, UNWRAP_ETH, NO_ACTION, false);

		uint256 amountOut = adapter.exchange(data);
		assertEq(amountOut, expected, "!amountOut");
	}

	function testStakeETHThenWrapSTETH() public {
		Currency currencyIn = ETH;
		Currency currencyOut = WSTETH;

		uint8 i = 0;
		uint8 j = 2;

		uint256 amountIn = ethAmount;
		deal(currencyIn, address(adapter), amountIn);
		assertEq(currencyIn.balanceOf(address(adapter)), amountIn, "!amountIn");

		(address pool, uint256 expected) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(pool, WSTETH.toAddress());
		assertGt(expected, 0, "!expected");

		bytes32 data = pack(pool, i, j, NO_ACTION, NO_ACTION, false);

		uint256 amountOut = adapter.exchange(data);
		assertEq(amountOut, expected, "!amountOut");
	}

	function testUnwrapWETHAndStakeETHThenWrapSTETH() public {
		Currency currencyIn = WETH;
		Currency currencyOut = WSTETH;

		uint8 i = 0;
		uint8 j = 2;

		uint256 amountIn = deal(currencyIn, address(adapter), ethAmount);
		assertEq(currencyIn.balanceOf(address(adapter)), amountIn, "!amountIn");

		(address pool, uint256 expected) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(pool, WSTETH.toAddress());
		assertGt(expected, 0, "!expected");

		bytes32 data = pack(pool, i, j, UNWRAP_ETH, NO_ACTION, false);

		uint256 amountOut = adapter.exchange(data);
		assertEq(amountOut, expected, "!amountOut");
	}

	function testWrapSTETH() public {
		Currency currencyIn = STETH;
		Currency currencyOut = WSTETH;

		uint8 i = 1;
		uint8 j = 2;

		uint256 amountIn = deal(currencyIn, address(adapter), ethAmount);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn, "!amountIn");

		(address pool, uint256 expected) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(pool, WSTETH.toAddress(), "!pool");
		assertGt(expected, 0, "!query");

		bytes32 data = pack(pool, i, j, NO_ACTION, NO_ACTION, false);

		uint256 amountOut = adapter.exchange(data);
		assertEq(amountOut, expected, "!exchange");
	}

	function testUnwrapWSTETH() public {
		Currency currencyIn = WSTETH;
		Currency currencyOut = STETH;

		uint8 i = 2;
		uint8 j = 1;

		uint256 amountIn = deal(currencyIn, address(adapter), ethAmount);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn, "!amountIn");

		(address pool, uint256 expected) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(pool, WSTETH.toAddress(), "!pool");
		assertGt(expected, 0, "!expected");

		bytes32 data = pack(pool, i, j, NO_ACTION, NO_ACTION, false);

		uint256 amountOut = adapter.exchange(data);
		assertEq(amountOut, expected, "!amountOut");
	}
}
