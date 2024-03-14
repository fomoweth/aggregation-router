// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency} from "src/types/Currency.sol";

interface IWrapper {
	function wrap(bytes32 path) external payable returns (uint256);

	function unwrap(bytes32 path) external payable returns (uint256);

	function query(
		Currency wrapped,
		Currency underlying,
		uint256 amountIn,
		bool direction
	) external view returns (bytes32 path, uint256 amountOut);

	function quote(bytes32 path, uint256 amountIn) external view returns (uint256 amountOut);
}
