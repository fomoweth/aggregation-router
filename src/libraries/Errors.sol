// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Errors {
	error ZeroAddress();

	error ZeroAmount();

	error ZeroBytes();

	error ZeroBytes32();

	error IdenticalCurrencyIds();

	error InvalidCurrencyId();

	error InvalidCurrency();

	error InvalidDirection();

	error InvalidPool();

	error InsufficientAmountIn();

	error InsufficientAmountOut();

	error InsufficientReserves();

	error NotSupported();

	error OutOfBound();
}
