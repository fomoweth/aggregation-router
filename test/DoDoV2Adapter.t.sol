// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2 as console} from "forge-std/Test.sol";
import {DoDoV2Adapter} from "src/adapters/DoDoV2Adapter.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseTest} from "test/BaseTest.t.sol";

// forge test -vvv --match-path test/DoDoV2Adapter.t.sol

contract DoDoV2AdapterTest is BaseTest {
	using CurrencyLibrary for Currency;

	uint256 ethAmount = 20 ether;

	DoDoV2Adapter adapter;

	address constant DVM_FACTORY = 0x72d220cE168C4f361dD4deE5D826a01AD8598f6C;
	address constant DSP_FACTORY = 0x6fdDB76c93299D985f4d3FC7ac468F9A168577A4;
	address constant DPP_FACTORY = 0x5336edE8F971339F6c0e304c66ba16F1296A2Fbe;

	address constant APPROVE_PROXY = 0x335aC99bb3E51BDbF22025f092Ebc1Cf2c5cC619;
	address constant V2_PROXY = 0xa356867fDCEa8e71AEaF87805808803806231FdC;
	address constant DSP_PROXY = 0x4599ed18F34cFE06820E3684bF0aACB8D75c644d;
	address constant DPP_PROXY = 0xfF7C8F518e6f1435957ed3d3E0692C94676dAE7a;

	function setUp() public {
		fork();

		adapter = DoDoV2Adapter(
			deployAdapter(
				"DODO_V2_ADAPTER",
				abi.encodePacked(type(DoDoV2Adapter).creationCode, abi.encode(DODO_V2_ID, WETH))
			)
		);
	}

	function testSellBaseOnDoDoV2() public {
		Currency currencyIn = base();
		Currency currencyOut = quote();

		uint8 i = 0;
		uint8 j = 1;

		uint256 amountIn = feed() != address(0)
			? computeAmountIn(currencyIn, feed(), ethAmount)
			: querySellQuote(pool(), ethAmount);

		deal(currencyIn, address(adapter), amountIn);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, pool());
		assertGt(queryAmount, 0);

		bytes32 path = pack(queryPool, i, j, NO_ACTION, NO_ACTION, false);

		uint256 amountOut = adapter.dodoV2Swap(path);
		assertEq(amountOut, queryAmount);
	}

	function testWrapETHThenSellBaseOnDoDoV2() public {
		Currency currencyIn = base();
		Currency currencyOut = quote();

		uint8 i = 0;
		uint8 j = 1;

		uint256 amountIn = computeAmountIn(currencyIn, feed(), ethAmount);

		deal(ETH, address(adapter), amountIn);
		assertEq(getBalance(ETH, address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, pool());
		assertGt(queryAmount, 0);

		bytes32 path = pack(queryPool, i, j, WRAP_ETH, NO_ACTION, false);

		uint256 amountOut = adapter.dodoV2Swap(path);
		assertEq(amountOut, queryAmount);
	}

	function testSellQuoteOnDoDoV2() public {
		Currency currencyIn = quote();
		Currency currencyOut = base();

		uint8 i = 1;
		uint8 j = 0;

		uint256 amountIn = feed() != address(0)
			? computeAmountIn(currencyIn, feed(), ethAmount)
			: querySellBase(pool(), ethAmount);

		deal(currencyIn, address(adapter), amountIn);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, pool());
		assertGt(queryAmount, 0);

		bytes32 path = pack(queryPool, i, j, NO_ACTION, NO_ACTION, false);

		uint256 amountOut = adapter.dodoV2Swap(path);
		assertEq(amountOut, queryAmount);
	}

	function testSellQuoteThenUnwrapWETHOnDoDoV2() public {
		Currency currencyIn = quote();
		Currency currencyOut = base();

		uint8 i = 1;
		uint8 j = 0;

		uint256 amountIn = feed() != address(0)
			? computeAmountIn(currencyIn, feed(), ethAmount)
			: querySellBase(pool(), ethAmount);

		deal(currencyIn, address(adapter), amountIn);
		assertEq(getBalance(currencyIn, address(adapter)), amountIn);

		(address queryPool, uint256 queryAmount) = adapter.query(currencyIn, currencyOut, amountIn);
		assertEq(queryPool, pool());
		assertGt(queryAmount, 0);

		bytes32 path = pack(queryPool, i, j, NO_ACTION, UNWRAP_ETH, false);

		uint256 amountOut = adapter.dodoV2Swap(path);
		assertEq(amountOut, queryAmount);
		assertEq(address(adapter).balance, amountOut, "!balance");
	}

	function sync(address dodoPool) internal {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xfff6cae900000000000000000000000000000000000000000000000000000000) // sync()

			if iszero(call(gas(), dodoPool, 0x00, ptr, 0x04, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}
		}
	}

	function getPools(
		address factory,
		Currency currencyIn,
		Currency currencyOut
	) internal view returns (address[] memory) {
		bytes memory returndata;

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x57a281dc00000000000000000000000000000000000000000000000000000000) // getDODOPool(address,address)
			mstore(add(ptr, 0x04), and(currencyIn, 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), and(currencyOut, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), factory, ptr, 0x44, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x40, add(returndata, add(returndatasize(), 0x20)))
			mstore(returndata, returndatasize())
			returndatacopy(add(returndata, 0x20), 0x00, returndatasize())
		}

		return abi.decode(returndata, (address[]));
	}

	function querySellBase(address dodoPool, uint256 amount) internal view returns (uint256 value) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x79a0487600000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), amount)

			if iszero(staticcall(gas(), dodoPool, ptr, 0x44, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			value := mload(0x00)
		}
	}

	function querySellQuote(address dodoPool, uint256 amount) internal view returns (uint256 value) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x66410a2100000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
			mstore(add(ptr, 0x24), amount)

			if iszero(staticcall(gas(), dodoPool, ptr, 0x44, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			value := mload(0x00)
		}
	}

	function isBase(address dodoPool, Currency currency) internal view returns (bool res) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x4a248d2a00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), dodoPool, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			res := eq(currency, mload(0x00))
		}
	}

	function pool() internal pure returns (address) {
		return DODO_V2_WETH_NEAR_DVM_POOL;
	}

	function base() internal pure returns (Currency) {
		return WETH;
	}

	function quote() internal pure returns (Currency) {
		return NEAR;
	}

	function feed() internal pure returns (address) {
		return address(0);
	}
}
