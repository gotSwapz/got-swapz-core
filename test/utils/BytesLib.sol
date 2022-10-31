// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

library BytesLib {
	function toBytes32(bytes memory input, uint256 offset)
		internal
		pure
		returns (bytes32 output)
	{
		for (uint256 i; i < 32; ++i) {
			output |= bytes32(input[offset + i] & 0xFF) >> (i * 8);
		}
	}

	function toBytes32Array(bytes memory input)
		internal
		pure
		returns (bytes32[] memory)
	{
		uint256 size = input.length / 32;

		bytes32[] memory output = new bytes32[](size);

		for (uint256 i; i < size; ++i) {
			output[i] = toBytes32(input, 32 * i);
		}

		return output;
	}
}
