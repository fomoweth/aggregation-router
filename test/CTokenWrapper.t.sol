// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2 as console} from "forge-std/Test.sol";
import {CTokenWrapper} from "src/adapters/wrappers/CTokenWrapper.sol";
import {PercentageMath} from "src/libraries/PercentageMath.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseTest} from "test/shared/BaseTest.t.sol";

contract CTokenWrapperTest is BaseTest {
	using CurrencyLibrary for Currency;
	using PercentageMath for uint256;

	address constant ORACLE = 0x50ce56A3239671Ab62f185704Caedf626352741e;

	Currency constant cWBTC = Currency.wrap(0xccF4429DB6322D5C611ee964527D42E5d685DD6a);
	Currency constant cUSDC = Currency.wrap(0x39AA39c021dfbaE8faC545936693aC917d5E7563);

	uint256 ethAmount = 20 ether;

	CTokenWrapper adapter;

	function setUp() public {
		fork();

		adapter = CTokenWrapper(
			deployAdapter(
				"CTOKEN_WRAPPER",
				abi.encodePacked(
					type(CTokenWrapper).creationCode,
					abi.encode(CTOKEN_WRAPPER_ID, WETH, COMPTROLLER, CETH, CETH)
				)
			)
		);
	}

	function testWrapCNative() public {
		Currency cToken = CETH;
		Currency underlying = WETH;

		uint256 snapshot = vm.snapshot();

		uint256 amountIn;
		uint256 amountOut;
		bytes32 queryPath;
		uint256 queryAmount;
		uint256 quoteAmount;

		// ETH -> cETH

		amountIn = deal(ETH, address(adapter), ethAmount);

		(queryPath, queryAmount) = adapter.query(ETH, cToken, amountIn, true);
		assertEq(toPool(queryPath), cToken.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		amountOut = adapter.wrapCToken(queryPath);
		assertApproxEqAbs(amountOut, quoteAmount, quoteAmount.percentMul(1));

		vm.revertTo(snapshot);

		// WETH -> cETH

		amountIn = deal(underlying, address(adapter), ethAmount);

		(queryPath, queryAmount) = adapter.query(underlying, cToken, amountIn, true);
		assertEq(toPool(queryPath), cToken.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		amountOut = adapter.wrapCToken(queryPath);
		assertApproxEqAbs(amountOut, quoteAmount, quoteAmount.percentMul(1));
	}

	function testUnwrapCNative() public {
		uint256 amountIn;
		uint256 amountOut;
		bytes32 queryPath;
		uint256 queryAmount;
		uint256 quoteAmount;

		// cETH -> ETH

		amountIn = deal(ETH, address(adapter), ethAmount);

		(queryPath, queryAmount) = adapter.query(ETH, CETH, amountIn, true);
		assertEq(toPool(queryPath), CETH.toAddress());
		assertGt(queryAmount, 0);

		amountIn = adapter.wrapCToken(queryPath);
		assertEq(CETH.balanceOf(address(adapter)), amountIn);

		uint256 snapshot = vm.snapshot();

		(queryPath, queryAmount) = adapter.query(CETH, ETH, amountIn, false);
		assertEq(toPool(queryPath), CETH.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		amountOut = adapter.unwrapCToken(queryPath);
		assertApproxEqAbs(amountOut, quoteAmount, quoteAmount.percentMul(1));
		assertEq(address(adapter).balance, amountOut);

		vm.revertTo(snapshot);

		// cETH -> WETH

		(queryPath, queryAmount) = adapter.query(CETH, WETH, amountIn, false);
		assertEq(toPool(queryPath), CETH.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		amountOut = adapter.unwrapCToken(queryPath);
		assertApproxEqAbs(amountOut, quoteAmount, quoteAmount.percentMul(1));
	}

	function testWrapCToken() public {
		uint256 snapshot = vm.snapshot();

		Currency cToken;
		Currency underlying;

		uint256 ethPrice;
		uint256 assetPrice;
		uint256 derived;
		uint256 amountIn;
		uint256 amountOut;
		bytes32 queryPath;
		uint256 queryAmount;
		uint256 quoteAmount;

		// USDC -> cUSDC

		cToken = cUSDC;
		underlying = USDC;

		ethPrice = getUnderlyingPrice(CETH, 18);
		assetPrice = getUnderlyingPrice(cToken, underlying.decimals());
		derived = derivePrice(assetPrice, ethPrice, 8, 8, 18);

		amountIn = convertFromETH(ethAmount, derived, underlying.decimals());
		deal(underlying, address(adapter), amountIn);

		(queryPath, queryAmount) = adapter.query(underlying, cToken, amountIn, true);
		assertEq(toPool(queryPath), cToken.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		amountOut = adapter.wrapCToken(queryPath);
		assertApproxEqAbs(amountOut, quoteAmount, quoteAmount.percentMul(1));

		vm.revertTo(snapshot);

		// WBTC -> cWBTC

		cToken = cWBTC;
		underlying = WBTC;

		ethPrice = getUnderlyingPrice(CETH, 18);
		assetPrice = getUnderlyingPrice(cToken, underlying.decimals());
		derived = derivePrice(assetPrice, ethPrice, 8, 8, 18);

		amountIn = convertFromETH(ethAmount, derived, underlying.decimals());
		deal(underlying, address(adapter), amountIn);

		(queryPath, queryAmount) = adapter.query(underlying, cToken, amountIn, true);
		assertEq(toPool(queryPath), cToken.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		amountOut = adapter.wrapCToken(queryPath);
		assertApproxEqAbs(amountOut, quoteAmount, quoteAmount.percentMul(1));
	}

	function testUnwrapCToken() public {
		uint256 snapshot = vm.snapshot();

		Currency cToken;
		Currency underlying;

		uint256 ethPrice;
		uint256 assetPrice;
		uint256 derived;
		uint256 amountIn;
		uint256 amountOut;
		bytes32 queryPath;
		uint256 queryAmount;
		uint256 quoteAmount;

		// cUSDC -> USDC

		cToken = cUSDC;
		underlying = USDC;

		ethPrice = getUnderlyingPrice(CETH, 18);
		assetPrice = getUnderlyingPrice(cToken, underlying.decimals());
		derived = derivePrice(assetPrice, ethPrice, 8, 8, 18);

		amountIn = convertFromETH(ethAmount, derived, underlying.decimals());
		deal(underlying, address(adapter), amountIn);

		(queryPath, queryAmount) = adapter.query(underlying, cToken, amountIn, true);
		assertEq(toPool(queryPath), cToken.toAddress());
		assertGt(queryAmount, 0);

		amountIn = adapter.wrapCToken(queryPath);
		assertEq(cToken.balanceOf(address(adapter)), amountIn);

		(queryPath, queryAmount) = adapter.query(cToken, underlying, amountIn, false);
		assertEq(toPool(queryPath), cToken.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		amountOut = adapter.unwrapCToken(queryPath);
		assertApproxEqAbs(amountOut, quoteAmount, quoteAmount.percentMul(1));

		vm.revertTo(snapshot);

		// cWBTC -> WBTC

		cToken = cWBTC;
		underlying = WBTC;

		ethPrice = getUnderlyingPrice(CETH, 18);
		assetPrice = getUnderlyingPrice(cToken, underlying.decimals());
		derived = derivePrice(assetPrice, ethPrice, 8, 8, 18);

		amountIn = convertFromETH(ethAmount, derived, underlying.decimals());
		deal(underlying, address(adapter), amountIn);

		(queryPath, queryAmount) = adapter.query(underlying, cToken, amountIn, true);
		assertEq(toPool(queryPath), cToken.toAddress());
		assertGt(queryAmount, 0);

		amountIn = adapter.wrapCToken(queryPath);
		assertEq(cToken.balanceOf(address(adapter)), amountIn);

		(queryPath, queryAmount) = adapter.query(cToken, underlying, amountIn, false);
		assertEq(toPool(queryPath), cToken.toAddress());
		assertGt(queryAmount, 0);

		quoteAmount = adapter.quote(queryPath, amountIn);
		assertEq(quoteAmount, queryAmount);

		amountOut = adapter.unwrapCToken(queryPath);
		assertApproxEqAbs(amountOut, quoteAmount, quoteAmount.percentMul(1));
	}

	function getUnderlyingPrice(
		Currency cToken,
		uint256 underlyingDecimals
	) internal view virtual returns (uint256 price) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0xfc57d4df00000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), and(cToken, 0xffffffffffffffffffffffffffffffffffffffff))

			if iszero(staticcall(gas(), ORACLE, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			price := div(mload(0x00), exp(10, sub(28, underlyingDecimals)))
		}
	}
}
