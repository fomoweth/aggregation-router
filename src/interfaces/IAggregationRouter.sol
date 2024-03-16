// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency} from "src/types/Currency.sol";

interface IAggregationRouter {
	function aggregate(
		bytes[] calldata calls,
		address recipient,
		Currency currencyIn,
		Currency currencyOut,
		uint256 amountIn,
		uint256 amountOutMin
	) external payable returns (uint256 amountOut);
}
