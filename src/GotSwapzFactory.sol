// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { GotSwapzCollection } from "./GotSwapzCollection.sol";
import { Owned } from "solmate/auth/Owned.sol";
import { VRFCoordinatorV2Interface } from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import { VRFConsumerBaseV2 } from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/*___________________________________________________________________________________________________

                                   ad88888ba                                                           
                           ,d     d8"     "8b                                                          
                           88     Y8,                                                                  
 ,adPPYb,d8   ,adPPYba,  MM88MMM  `Y8aaaaa,    8b      db      d8  ,adPPYYba,  8b,dPPYba,   888888888  
a8"    `Y88  a8"     "8a   88       `"""""8b,  `8b    d88b    d8'  ""     `Y8  88P'    "8a       a8P"  
8b       88  8b       d8   88             `8b   `8b  d8'`8b  d8'   ,adPPPPP88  88       d8    ,d8P'    
"8a,   ,d88  "8a,   ,a8"   88,    Y8a     a8P    `8bd8'  `8bd8'    88,    ,88  88b,   ,a8"  ,d8"       
 `"YbbdP"Y8   `"YbbdP"'    "Y888   "Y88888P"       YP      YP      `"8bbdP"Y8  88`YbbdP"'   888888888  
 aa,    ,88                                                                    88                      
  "Y8bbdP"                                                                     88                      
____________________________________________________________________________________________________*/

/// @title GotSwapzFactory
/// @notice Factory to create GotSwapzCollection instances and interact with Chainlink VRF for randomness.
contract GotSwapzFactory is VRFConsumerBaseV2, Owned {
	// ======================= ERRORS ==============================

	/// @notice The service fee cannot be higher than 1000 (10%).
	error GotSwapzFactory_ServiceFeeTooHigh();
	/// @notice The sender of the transaction must be GotSwapzCollection created by this contract.
	error GotSwapzFactory_SenderNotValidCollection();
	/// @notice The tranfer of funds has failed.
	error GotSwapzFactory_TransferFailed();

	// ======================= CONSTANTS ===========================

	// How many confirmations the Chainlink node should wait before responding.
	uint16 private constant _VRF_REQUEST_CONFIRAMATIONS = 3;
	// Limit for how much gas to use for the callback request to fulfillRandomWords() function.
	uint32 private constant _VRF_CALLBACK_GAS_LIMIT = 1_000_000;

	// ======================= IMMUTABLES ==========================

	// Address of the Chainlink VRF Coordinator contract.
	VRFCoordinatorV2Interface private immutable _vrfCoordinator;
	// VRF subscription ID that this contract uses for funding requests.
	uint64 private immutable _vrfSubscriptionId;
	// VRF gas lane key hash value, which is the maximum gas price that will be paid for a request.
	bytes32 private immutable _vrfGasLane;

	// ======================= PUBLIC STORAGE ======================

	// Service fee to be applied to package sales.
	/// @notice Represents percentage with two decimal places (e.g. 125 = 1.25%).
	uint256 public serviceFee;

	// ======================= PRIVATE STORAGE =====================

	// GotSwapzCollection => has been created by this contract.
	mapping(address => bool) private _validCollection;
	// VRF request ID => GotSwapzCollection that requested it.
	mapping(uint256 => address) private _vrfRequestIdToCollectionAddress;

	// ======================= EVENTS ==============================

	/// @dev Emmited when a new collection is created.
	event CollectionCreated(
		address indexed addr,
		uint8[] packageUnits,
		uint256[] packagePrices,
		uint8[] rarity
	);

	// ======================= CONSTRUCTOR =========================

	/// @notice Constructor inherits VRFConsumerBaseV2.
	/// @param owner_ - Owner of the factory.
	/// @param subscriptionId - Subscription ID that this contract uses for funding VRF requests.
	/// @param vrfCoordinator - VRF coordinator, check https://docs.chain.link/docs/vrf-contracts/#configurations.
	/// @param gasLane - VRF gas lane to use, which specifies the maximum gas price to bump to.
	constructor(
		address owner_,
		uint256 serviceFee_,
		uint64 subscriptionId,
		address vrfCoordinator,
		bytes32 gasLane
	) VRFConsumerBaseV2(vrfCoordinator) Owned(owner_) {
		if (serviceFee_ > 1000) revert GotSwapzFactory_ServiceFeeTooHigh();
		serviceFee = serviceFee_;
		_vrfSubscriptionId = subscriptionId;
		_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
		_vrfGasLane = gasLane;
	}

	// ======================= CREATE COLLECTION ===================

	/// @notice Create a new instance of GotSwapzCollection and store its address.
	/// @param owner - Owner of the new collection.
	/// @param name - Name of the new collection.
	/// @param uri - IPFS URI of the new collection.
	/// @param packageUnits - Array of the package sizes of the new collection.
	/// @param packagePrices - Array of the prices for the package sizes of the new collection.
	/// @param rarity - Array of the rarity values for each NFT of the new collection.
	function createCollection(
		address owner,
		string calldata name,
		string calldata uri,
		uint8[] calldata packageUnits,
		uint256[] calldata packagePrices,
		uint8[] calldata rarity
	) external {
		// Create new collection.
		address collection = address(
			new GotSwapzCollection(
				owner,
				serviceFee,
				name,
				uri,
				packageUnits,
				packagePrices,
				rarity
			)
		);

		// Store address of the new collection.
		_validCollection[collection] = true;

		emit CollectionCreated(collection, packageUnits, packagePrices, rarity);
	}

	// ======================= ADMIN FUNCTIONS =====================

	/// @notice Sets service fee. Only owner is allowed.
	/// @param serviceFee_ - Service fee to be applied to package sales.
	function setServiceFee(uint256 serviceFee_) external onlyOwner {
		if (serviceFee_ > 1000) revert GotSwapzFactory_ServiceFeeTooHigh();
		serviceFee = serviceFee_;
	}

	/// @notice Withdraws all the balance of the contract. Only owner is allowed.
	function withdraw() external onlyOwner {
		(bool success, ) = msg.sender.call{ value: address(this).balance }("");
		if (!success) revert GotSwapzFactory_TransferFailed();
	}

	// ======================= RECEIVE MATIC =======================

	/// @notice Receive MATIC function.
	receive() external payable {}

	// ======================= RANDOM WORDS ========================

	/// @notice Request random words to Chainlink.
	/// @param numWords - Number of words requested.
	/// @return requestId - VRF request ID.
	function requestRandomWords(uint32 numWords)
		external
		returns (uint256 requestId)
	{
		// Only collection created by this factory can request random words.
		if (!_validCollection[msg.sender])
			revert GotSwapzFactory_SenderNotValidCollection();

		// Request random words to VRF coordinator.
		requestId = _vrfCoordinator.requestRandomWords(
			_vrfGasLane,
			_vrfSubscriptionId,
			_VRF_REQUEST_CONFIRAMATIONS,
			_VRF_CALLBACK_GAS_LIMIT,
			numWords
		);

		// Map request ID to the collection that requested it.
		_vrfRequestIdToCollectionAddress[requestId] = msg.sender;
	}

	/// @notice Callback function used by VRF Coordinator.
	/// @param requestId - ID of the VRF request.
	/// @param randomWords - Array of random results from VRF Coordinator.
	function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
		internal
		override
	{
		// Send request ID and random words to collection contract to process the order.
		GotSwapzCollection(_vrfRequestIdToCollectionAddress[requestId])
			.processOrder(requestId, randomWords);
	}
}
