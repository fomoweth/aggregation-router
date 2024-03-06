// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2 as console} from "forge-std/Test.sol";
import {UniswapV3Adapter} from "src/adapters/UniswapV3Adapter.sol";
import {Create3} from "src/libraries/Create3.sol";
import {Errors} from "src/libraries/Errors.sol";
import {FullMath} from "src/libraries/FullMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {PriceUtils} from "test/utils/PriceUtils.sol";
import {Constants} from "test/utils/Constants.sol";

// forge test -vvv --match-path test/UniswapV3Adapter.t.sol

contract UniswapV3AdapterTest is Test, Constants {
	using CurrencyLibrary for Currency;

	address constant WBTC_ETH_3000_POOL = 0xCBCdF9626bC03E24f779434178A73a0B4bad62eD;

	UniswapV3Adapter adapter;

	uint256 ethAmount = 20 ether;

	function setUp() public {
		vm.createSelectFork(vm.envString("RPC_ETHEREUM"), 19378914);

		adapter = UniswapV3Adapter(
			payable(
				Create3.create3(
					keccak256(abi.encodePacked("UNISWAP_V3_ADAPTER", address(this))),
					abi.encodePacked(type(UniswapV3Adapter).creationCode, abi.encode(WETH, UNISWAP_V3_ID))
				)
			)
		);
	}

	function testSwap0For1() public {
		uint256 amountIn = FullMath.mulDiv(ethAmount, 10 ** currency0().decimals(), latestAnswer(feed()));

		deal(currency0(), address(adapter), amountIn);
		assertEq(currency0().balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currency0(), currency1(), amountIn);
		assertEq(pool, WBTC_ETH_3000_POOL);

		bytes32 data = pack(pool, 0, 1, NO_ACTION, NO_ACTION);

		uint256 amountOut = adapter.uniswapV3Swap(data);
		assertEq(amountOut, expected);

		uint256 balance0 = currency0().balanceOf(address(adapter));
		uint256 balance1 = currency1().balanceOf(address(adapter));

		assertEq(balance0, 0);
		assertEq(balance1, amountOut);
	}

	function testSwap1For0() public {
		uint256 amountIn = ethAmount;

		deal(currency1(), address(adapter), amountIn);
		assertEq(currency1().balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currency1(), currency0(), amountIn);
		assertEq(pool, WBTC_ETH_3000_POOL);

		bytes32 data = pack(pool, 1, 0, NO_ACTION, NO_ACTION);

		uint256 amountOut = adapter.uniswapV3Swap(data);
		assertEq(amountOut, expected);

		uint256 balance0 = currency0().balanceOf(address(adapter));
		uint256 balance1 = currency1().balanceOf(address(adapter));

		assertEq(balance0, amountOut);
		assertEq(balance1, 0);
	}

	function testSwap0For1UnwrapETHAfter() public {
		uint256 amountIn = FullMath.mulDiv(ethAmount, 10 ** currency0().decimals(), latestAnswer(feed()));

		deal(currency0(), address(adapter), amountIn);
		assertEq(currency0().balanceOf(address(adapter)), amountIn);

		(address pool, uint256 expected) = adapter.query(currency0(), currency1(), amountIn);
		assertEq(pool, WBTC_ETH_3000_POOL);

		bytes32 data = pack(pool, 0, 1, NO_ACTION, UNWRAP_ETH);

		uint256 amountOut = adapter.uniswapV3Swap(data);
		assertEq(amountOut, expected);

		uint256 balance0 = currency0().balanceOf(address(adapter));
		uint256 balance1 = address(adapter).balance;

		assertEq(balance0, 0);
		assertEq(balance1, amountOut);
	}

	function testSwap0For1WrapETHBefore() public {
		uint256 amountIn = ethAmount;

		deal(address(adapter), amountIn);
		assertEq(address(adapter).balance, amountIn);

		(address pool, uint256 expected) = adapter.query(currency1(), currency0(), amountIn);
		assertEq(pool, WBTC_ETH_3000_POOL);

		bytes32 data = pack(pool, 1, 0, WRAP_ETH, NO_ACTION);

		uint256 amountOut = adapter.uniswapV3Swap(data);
		assertEq(amountOut, expected);
	}

	function currency0() internal pure returns (Currency) {
		return WBTC;
	}

	function currency1() internal pure returns (Currency) {
		return WETH;
	}

	function feed() internal pure returns (address) {
		return 0xdeb288F737066589598e9214E782fa5A8eD689e8;
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
}
