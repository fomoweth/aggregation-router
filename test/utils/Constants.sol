// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency} from "src/types/Currency.sol";

abstract contract Constants {
	uint256 constant FORK_BLOCK = 19378914;

	address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
	address constant BTC = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
	address constant USD = 0x0000000000000000000000000000000000000348;

	Currency constant WETH = Currency.wrap(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
	Currency constant WBTC = Currency.wrap(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
	Currency constant FXS = Currency.wrap(0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0);
	Currency constant SUSHI = Currency.wrap(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);

	Currency constant DAI = Currency.wrap(0x6B175474E89094C44Da98b954EedeAC495271d0F);
	Currency constant FRAX = Currency.wrap(0x853d955aCEf822Db058eb8505911ED77F175b99e);
	Currency constant USDC = Currency.wrap(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
	Currency constant USDT = Currency.wrap(0xdAC17F958D2ee523a2206206994597C13D831ec7);

	address constant ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
	address constant USDC_ETH_FEED = 0x986b5E1e1755e3C2440e960477f25201B0a8bbD4;
	address constant BTC_ETH_FEED = 0xdeb288F737066589598e9214E782fa5A8eD689e8;
	address constant FRAX_ETH_FEED = 0x14d04Fff8D21bd62987a5cE9ce543d2F1edF5D3E;
	address constant FRAX_FXS_FEED = 0x03B59Bd1c8B9F6C265bA0c3421923B93f15036Fa;
	address constant SUSHI_ETH_FEED = 0xe572CeF69f43c2E488b33924AF04BDacE19079cf;

	uint8 constant NO_ACTION = 0;
	uint8 constant WRAP_ETH = 1;
	uint8 constant UNWRAP_ETH = 2;

	uint256 constant UNISWAP_V3_ID = 0;
	uint256 constant UNISWAP_V2_ID = 1;
	uint256 constant SUSHI_V3_ID = 2;
	uint256 constant SUSHI_V2_ID = 3;
	uint256 constant FRAX_V2_ID = 4;
	uint256 constant PANCAKE_V3_ID = 5;
	uint256 constant PANCAKE_V2_ID = 6;
}
