# Aggregation Router

The Aggregation Router is a swap router that can perform trades across multiple DeFi protocols in a single transaction.

It can be aggregated with:

- [Uniswap V3 pools](https://github.com/fomoweth/aggregation-router/blob/main/src/adapters/UniswapV3Adapter.sol)
- [Uniswap V2 pools](https://github.com/fomoweth/aggregation-router/blob/main/src/adapters/UniswapV2Adapter.sol)
- [Balancer V2 pools](https://github.com/fomoweth/aggregation-router/blob/main/src/adapters/BalancerV2Adapter.sol)
- [Curve pools](https://github.com/fomoweth/aggregation-router/blob/main/src/adapters/CurveAdapter.sol)
- [DODO V2 pools](https://github.com/fomoweth/aggregation-router/blob/main/src/adapters/DoDoV2Adapter.sol)
- [DODO V1 pools](https://github.com/fomoweth/aggregation-router/blob/main/src/adapters/DoDoV1Adapter.sol)
- [FraxSwap V2 pools](https://github.com/fomoweth/aggregation-router/blob/main/src/adapters/FraxSwapV2Adapter.sol)
- [PancakeSwap V3 pools](https://github.com/fomoweth/aggregation-router/blob/main/src/adapters/PancakeV3Adapter.sol)
- [PancakeSwap V2 pools](https://github.com/fomoweth/aggregation-router/blob/main/src/adapters/PancakeV2Adapter.sol)
- [SushiSwap V3 pools](https://github.com/fomoweth/aggregation-router/blob/main/src/adapters/SushiV3Adapter.sol)
- [SushiSwap V2 pools](https://github.com/fomoweth/aggregation-router/blob/main/src/adapters/SushiV2Adapter.sol)
- [Aave V2 & V3 aTokens](https://github.com/fomoweth/aggregation-router/blob/main/src/adapters/wrappers/ATokenWrapper.sol)
- [Compound cTokens](https://github.com/fomoweth/aggregation-router/blob/main/src/adapters/wrappers/CTokenWrapper.sol)
- [Frax: frxETH & sfrxETH](https://github.com/fomoweth/aggregation-router/blob/main/src/adapters/wrappers/FRXETHWrapper.sol)
- [Lido: stETH & wstETH](https://github.com/fomoweth/aggregation-router/blob/main/src/adapters/wrappers/STETHWrapper.sol)

## Contract Overview

### AggregationRouter

The [`AggregationRouter`](https://github.com/fomoweth/aggregation-router/blob/main/src/AggregationRouter.sol) contract was inspired by [Synthetix: CoreRouter](https://etherscan.io/address/0xaf476d7817105437aed79a86e802b79d4b1c473f#code). The constant address variables in the [`AggregationRouter`](https://github.com/fomoweth/aggregation-router/blob/main/src/AggregationRouter.sol) were obtained via [CREATE3](https://github.com/transmissions11/solmate/blob/main/src/utils/CREATE3.sol). **These address variables must be updated before the deployment.**

[`aggregate`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/AggregationRouter.sol#L32)

```solidity
function aggregate(
	bytes[] calldata calls,
	address recipient,
	Currency currencyIn,
	Currency currencyOut,
	uint256 amountIn,
	uint256 amountOutMin
) external payable returns (uint256 amountOut);
```

Performs swaps, delegating all encoded calls to the adapters mapped by function selectors.

#### Encoding calls

```
			┌─────────────────┬──────────────┐
bytes call: │ bytes4 selector │ bytes32 path │
			└─────────────────┴──────────────┘
```

#### Path

`Path` is the encoding of 5 parameters and optional flags (up to 8).

| Name      | Type      | Description                                            |
| :-------- | :-------- | :----------------------------------------------------- |
| `pool`    | `address` | The address of the `pool`                              |
| `i`       | `uint8`   | The index of currency to be swapped from               |
| `j`       | `uint8`   | The index of currency to be swapped for                |
| `wrapIn`  | `uint8`   | The `wrapping command` for currency to be swapped from |
| `wrapOut` | `uint8`   | The `wrapping command` of currency to be swapped for   |

#### Wrapping Command

| Value | Description                    |
| :---- | :----------------------------- |
| `0`   | No action                      |
| `1`   | Wrap native currency           |
| `2`   | Unwrap wrapped native currency |

### Adapters

[`query`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/BaseAdapter.sol#L25)

```solidity
function query(
	Currency currencyIn,
	Currency currencyOut,
	uint256 amountIn
) external view returns (bytes32 path, uint256 amountOut);
```

Returns the encoded path and expected amount of currency-out to be received in exchange of currency-in.

[`quote`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/BaseAdapter.sol#L35)

```solidity
function quote(bytes32 path, uint256 amountIn) external view returns (uint256 amountOut);
```

Returns expected amount of currency-out to be received in exchange of currency-in.

### UniswapV3Adapter

[`uniswapV3Swap`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/UniswapV3Adapter.sol#L55)

```solidity
function uniswapV3Swap(bytes32 path) external payable returns (uint256);
```

Performs a swap on Uniswap V3 pool. Wraps and unwraps both currency in and out if requested.

[`uniswapV3SwapCallback`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/UniswapV3Adapter.sol#L24)

```solidity
function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
```

A callback executed by Uniswap V3 pool after executing a swap.

### UniswapV2Adapter

[`uniswapV2Swap`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/UniswapV2Adapter.sol#L21)

```solidity
function uniswapV2Swap(bytes32 path) external payable returns (uint256);
```

Performs a swap on Uniswap V2 pool. Wraps and unwraps both currency in and out if requested.

### BalancerV2Adapter

[`balancerV2Swap`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/BalancerV2Adapter.sol#L27)

```solidity
function balancerV2Swap(bytes32 path) external payable returns (uint256);
```

Performs a swap on Balancer V2 pool. Wraps and unwraps both currency in and out if requested.

### CurveAdapter

[`curveSwap`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/CurveAdapter.sol#L22)

```solidity
function curveSwap(bytes32 path) external payable returns (uint256);
```

Performs a swap on Curve pool. Wraps and unwraps both currency in and out if requested.

### DoDoV2Adapter

[`dodoV2Swap`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/DoDoV2Adapter.sol#L24)

```solidity
function dodoV2Swap(bytes32 path) external payable returns (uint256);
```

Performs a swap on DODO V2 pool. Wraps and unwraps both currency in and out if requested.

### DoDoV1Adapter

[`dodoV1Swap`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/DoDoV1Adapter.sol#L22)

```solidity
function dodoV1Swap(bytes32 path) external payable returns (uint256);
```

Performs a swap on DODO V1 pool. Wraps and unwraps both currency in and out if requested.

### FraxSwapV2Adapter

[`fraxV2Swap`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/FraxSwapV2Adapter.sol#L21)

```solidity
function fraxV2Swap(bytes32 path) external payable returns (uint256);
```

Performs a swap on FraxSwap V2 pool. Wraps and unwraps both currency in and out if requested.

### PancakeV3Adapter

[`pancakeV3Swap`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/PancakeV3Adapter.sol#L55)

```solidity
function pancakeV3Swap(bytes32 path) external payable returns (uint256);
```

Performs a swap on PancakeSwap V3 pool. Wraps and unwraps both currency in and out if requested.

[`pancakeV3SwapCallback`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/PancakeV3Adapter.sol#L24)

```solidity
function pancakeV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
```

A callback executed by PancakeSwap V3 pool after executing a swap.

### PancakeV2Adapter

[`pancakeV2Swap`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/PancakeV2Adapter.sol#L21)

```solidity
function pancakeV2Swap(bytes32 path) external payable returns (uint256);
```

Performs a swap on PancakeSwap V2 pool. Wraps and unwraps both currency in and out if requested.

### SushiV3Adapter

[`sushiV3Swap`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/SushiV3Adapter.sol#L57)

```solidity
function sushiV3Swap(bytes32 path) external payable returns (uint256);
```

Performs a swap on SushiSwap V3 pool. Wraps and unwraps both currency in and out if requested.

[`uniswapV3SwapCallback`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/SushiV3Adapter.sol#L26)

```solidity
function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
```

A callback executed by SushiSwap V3 pool after executing a swap.

### SushiV2Adapter

[`sushiV2Swap`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/SushiV2Adapter.sol#L21)

```solidity
function sushiV2Swap(bytes32 path) external payable returns (uint256);
```

Performs a swap on SushiSwap V2 pool. Wraps and unwraps both currency in and out if requested.

### Wrappers

[`query`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/wrappers/BaseWrapper.sol#L25)

```solidity
function query(
	Currency wrapped,
	Currency underlying,
	uint256 amountIn,
	bool direction // true for wrapping and false for unwrapping
) external view returns (bytes32 path, uint256 amountOut);
```

Returns the encoded path and expected amount of currency-out to be received in exchange of currency-in.

[`quote`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/wrappers/BaseWrapper.sol#L36)

```solidity
function quote(bytes32 path, uint256 amountIn) external view returns (uint256 amountOut);
```

Returns expected amount of currency-out to be received in exchange of currency-in.

### ATokenWrapper

[`wrapAToken`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/wrappers/ATokenWrapper.sol#L29)

```solidity
function wrapAToken(bytes32 path) external payable returns (uint256);
```

Supplies the underlying currency into Aave and receives overlying aToken in return. Wraps ETH beforehand if requested.

[`unwrapAToken`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/wrappers/ATokenWrapper.sol#L33C11-L33C23)

```solidity
function unwrapAToken(bytes32 path) external payable returns (uint256);
```

Withdraws the underlying currency by redeeming aToken. Unwraps WETH afterward if requested.

### CTokenWrapper

[`wrapCToken`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/wrappers/CTokenWrapper.sol#L45)

```solidity
function wrapCToken(bytes32 path) external payable returns (uint256);
```

Supplies the underlying currency into Compound and receives overlying cToken in return. Unwraps WETH beforehand if requested.

[`unwrapCToken`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/wrappers/CTokenWrapper.sol#L49)

```solidity
function unwrapCToken(bytes32 path) external payable returns (uint256);
```

Withdraws the underlying currency by redeeming the cToken. Wraps ETH afterward if requested.

### FRXETHWrapper

[`wrapFRXETH`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/wrappers/FRXETHWrapper.sol#L30)

```solidity
function wrapFRXETH(bytes32 path) external payable returns (uint256);
```

Stakes ETH and receives frxETH in return. Unwraps WETH beforehand if requested.

[`wrapSFRXETH`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/wrappers/FRXETHWrapper.sol#L34)

```solidity
function wrapSFRXETH(bytes32 path) external payable returns (uint256);
```

Wraps frxETH and receives sfrxETH in return. Stakes ETH beforehand if requested.

[`unwrapSFRXETH`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/wrappers/FRXETHWrapper.sol#L38)

```solidity
function unwrapSFRXETH(bytes32 path) external payable returns (uint256);
```

Unwraps sfrxETH and receives frxETH in return.

### STETHWrapper

[`wrapSTETH`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/wrappers/STETHWrapper.sol#L29)

```solidity
function wrapSTETH(bytes32 path) external payable returns (uint256);
```

Stakes ETH and receives stETH in return. Unwraps WETH beforehand if requested.

[`wrapWSTETH`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/wrappers/STETHWrapper.sol#L33)

```solidity
function wrapWSTETH(bytes32 path) external payable returns (uint256);
```

Wraps stETH and receives wstETH in return. Stakes ETH beforehand if requested.

[`unwrapWSTETH`](https://github.com/fomoweth/aggregation-router/blob/7328ea759417c66ac05b2873c02729a4720225c7/src/adapters/wrappers/STETHWrapper.sol#L37)

```solidity
function unwrapWSTETH(bytes32 path) external payable returns (uint256);
```

Unwraps wstETH and receives stETH in return.

## Usage

Create `.env` file with the following content:

```text
INFURA_API_KEY=YOUR_INFURA_API_KEY
RPC_ETHEREUM="https://mainnet.infura.io/v3/${INFURA_API_KEY}"

ETHERSCAN_API_KEY=YOUR_ETHERSCAN_API_KEY
ETHERSCAN_URL="https://api.etherscan.io/api"
```

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```
