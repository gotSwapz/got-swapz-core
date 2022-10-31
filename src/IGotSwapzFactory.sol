// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @title IGotSwapzFactory
/// @notice Minimal interface of the GotSwapzFactory contract, containing only the `requestRandomWords` function.
interface IGotSwapzFactory {
	/// @notice Request random words to Chainlink.
	/// @param numWords - Number of words requested.
	/// @return requestId - VRF request ID.
	function requestRandomWords(uint32 numWords)
		external
		returns (uint256 requestId);
}
