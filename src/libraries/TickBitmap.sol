// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BitMath} from "./BitMath.sol";
import {SafeCast} from "./SafeCast.sol";
import {TickMath} from "./TickMath.sol";

/// @title TickBitmap
/// @dev implementation from: https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/TickBitmap.sol

library TickBitmap {
	function nextInitializedTickWithinOneWord(
		address pool,
		int24 tick,
		int24 tickSpacing,
		bool lte
	) internal view returns (int24 tickNext, bool initialized) {
		unchecked {
			int24 compressed = tick / tickSpacing;
			if (tick < 0 && tick % tickSpacing != 0) --compressed;

			if (lte) {
				(int16 wordPos, uint8 bitPos) = position(compressed);
				uint256 mask = (1 << bitPos) - 1 + (1 << bitPos);
				uint256 masked = tickBitmap(pool, wordPos) & mask;

				initialized = masked != 0;

				tickNext = initialized
					? (compressed - int24(uint24(bitPos - BitMath.mostSignificantBit(masked)))) * tickSpacing
					: (compressed - int24(uint24(bitPos))) * tickSpacing;
			} else {
				(int16 wordPos, uint8 bitPos) = position(compressed + 1);
				uint256 mask = ~((1 << bitPos) - 1);
				uint256 masked = tickBitmap(pool, wordPos) & mask;

				initialized = masked != 0;

				tickNext = initialized
					? (compressed + 1 + int24(uint24(BitMath.leastSignificantBit(masked) - bitPos))) *
						tickSpacing
					: (compressed + 1 + int24(uint24(type(uint8).max - bitPos))) * tickSpacing;
			}
		}
	}

	function tickBitmap(address pool, int16 wordPos) private view returns (uint256 bitmap) {
		assembly ("memory-safe") {
			let ptr := mload(0x40)

			mstore(ptr, 0x5339c29600000000000000000000000000000000000000000000000000000000)
			mstore(add(ptr, 0x04), wordPos)

			if iszero(staticcall(gas(), pool, ptr, 0x24, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			bitmap := mload(0x00)
		}
	}

	function position(int24 tick) private pure returns (int16 wordPos, uint8 bitPos) {
		unchecked {
			wordPos = int16(tick >> 8);
			bitPos = uint8(int8(tick % 256));
		}
	}
}
