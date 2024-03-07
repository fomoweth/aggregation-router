// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency} from "src/types/Currency.sol";

abstract contract Constants {
	uint256 constant FORK_BLOCK = 19378914;

	address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
	address constant BTC = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
	address constant USD = 0x0000000000000000000000000000000000000348;

	address constant ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
	address constant USDC_ETH_FEED = 0x986b5E1e1755e3C2440e960477f25201B0a8bbD4;
	address constant BTC_ETH_FEED = 0xdeb288F737066589598e9214E782fa5A8eD689e8;
	address constant SUSHI_ETH_FEED = 0xe572CeF69f43c2E488b33924AF04BDacE19079cf;

	Currency constant WETH = Currency.wrap(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
	Currency constant WBTC = Currency.wrap(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
	Currency constant USDC = Currency.wrap(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
	Currency constant USDT = Currency.wrap(0xdAC17F958D2ee523a2206206994597C13D831ec7);
	Currency constant SUSHI = Currency.wrap(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);

	uint8 constant NO_ACTION = 0;
	uint8 constant WRAP_ETH = 1;
	uint8 constant UNWRAP_ETH = 2;

	uint256 constant UNISWAP_V3_ID = 0;
	uint256 constant UNISWAP_V2_ID = 1;
	uint256 constant SUSHI_V3_ID = 2;
	uint256 constant SUSHI_V2_ID = 3;
}
