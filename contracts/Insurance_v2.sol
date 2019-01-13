pragma solidity ^0.5.2;

import "./BehaviourToken.sol";
import "./BikeSharing_v2.sol";

contract Insurance is BikeSharing {

	using SafeMath for uint256;

	// Constant
	uint constant public INSURANCE_RETENTION = 200 finney;
	uint256 constant public CLAIM_TOKEN_RATIO = 5;
	uint256 constant public PREMIUM_RATE = 100 finney;

	// Global Variables
	address insurer;
	uint premiumRate;

    // InsuredList for count
    address[] public insuredList;

	// Storage
	mapping(address => bool) isClientInsured;
	mapping(address => InsuranceClient) insuranceMapping;

	struct InsuranceClient {
		uint insuredListPointer;
		uint totalPremiumPaid;
		// Total rides
		uint256 totalRides;
		// Count the number of claims, and the amounts
		uint256 grossClaims; // Real counter of claims (total)
		uint256 netClaims;
		// Token count
		uint256 nbTokensOwned;
	}

	// Token variables
	address public tokenAddress;
	uint256 public tokenRewardAmount;
	uint256 public claimTokenRatio;
	BehaviourToken public behaviourToken;

	// Create a storage for Bike Shop
	// BikeSharing bikeSharing;

	/*
	================================================================
								Events
	================================================================
	*/

	event TokenCreated(address newTokenAddress);
	event TokenRewardSet(uint256 tokenReward);
	event TokenPaid(address insuredAddress, uint256 amount);

	/*
	================================================================
								Modifiers
	================================================================
	*/

	modifier notNullAddress (address _address) {
		require(_address != 0);
		_;
	}

	modifier positiveReward (uint256 _rewardValue) {
        require(_rewardValue > 0);
        _;
    }

    modifier insuredClient (address _address) {
    	require(isClientInsured[_address] == true);
    	_;
    }

	/*
	================================================================
								Constructor
	================================================================
	*/

	constructor (uint256 _rideReward) public {

    	insurer = msg.sender;
    	claimTokenRatio = CLAIM_TOKEN_RATIO;
    	premiumRate = PREMIUM_RATE;
        
        // Initialize a BehaviourToken
        setBehaviourToken(new BehaviourToken());
        uint256 rideReward = _rideReward; // 1 by default
        setBehaviourTokenReward(rideReward);

        // Connect with the Bike Sharing contract
        //

        // One option : 
        // address mapBikeClients in argument
        /// bikeSharing = BikeSharing(mapBikeClients);

        // Second option : inheritance

    }

	/*
	================================================================
								Tokens
	================================================================
	*/

    function setBehaviourToken(address _newBehaviourToken)
        private
        notNullAddress(_newBehaviourToken)
    {
        behaviourToken = BehaviourToken(_newBehaviourToken);
        tokenAddress = address(behaviourToken);
        emit TokenCreated(tokenAddress);
    }

    function setBehaviourTokenReward(uint256 _tokenReward)
        private
        positiveReward(_tokenReward)
    {
        tokenRewardAmount = _tokenReward;
        emit TokenRewardSet(tokenRewardAmount);
    }

    function rewardRider(address _riderAddress, uint256 _rewardAmount)
        private
        notNullAddress(_riderAddress)
    {
        require(_rewardAmount > 0);
        behaviourToken.transfer(_riderAddress, _rewardAmount);
        emit TokenPaid(_riderAddress, _rewardAmount);
    }

	/*
	================================================================
								Insurance
	================================================================
	*/

    function underwriteInsurance()
        public
        payable
        returns (bool success)
    {
        // The client must not be a client already
        require(isClientInsured[msg.sender]==false);        
        require(msg.value == premiumRate); // The client must pay the 1st premium upfront

        insuranceMapping[msg.sender] = InsuranceClient(
        	{
        		insuredListPointer: insuredList.push(msg.sender) - 1,
        		totalPremiumPaid: msg.value,
        		totalRides: 0,
        		grossClaims: 0,
        		netClaims: 0,
        		nbTokensOwned: 0
        	}
    	);

        // Finally, include client in the mapping
        isClientInsured[msg.sender] = true;

        return isClientInsured[msg.sender];
    }

	function calculatePremium(address insuranceTaker) 
	    view
	    public
	    insuredClient(insuranceTaker)
	    returns (uint premium)
	{
	    InsuranceClient memory customer = insuranceMapping[insuranceTaker];
	    return (customer.netClaims + 1) * premiumRate;
	}

	// Big function for the customer to update his/her account of claims, premium, tokens
	function regularizePayments ()
		public
		payable
		returns (bool success)
	{

		regularizeClaims(msg.sender);


	}

	function regularizeClaims (address insuredAddress)
	{

	}

	function regularizePremia (address insuredAddress)
	{

	}

	function regularizeTokens (address insuredAddress)
	{

	}

	function tokenClaimReducer()
	{

	}


}