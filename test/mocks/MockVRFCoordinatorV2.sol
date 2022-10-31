// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { VRFCoordinatorV2Mock } from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract MockVRFCoordinatorV2 is VRFCoordinatorV2Mock {
	uint96 constant MOCK_BASE_FEE = 5e14; // 0.0005 LINK premium
	uint96 constant MOCK_GAS_PRICE_LINK = 1e9;

	constructor() VRFCoordinatorV2Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK) {}
}
