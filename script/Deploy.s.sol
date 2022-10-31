// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

/* solhint-disable */
import "forge-std/Script.sol";
import "../src/GotSwapzFactory.sol";
import "../test/mocks/MockVRFCoordinatorV2.sol";

contract Deploy is Script {
	uint256 constant POLYGON_CHAIN_ID = 137;
	uint256 constant MUMBAI_CHAIN_ID = 80001;
	uint256 constant ANVIL_CHAIN_ID = 31337;

	uint256 constant serviceFee = 150; // 1.5%
	// Replace with owner address❗
	address constant owner = address(0);

	uint64 subscriptionId;
	address vrfCoordinatorAddress;
	bytes32 gasLane;

	function setUp() public {
		if (block.chainid == POLYGON_CHAIN_ID) {
			subscriptionId = 243;
			vrfCoordinatorAddress = 0xAE975071Be8F8eE67addBC1A82488F1C24858067;
			gasLane = 0xcc294a196eeeb44da2888d17c0625cc88d70d9760a69d58d853ba6581a9ab0cd;
		} else if (block.chainid == MUMBAI_CHAIN_ID) {
			subscriptionId = 2350;
			vrfCoordinatorAddress = 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed;
			gasLane = 0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;
		} else if (block.chainid == ANVIL_CHAIN_ID) {
			vm.startBroadcast();
			MockVRFCoordinatorV2 vrfCoordinator = new MockVRFCoordinatorV2();
			uint64 subId = vrfCoordinator.createSubscription();
			vrfCoordinator.fundSubscription(subId, 1_000_000 * 1e18);
			vm.stopBroadcast();
			subscriptionId = subId;
			vrfCoordinatorAddress = address(vrfCoordinator);
		} else {
			revert("Unknown chain id.");
		}
	}

	function run() public {
		if (owner == address(0)) {
			revert("Owner address is not set.");
		}

		vm.startBroadcast();
		new GotSwapzFactory(
			owner,
			serviceFee,
			subscriptionId,
			vrfCoordinatorAddress,
			gasLane
		);
		vm.stopBroadcast();
	}
}
