// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency} from "src/types/Currency.sol";

interface IAdapter {
	function query(
		Currency currencyIn,
		Currency currencyOut,
		uint256 amountIn
	) external view returns (bytes32 path, uint256 amountOut);

	function quote(bytes32 path, uint256 amountIn) external view returns (uint256 amountOut);
}
