// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Errors} from "src/libraries/Errors.sol";
import {FullMath} from "src/libraries/FullMath.sol";
import {PathDecoder} from "src/libraries/PathDecoder.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseAdapter} from "./BaseAdapter.sol";

/// @title BalancerV2Adapter
/// @notice Performs swaps on Balancer V2 pools

contract BalancerV2Adapter is BaseAdapter {
	using CurrencyLibrary for Currency;
	using FullMath for uint256;
	using PathDecoder for bytes32;

	address internal constant VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

	address internal constant EXTERNAL_WEIGHTED_MATH = 0x3db89f0CA3b388f2BcDbccD2ff8E13C22459CF75;

	uint8 internal constant SWAP_KIND_GIVEN_IN = 0;
	uint8 internal constant SWAP_KIND_GIVEN_OUT = 1;

	constructor(uint256 _id, Currency _weth) BaseAdapter(_id, _weth) {}

	function balancerV2Swap(bytes32 path) external payable returns (uint256) {
		return _swap(path);
	}

	function _swap(bytes32 path) internal virtual override returns (uint256 amountOut) {
		(address pool, uint8 i, uint8 j, uint8 wrapIn, uint8 wrapOut) = path.decode();

		if (i == j) revert Errors.IdenticalCurrencyIds();

		bytes32 poolId = getPoolId(pool);

		(Currency[] memory poolAssets, , ) = getPoolTokens(poolId);

		if (i >= poolAssets.length || j >= poolAssets.length) revert Errors.OutOfBound();

		Currency currencyIn = poolAssets[i];
		Currency currencyOut = poolAssets[j];

		if (wrapIn == WRAP_ETH) wrapETH(currencyIn, address(this).balance);

		uint256 amountIn = currencyIn.balanceOfSelf();
		if (amountIn == 0) revert Errors.InsufficientAmountIn();

		if (wrapIn == UNWRAP_WETH) unwrapWETH(currencyIn, amountIn);

		if (currencyIn.allowance(address(this), VAULT) < amountIn) {
			currencyIn.approve(VAULT, amountIn);
		}

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x52bbbe2900000000000000000000000000000000000000000000000000000000) // swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)
			mstore(add(ptr, 0x04), 0xe0)
			mstore(add(ptr, 0x24), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x44), and(0x00, 0xff))
			mstore(add(ptr, 0x64), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x84), and(0x00, 0xff))
			mstore(add(ptr, 0xa4), 0x00)
			mstore(add(ptr, 0xc4), timestamp())
			mstore(add(ptr, 0xe4), poolId)
			mstore(add(ptr, 0x104), and(SWAP_KIND_GIVEN_IN, 0xff))
			mstore(add(ptr, 0x124), and(currencyIn, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x144), and(currencyOut, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x164), amountIn)
			mstore(add(ptr, 0x184), 0xc0)
			mstore(add(ptr, 0x1a4), 0x00)

			if iszero(call(gas(), VAULT, 0x00, ptr, 0x1c4, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			amountOut := mload(0x00)
		}

		if (wrapOut == WRAP_ETH) wrapETH(currencyOut, amountOut);
		else if (wrapOut == UNWRAP_WETH) unwrapWETH(currencyOut, amountOut);
	}

	function _query(Currency, Currency, uint256) internal view virtual override returns (bytes32, uint256) {
		revert Errors.NotSupported();
	}

	function _quote(
		bytes32 path,
		uint256 amountIn
	) internal view virtual override returns (uint256 amountOut) {
		(address pool, uint8 i, uint8 j, , ) = path.decode();

		if (i == j) revert Errors.IdenticalCurrencyIds();

		(Currency[] memory poolAssets, uint256[] memory balances, ) = getPoolTokens(getPoolId(pool));

		if (i >= poolAssets.length || j >= poolAssets.length) revert Errors.OutOfBound();

		uint256[] memory weights = getNormalizedWeights(pool);

		uint256 swapFee = amountIn.mulDivRoundingUp(getSwapFeePercentage(pool), 1e18);

		return calcOutGivenIn(balances[i], weights[i], balances[j], weights[j], amountIn - swapFee);
	}

	function getPoolId(address pool) internal view returns (bytes32 poolId) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x38fff2d000000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), pool, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			poolId := mload(0x00)
		}
	}

	function getPoolTokens(
		bytes32 poolId
	)
		internal
		view
		returns (Currency[] memory poolAssets, uint256[] memory balances, uint256 lastChangeBlock)
	{
		bytes memory returndata;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xf94d466800000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), poolId)

			if iszero(staticcall(gas(), VAULT, ptr, 0x24, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x40, add(returndata, add(returndatasize(), 0x20)))
			mstore(returndata, returndatasize())
			returndatacopy(add(returndata, 0x20), 0x00, returndatasize())
		}

		return abi.decode(returndata, (Currency[], uint256[], uint256));
	}

	function getNormalizedWeights(address pool) internal view returns (uint256[] memory) {
		bytes memory returndata;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xf89f27ed00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), pool, ptr, 0x04, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x40, add(returndata, add(returndatasize(), 0x20)))
			mstore(returndata, returndatasize())
			returndatacopy(add(returndata, 0x20), 0x00, returndatasize())
		}

		return abi.decode(returndata, (uint256[]));
	}

	function getSwapFeePercentage(address pool) internal view returns (uint256 swapFee) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x55c6762800000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), pool, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			swapFee := mload(0x00)
		}
	}

	function calcOutGivenIn(
		uint256 balanceIn,
		uint256 weightIn,
		uint256 balanceOut,
		uint256 weightOut,
		uint256 amountIn
	) internal view returns (uint256 amountOut) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x0c78bb4e00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), balanceIn)
			mstore(add(ptr, 0x24), weightIn)
			mstore(add(ptr, 0x44), balanceOut)
			mstore(add(ptr, 0x64), weightOut)
			mstore(add(ptr, 0x84), amountIn)

			if iszero(staticcall(gas(), EXTERNAL_WEIGHTED_MATH, ptr, 0xa4, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			amountOut := mload(0x00)
		}
	}

	function maxCurrencyId() internal pure virtual override returns (uint256) {
		return 8;
	}
}
