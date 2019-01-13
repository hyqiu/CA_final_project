pragma solidity ^0.5.2;

import "./BehaviourToken.sol";
import "./BikeSharing_v2.sol";

contract Insurance {

	using SafeMath for uint256;

	// Constant
	uint constant public INSURANCE_RETENTION = 100 finney;

	// Global Variables
	address insurer;

	// Storage
	mapping(address => bool) isClientInsured;
	mapping(address => InsuranceClient) insuranceMapping;

	struct InsuranceClient {
		uint insuredListPointer;
		uint totalPremiumPaid;
		// Count the number of claims, and the amounts
		uint256 countClaimsMade;
		uint256 countClaimsPaid;

		// Token count
		uint256 nbTokensOwned;
	}

	// Token variables
	address public tokenAddress;
	uint256 public tokenRewardAmount;
	uint256 public claimTokenRatio;
	BehaviourToken public behaviourToken;

	/*
	================================================================
								Events
	================================================================
	*/

	event TokenPaid(address insuredAddress, uint256 amount);

	/*
	================================================================
								Tokens
	================================================================
	*/



}