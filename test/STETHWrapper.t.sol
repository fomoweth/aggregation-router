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
		address queryPool;
		uint256 queryAmount;

		uint256 snapshot = vm.snapshot();

		amountIn = deal(ETH, address(adapter), ethAmount);
		assertEq(ETH.balanceOf(address(adapter)), amountIn);

		(queryPool, queryAmount) = adapter.query(ETH, STETH, amountIn);
		assertEq(queryPool, STETH.toAddress());

		amountOut = adapter.wrapSTETH(amountIn, false, false);
		assertEq(amountOut, queryAmount);

		vm.revertTo(snapshot);

		amountIn = deal(WETH, address(adapter), ethAmount);
		assertEq(WETH.balanceOf(address(adapter)), amountIn);

		(queryPool, queryAmount) = adapter.query(WETH, STETH, amountIn);
		assertEq(queryPool, STETH.toAddress());

		amountOut = adapter.wrapSTETH(amountIn, true, false);
		assertEq(amountOut, queryAmount);

		vm.revertTo(snapshot);

		amountIn = deal(ETH, address(adapter), ethAmount);
		assertEq(ETH.balanceOf(address(adapter)), amountIn);

		(queryPool, queryAmount) = adapter.query(ETH, WSTETH, amountIn);
		assertEq(queryPool, WSTETH.toAddress());

		amountOut = adapter.wrapSTETH(amountIn, false, true);
		assertEq(amountOut, queryAmount);

		vm.revertTo(snapshot);

		amountIn = deal(WETH, address(adapter), ethAmount);
		assertEq(WETH.balanceOf(address(adapter)), amountIn);

		(queryPool, queryAmount) = adapter.query(WETH, WSTETH, amountIn);
		assertEq(queryPool, WSTETH.toAddress());

		amountOut = adapter.wrapSTETH(amountIn, true, true);
		assertEq(amountOut, queryAmount);
	}

	function test_wrapWSTETH() public {
		uint256 amountIn = deal(STETH, address(adapter), ethAmount);
		assertEq(getBalance(STETH, address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(STETH, WSTETH, amountIn);
		assertEq(queryPool, WSTETH.toAddress());
		assertGt(queryAmount, 0);

		uint256 amountOut = adapter.wrapWSTETH(amountIn);
		assertEq(amountOut, queryAmount);
	}

	function test_unwrapWSTETH() public {
		uint256 amountIn = deal(WSTETH, address(adapter), ethAmount);
		assertEq(getBalance(WSTETH, address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(WSTETH, STETH, amountIn);
		assertEq(queryPool, WSTETH.toAddress());
		assertGt(queryAmount, 0);

		uint256 amountOut = adapter.unwrapWSTETH(amountIn);
		assertEq(amountOut, queryAmount);
	}

	function testStakeETH() public {
		Currency currencyIn = ETH;
		Currency currencyOut = STETH;

		uint8 i = 0;
		uint8 j = 1;

		uint256 amountIn = deal(currencyIn, address(adapter), ethAmount);
		assertEq(currencyIn.balanceOf(address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, STETH.toAddress());
		assertGt(queryAmount, 0);

		bytes32 path = pack(queryPool, i, j, NO_ACTION, NO_ACTION, false);

		uint256 amountOut = adapter.exchange(path);
		assertEq(amountOut, queryAmount);
	}

	function testUnwrapWETHThenStakeETH() public {
		Currency currencyIn = WETH;
		Currency currencyOut = STETH;

		uint8 i = 0;
		uint8 j = 1;

		uint256 amountIn = ethAmount;
		deal(currencyIn, address(adapter), amountIn);
		assertEq(currencyIn.balanceOf(address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, STETH.toAddress());
		assertGt(queryAmount, 0);

		bytes32 path = pack(queryPool, i, j, UNWRAP_ETH, NO_ACTION, false);

		uint256 amountOut = adapter.exchange(path);
		assertEq(amountOut, queryAmount);
	}

	function testStakeETHThenWrapSTETH() public {
		Currency currencyIn = ETH;
		Currency currencyOut = WSTETH;

		uint8 i = 0;
		uint8 j = 2;

		uint256 amountIn = ethAmount;
		deal(currencyIn, address(adapter), amountIn);
		assertEq(currencyIn.balanceOf(address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, WSTETH.toAddress());
		assertGt(queryAmount, 0);

		bytes32 path = pack(queryPool, i, j, NO_ACTION, NO_ACTION, false);

		uint256 amountOut = adapter.exchange(path);
		assertEq(amountOut, queryAmount);
	}

	function testUnwrapWETHAndStakeETHThenWrapSTETH() public {
		Currency currencyIn = WETH;
		Currency currencyOut = WSTETH;

		uint8 i = 0;
		uint8 j = 2;

		uint256 amountIn = deal(currencyIn, address(adapter), ethAmount);
		assertEq(currencyIn.balanceOf(address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, WSTETH.toAddress());
		assertGt(queryAmount, 0);

		bytes32 path = pack(queryPool, i, j, UNWRAP_ETH, NO_ACTION, false);

		uint256 amountOut = adapter.exchange(path);
		assertEq(amountOut, queryAmount);
	}

	function testWrapSTETH() public {
		Currency currencyIn = STETH;
		Currency currencyOut = WSTETH;

		uint8 i = 1;
		uint8 j = 2;

		uint256 amountIn = deal(currencyIn, address(adapter), ethAmount);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, WSTETH.toAddress());
		assertGt(queryAmount, 0);

		bytes32 path = pack(queryPool, i, j, NO_ACTION, NO_ACTION, false);

		uint256 amountOut = adapter.exchange(path);
		assertEq(amountOut, queryAmount);
	}

	function testUnwrapWSTETH() public {
		Currency currencyIn = WSTETH;
		Currency currencyOut = STETH;

		uint8 i = 2;
		uint8 j = 1;

		uint256 amountIn = deal(currencyIn, address(adapter), ethAmount);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, WSTETH.toAddress());
		assertGt(queryAmount, 0);

		bytes32 path = pack(queryPool, i, j, NO_ACTION, NO_ACTION, false);

		uint256 amountOut = adapter.exchange(path);
		assertEq(amountOut, queryAmount);
	}
}
