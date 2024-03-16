// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregationRouter} from "src/AggregationRouter.sol";
import {BalancerV2Adapter} from "src/adapters/BalancerV2Adapter.sol";
import {CurveAdapter} from "src/adapters/CurveAdapter.sol";
import {DoDoV1Adapter} from "src/adapters/DoDoV1Adapter.sol";
import {DoDoV2Adapter} from "src/adapters/DoDoV2Adapter.sol";
import {FraxSwapV2Adapter} from "src/adapters/FraxSwapV2Adapter.sol";
import {PancakeV2Adapter} from "src/adapters/PancakeV2Adapter.sol";
import {PancakeV3Adapter} from "src/adapters/PancakeV3Adapter.sol";
import {SushiV2Adapter} from "src/adapters/SushiV2Adapter.sol";
import {SushiV3Adapter} from "src/adapters/SushiV3Adapter.sol";
import {UniswapV2Adapter} from "src/adapters/UniswapV2Adapter.sol";
import {UniswapV3Adapter} from "src/adapters/UniswapV3Adapter.sol";
import {ATokenWrapper} from "src/adapters/wrappers/ATokenWrapper.sol";
import {CTokenWrapper} from "src/adapters/wrappers/CTokenWrapper.sol";
import {FRXETHWrapper} from "src/adapters/wrappers/FRXETHWrapper.sol";
import {STETHWrapper} from "src/adapters/wrappers/STETHWrapper.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {BaseTest} from "test/shared/BaseTest.t.sol";

contract AggregationRouterTest is BaseTest {
	using CurrencyLibrary for Currency;

	AggregationRouter router;

	UniswapV3Adapter uniV3Adapter;
	UniswapV2Adapter uniV2Adapter;
	SushiV3Adapter sushiV3Adapter;
	SushiV2Adapter sushiV2Adapter;
	PancakeV3Adapter pancakeV3Adapter;
	PancakeV2Adapter pancakeV2Adapter;
	FraxSwapV2Adapter fraxAdapter;
	BalancerV2Adapter balancerAdapter;
	CurveAdapter curveAdapter;
	DoDoV2Adapter dodoV2Adapter;
	DoDoV1Adapter dodoV1Adapter;
	FRXETHWrapper frxethWrapper;
	STETHWrapper stethWrapper;
	ATokenWrapper aTokenWrapper;
	CTokenWrapper cTokenWrapper;

	function setUp() public {
		fork();

		uniV3Adapter = UniswapV3Adapter(
			deployAdapter(
				"UNISWAP_V3_ADAPTER",
				abi.encodePacked(type(UniswapV3Adapter).creationCode, abi.encode(UNISWAP_V3_ID, WETH))
			)
		);

		uniV2Adapter = UniswapV2Adapter(
			deployAdapter(
				"UNISWAP_V2_ADAPTER",
				abi.encodePacked(type(UniswapV2Adapter).creationCode, abi.encode(UNISWAP_V2_ID, WETH))
			)
		);

		sushiV3Adapter = SushiV3Adapter(
			deployAdapter(
				"SUSHI_V3_ADAPTER",
				abi.encodePacked(type(SushiV3Adapter).creationCode, abi.encode(SUSHI_V3_ID, WETH))
			)
		);

		sushiV2Adapter = SushiV2Adapter(
			deployAdapter(
				"SUSHI_V2_ADAPTER",
				abi.encodePacked(type(SushiV2Adapter).creationCode, abi.encode(SUSHI_V2_ID, WETH))
			)
		);

		pancakeV3Adapter = PancakeV3Adapter(
			deployAdapter(
				"PANCAKESWAP_V3_ADAPTER",
				abi.encodePacked(type(PancakeV3Adapter).creationCode, abi.encode(PANCAKE_V3_ID, WETH))
			)
		);

		pancakeV2Adapter = PancakeV2Adapter(
			deployAdapter(
				"PANCAKESWAP_V2_ADAPTER",
				abi.encodePacked(type(PancakeV2Adapter).creationCode, abi.encode(PANCAKE_V2_ID, WETH))
			)
		);

		fraxAdapter = FraxSwapV2Adapter(
			deployAdapter(
				"FRAXSWAP_V2_ADAPTER",
				abi.encodePacked(type(FraxSwapV2Adapter).creationCode, abi.encode(FRAX_V2_ID, WETH))
			)
		);

		balancerAdapter = BalancerV2Adapter(
			deployAdapter(
				"BALANCER_V2_ADAPTER",
				abi.encodePacked(type(BalancerV2Adapter).creationCode, abi.encode(BALANCER_V2_ID, WETH))
			)
		);

		curveAdapter = CurveAdapter(
			deployAdapter(
				"CURVE_ADAPTER",
				abi.encodePacked(type(CurveAdapter).creationCode, abi.encode(CURVE_ID, WETH))
			)
		);

		dodoV2Adapter = DoDoV2Adapter(
			deployAdapter(
				"DODO_V2_ADAPTER",
				abi.encodePacked(type(DoDoV2Adapter).creationCode, abi.encode(DODO_V2_ID, WETH))
			)
		);

		dodoV1Adapter = DoDoV1Adapter(
			deployAdapter(
				"DODO_V1_ADAPTER",
				abi.encodePacked(type(DoDoV1Adapter).creationCode, abi.encode(DODO_V1_ID, WETH))
			)
		);

		frxethWrapper = FRXETHWrapper(
			deployAdapter(
				"FRXETH_WRAPPER",
				abi.encodePacked(
					type(FRXETHWrapper).creationCode,
					abi.encode(FRXETH_WRAPPER_ID, WETH, FRXETH, SFRXETH)
				)
			)
		);

		stethWrapper = STETHWrapper(
			deployAdapter(
				"STETH_WRAPPER",
				abi.encodePacked(
					type(STETHWrapper).creationCode,
					abi.encode(STETH_WRAPPER_ID, WETH, STETH, WSTETH)
				)
			)
		);

		aTokenWrapper = ATokenWrapper(
			deployAdapter(
				"ATOKEN_WRAPPER",
				abi.encodePacked(
					type(ATokenWrapper).creationCode,
					abi.encode(ATOKEN_WRAPPER_ID, WETH, POOL, LENDING_POOL)
				)
			)
		);

		cTokenWrapper = CTokenWrapper(
			deployAdapter(
				"CTOKEN_WRAPPER",
				abi.encodePacked(
					type(CTokenWrapper).creationCode,
					abi.encode(CTOKEN_WRAPPER_ID, WETH, COMPTROLLER, CETH, CETH)
				)
			)
		);

		router = new AggregationRouter();
	}

	function testMultihop() public {
		uint256 snapshot = vm.snapshot();

		bytes[] memory calls = new bytes[](2);

		// UNI-V3 -> UNI-V2: (ETH -> WETH -> UNI -> WETH -> ETH)

		// UNI-V3 UNI-ETH/3000
		calls[0] = abi.encodeCall(
			uniV3Adapter.uniswapV3Swap,
			(pack(0x1d42064Fc4Beb5F8aAF85F4617AE8b3b5B8Bd801, 1, 0, WRAP_ETH, NO_ACTION, false))
		);

		// UNI-V2 UNI-ETH
		calls[1] = abi.encodeCall(
			uniV2Adapter.uniswapV2Swap,
			(pack(0xd3d2E2692501A5c9Ca623199D38826e513033a17, 0, 1, NO_ACTION, UNWRAP_WETH, false))
		);

		callAggregator(calls, ETH, ETH, ethAmount);

		vm.revertTo(snapshot);

		// UNI-V3 -> BAL-V2: (ETH -> WETH -> WBTC -> WETH -> ETH)

		// UNI-V3 WBTC-ETH/3000
		calls[0] = abi.encodeCall(
			uniV3Adapter.uniswapV3Swap,
			(pack(0xCBCdF9626bC03E24f779434178A73a0B4bad62eD, 1, 0, WRAP_ETH, NO_ACTION, false))
		);

		// BAL-V2 B-50WBTC-50WETH
		calls[1] = abi.encodeCall(
			balancerAdapter.balancerV2Swap,
			(pack(0xA6F548DF93de924d73be7D25dC02554c6bD66dB5, 0, 1, NO_ACTION, UNWRAP_WETH, false))
		);

		callAggregator(calls, ETH, ETH, ethAmount);

		vm.revertTo(snapshot);

		// Curve -> UNI-V3: (ETH -> WETH -> USDT -> WETH -> ETH)

		// Curve Tricrypto2
		calls[0] = abi.encodeCall(
			curveAdapter.curveSwap,
			(pack(0xD51a44d3FaE010294C616388b506AcdA1bfAAE46, 2, 0, WRAP_ETH, NO_ACTION, false))
		);

		// UNI-V3 ETH-USDT/500
		calls[1] = abi.encodeCall(
			uniV3Adapter.uniswapV3Swap,
			(pack(0x11b815efB8f581194ae79006d24E0d814B7697F6, 1, 0, NO_ACTION, UNWRAP_WETH, false))
		);

		callAggregator(calls, ETH, ETH, ethAmount);
	}

	function testUniswapV3() public {
		// FRAX -> USDC -> ETH -> SUSHI

		bytes[] memory calls = new bytes[](3);

		// UNI-V3 FRAX-USDC/500
		calls[0] = abi.encodeCall(
			uniV3Adapter.uniswapV3Swap,
			(pack(0xc63B0708E2F7e69CB8A1df0e1389A98C35A76D52, 0, 1, NO_ACTION, NO_ACTION, false))
		);

		// PANCAKE-V3 USDC-WETH/500
		calls[1] = abi.encodeCall(
			pancakeV3Adapter.pancakeV3Swap,
			(pack(0x1ac1A8FEaAEa1900C4166dEeed0C11cC10669D36, 0, 1, NO_ACTION, NO_ACTION, false))
		);

		// SUSHI-V3 SUSHI-WETH/3000
		calls[2] = abi.encodeCall(
			sushiV3Adapter.sushiV3Swap,
			(pack(0x87C7056BBE6084f03304196Be51c6B90B6d85Aa2, 1, 0, NO_ACTION, NO_ACTION, false))
		);

		callAggregator(calls, FRAX, SUSHI, computeAmountIn(FRAX, FRAX_ETH_FEED, ethAmount));
	}

	function testUniswapV2() public {
		// FRAX -> WETH -> WBTC -> WETH -> SUSHI

		bytes[] memory calls = new bytes[](4);

		// FRAX-V2 FRAX-WETH
		calls[0] = abi.encodeCall(
			fraxAdapter.fraxV2Swap,
			(pack(0x31351Bf3fba544863FBff44DDC27bA880916A199, 0, 1, NO_ACTION, NO_ACTION, false))
		);

		// UNI-V2 WBTC-WETH
		calls[1] = abi.encodeCall(
			uniV2Adapter.uniswapV2Swap,
			(pack(0xBb2b8038a1640196FbE3e38816F3e67Cba72D940, 1, 0, NO_ACTION, NO_ACTION, false))
		);

		// PANCAKE-V2 WBTC-WETH
		calls[2] = abi.encodeCall(
			pancakeV2Adapter.pancakeV2Swap,
			(pack(0x4AB6702B3Ed3877e9b1f203f90cbEF13d663B0e8, 0, 1, NO_ACTION, NO_ACTION, false))
		);

		// SUSHI-V2 SUSHI-WETH
		calls[3] = abi.encodeCall(
			sushiV2Adapter.sushiV2Swap,
			(pack(0x795065dCc9f64b5614C407a6EFDC400DA6221FB0, 1, 0, NO_ACTION, NO_ACTION, false))
		);

		callAggregator(calls, FRAX, SUSHI, computeAmountIn(FRAX, FRAX_ETH_FEED, ethAmount));
	}

	function testBalancerV2() public {
		// WBTC -> WETH -> BAL

		bytes[] memory calls = new bytes[](2);

		// BAL-V2 B-50WBTC-50WETH
		calls[0] = abi.encodeCall(
			balancerAdapter.balancerV2Swap,
			(pack(0xA6F548DF93de924d73be7D25dC02554c6bD66dB5, 0, 1, NO_ACTION, NO_ACTION, false))
		);

		// BAL-V2 B-80BAL-20WETH
		calls[1] = abi.encodeCall(
			balancerAdapter.balancerV2Swap,
			(pack(0x5c6Ee304399DBdB9C8Ef030aB642B10820DB8F56, 1, 0, NO_ACTION, NO_ACTION, false))
		);

		callAggregator(calls, WBTC, BAL, computeAmountIn(WBTC, BTC_ETH_FEED, ethAmount));
	}

	function testCurve() public {
		// ETH -> stETH -> wstETH -> sfrxETH -> frxETH

		bytes[] memory calls = new bytes[](4);

		// Curve stETH-ETH
		calls[0] = abi.encodeCall(
			curveAdapter.curveSwap,
			(pack(0xDC24316b9AE028F1497c275EB9192a3Ea0f67022, 0, 1, NO_ACTION, NO_ACTION, false))
		);

		// wstETH
		calls[1] = abi.encodeCall(
			stethWrapper.wrapWSTETH,
			(pack(WSTETH.toAddress(), 1, 2, NO_ACTION, NO_ACTION, false))
		);

		// Curve TryLSD
		calls[2] = abi.encodeCall(
			curveAdapter.curveSwap,
			(pack(0x2570f1bD5D2735314FC102eb12Fc1aFe9e6E7193, 0, 2, NO_ACTION, NO_ACTION, false))
		);

		// frxETH
		calls[3] = abi.encodeCall(
			frxethWrapper.unwrapSFRXETH,
			(pack(SFRXETH.toAddress(), 2, 1, NO_ACTION, NO_ACTION, false))
		);

		callAggregator(calls, ETH, FRXETH, ethAmount);
	}

	function testCurveAavePool() public {
		// USDC -> aUSDC -> aDAI -> DAI

		uint256 amountIn = computeAmountIn(USDC, USDC_ETH_FEED, ethAmount);

		uint256 snapshot = vm.snapshot();

		bytes[] memory calls = new bytes[](3);

		// Aave aUSDC
		calls[0] = abi.encodeCall(
			aTokenWrapper.wrapAToken,
			(pack(0xBcca60bB61934080951369a648Fb03DF4F96263C, 0, 1, NO_ACTION, NO_ACTION, false))
		);

		// Curve a3CRV
		calls[1] = abi.encodeCall(
			curveAdapter.curveSwap,
			(pack(0xDeBF20617708857ebe4F679508E7b7863a8A8EeE, 1, 0, NO_ACTION, NO_ACTION, false))
		);

		// Aave aDAI
		calls[2] = abi.encodeCall(
			aTokenWrapper.unwrapAToken,
			(pack(0x028171bCA77440897B824Ca71D1c56caC55b68A3, 1, 0, NO_ACTION, NO_ACTION, false))
		);

		callAggregator(calls, USDC, DAI, amountIn);

		vm.revertTo(snapshot);

		// swap by executing exchange_underlying()

		calls = new bytes[](1);

		// Curve a3CRV
		calls[0] = abi.encodeCall(
			curveAdapter.curveSwap,
			(pack(0xDeBF20617708857ebe4F679508E7b7863a8A8EeE, 1, 0, NO_ACTION, NO_ACTION, true))
		);

		callAggregator(calls, USDC, DAI, amountIn);
	}

	function testDODO() public {
		// DAI -> USDT -> DODO

		bytes[] memory calls = new bytes[](2);

		// DODO-V2 DAI-USDT DSP
		calls[0] = abi.encodeCall(
			dodoV2Adapter.dodoV2Swap,
			(pack(0x3058EF90929cb8180174D74C507176ccA6835D73, 0, 1, NO_ACTION, NO_ACTION, false))
		);

		// DODO-V1 DODO-USDT
		calls[1] = abi.encodeCall(
			dodoV1Adapter.dodoV1Swap,
			(pack(0x8876819535b48b551C9e97EBc07332C7482b4b2d, 1, 0, NO_ACTION, NO_ACTION, false))
		);

		callAggregator(calls, DAI, DODO, computeAmountIn(DAI, DAI_ETH_FEED, ethAmount));
	}

	function callAggregator(
		bytes[] memory calls,
		Currency currencyIn,
		Currency currencyOut,
		uint256 amountIn
	) internal {
		deal(currencyIn, address(this), amountIn);

		uint256 value;
		if (currencyIn.isNative()) value = amountIn;
		else currencyIn.approve(address(router), amountIn);

		uint256 amountOut = router.aggregate{value: value}(
			calls,
			address(this),
			currencyIn,
			currencyOut,
			amountIn,
			0
		);

		assertGt(amountOut, 0);
		assertEq(getBalance(currencyOut, address(this)), amountOut);
	}
}
