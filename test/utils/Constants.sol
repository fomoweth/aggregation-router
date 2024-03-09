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
	Currency constant DODO = Currency.wrap(0x43Dfc4159D86F3A37A5A4B3D4580b888ad7d4DDd);
	Currency constant FXS = Currency.wrap(0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0);
	Currency constant NEAR = Currency.wrap(0x85F17Cf997934a597031b2E18a9aB6ebD4B9f6a4);
	Currency constant SUSHI = Currency.wrap(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);

	Currency constant DAI = Currency.wrap(0x6B175474E89094C44Da98b954EedeAC495271d0F);
	Currency constant FRAX = Currency.wrap(0x853d955aCEf822Db058eb8505911ED77F175b99e);
	Currency constant USDC = Currency.wrap(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
	Currency constant USDT = Currency.wrap(0xdAC17F958D2ee523a2206206994597C13D831ec7);

	address constant ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
	address constant USDC_ETH_FEED = 0x986b5E1e1755e3C2440e960477f25201B0a8bbD4;
	address constant USDT_ETH_FEED = 0xEe9F2375b4bdF6387aa8265dD4FB8F16512A1d46;
	address constant BTC_ETH_FEED = 0xdeb288F737066589598e9214E782fa5A8eD689e8;
	address constant FRAX_ETH_FEED = 0x14d04Fff8D21bd62987a5cE9ce543d2F1edF5D3E;
	address constant FRAX_FXS_FEED = 0x03B59Bd1c8B9F6C265bA0c3421923B93f15036Fa;
	address constant SUSHI_ETH_FEED = 0xe572CeF69f43c2E488b33924AF04BDacE19079cf;

	address constant UNI_V3_WBTC_ETH_3000_POOL = 0xCBCdF9626bC03E24f779434178A73a0B4bad62eD;
	address constant UNI_V2_WBTC_ETH_POOL = 0xBb2b8038a1640196FbE3e38816F3e67Cba72D940;

	address constant SUSHI_V3_SUSHI_ETH_3000_POOL = 0x87C7056BBE6084f03304196Be51c6B90B6d85Aa2;
	address constant SUSHI_V2_SUSHI_ETH_POOL = 0x795065dCc9f64b5614C407a6EFDC400DA6221FB0;

	address constant PANCAKE_V3_ETH_USDT_500_POOL = 0x6CA298D2983aB03Aa1dA7679389D955A4eFEE15C;
	address constant PANCAKE_V2_WBTC_ETH_POOL = 0x4AB6702B3Ed3877e9b1f203f90cbEF13d663B0e8;

	address constant FRAX_V2_FRAX_ETH_POOL = 0x31351Bf3fba544863FBff44DDC27bA880916A199;

	address constant TRICRYPTO_POOL = 0x80466c64868E1ab14a1Ddf27A676C3fcBE638Fe5;

	address constant DODO_V2_WETH_NEAR_DVM_POOL = 0x983dfBa1c0724786598Af0E63a9a6f94aAbd24A1;
	address constant DODO_V2_DAI_USDT_DSP_POOL = 0x3058EF90929cb8180174D74C507176ccA6835D73;
	address constant DODO_V1_WETH_USDC_POOL = 0x75c23271661d9d143DCb617222BC4BEc783eff34;
	address constant DODO_V1_DODO_USDT_POOL = 0x8876819535b48b551C9e97EBc07332C7482b4b2d;
	address constant DODO_V3_WETH_WSTETH_POOL = 0x7bcE750a34F69D33AC785C04fBc87d6455C19453;

	address constant USDC_MASTER_MINTER = 0xE982615d461DD5cD06575BbeA87624fda4e3de17;

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
	uint256 constant CURVE_ID = 7;
	uint256 constant DODO_V2_ID = 8;
	uint256 constant DODO_V1_ID = 9;
	uint256 constant FRXETH_WRAPPER_ID = 10;
	uint256 constant STETH_WRAPPER_ID = 11;
}
