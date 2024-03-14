// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FRXETHWrapper} from "src/adapters/FRXETHWrapper.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseTest} from "test/BaseTest.t.sol";

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

	function testWrapFRXETH() public {
		uint256 snapshotInitial = vm.snapshot();
		uint256 snapshot;

		uint256 amountIn;
		uint256 amountOut;
		bytes32 queryPath;
		uint256 queryAmount;
		uint256 quoteAmount;

		// ETH -> frxETH

		amountIn = deal(ETH, address(adapter), ethAmount);
		assertEq(ETH.balanceOf(address(adapter)), amountIn);

		(queryPath, queryAmount) = adapter.query(ETH, FRXETH, amountIn);
		assertEq(toPool(queryPath), FRXETH.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		snapshot = vm.snapshot();

		amountOut = adapter.wrapFRXETH(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshot);

		amountOut = adapter.exchange(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshotInitial);

		// WETH -> frxETH

		amountIn = deal(WETH, address(adapter), ethAmount);
		assertEq(WETH.balanceOf(address(adapter)), amountIn);

		(queryPath, queryAmount) = adapter.query(WETH, FRXETH, amountIn);
		assertEq(toPool(queryPath), FRXETH.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		snapshot = vm.snapshot();

		amountOut = adapter.wrapFRXETH(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshot);

		amountOut = adapter.exchange(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	function testWrapSFRXETH() public {
		uint256 snapshotInitial = vm.snapshot();
		uint256 snapshot;

		uint256 amountIn;
		uint256 amountOut;
		bytes32 queryPath;
		uint256 queryAmount;
		uint256 quoteAmount;

		// ETH -> sfrxETH

		amountIn = deal(ETH, address(adapter), ethAmount);
		assertEq(ETH.balanceOf(address(adapter)), amountIn);

		(queryPath, queryAmount) = adapter.query(ETH, SFRXETH, amountIn);
		assertEq(toPool(queryPath), SFRXETH.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		snapshot = vm.snapshot();

		amountOut = adapter.wrapSFRXETH(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshot);

		amountOut = adapter.exchange(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshotInitial);

		// WETH -> sfrxETH

		amountIn = deal(WETH, address(adapter), ethAmount);
		assertEq(WETH.balanceOf(address(adapter)), amountIn);

		(queryPath, queryAmount) = adapter.query(WETH, SFRXETH, amountIn);
		assertEq(toPool(queryPath), SFRXETH.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		snapshot = vm.snapshot();

		amountOut = adapter.wrapSFRXETH(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshot);

		amountOut = adapter.exchange(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshotInitial);

		// frxETH -> sfrxETH

		amountIn = deal(FRXETH, address(adapter), ethAmount);
		assertEq(FRXETH.balanceOf(address(adapter)), amountIn);

		(queryPath, queryAmount) = adapter.query(FRXETH, SFRXETH, amountIn);
		assertEq(toPool(queryPath), SFRXETH.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		snapshot = vm.snapshot();

		amountOut = adapter.wrapSFRXETH(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshot);

		amountOut = adapter.exchange(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	function testUnwrapSFRXETH() public {
		// sfrxETH -> frxETH

		uint256 amountIn = deal(SFRXETH, address(adapter), ethAmount);
		assertEq(SFRXETH.balanceOf(address(adapter)), amountIn);

		(bytes32 queryPath, uint256 queryAmount) = adapter.query(SFRXETH, FRXETH, amountIn);
		assertEq(toPool(queryPath), SFRXETH.toAddress());
		assertGt(queryAmount, 0);

		uint256 quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		uint256 snapshot = vm.snapshot();

		uint256 amountOut;

		amountOut = adapter.unwrapSFRXETH(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshot);

		amountOut = adapter.exchange(queryPath);
		assertEq(amountOut, quoteAmount);
	}
}
