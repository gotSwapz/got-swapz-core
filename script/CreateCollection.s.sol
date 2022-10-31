// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

/* solhint-disable */
import "forge-std/Script.sol";
import "../src/GotSwapzFactory.sol";
import "../src/GotSwapzCollection.sol";

contract CreateCollection is Script {
	uint256 constant POLYGON_CHAIN_ID = 137;
	uint256 constant MUMBAI_CHAIN_ID = 80001;
	uint256 constant ANVIL_CHAIN_ID = 31337;

	address factoryAddress;
	address owner;
	string name;
	string uri;
	uint8[] packageUnits = new uint8[](6);
	uint256[] packagePrices = new uint256[](6);
	uint8[] rarity = new uint8[](10);

	function setUp() public {
		// Replace with factory address❗
		factoryAddress = 0x0000000000000000000000000000000000000000;
		// Replace with owner address❗
		owner = 0x0000000000000000000000000000000000000000;
		name = "My cool collection";
		uri = "ipfs://fake_{id}";
		packageUnits = [10, 25];
		packagePrices = [1e18, 2e18];
		rarity = [1, 2, 3, 4, 5];
	}

	function run() public {
		if (factoryAddress == address(0) || owner == address(0)) {
			revert("Factory address or owner address are not set.");
		}

		vm.startBroadcast();
		GotSwapzFactory(payable(factoryAddress)).createCollection(
			owner,
			name,
			uri,
			packageUnits,
			packagePrices,
			rarity
		);
		vm.stopBroadcast();
	}
}
