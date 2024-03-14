// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {STETHWrapper} from "src/adapters/wrappers/STETHWrapper.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseTest} from "test/BaseTest.t.sol";

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

	function testWrapSTETH() public {
		uint256 snapshotInitial = vm.snapshot();
		uint256 snapshot;

		uint256 amountIn;
		uint256 amountOut;
		bytes32 queryPath;
		uint256 queryAmount;
		uint256 quoteAmount;

		// ETH -> stETH

		amountIn = deal(ETH, address(adapter), ethAmount);
		assertEq(ETH.balanceOf(address(adapter)), amountIn);

		(queryPath, queryAmount) = adapter.query(ETH, STETH, amountIn, true);
		assertEq(toPool(queryPath), STETH.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		snapshot = vm.snapshot();

		amountOut = adapter.wrapSTETH(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshot);

		amountOut = adapter.wrap(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshotInitial);

		// WETH -> stETH

		amountIn = deal(WETH, address(adapter), ethAmount);
		assertEq(WETH.balanceOf(address(adapter)), amountIn);

		(queryPath, queryAmount) = adapter.query(WETH, STETH, amountIn, true);
		assertEq(toPool(queryPath), STETH.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		snapshot = vm.snapshot();

		amountOut = adapter.wrapSTETH(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshot);

		amountOut = adapter.wrap(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	function testWrapWSTETH() public {
		uint256 snapshotInitial = vm.snapshot();
		uint256 snapshot;

		uint256 amountIn;
		uint256 amountOut;
		bytes32 queryPath;
		uint256 queryAmount;
		uint256 quoteAmount;

		// ETH -> wstETH

		amountIn = deal(ETH, address(adapter), ethAmount);
		assertEq(ETH.balanceOf(address(adapter)), amountIn);

		(queryPath, queryAmount) = adapter.query(ETH, WSTETH, amountIn, true);
		assertEq(toPool(queryPath), WSTETH.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		snapshot = vm.snapshot();

		amountOut = adapter.wrapWSTETH(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshot);

		amountOut = adapter.wrap(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshotInitial);

		// WETH -> wstETH

		amountIn = deal(WETH, address(adapter), ethAmount);
		assertEq(WETH.balanceOf(address(adapter)), amountIn);

		(queryPath, queryAmount) = adapter.query(WETH, WSTETH, amountIn, true);
		assertEq(toPool(queryPath), WSTETH.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		snapshot = vm.snapshot();

		amountOut = adapter.wrapWSTETH(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshot);

		amountOut = adapter.wrap(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshotInitial);

		// stETH -> wstETH

		amountIn = deal(STETH, address(adapter), ethAmount);
		assertEq(getBalance(STETH, address(adapter)), amountIn);

		(queryPath, queryAmount) = adapter.query(STETH, WSTETH, amountIn, true);
		assertEq(toPool(queryPath), WSTETH.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		snapshot = vm.snapshot();

		amountOut = adapter.wrapWSTETH(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshot);

		amountOut = adapter.wrap(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	function testUnwrapWSTETH() public {
		// wstETH -> stETH

		uint256 amountIn = deal(WSTETH, address(adapter), ethAmount);
		assertEq(getBalance(WSTETH, address(adapter)), amountIn);

		(bytes32 queryPath, uint256 queryAmount) = adapter.query(WSTETH, STETH, amountIn, false);
		assertEq(toPool(queryPath), WSTETH.toAddress());
		assertGt(queryAmount, 0);

		uint256 quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		uint256 snapshot = vm.snapshot();

		uint256 amountOut;

		amountOut = adapter.unwrapWSTETH(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshot);

		amountOut = adapter.unwrap(queryPath);
		assertEq(amountOut, quoteAmount);
	}
}
