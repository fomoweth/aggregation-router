// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2 as console} from "forge-std/Test.sol";
import {CurveAdapter} from "src/adapters/CurveAdapter.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseTest} from "./BaseTest.t.sol";

// forge test -vvv --match-path test/CurveAdapter.t.sol

contract CurveAdapterTest is BaseTest {
	using CurrencyLibrary for Currency;

	uint256 ethAmount = 20 ether;

	CurveAdapter adapter;

	address constant META_REGISTRY = 0xF98B45FA17DE75FB1aD0e7aFD971b0ca00e379fC;

	function setUp() public {
		fork();

		adapter = CurveAdapter(
			deployAdapter(
				"CURVE_ADAPTER",
				abi.encodePacked(type(CurveAdapter).creationCode, abi.encode(CURVE_ID, WETH))
			)
		);
	}

	function testSwapWETHForWBTCOnCurve() public {
		Currency currencyIn = WETH;
		Currency currencyOut = WBTC;

		uint256 amountIn = deal(currencyIn, address(adapter), computeAmountIn(currencyIn, feed(), ethAmount));
		assertEq(getBalance(currencyIn, address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, pool());
		assertGt(queryAmount, 0);

		(uint8 i, uint8 j, bool isUnderlying) = getCoinIndices(queryPool, currencyIn, currencyOut);

		bytes32 path = pack(queryPool, i, j, NO_ACTION, NO_ACTION, isUnderlying);

		uint256 amountOut = adapter.curveSwap(path);
		assertEq(amountOut, queryAmount);
	}

	function testSwapWETHForWBTCWrapETHBeforeOnCurve() public {
		Currency currencyIn = WETH;
		Currency currencyOut = WBTC;

		uint256 amountIn = computeAmountIn(currencyIn, feed(), ethAmount);

		deal(address(adapter), amountIn);
		assertEq(address(adapter).balance, amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, pool());
		assertGt(queryAmount, 0);

		(uint8 i, uint8 j, bool isUnderlying) = getCoinIndices(queryPool, currencyIn, currencyOut);

		bytes32 path = pack(queryPool, i, j, WRAP_ETH, NO_ACTION, isUnderlying);

		uint256 amountOut = adapter.curveSwap(path);
		assertEq(amountOut, queryAmount);
	}

	function testSwapWBTCForWETHOnCurve() public {
		Currency currencyIn = WBTC;
		Currency currencyOut = WETH;

		uint256 amountIn = deal(currencyIn, address(adapter), computeAmountIn(currencyIn, feed(), ethAmount));
		assertEq(currencyIn.balanceOf(address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, pool());
		assertGt(queryAmount, 0);

		(uint8 i, uint8 j, bool isUnderlying) = getCoinIndices(queryPool, currencyIn, currencyOut);

		bytes32 path = pack(queryPool, i, j, NO_ACTION, NO_ACTION, isUnderlying);

		uint256 amountOut = adapter.curveSwap(path);
		assertEq(amountOut, queryAmount);
	}

	function testSwapWBTCForWETHunwrapWETHAfterOnCurve() public {
		Currency currencyIn = WBTC;
		Currency currencyOut = WETH;

		uint256 amountIn = deal(currencyIn, address(adapter), computeAmountIn(currencyIn, feed(), ethAmount));
		assertEq(currencyIn.balanceOf(address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, pool());
		assertGt(queryAmount, 0);

		(uint8 i, uint8 j, bool isUnderlying) = getCoinIndices(queryPool, currencyIn, currencyOut);

		bytes32 path = pack(queryPool, i, j, NO_ACTION, UNWRAP_ETH, isUnderlying);

		uint256 amountOut = adapter.curveSwap(path);
		assertEq(amountOut, queryAmount);
	}

	function findPoolsFor(
		Currency currencyIn,
		Currency currencyOut
	) internal view returns (address[] memory) {
		bytes memory returndata;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xa064072b00000000000000000000000000000000000000000000000000000000) // find_pools_for_coins(address,address)
			mstore(add(ptr, 0x04), and(currencyIn, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(currencyOut, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), META_REGISTRY, ptr, 0x64, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x40, add(returndata, add(returndatasize(), 0x20)))
			mstore(returndata, returndatasize())
			returndatacopy(add(returndata, 0x20), 0x00, returndatasize())
		}

		return abi.decode(returndata, (address[]));
	}

	function findPoolFor(Currency currencyIn, Currency currencyOut) internal view returns (address crvPool) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xa87df06c00000000000000000000000000000000000000000000000000000000) // find_pool_for_coins(address,address)
			mstore(add(ptr, 0x04), and(currencyIn, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(currencyOut, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), META_REGISTRY, ptr, 0x64, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			crvPool := mload(0x00)
		}
	}

	function getCoinIndices(
		address crvPool,
		Currency currencyIn,
		Currency currencyOut
	) internal view returns (uint8 i, uint8 j, bool isUnderlying) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)
			let res := add(ptr, 0x64)

			mstore(ptr, 0xeb85226d00000000000000000000000000000000000000000000000000000000) // get_coin_indices(address,address,address)
			mstore(add(ptr, 0x04), and(crvPool, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(currencyIn, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x44), and(currencyOut, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), META_REGISTRY, ptr, 0x64, res, 0x60)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			i := mload(res)
			j := mload(add(res, 0x20))
			isUnderlying := mload(add(res, 0x40))
		}
	}

	function getPoolAssets(
		address crvPool,
		bool isUnderlying
	) internal view returns (Currency[] memory assets) {
		bytes memory returndata;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			switch isUnderlying
			case 0x00 {
				mstore(ptr, 0x9ac90d3d00000000000000000000000000000000000000000000000000000000) // get_coins(address)
			}
			default {
				mstore(ptr, 0xa77576ef00000000000000000000000000000000000000000000000000000000) // get_underlying_coins(address)
			}

			mstore(add(ptr, 0x04), and(crvPool, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), META_REGISTRY, ptr, 0x24, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x40, add(returndata, add(returndatasize(), 0x60)))
			mstore(returndata, add(returndatasize(), 0x40))
			mstore(add(returndata, 0x20), 0x20)
			mstore(add(returndata, 0x40), div(returndatasize(), 0x20))
			returndatacopy(add(returndata, 0x60), 0x00, returndatasize())
		}

		assets = abi.decode(returndata, (Currency[]));

		uint256 length = getNumAssets(crvPool, isUnderlying);

		assembly ("memory-safe") {
			mstore(assets, length)
		}
	}

	function getNumAssets(address crvPool, bool isUnderlying) internal view returns (uint256 numAssets) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			switch isUnderlying
			case 0x00 {
				mstore(ptr, 0x940494f100000000000000000000000000000000000000000000000000000000) // get_n_coins(address)
			}
			default {
				mstore(ptr, 0xa77576ef00000000000000000000000000000000000000000000000000000000) // get_n_underlying_coins(address)
			}

			mstore(add(ptr, 0x04), and(crvPool, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), META_REGISTRY, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			numAssets := mload(0x00)
		}
	}

	function pool() internal pure returns (address) {
		return TRICRYPTO_POOL;
	}

	function feed() internal pure returns (address) {
		return BTC_ETH_FEED;
	}
}
