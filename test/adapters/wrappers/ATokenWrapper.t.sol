// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ATokenWrapper} from "src/adapters/wrappers/ATokenWrapper.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseTest} from "test/shared/BaseTest.t.sol";

contract ATokenWrapperTest is BaseTest {
	using CurrencyLibrary for Currency;

	// V3
	address constant V3_ORACLE = 0x54586bE62E3c3580375aE3723C145253060Ca0C2;

	Currency constant aEthWETH = Currency.wrap(0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8);
	Currency constant aEthWBTC = Currency.wrap(0x5Ee5bf7ae06D1Be5997A1A72006FE6C607eC6DE8);
	Currency constant aEthUSDC = Currency.wrap(0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c);

	// V2
	address constant V2_ORACLE = 0xA50ba011c48153De246E5192C8f9258A2ba79Ca9;

	Currency constant aWETH = Currency.wrap(0x030bA81f1c18d280636F32af80b9AAd02Cf0854e);
	Currency constant aWBTC = Currency.wrap(0x9ff58f4fFB29fA2266Ab25e75e2A8b3503311656);
	Currency constant aUSDC = Currency.wrap(0xBcca60bB61934080951369a648Fb03DF4F96263C);

	ATokenWrapper adapter;

	function setUp() public {
		fork();

		adapter = ATokenWrapper(
			deployAdapter(
				"ATOKEN_WRAPPER",
				abi.encodePacked(
					type(ATokenWrapper).creationCode,
					abi.encode(ATOKEN_WRAPPER_ID, WETH, POOL, LENDING_POOL)
				)
			)
		);
	}

	function testWrapAWETHV3() public {
		Currency aToken = aEthWETH;

		uint256 snapshot = vm.snapshot();

		uint256 amountIn;
		uint256 amountOut;
		bytes32 queryPath;
		uint256 queryAmount;
		uint256 quoteAmount;

		// WETH -> aEthWETH

		amountIn = computeAmountIn(WETH, getSourceOfAsset(WETH), ethAmount);
		deal(WETH, address(adapter), amountIn);

		(queryPath, queryAmount) = adapter.query(WETH, aToken, amountIn, true);
		assertEq(toPool(queryPath), aToken.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		amountOut = adapter.wrapAToken(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshot);

		// ETH -> aEthWETH

		amountIn = deal(ETH, address(adapter), ethAmount);
		assertEq(ETH.balanceOf(address(adapter)), amountIn);

		(queryPath, queryAmount) = adapter.query(ETH, aToken, amountIn, true);
		assertEq(toPool(queryPath), aToken.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		amountOut = adapter.wrapAToken(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	function testUnwrapAWETHV3() public {
		Currency aToken = aEthWETH;

		uint256 amountIn;
		uint256 amountOut;
		bytes32 queryPath;
		uint256 queryAmount;
		uint256 quoteAmount;

		amountIn = computeAmountIn(WETH, getSourceOfAsset(WETH), ethAmount);

		deal(WETH, address(adapter), amountIn);

		(queryPath, queryAmount) = adapter.query(WETH, aToken, ethAmount, true);
		assertEq(toPool(queryPath), aToken.toAddress());
		assertGt(queryAmount, 0);

		amountIn = adapter.wrapAToken(queryPath);
		assertEq(aToken.balanceOf(address(adapter)), amountIn);

		uint256 snapshot = vm.snapshot();

		// aEthWETH -> WETH

		(queryPath, queryAmount) = adapter.query(aToken, WETH, amountIn, false);
		assertEq(toPool(queryPath), aToken.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		amountOut = adapter.unwrapAToken(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshot);

		// aEthWETH -> ETH

		(queryPath, queryAmount) = adapter.query(aToken, ETH, amountIn, false);
		assertEq(toPool(queryPath), aToken.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		amountOut = adapter.unwrapAToken(queryPath);
		assertEq(amountOut, quoteAmount);
		assertEq(address(adapter).balance, amountOut);
	}

	function testWrapATokenV3() public {
		uint256 snapshot = vm.snapshot();

		Currency aToken;
		Currency underlying;

		uint256 amountIn;
		uint256 amountOut;
		bytes32 queryPath;
		uint256 queryAmount;
		uint256 quoteAmount;

		// USDC -> aEthUSDC

		aToken = aEthUSDC;
		underlying = USDC;

		amountIn = computeAmountIn(underlying, getSourceOfAsset(underlying), ethAmount);
		deal(underlying, address(adapter), amountIn);

		(queryPath, queryAmount) = adapter.query(underlying, aToken, amountIn, true);
		assertEq(toPool(queryPath), aToken.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		amountOut = adapter.wrapAToken(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshot);

		// WBTC -> aEthWBTC

		aToken = aEthWBTC;
		underlying = WBTC;

		amountIn = computeAmountIn(underlying, getSourceOfAsset(underlying), ethAmount);
		deal(underlying, address(adapter), amountIn);

		(queryPath, queryAmount) = adapter.query(underlying, aToken, amountIn, true);
		assertEq(toPool(queryPath), aToken.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		amountOut = adapter.wrapAToken(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	function testUnwrapATokenV3() public {
		uint256 snapshot = vm.snapshot();

		Currency aToken;
		Currency underlying;

		uint256 amountIn;
		uint256 amountOut;
		bytes32 queryPath;
		uint256 queryAmount;
		uint256 quoteAmount;

		// aEthUSDC -> USDC

		aToken = aEthUSDC;
		underlying = USDC;

		amountIn = computeAmountIn(underlying, getSourceOfAsset(underlying), ethAmount);
		deal(underlying, address(adapter), amountIn);

		(queryPath, queryAmount) = adapter.query(underlying, aToken, ethAmount, true);
		assertEq(toPool(queryPath), aToken.toAddress());
		assertGt(queryAmount, 0);

		amountIn = adapter.wrapAToken(queryPath);
		assertEq(aToken.balanceOf(address(adapter)), amountIn);

		(queryPath, queryAmount) = adapter.query(aToken, underlying, amountIn, false);
		assertEq(toPool(queryPath), aToken.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		amountOut = adapter.unwrapAToken(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshot);

		// aEthWBTC -> WBTC

		aToken = aEthWBTC;
		underlying = WBTC;

		amountIn = computeAmountIn(underlying, getSourceOfAsset(underlying), ethAmount);
		deal(underlying, address(adapter), amountIn);

		(queryPath, queryAmount) = adapter.query(underlying, aToken, ethAmount, true);
		assertEq(toPool(queryPath), aToken.toAddress());
		assertGt(queryAmount, 0);

		amountIn = adapter.wrapAToken(queryPath);
		assertEq(aToken.balanceOf(address(adapter)), amountIn);

		(queryPath, queryAmount) = adapter.query(aToken, underlying, amountIn, false);
		assertEq(toPool(queryPath), aToken.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		amountOut = adapter.unwrapAToken(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	function testWrapAWETHV2() public {
		Currency aToken = aWETH;

		uint256 snapshot = vm.snapshot();

		uint256 amountIn;
		uint256 amountOut;
		bytes32 queryPath;
		uint256 queryAmount;
		uint256 quoteAmount;

		// WETH -> aWETH

		amountIn = computeAmountIn(WETH, getSourceOfAsset(WETH), ethAmount);
		deal(WETH, address(adapter), amountIn);

		(queryPath, queryAmount) = adapter.query(WETH, aToken, amountIn, true);
		assertEq(toPool(queryPath), aToken.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		amountOut = adapter.wrapAToken(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshot);

		// ETH -> aWETH

		amountIn = deal(ETH, address(adapter), ethAmount);
		assertEq(ETH.balanceOf(address(adapter)), amountIn);

		(queryPath, queryAmount) = adapter.query(ETH, aToken, amountIn, true);
		assertEq(toPool(queryPath), aToken.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		amountOut = adapter.wrapAToken(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	function testUnwrapAWETHV2() public {
		Currency aToken = aWETH;

		uint256 amountIn;
		uint256 amountOut;
		bytes32 queryPath;
		uint256 queryAmount;
		uint256 quoteAmount;

		// aWETH -> WETH

		amountIn = computeAmountIn(WETH, getSourceOfAsset(WETH), ethAmount);
		deal(WETH, address(adapter), amountIn);

		(queryPath, queryAmount) = adapter.query(WETH, aToken, amountIn, true);
		assertEq(toPool(queryPath), aToken.toAddress());
		assertGt(queryAmount, 0);

		amountIn = adapter.wrapAToken(queryPath);
		assertEq(aToken.balanceOf(address(adapter)), amountIn);

		uint256 snapshot = vm.snapshot();

		(queryPath, queryAmount) = adapter.query(aToken, WETH, amountIn, false);
		assertEq(toPool(queryPath), aToken.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		amountOut = adapter.wrapAToken(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshot);

		// aWETH -> ETH

		(queryPath, queryAmount) = adapter.query(aToken, ETH, amountIn, false);
		assertEq(toPool(queryPath), aToken.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		amountOut = adapter.wrapAToken(queryPath);
		assertEq(amountOut, quoteAmount);
		assertEq(address(adapter).balance, amountOut);
	}

	function testWrapATokenV2() public {
		uint256 snapshot = vm.snapshot();

		Currency aToken;
		Currency underlying;

		uint256 amountIn;
		uint256 amountOut;
		bytes32 queryPath;
		uint256 queryAmount;
		uint256 quoteAmount;

		// USDC -> aUSDC

		aToken = aUSDC;
		underlying = USDC;

		amountIn = computeAmountIn(underlying, getSourceOfAsset(underlying), ethAmount);
		deal(underlying, address(adapter), amountIn);

		(queryPath, queryAmount) = adapter.query(underlying, aToken, amountIn, true);
		assertEq(toPool(queryPath), aToken.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		amountOut = adapter.wrapAToken(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshot);

		// WBTC -> aWBTC

		aToken = aWBTC;
		underlying = WBTC;

		amountIn = computeAmountIn(underlying, getSourceOfAsset(underlying), ethAmount);
		deal(underlying, address(adapter), amountIn);

		(queryPath, queryAmount) = adapter.query(underlying, aToken, amountIn, true);
		assertEq(toPool(queryPath), aToken.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		amountOut = adapter.wrapAToken(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	function testUnwrapATokenV2() public {
		uint256 snapshot = vm.snapshot();

		Currency aToken;
		Currency underlying;

		uint256 amountIn;
		uint256 amountOut;
		bytes32 queryPath;
		uint256 queryAmount;
		uint256 quoteAmount;

		// aUSDC -> USDC

		aToken = aUSDC;
		underlying = USDC;

		amountIn = computeAmountIn(underlying, getSourceOfAsset(underlying), ethAmount);
		deal(underlying, address(adapter), amountIn);

		(queryPath, queryAmount) = adapter.query(underlying, aToken, ethAmount, true);
		assertEq(toPool(queryPath), aToken.toAddress());
		assertGt(queryAmount, 0);

		amountIn = adapter.wrapAToken(queryPath);
		assertEq(aToken.balanceOf(address(adapter)), amountIn);

		(queryPath, queryAmount) = adapter.query(aToken, underlying, amountIn, false);
		assertEq(toPool(queryPath), aToken.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		amountOut = adapter.unwrapAToken(queryPath);
		assertEq(amountOut, quoteAmount);

		vm.revertTo(snapshot);

		// aWBTC -> WBTC

		aToken = aWBTC;
		underlying = WBTC;

		amountIn = computeAmountIn(underlying, getSourceOfAsset(underlying), ethAmount);
		deal(underlying, address(adapter), amountIn);

		(queryPath, queryAmount) = adapter.query(underlying, aToken, ethAmount, true);
		assertEq(toPool(queryPath), aToken.toAddress());
		assertGt(queryAmount, 0);

		amountIn = adapter.wrapAToken(queryPath);
		assertEq(aToken.balanceOf(address(adapter)), amountIn);

		(queryPath, queryAmount) = adapter.query(aToken, underlying, amountIn, false);
		assertEq(toPool(queryPath), aToken.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		amountOut = adapter.unwrapAToken(queryPath);
		assertEq(amountOut, quoteAmount);
	}

	function getSourceOfAsset(Currency asset) internal view returns (address feed) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x92bf2be000000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(asset, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), V2_ORACLE, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			feed := mload(0x00)
		}
	}
}
