// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency} from "src/types/Currency.sol";

interface IAggregationRouter {
	function execute(
		bytes[] calldata path,
		address recipient,
		uint256 amountIn,
		uint256 amountOutMin
	) external payable returns (uint256 amountOut);

	function query(
		Currency currencyIn,
		Currency currencyOut,
		uint256 amountIn
	) external view returns (address adapter, address pool, uint256 amountOut);
}
