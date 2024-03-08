// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Errors {
	error ZeroAddress();

	error ZeroAmount();

	error ZeroBytes();

	error ZeroBytes32();

	error EmptyData();

	error InvalidAction();

	error IdenticalCurrencyIds();

	error InvalidCurrencyId();

	error InvalidCurrency();

	error InvalidPool();

	error InsufficientAmountIn();

	error InsufficientAmountOut();

	error InsufficientBalance();

	error InsufficientReserves();

	error OutOfBound();
}
