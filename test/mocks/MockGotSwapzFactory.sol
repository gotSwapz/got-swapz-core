// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

contract MockGotSwapzFactory {
	uint256 private _requestId;

	constructor(uint256 requestId_) {
		_requestId = requestId_;
	}

	receive() external payable {}

	function requestRandomWords(uint32 numWords)
		external
		returns (uint256 requestId)
	{
		requestId = _requestId;
	}
}
