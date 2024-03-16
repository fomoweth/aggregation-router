// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAggregationRouter} from "src/interfaces/IAggregationRouter.sol";
import {Errors} from "src/libraries/Errors.sol";
import {Currency, CurrencyLibrary} from "src/types/Currency.sol";
import {Context} from "@openzeppelin/utils/Context.sol";

/// @title AggregationRouter

contract AggregationRouter is IAggregationRouter, Context {
	using CurrencyLibrary for Currency;

	error InvalidSelector(bytes4 selector);

	address private constant UNISWAP_V3_ADAPTER = 0xB2eCeBDE04C3DCCDFbe24EBB4386B7424fD1dcE1;
	address private constant UNISWAP_V2_ADAPTER = 0x945F1f1E4EAeB05a04AFF98de80ee045156932a7;
	address private constant SUSHI_V3_ADAPTER = 0x273bAA48A56608E942D0a033Ff70b5278feA5935;
	address private constant SUSHI_V2_ADAPTER = 0xbBCDA9E3c1897D9Dd202736592dec44954F60C82;
	address private constant PANCAKE_V3_ADAPTER = 0x4c3a138163eFA2Ede9BCDE835a94F4f4d9E52A76;
	address private constant PANCAKE_V2_ADAPTER = 0xDCC8f00390b0F667cCc905Dd8B1E70937245267d;
	address private constant FRAXSWAP_V2_ADAPTER = 0xcf4c0fA8d2a97d56Daa23CB07c1A47f4a94721d9;
	address private constant BALANCER_V2_ADAPTER = 0xD41081112e6B1ee176E34728ABB10241d03824c3;
	address private constant CURVE_ADAPTER = 0xa2b2936353F9f9a2ebDc3258714581aCA16E0e18;
	address private constant DODO_V2_ADAPTER = 0xc3CA53d50636c5Ec6f25F5775BF1954671cba183;
	address private constant DODO_V1_ADAPTER = 0xb7a2ad0007B71ecc4F3E76A952F1116aa7AAaBE2;
	address private constant FRXETH_WRAPPER = 0x15399DCC4d61206c6C55f0223F302F00E751Ef89;
	address private constant STETH_WRAPPER = 0x41A0d6641e9cd7a699715e11875132F4E042453A;
	address private constant ATOKEN_WRAPPER = 0xCF2A87Fe7094abfc8063F9a524bc20Cd101a73c8;
	address private constant CTOKEN_WRAPPER = 0x3D7780FF72801bd6e116c3C3Ccf637118771A39A;

	function aggregate(
		bytes[] calldata calls,
		address recipient,
		Currency currencyIn,
		Currency currencyOut,
		uint256 amountIn,
		uint256 amountOutMin
	) external payable returns (uint256 amountOut) {
		if (recipient == address(0)) revert Errors.ZeroAddress();
		if (amountIn == 0) revert Errors.InsufficientAmountIn();

		currencyIn.transferFrom(_msgSender(), address(this), amountIn);

		uint256 length = calls.length;
		uint256 i;

		while (i < length) {
			dispatch(calls[i]);

			unchecked {
				i = i + 1;
			}
		}

		if ((amountOut = currencyOut.balanceOfSelf()) < amountOutMin) {
			revert Errors.InsufficientAmountOut();
		}

		currencyOut.transfer(recipient, amountOut);
	}

	function dispatch(bytes calldata call) internal returns (bytes memory returndata) {
		if (call.length == 0) revert Errors.ZeroBytes();

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			calldatacopy(ptr, call.offset, call.length)

			if iszero(delegatecall(gas(), address(), ptr, call.length, 0x00, 0x00)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			mstore(0x40, add(returndata, add(returndatasize(), 0x20)))
			mstore(returndata, returndatasize())
			returndatacopy(add(returndata, 0x20), 0x00, returndatasize())
		}
	}

	fallback() external payable {
		bytes4 selector = msg.sig;
		address adapter;

		assembly ("memory-safe") {
			function map(sig) -> imp {
				if lt(sig, 0x355672eb) {
					if lt(sig, 0x1f99f749) {
						switch sig
						case 0x00befae3 {
							imp := ATOKEN_WRAPPER // wrapAToken(bytes32)
						}
						case 0x04addc5c {
							imp := FRXETH_WRAPPER // unwrapSFRXETH(bytes32)
						}
						case 0x07aa7eb5 {
							imp := UNISWAP_V2_ADAPTER // uniswapV2Swap(bytes32)
						}
						case 0x07af82a0 {
							imp := PANCAKE_V2_ADAPTER // pancakeV2Swap(bytes32)
						}
						case 0x0c3896b8 {
							imp := STETH_WRAPPER // unwrapWSTETH(bytes32)
						}
						leave
					}
					switch sig
					case 0x1f99f749 {
						imp := FRAXSWAP_V2_ADAPTER // fraxV2Swap(bytes32)
					}
					case 0x23a69e75 {
						imp := PANCAKE_V3_ADAPTER // pancakeV3SwapCallback(int256,int256,bytes)
					}
					case 0x2707a06c {
						imp := STETH_WRAPPER // wrapWSTETH(bytes32)
					}
					case 0x2d66d91f {
						imp := FRXETH_WRAPPER // wrapSFRXETH(bytes32)
					}
					case 0x3395962c {
						imp := SUSHI_V3_ADAPTER // sushiV3Swap(bytes32)
					}
					leave
				}

				if lt(sig, 0xf1553d53) {
					if lt(sig, 0x85abd8bb) {
						switch sig
						case 0x355672eb {
							imp := FRXETH_WRAPPER // wrapFRXETH(bytes32)
						}
						case 0x3d36c8c0 {
							imp := SUSHI_V2_ADAPTER // sushiV2Swap(bytes32)
						}
						case 0x617c7f56 {
							imp := CTOKEN_WRAPPER // unwrapCToken(bytes32)
						}
						case 0x648d8619 {
							imp := ATOKEN_WRAPPER // unwrapAToken(bytes32)
						}
						case 0x75c033fa {
							imp := UNISWAP_V3_ADAPTER // uniswapV3Swap(bytes32)
						}
						leave
					}

					switch sig
					case 0x85abd8bb {
						imp := DODO_V1_ADAPTER // dodoV1Swap(bytes32)
					}
					case 0x89d0b46b {
						imp := STETH_WRAPPER // wrapSTETH(bytes32)
					}
					case 0x9d6a221b {
						imp := BALANCER_V2_ADAPTER // balancerV2Swap(bytes32)
					}
					case 0xbc6b4e64 {
						imp := CTOKEN_WRAPPER // wrapCToken(bytes32)
					}
					case 0xe9fd0ca0 {
						imp := DODO_V2_ADAPTER // dodoV2Swap(bytes32)
					}
					leave
				}

				switch sig
				case 0xf1553d53 {
					imp := CURVE_ADAPTER // curveSwap(bytes32)
				}
				case 0xf78144f4 {
					imp := PANCAKE_V3_ADAPTER // pancakeV3Swap(bytes32)
				}
				case 0xfa461e33 {
					imp := UNISWAP_V3_ADAPTER // uniswapV3SwapCallback(int256,int256,bytes)
				}
				leave
			}

			adapter := map(shr(224, selector))
		}

		if (adapter == address(0)) revert InvalidSelector(selector);

		assembly ("memory-safe") {
			let ptr := mload(0x40)

			calldatacopy(ptr, 0x00, calldatasize())

			let success := delegatecall(gas(), adapter, ptr, calldatasize(), 0x00, 0x00)

			returndatacopy(ptr, 0x00, returndatasize())

			switch success
			case 0x00 {
				revert(ptr, returndatasize())
			}
			default {
				return(ptr, returndatasize())
			}
		}
	}

	receive() external payable {}
}
