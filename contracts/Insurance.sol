pragma solidity ^0.5.2;


import "./BehaviourToken.sol"


contract Insurance {

	// Storage

	mapping(address => insuranceClient) public insuredPortfolio;

	struct insuranceClient {
		uint accidentCount;
		uint receivedPremiums;
	}

	BehaviourToken public behaviourToken;
	

}