// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Currency} from "src/types/Currency.sol";

abstract contract Constants {
	uint256 constant FORK_BLOCK = 19378914;

	Currency constant ETH = Currency.wrap(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
	Currency constant WETH = Currency.wrap(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
	Currency constant STETH = Currency.wrap(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
	Currency constant WSTETH = Currency.wrap(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
	Currency constant FRXETH = Currency.wrap(0x5E8422345238F34275888049021821E8E08CAa1f);
	Currency constant SFRXETH = Currency.wrap(0xac3E018457B222d93114458476f3E3416Abbe38F);
	Currency constant WBTC = Currency.wrap(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
	Currency constant BAL = Currency.wrap(0xba100000625a3754423978a60c9317c58a424e3D);
	Currency constant DODO = Currency.wrap(0x43Dfc4159D86F3A37A5A4B3D4580b888ad7d4DDd);
	Currency constant NEAR = Currency.wrap(0x85F17Cf997934a597031b2E18a9aB6ebD4B9f6a4);
	Currency constant SUSHI = Currency.wrap(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);

	Currency constant DAI = Currency.wrap(0x6B175474E89094C44Da98b954EedeAC495271d0F);
	Currency constant FRAX = Currency.wrap(0x853d955aCEf822Db058eb8505911ED77F175b99e);
	Currency constant USDC = Currency.wrap(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
	Currency constant USDT = Currency.wrap(0xdAC17F958D2ee523a2206206994597C13D831ec7);

	// ChainLink Aggregators
	address constant ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
	address constant BTC_ETH_FEED = 0xdeb288F737066589598e9214E782fa5A8eD689e8;
	address constant USDC_ETH_FEED = 0x986b5E1e1755e3C2440e960477f25201B0a8bbD4;
	address constant USDT_ETH_FEED = 0xEe9F2375b4bdF6387aa8265dD4FB8F16512A1d46;
	address constant DAI_ETH_FEED = 0x773616E4d11A78F511299002da57A0a94577F1f4;
	address constant FRAX_ETH_FEED = 0x14d04Fff8D21bd62987a5cE9ce543d2F1edF5D3E;
	address constant SUSHI_ETH_FEED = 0xe572CeF69f43c2E488b33924AF04BDacE19079cf;

	// AAVE
	address constant POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
	address constant LENDING_POOL = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;

	// Compound
	address constant COMPTROLLER = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
	Currency constant CETH = Currency.wrap(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5);

	address constant USDC_MASTER_MINTER = 0xE982615d461DD5cD06575BbeA87624fda4e3de17;

	uint8 constant NO_ACTION = 0;
	uint8 constant WRAP_ETH = 1;
	uint8 constant UNWRAP_WETH = 2;

	uint256 constant UNISWAP_V3_ID = 0;
	uint256 constant UNISWAP_V2_ID = 1;
	uint256 constant SUSHI_V3_ID = 2;
	uint256 constant SUSHI_V2_ID = 3;
	uint256 constant PANCAKE_V3_ID = 4;
	uint256 constant PANCAKE_V2_ID = 5;
	uint256 constant FRAX_V2_ID = 6;
	uint256 constant BALANCER_V2_ID = 7;
	uint256 constant CURVE_ID = 8;
	uint256 constant DODO_V2_ID = 9;
	uint256 constant DODO_V1_ID = 10;
	uint256 constant FRXETH_WRAPPER_ID = 11;
	uint256 constant STETH_WRAPPER_ID = 12;
	uint256 constant ATOKEN_WRAPPER_ID = 13;
	uint256 constant CTOKEN_WRAPPER_ID = 14;
}
