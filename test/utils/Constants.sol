// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency} from "src/types/Currency.sol";

abstract contract Constants {
	address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
	address constant BTC = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
	address constant USD = 0x0000000000000000000000000000000000000348;

	Currency constant WETH = Currency.wrap(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
	Currency constant WBTC = Currency.wrap(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
	Currency constant USDC = Currency.wrap(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

	address constant ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
	address constant BTC_ETH_FEED = 0xdeb288F737066589598e9214E782fa5A8eD689e8;

	uint8 constant NO_ACTION = 0;
	uint8 constant WRAP_ETH = 1;
	uint8 constant UNWRAP_ETH = 2;

	uint256 constant UNISWAP_V3_ID = 0;
}
