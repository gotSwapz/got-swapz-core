// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

/* solhint-disable */
import "../src/GotSwapzFactory.sol";
import "../src/GotSwapzCollection.sol";
import "./mocks/MockVRFCoordinatorV2.sol";
import "./utils/Util.sol";
import "forge-std/Test.sol";

contract GotSwapzFactoryTest is Test, Util {
	GotSwapzFactory private factory;
	MockVRFCoordinatorV2 private vrfCoordinator;

	address private alice = address(0x1);
	address private owner = address(0x99);

	uint96 private constant FUND_AMOUNT = 1e18;
	uint256 private serviceFee;
	string private name;
	string private uri;
	uint64 private subId;
	bytes32 private gasLane;
	uint8[] private packageUnits = new uint8[](6);
	uint256[] private packagePrices = new uint256[](6);
	uint8[] private rarity = new uint8[](10);
	address private newCollectionAddress;

	function setUp() public {
		vm.label(alice, "Alice");
		vm.label(owner, "Owner");

		serviceFee = 200; // 2%
		name = "My cool collection";
		uri = "ipfs://fake_{id}";
		packageUnits = [2, 4, 6, 8, 10, 25];
		packagePrices = [1e16, 1e16, 1e16, 1e16, 1e16, 2e16];
		rarity = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

		vrfCoordinator = new MockVRFCoordinatorV2();
		subId = vrfCoordinator.createSubscription();
		vrfCoordinator.fundSubscription(subId, FUND_AMOUNT);

		factory = new GotSwapzFactory(
			owner,
			serviceFee,
			subId,
			address(vrfCoordinator),
			gasLane
		);
	}

	function test_createCollection() public {
		vm.recordLogs();
		vm.prank(alice);

		factory.createCollection(
			owner,
			name,
			uri,
			packageUnits,
			packagePrices,
			rarity
		);

		Vm.Log memory collectionCreatedEvent = vm.getRecordedLogs()[1];

		newCollectionAddress = bytes32ToAddress(
			collectionCreatedEvent.topics[1]
		);

		GotSwapzCollection newCollection = GotSwapzCollection(
			newCollectionAddress
		);

		assertEq(newCollection.owner(), owner);
		assertEq(newCollection.name(), name);
		assertEq(newCollection.uri(1), uri);

		(
			uint8[] memory _packageUnits,
			uint256[] memory _packagePrices
		) = newCollection.getPackageInfo();
		uint8[] memory _rarity = newCollection.getRarity();

		assertEq(_packageUnits.length, packageUnits.length);
		for (uint256 i; i < packageUnits.length; ++i) {
			assertEq(_packageUnits[i], packageUnits[i]);
		}

		assertEq(_packagePrices.length, packagePrices.length);
		for (uint256 i; i < packagePrices.length; ++i) {
			assertEq(_packagePrices[i], packagePrices[i]);
		}

		assertEq(_rarity.length, rarity.length);
		for (uint256 i; i < rarity.length; ++i) {
			assertEq(_rarity[i], rarity[i]);
		}
	}

	function test_requestRandomWords() public {
		uint32 numWords = 10;

		vm.recordLogs();
		factory.createCollection(
			owner,
			name,
			uri,
			packageUnits,
			packagePrices,
			rarity
		);
		Vm.Log memory collectionCreatedEvent = vm.getRecordedLogs()[1];
		newCollectionAddress = bytes32ToAddress(
			collectionCreatedEvent.topics[1]
		);

		vm.expectCall(
			address(vrfCoordinator),
			abi.encodeCall(
				vrfCoordinator.requestRandomWords,
				(gasLane, subId, 3, 1_000_000, numWords)
			)
		);
		vm.prank(newCollectionAddress);
		factory.requestRandomWords(numWords);
	}

	function test_fulfillRandomWords() public {
		uint256[] memory randomWords = new uint256[](1);
		// This is the value computed by mock vrfCoordinator for a request id = 1
		randomWords[
			0
		] = 78541660797044910968829902406342334108369226379826116161446442989268089806461;

		vm.recordLogs();
		factory.createCollection(
			owner,
			name,
			uri,
			packageUnits,
			packagePrices,
			rarity
		);
		Vm.Log memory collectionCreatedEvent = vm.getRecordedLogs()[1];
		newCollectionAddress = bytes32ToAddress(
			collectionCreatedEvent.topics[1]
		);

		vm.prank(newCollectionAddress);
		factory.requestRandomWords(1);

		vm.expectCall(
			newCollectionAddress,
			abi.encodeCall(
				GotSwapzCollection(newCollectionAddress).processOrder,
				(1, randomWords)
			)
		);
		vrfCoordinator.fulfillRandomWords(1, address(factory));
	}

	function test_setServiceFee() public {
		assertEq(serviceFee, factory.serviceFee());

		uint256 newServiceFee = 300;

		vm.prank(owner);
		factory.setServiceFee(newServiceFee);

		assertEq(newServiceFee, factory.serviceFee());
	}

	function test_factoryWithdraw() public {
		uint256 amount = 10e18;
		deal(address(factory), amount);

		uint256 initialFactoryBalance = address(factory).balance;
		uint256 initialOwnerBalance = owner.balance;

		vm.prank(owner);
		factory.withdraw();

		uint256 finalFactoryBalance = address(factory).balance;
		uint256 finalOwnerBalance = owner.balance;

		assertEq(finalFactoryBalance, initialFactoryBalance - amount);
		assertEq(finalOwnerBalance, initialOwnerBalance + amount);
	}

	function test_serviceFeeTooHighRevert() public {
		vm.expectRevert(
			abi.encodeWithSelector(
				GotSwapzFactory.GotSwapzFactory_ServiceFeeTooHigh.selector
			)
		);
		factory = new GotSwapzFactory(
			owner,
			2001,
			subId,
			address(vrfCoordinator),
			gasLane
		);
	}

	function test_senderNotValidCollectionRevert() public {
		vm.expectRevert(
			abi.encodeWithSelector(
				GotSwapzFactory
					.GotSwapzFactory_SenderNotValidCollection
					.selector
			)
		);
		factory.requestRandomWords(1);
	}

	function test_factoryUnauthorizedRevert() public {
		vm.expectRevert("UNAUTHORIZED");
		factory.setServiceFee(350);

		vm.expectRevert("UNAUTHORIZED");
		factory.withdraw();
	}
}
