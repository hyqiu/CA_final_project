pragma solidity ^0.5.2;

import "./BehaviourToken.sol";
//import "./PublicLedger.sol";
import "./BikeSharing_v1.sol";

contract Insurance {

	using SafeMath for uint256;

	// Global variables

	address insurer;

	// Storage

	mapping(address => bool) public isClientInsured;
	mapping(address => InsuranceClient) public insuranceMapping;

	struct InsuranceClient {
		uint256 accidentCount;
		uint receivedPremiums;
		uint claimPayouts;
		uint256 tokenCount;
	}

	BehaviourToken public behaviourToken;
	
	//////////// Tokens ////////////

    address public tokenAddress;
    uint256 public tokenRewardAmount;
    uint256 public claimTokenRatio;

    /*
    ================================================================
                            Events
    ================================================================
    */ 

    event TokenPaid(address riderAddress, uint256 amount);

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

    /*
    ================================================================
                            Constructor
    ================================================================
    */ 

    constructor () public {
    	insurer = msg.sender;
    	claimTokenRatio = CLAIM_TOKEN_RATIO;
        // Initialize a BehaviourToken
        setBehaviourToken(new BehaviourToken());
        uint256 rideReward = 1;
        setBehaviourTokenReward(rideReward);
    }

    /*
    ================================================================
                            Token intendance
    ================================================================
    */ 

    function setBehaviourToken(address _newBehaviourToken)
        internal
        notNullAddress(_newBehaviourToken)
    {
        behaviourToken = BehaviourToken(_newBehaviourToken);
        tokenAddress = address(behaviourToken);
    }

    function setBehaviourTokenReward(uint256 _tokenReward)
        public
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
                    Reconcile Insurance and Claim Data
    ================================================================
    */ 

    BikeSharing bikeSharing;

    function connectToBikeSharing(address addr) 
        private
    {
        bikeSharing = BikeSharing(addr);
    }

    // Read how many the guy has claims

    
    

    // Read how much I must repay the user

    // Make a struct : 
    //// - the net claims the guy has (after he repaid the claims with tokens)
    //// - the token amount insurer has distributed 

	struct InsuranceClient {
		uint256 grossAccidentCount;
		uint256 redeemedClaims;
		uint claimPayouts;
		uint256 tokenCount;
	}

	function getNetAccidentCount(address insuredAddr)
		view
		public
		returns (uint256 netAccidentCount)
	{
		InsuranceClient memory client = insuranceMapping[insuredAddr];
		return (sub(client.grossAccidentCount, client.redeemedClaims));
	}

    /*
    ================================================================
                            Insurance
    ================================================================
    */ 

    function calculatePremium(address insuranceTaker) 
	    view
	    public
	    returns (uint256 premium)
	{
	    InsuranceClient memory customer = insuranceMapping[msg.sender];
	    return (customer.accidentCount + 1) * premiumRate;
	}

    function underwriteInsurance()
        public
        payable
        returns (bool success)
    {
        // The client must not be a client already
        require(isClientInsured[msg.sender]==false);        
        require(msg.value == calculatePremium(msg.sender));

        InsuranceClient storage customer = insuranceMapping[msg.sender];
        customer.receivedPremiums += msg.value;

        // Initialize the other 
        customer.claimPayouts = 0;
        customer.tokenCount = 0;

        // 
        isClientInsured[msg.sender] = true;

        return isClientInsured[msg.sender];
    }

	function checkTokenCount()
	{

	}

    function tokenClaimReducer(uint256 _tokenBack)
    	public
    	// MODIFIER : THE GUY MUST BE INSURED
    	returns (bool success)
    {
    	PublicTokenCount storage customer = TokenLedger[msg.sender];

    	// Check that the _tokenBack is superior to what the guy really has

    	uint claimsToDecrease = div(customer.totalDistributedTokenCount, _tokenBack);

    	if (claimsToDecrease > 0) {
    		require(behaviourToken.transferFrom(msg.sender, address(this), _tokenBack));
    		// 
    	}
    }

    // Regularize Token : distribute token to the guy who claims it
    function regularizeToken()
    	public
    	returns (bool success)
    {
    	PublicTokenCount storage customer = TokenLedger[msg.sender];
    	require(customer.clientInsured == true);

    	uint256 owedTokens = customer.totalEarnedTokenCount - customer.totalDistributedTokenCount;

    	if(owedTokens > 0) {
    		// TODO : Increase limit allowed to user
    		rewardRider(msg.sender, owedTokens);
    		emit TokenPaid(msg.sender, owedTokens);
			customer.totalDistributedTokenCount += owedTokens;
    	}

    	return customer.totalDistributedTokenCount == customer.totalEarnedTokenCount;

    }

    // To trigger the payment for claim

    function claimPayment ()
    	public
    	returns (bool success)
	{

	}



}