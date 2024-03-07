// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2 as console} from "forge-std/Test.sol";
import {Test} from "forge-std/Test.sol";
import {CurveAdapter} from "src/adapters/CurveAdapter.sol";
import {Create3} from "src/libraries/Create3.sol";
import {FullMath} from "src/libraries/FullMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {Constants} from "test/utils/Constants.sol";

// forge test -vvv --match-path test/crv/CurveAdapter.t.sol

contract CurveAdapterTest is Test, Constants {
	using CurrencyLibrary for Currency;

	address constant TRICRYPTO_POOL = 0x80466c64868E1ab14a1Ddf27A676C3fcBE638Fe5;

	uint256 ethAmount = 20 ether;

	CurveAdapter adapter;

	function setUp() public {
		vm.createSelectFork(vm.envString("RPC_ETHEREUM"), FORK_BLOCK);

		adapter = CurveAdapter(
			payable(
				Create3.create3(
					keccak256(abi.encodePacked("CURVE_ADAPTER", address(this))),
					abi.encodePacked(type(CurveAdapter).creationCode, abi.encode(WETH, CURVE_ID))
				)
			)
		);
	}

	function testSwapWETHForWBTCOnCurve() public {
		Currency currencyIn = WETH;
		Currency currencyOut = WBTC;

		uint256 amountIn = ethAmount;

		deal(currencyIn, address(adapter), amountIn);
		assertEq(currencyIn.balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(pool, TRICRYPTO_POOL);

		(uint8 i, uint8 j, bool isUnderlying) = adapter.getCoinIndices(pool, currencyIn, currencyOut);

		bytes32 data = pack(pool, i, j, NO_ACTION, NO_ACTION, isUnderlying);

		uint256 amountOut = adapter.curveSwap(data);
		assertEq(amountOut, expected);

		uint256 balanceIn = currencyIn.balanceOf(address(adapter));
		uint256 balanceOut = currencyOut.balanceOf(address(adapter));

		assertEq(balanceIn, 0);
		assertEq(balanceOut, amountOut);
	}

	function testSwapWETHForWBTCWrapETHBeforeOnCurve() public {
		Currency currencyIn = WETH;
		Currency currencyOut = WBTC;

		uint256 amountIn = ethAmount;

		deal(address(adapter), amountIn);
		assertEq(address(adapter).balance, amountIn);

		(address pool, uint256 expected) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(pool, TRICRYPTO_POOL);

		(uint8 i, uint8 j, bool isUnderlying) = adapter.getCoinIndices(pool, currencyIn, currencyOut);

		bytes32 data = pack(pool, i, j, WRAP_ETH, NO_ACTION, isUnderlying);

		uint256 amountOut = adapter.curveSwap(data);
		assertEq(amountOut, expected);

		uint256 balanceIn = currencyIn.balanceOf(address(adapter));
		uint256 balanceOut = currencyOut.balanceOf(address(adapter));

		assertEq(balanceIn, 0);
		assertEq(balanceOut, amountOut);
	}

	function testSwapWBTCForWETHOnCurve() public {
		Currency currencyIn = WBTC;
		Currency currencyOut = WETH;

		uint256 amountIn = FullMath.mulDiv(ethAmount, 10 ** currencyIn.decimals(), latestAnswer(feed()));

		deal(currencyIn, address(adapter), amountIn);
		assertEq(currencyIn.balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(pool, TRICRYPTO_POOL);

		(uint8 i, uint8 j, bool isUnderlying) = adapter.getCoinIndices(pool, currencyIn, currencyOut);

		bytes32 data = pack(pool, i, j, NO_ACTION, NO_ACTION, isUnderlying);

		uint256 amountOut = adapter.curveSwap(data);
		assertEq(amountOut, expected);

		uint256 balanceIn = currencyIn.balanceOf(address(adapter));
		uint256 balanceOut = currencyOut.balanceOf(address(adapter));

		assertEq(balanceIn, 0);
		assertEq(balanceOut, amountOut);
	}

	function testSwapWBTCForWETHUnwrapETHAfterOnCurve() public {
		Currency currencyIn = WBTC;
		Currency currencyOut = WETH;

		uint256 amountIn = FullMath.mulDiv(ethAmount, 10 ** currencyIn.decimals(), latestAnswer(feed()));

		deal(currencyIn, address(adapter), amountIn);
		assertEq(currencyIn.balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(pool, TRICRYPTO_POOL);

		(uint8 i, uint8 j, bool isUnderlying) = adapter.getCoinIndices(pool, currencyIn, currencyOut);

		bytes32 data = pack(pool, i, j, NO_ACTION, UNWRAP_ETH, isUnderlying);

		uint256 amountOut = adapter.curveSwap(data);
		assertEq(amountOut, expected);

		uint256 balanceIn = currencyIn.balanceOf(address(adapter));
		uint256 balanceOut = address(adapter).balance;

		assertEq(balanceIn, 0);
		assertEq(balanceOut, amountOut);
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
		uint8 wrapOut,
		bool isUnderlying
	) internal pure returns (bytes32 data) {
		assembly ("memory-safe") {
			data := add(
				pool,
				add(
					shl(160, i),
					add(shl(168, j), add(shl(176, wrapIn), add(shl(184, wrapOut), shl(192, isUnderlying))))
				)
			)
		}
	}

	function currency0() internal pure returns (Currency) {
		return WBTC;
	}

	function currency1() internal pure returns (Currency) {
		return WETH;
	}

	function feed() internal pure returns (address) {
		return BTC_ETH_FEED;
	}
}
