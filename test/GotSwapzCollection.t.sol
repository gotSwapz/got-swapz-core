// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

/* solhint-disable */
import "../src/GotSwapzCollection.sol";
import "./mocks/MockGotSwapzFactory.sol";
import "./utils/Util.sol";
import "./utils/BytesLib.sol";
import "forge-std/Test.sol";

contract GotSwapzCollectionTest is Test, Util {
	using BytesLib for bytes;

	GotSwapzCollection private collection;
	MockGotSwapzFactory private factory;

	address private alice = address(0x1);
	address private bob = address(0x2);
	address private owner = address(0x99);

	uint256 private serviceFee;
	string private name;
	string private uri;
	uint256 private requestId;

	uint256[] private offeredTokenIds;
	uint256[] private demandedTokenIds;

	uint256 private swapId;

	uint8[] private packageUnits = new uint8[](6);
	uint256[] private packagePrices = new uint256[](6);
	uint8[] private rarity = new uint8[](10);

	function setUp() public {
		vm.label(alice, "Alice");
		vm.label(bob, "Bob");
		vm.label(owner, "Owner");

		serviceFee = 200; // 2%
		name = "My cool collection";
		uri = "ipfs://fake_{id}";
		rarity = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
		packageUnits = [2, 4, 6, 8, 10, 25];
		packagePrices = [1e16, 1e16, 1e16, 1e16, 1e16, 2e16];
		requestId = 123;
		offeredTokenIds = [1, 2];
		demandedTokenIds = [4, 5, 6];
		vm.deal(alice, 1000 * 1e18);
		vm.deal(bob, 1000 * 1e18);

		factory = new MockGotSwapzFactory(requestId);

		vm.prank(address(factory));
		collection = new GotSwapzCollection(
			owner,
			serviceFee,
			name,
			uri,
			packageUnits,
			packagePrices,
			rarity
		);
	}

	function test_initialData() public {
		assertEq(collection.name(), name);
		assertEq(collection.uri(1), uri);
	}

	function test_buyPackage() public {
		uint8 units = 10;
		uint256 price = 1e16;

		uint256 initialFactoryBalance = address(factory).balance;
		uint256 initialCollectionBalance = address(collection).balance;

		vm.recordLogs();
		vm.prank(alice);
		collection.buyPackage{ value: price }(units);
		Vm.Log memory orderCreatedEvent = vm.getRecordedLogs()[0];

		assertEq(bytes32ToAddress(orderCreatedEvent.topics[1]), alice);

		bytes32[] memory orderCreatedEventData = orderCreatedEvent
			.data
			.toBytes32Array();

		uint256 finalFactoryBalance = address(factory).balance;
		uint256 finalCollectionBalance = address(collection).balance;
		uint256 feeAmount = (price * serviceFee) / 10000;

		assertEq(uint256(orderCreatedEventData[0]), units);
		assertEq(uint256(orderCreatedEventData[1]), requestId);
		assertEq(finalFactoryBalance, initialFactoryBalance + feeAmount);
		assertEq(
			finalCollectionBalance,
			initialCollectionBalance + price - feeAmount
		);
	}

	function test_processOrder() public {
		uint8 units = 10;
		uint256[] memory randomWords = getWords(requestId, units);

		vm.prank(alice);
		collection.buyPackage{ value: 1e16 }(units);

		vm.recordLogs();
		vm.prank(address(factory));
		collection.processOrder(requestId, randomWords);

		Vm.Log[] memory events = vm.getRecordedLogs();
		// Vm.Log memory transferBatchEvent = events[0];
		// emit log_bytes(transferBatchEvent.data);
		// bytes32[] memory transferBatchEventData = transferBatchEvent
		// 	.data
		// 	.toBytes32Array();
		// console.log(transferBatchEventData.length);

		Vm.Log memory orderProcessedEvent = events[1];
		assertEq(bytes32ToAddress(orderProcessedEvent.topics[1]), alice);

		// bytes32[] memory orderProcessededEventData = orderProcessedEvent
		// 	.data
		// 	.toBytes32Array();
		// console.log(orderProcessededEventData.length);
	}

	function test_createSwapOffer() public {
		vm.prank(alice);
		collection.buyPackage{ value: 1e16 }(10);

		uint256[10] memory aliceWords = [
			uint256(0),
			2,
			2,
			5,
			5,
			54,
			54,
			54,
			54,
			54
		];
		uint256[] memory aliceWordsDynamic = new uint256[](10);
		for (uint256 i = 0; i < 10; ++i) {
			aliceWordsDynamic[i] = aliceWords[i];
		}

		vm.prank(address(factory));
		collection.processOrder(requestId, aliceWordsDynamic);
		// NFTs minted to Alice [1, 2, 2, 3, 3, 10, 10, 10, 10, 10]

		vm.prank(bob);
		collection.buyPackage{ value: 1e16 }(10);

		uint256[10] memory bobWords = [
			uint256(5),
			9,
			14,
			14,
			14,
			14,
			20,
			20,
			54,
			54
		];
		uint256[] memory bobWordsDynamic = new uint256[](10);
		for (uint256 i = 0; i < 10; ++i) {
			bobWordsDynamic[i] = bobWords[i];
		}

		vm.prank(address(factory));
		collection.processOrder(requestId, bobWordsDynamic);
		// NFTs minted to Bob [3, 4, 5, 5, 5, 5, 6, 6, 10, 10]

		vm.prank(alice);
		swapId = collection.createSwapOffer(
			offeredTokenIds,
			demandedTokenIds,
			bob
		);

		assertEq(collection.swapCounter(), 1);

		(
			address ownerA,
			address ownerB,
			uint256[] memory nftsA,
			uint256[] memory nftsB,
			GotSwapzCollection.SwapState state
		) = collection.getSwap(swapId);
		assertEq(ownerA, alice);
		assertEq(ownerB, bob);
		assertEq(nftsA, offeredTokenIds);
		assertEq(nftsB, demandedTokenIds);
		assertEq(uint256(state), uint256(GotSwapzCollection.SwapState.OFFERED));

		assertEq(collection.balanceOf(alice, 1), 0);
		assertEq(collection.balanceOf(alice, 2), 1);
		assertEq(collection.balanceOf(alice, 3), 2);
		assertEq(collection.balanceOf(alice, 4), 0);
		assertEq(collection.balanceOf(alice, 5), 0);
		assertEq(collection.balanceOf(alice, 6), 0);

		assertEq(collection.balanceOf(bob, 1), 0);
		assertEq(collection.balanceOf(bob, 2), 0);
		assertEq(collection.balanceOf(bob, 3), 1);
		assertEq(collection.balanceOf(bob, 4), 1);
		assertEq(collection.balanceOf(bob, 5), 4);
		assertEq(collection.balanceOf(bob, 6), 2);
	}

	function test_cancelSwapOffer() public {
		test_createSwapOffer();

		vm.prank(alice);
		collection.cancelSwapOffer(swapId);

		(
			address ownerA,
			address ownerB,
			uint256[] memory nftsA,
			uint256[] memory nftsB,
			GotSwapzCollection.SwapState state
		) = collection.getSwap(swapId);
		assertEq(ownerA, alice);
		assertEq(ownerB, bob);
		assertEq(nftsA, offeredTokenIds);
		assertEq(nftsB, demandedTokenIds);
		assertEq(
			uint256(state),
			uint256(GotSwapzCollection.SwapState.CANCELLED)
		);

		assertEq(collection.balanceOf(alice, 1), 1);
		assertEq(collection.balanceOf(alice, 2), 2);
		assertEq(collection.balanceOf(alice, 3), 2);
		assertEq(collection.balanceOf(alice, 4), 0);
		assertEq(collection.balanceOf(alice, 5), 0);
		assertEq(collection.balanceOf(alice, 6), 0);

		assertEq(collection.balanceOf(bob, 1), 0);
		assertEq(collection.balanceOf(bob, 2), 0);
		assertEq(collection.balanceOf(bob, 3), 1);
		assertEq(collection.balanceOf(bob, 4), 1);
		assertEq(collection.balanceOf(bob, 5), 4);
		assertEq(collection.balanceOf(bob, 6), 2);
	}

	function test_rejectSwapOffer() public {
		test_createSwapOffer();

		vm.prank(bob);
		collection.rejectSwapOffer(swapId);

		(
			address ownerA,
			address ownerB,
			uint256[] memory nftsA,
			uint256[] memory nftsB,
			GotSwapzCollection.SwapState state
		) = collection.getSwap(swapId);
		assertEq(ownerA, alice);
		assertEq(ownerB, bob);
		assertEq(nftsA, offeredTokenIds);
		assertEq(nftsB, demandedTokenIds);
		assertEq(
			uint256(state),
			uint256(GotSwapzCollection.SwapState.REJECTED)
		);

		assertEq(collection.balanceOf(alice, 1), 1);
		assertEq(collection.balanceOf(alice, 2), 2);
		assertEq(collection.balanceOf(alice, 3), 2);
		assertEq(collection.balanceOf(alice, 4), 0);
		assertEq(collection.balanceOf(alice, 5), 0);
		assertEq(collection.balanceOf(alice, 6), 0);

		assertEq(collection.balanceOf(bob, 1), 0);
		assertEq(collection.balanceOf(bob, 2), 0);
		assertEq(collection.balanceOf(bob, 3), 1);
		assertEq(collection.balanceOf(bob, 4), 1);
		assertEq(collection.balanceOf(bob, 5), 4);
		assertEq(collection.balanceOf(bob, 6), 2);
	}

	function test_acceptSwapOffer() public {
		test_createSwapOffer();

		vm.prank(bob);
		collection.acceptSwapOffer(swapId);

		(
			address ownerA,
			address ownerB,
			uint256[] memory nftsA,
			uint256[] memory nftsB,
			GotSwapzCollection.SwapState state
		) = collection.getSwap(swapId);
		assertEq(ownerA, alice);
		assertEq(ownerB, bob);
		assertEq(nftsA, offeredTokenIds);
		assertEq(nftsB, demandedTokenIds);
		assertEq(
			uint256(state),
			uint256(GotSwapzCollection.SwapState.EXECUTED)
		);

		assertEq(collection.balanceOf(alice, 1), 0);
		assertEq(collection.balanceOf(alice, 2), 1);
		assertEq(collection.balanceOf(alice, 3), 2);
		assertEq(collection.balanceOf(alice, 4), 1);
		assertEq(collection.balanceOf(alice, 5), 1);
		assertEq(collection.balanceOf(alice, 6), 1);

		assertEq(collection.balanceOf(bob, 1), 1);
		assertEq(collection.balanceOf(bob, 2), 1);
		assertEq(collection.balanceOf(bob, 3), 1);
		assertEq(collection.balanceOf(bob, 4), 0);
		assertEq(collection.balanceOf(bob, 5), 3);
		assertEq(collection.balanceOf(bob, 6), 1);
	}

	function test_collectionWithdraw() public {
		uint256 amount = 10e18;
		deal(address(collection), amount);

		uint256 initialCollectionBalance = address(collection).balance;
		uint256 initialOwnerBalance = owner.balance;

		vm.prank(owner);
		collection.withdraw();

		uint256 finalCollectionBalance = address(collection).balance;
		uint256 finalOwnerBalance = owner.balance;

		assertEq(finalCollectionBalance, initialCollectionBalance - amount);
		assertEq(finalOwnerBalance, initialOwnerBalance + amount);
	}

	function test_emptyNameRevert() public {
		vm.expectRevert(
			abi.encodeWithSelector(
				GotSwapzCollection.GotSwapzCollection_EmptyName.selector
			)
		);
		vm.prank(address(factory));
		collection = new GotSwapzCollection(
			owner,
			serviceFee,
			"",
			uri,
			packageUnits,
			packagePrices,
			rarity
		);
	}

	function test_emptyUriRevert() public {
		vm.expectRevert(
			abi.encodeWithSelector(
				GotSwapzCollection.GotSwapzCollection_EmptyUri.selector
			)
		);
		vm.prank(address(factory));
		collection = new GotSwapzCollection(
			owner,
			serviceFee,
			name,
			"",
			packageUnits,
			packagePrices,
			rarity
		);
	}

	function test_invalidNumOfPackagesRevert() public {
		uint8[] memory packageUnitsEmpty;
		uint256[] memory packagePricesEmpty;
		vm.expectRevert(
			abi.encodeWithSelector(
				GotSwapzCollection
					.GotSwapzCollection_InvalidNumOfPackages
					.selector
			)
		);
		vm.prank(address(factory));
		collection = new GotSwapzCollection(
			owner,
			serviceFee,
			name,
			uri,
			packageUnitsEmpty,
			packagePricesEmpty,
			rarity
		);

		uint8[] memory packageUnitsOne = new uint8[](1);
		vm.expectRevert(
			abi.encodeWithSelector(
				GotSwapzCollection
					.GotSwapzCollection_InvalidNumOfPackages
					.selector
			)
		);
		vm.prank(address(factory));
		collection = new GotSwapzCollection(
			owner,
			serviceFee,
			name,
			uri,
			packageUnitsOne,
			packagePrices,
			rarity
		);

		uint8[] memory packageUnitsNine = new uint8[](9);
		uint256[] memory packagePricesNine = new uint256[](9);
		vm.expectRevert(
			abi.encodeWithSelector(
				GotSwapzCollection
					.GotSwapzCollection_InvalidNumOfPackages
					.selector
			)
		);
		vm.prank(address(factory));
		collection = new GotSwapzCollection(
			owner,
			serviceFee,
			name,
			uri,
			packageUnitsNine,
			packagePricesNine,
			rarity
		);
	}

	function test_invalidRarityLengthRevert() public {
		uint8[] memory rarityEmpty;
		vm.expectRevert(
			abi.encodeWithSelector(
				GotSwapzCollection
					.GotSwapzCollection_InvalidRariryLength
					.selector
			)
		);
		vm.prank(address(factory));
		collection = new GotSwapzCollection(
			owner,
			serviceFee,
			name,
			uri,
			packageUnits,
			packagePrices,
			rarityEmpty
		);

		uint8[] memory rarity1001 = new uint8[](1001);
		vm.expectRevert(
			abi.encodeWithSelector(
				GotSwapzCollection
					.GotSwapzCollection_InvalidRariryLength
					.selector
			)
		);
		vm.prank(address(factory));
		collection = new GotSwapzCollection(
			owner,
			serviceFee,
			name,
			uri,
			packageUnits,
			packagePrices,
			rarity1001
		);
	}

	function test_invalidRarityValueRevert() public {
		rarity[0] = 0;
		vm.expectRevert(
			abi.encodeWithSelector(
				GotSwapzCollection
					.GotSwapzCollection_InvalidRarityValue
					.selector
			)
		);
		vm.prank(address(factory));
		collection = new GotSwapzCollection(
			owner,
			serviceFee,
			name,
			uri,
			packageUnits,
			packagePrices,
			rarity
		);

		rarity[0] = 101;
		vm.expectRevert(
			abi.encodeWithSelector(
				GotSwapzCollection
					.GotSwapzCollection_InvalidRarityValue
					.selector
			)
		);
		vm.prank(address(factory));
		collection = new GotSwapzCollection(
			owner,
			serviceFee,
			name,
			uri,
			packageUnits,
			packagePrices,
			rarity
		);
	}

	function test_invalidPackageUnitsRevert() public {
		packageUnits[0] = 0;
		vm.expectRevert(
			abi.encodeWithSelector(
				GotSwapzCollection
					.GotSwapzCollection_InvalidPackageUnits
					.selector
			)
		);
		vm.prank(address(factory));
		collection = new GotSwapzCollection(
			owner,
			serviceFee,
			name,
			uri,
			packageUnits,
			packagePrices,
			rarity
		);

		packageUnits[0] = 101;
		vm.expectRevert(
			abi.encodeWithSelector(
				GotSwapzCollection
					.GotSwapzCollection_InvalidPackageUnits
					.selector
			)
		);
		vm.prank(address(factory));
		collection = new GotSwapzCollection(
			owner,
			serviceFee,
			name,
			uri,
			packageUnits,
			packagePrices,
			rarity
		);

		packagePrices[0] = 0;
		vm.expectRevert(
			abi.encodeWithSelector(
				GotSwapzCollection
					.GotSwapzCollection_InvalidPackageUnits
					.selector
			)
		);
		vm.prank(address(factory));
		collection = new GotSwapzCollection(
			owner,
			serviceFee,
			name,
			uri,
			packageUnits,
			packagePrices,
			rarity
		);
	}

	function test_invalidValueSentRevert() public {
		vm.expectRevert(
			abi.encodeWithSelector(
				GotSwapzCollection.GotSwapzCollection_InvalidValueSent.selector
			)
		);
		collection.buyPackage{ value: 1 }(10);
	}

	function test_senderNotFactoryRevert() public {
		vm.expectRevert(
			abi.encodeWithSelector(
				GotSwapzCollection
					.GotSwapzCollection_SenderNotGotSwapzFactory
					.selector
			)
		);
		collection.processOrder(1, new uint256[](1));
	}

	function test_pendingOrderNotFoundRevert() public {
		vm.expectRevert(
			abi.encodeWithSelector(
				GotSwapzCollection
					.GotSwapzCollection_PendingOrderNotFound
					.selector
			)
		);
		vm.prank(address(factory));
		collection.processOrder(1, new uint256[](1));
	}

	function test_senderIsReceiverRevert() public {
		vm.prank(alice);
		collection.buyPackage{ value: 1e16 }(2);

		uint256[] memory words = new uint256[](2);
		words[0] = 2;
		words[1] = 2;

		vm.prank(address(factory));
		collection.processOrder(requestId, words);

		vm.expectRevert(
			abi.encodeWithSelector(
				GotSwapzCollection.GotSwapzCollection_SenderIsReceiver.selector
			)
		);
		vm.prank(alice);
		offeredTokenIds = [2, 2];
		collection.createSwapOffer(offeredTokenIds, offeredTokenIds, alice);
	}

	function test_notOwnerOfAllRevert() public {
		vm.expectRevert(
			abi.encodeWithSelector(
				GotSwapzCollection.GotSwapzCollection_NotOwnerOfAll.selector
			)
		);
		collection.createSwapOffer(offeredTokenIds, demandedTokenIds, bob);
	}

	function test_invalidNumberOfItemsRevert() public {
		vm.expectRevert(
			abi.encodeWithSelector(
				GotSwapzCollection
					.GotSwapzCollection_InvalidNumberOfItems
					.selector
			)
		);
		collection.createSwapOffer(new uint256[](0), new uint256[](0), bob);
	}

	function test_notOfferOwnerRevert() public {
		test_createSwapOffer();

		vm.expectRevert(
			abi.encodeWithSelector(
				GotSwapzCollection.GotSwapzCollection_NotOfferOwner.selector
			)
		);
		collection.cancelSwapOffer(swapId);
	}

	function test_notOpenOfferRevert() public {
		test_cancelSwapOffer();

		vm.expectRevert(
			abi.encodeWithSelector(
				GotSwapzCollection.GotSwapzCollection_NotOpenOffer.selector
			)
		);
		vm.prank(address(bob));
		collection.acceptSwapOffer(swapId);
	}

	function test_notDemandedownerRevert() public {
		test_createSwapOffer();

		vm.expectRevert(
			abi.encodeWithSelector(
				GotSwapzCollection.GotSwapzCollection_NotDemandedOwner.selector
			)
		);
		collection.acceptSwapOffer(swapId);
	}

	function test_collectionUnauthorizedRevert() public {
		vm.expectRevert("UNAUTHORIZED");
		collection.withdraw();
	}
}
