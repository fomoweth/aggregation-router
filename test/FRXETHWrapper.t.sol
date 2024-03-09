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
		Currency currencyIn = ETH;
		Currency currencyOut = FRXETH;

		uint8 i = 0;
		uint8 j = 1;

		uint256 amountIn = ethAmount;
		deal(currencyIn, address(adapter), amountIn);
		assertEq(currencyIn.balanceOf(address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, FRXETH.toAddress());
		assertEq(queryAmount, amountIn);

		bytes32 path = pack(queryPool, i, j, NO_ACTION, NO_ACTION, false);

		uint256 amountOut = adapter.exchange(path);
		assertEq(amountOut, queryAmount);

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

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, FRXETH.toAddress());
		assertEq(queryAmount, amountIn);

		bytes32 path = pack(queryPool, i, j, UNWRAP_ETH, NO_ACTION, false);

		uint256 amountOut = adapter.exchange(path);
		assertEq(amountOut, queryAmount);

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

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, SFRXETH.toAddress());
		assertGt(queryAmount, 0);

		bytes32 path = pack(queryPool, i, j, NO_ACTION, NO_ACTION, false);

		uint256 amountOut = adapter.exchange(path);
		assertEq(amountOut, queryAmount);

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

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, SFRXETH.toAddress());
		assertGt(queryAmount, 0);

		bytes32 path = pack(queryPool, i, j, NO_ACTION, NO_ACTION, false);

		uint256 amountOut = adapter.exchange(path);
		// uint256 amountOut = adapter.wrapSFRXETH(amountIn);
		assertEq(amountOut, queryAmount);

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

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, SFRXETH.toAddress());
		assertGt(queryAmount, 0);

		bytes32 path = pack(queryPool, i, j, NO_ACTION, NO_ACTION, false);

		uint256 amountOut = adapter.exchange(path);
		assertEq(amountOut, queryAmount);

		uint256 balanceIn = currencyIn.balanceOf(address(adapter));
		uint256 balanceOut = currencyOut.balanceOf(address(adapter));

		assertEq(balanceIn, 0);
		assertEq(balanceOut, amountOut);
	}
}
