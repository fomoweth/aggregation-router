// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title FullMath
/// @notice Facilitates multiplication and division that can have overflow of an intermediate value without any loss of precision
/// @dev implementation from: https://github.com/Uniswap/v4-core/blob/main/src/libraries/FullMath.sol

library FullMath {
	uint256 internal constant MAX_UINT256 = 2 ** 256 - 1;

	function divRoundingUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
		assembly ("memory-safe") {
			z := add(div(x, y), gt(mod(x, y), 0))
		}
	}

	function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 z) {
		unchecked {
			uint256 prod0;
			uint256 prod1;

			assembly ("memory-safe") {
				let mm := mulmod(x, y, not(0))
				prod0 := mul(x, y)
				prod1 := sub(sub(mm, prod0), lt(mm, prod0))
			}

			require(denominator > prod1);

			if (prod1 == 0) {
				assembly ("memory-safe") {
					z := div(prod0, denominator)
				}

				return z;
			}

			uint256 remainder;
			assembly ("memory-safe") {
				remainder := mulmod(x, y, denominator)
			}

			assembly ("memory-safe") {
				prod1 := sub(prod1, gt(remainder, prod0))
				prod0 := sub(prod0, remainder)
			}

			uint256 twos = (0 - denominator) & denominator;

			assembly ("memory-safe") {
				denominator := div(denominator, twos)
			}

			assembly ("memory-safe") {
				prod0 := div(prod0, twos)
			}

			assembly ("memory-safe") {
				twos := add(div(sub(0, twos), twos), 1)
			}

			prod0 |= prod1 * twos;

			uint256 inv = (3 * denominator) ^ 2;

			inv *= 2 - denominator * inv;
			inv *= 2 - denominator * inv;
			inv *= 2 - denominator * inv;
			inv *= 2 - denominator * inv;
			inv *= 2 - denominator * inv;
			inv *= 2 - denominator * inv;

			z = prod0 * inv;
		}
	}

	function mulDivRoundingUp(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 z) {
		unchecked {
			z = mulDiv(x, y, denominator);

			if (mulmod(x, y, denominator) > 0) {
				require(z < MAX_UINT256);
				++z;
			}
		}
	}
}
