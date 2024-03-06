// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Errors {
	error IdenticalCurrencyIds();

	error InvalidCurrencyId();

	error InvalidCurrency();

	error InvalidPool();

	error InsufficientAmountIn();

	error InsufficientAmountOut();

	error OutOfBound();
}
