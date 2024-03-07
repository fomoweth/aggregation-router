// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Currency} from "src/types/Currency.sol";
import {Constants} from "test/utils/Constants.sol";

abstract contract V3SwapTest is Test, Constants {
	uint256 ethAmount = 20 ether;

	function setUp() public virtual {
		vm.createSelectFork(vm.envString("RPC_ETHEREUM"), FORK_BLOCK);
	}

	function deal(Currency currency, address account, uint256 amount) internal {
		deal(currency.toAddress(), account, amount);
	}

	function latestAnswer(address aggregator) internal view returns (uint256 answer) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x50d25bcd00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), aggregator, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			if iszero(slt(mload(0x00), 0x00)) {
				answer := mload(0x00)
			}
		}
	}

	function pack(
		address pool,
		uint8 i,
		uint8 j,
		uint8 wrapIn,
		uint8 wrapOut
	) internal pure returns (bytes32 data) {
		assembly ("memory-safe") {
			data := add(pool, add(shl(160, i), add(shl(168, j), add(shl(176, wrapIn), shl(184, wrapOut)))))
		}
	}

	function currency0() internal pure virtual returns (Currency);

	function currency1() internal pure virtual returns (Currency);

	function feed() internal pure virtual returns (address);
}
