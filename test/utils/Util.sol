// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

/* solhint-disable */

contract Util {
	/**
	 * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Strings.sol
	 * @dev Converts a `uint256` to its ASCII `string` decimal representation.
	 */
	function toString(uint256 value) internal pure returns (string memory) {
		// Inspired by OraclizeAPI's implementation - MIT licence
		// https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

		if (value == 0) {
			return "0";
		}
		uint256 temp = value;
		uint256 digits;
		while (temp != 0) {
			digits++;
			temp /= 10;
		}
		bytes memory buffer = new bytes(digits);
		while (value != 0) {
			digits -= 1;
			buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
			value /= 10;
		}
		return string(buffer);
	}

	function getWords(uint256 requestId, uint256 numWords)
		public
		pure
		returns (uint256[] memory)
	{
		uint256[] memory words = new uint256[](numWords);
		for (uint256 i = 0; i < numWords; ++i) {
			words[i] = uint256(keccak256(abi.encode(requestId, i)));
		}
		return words;
	}

	function uint8ArrayToUint256Array(uint8[] memory input)
		internal
		pure
		returns (uint256[] memory)
	{
		uint256[] memory output = new uint256[](input.length);
		for (uint256 i; i < input.length; ++i) {
			output[i] = input[i];
		}
		return output;
	}

	function bytes32ToAddress(bytes32 input) internal pure returns (address) {
		return address(uint160(uint256(input)));
	}
}
