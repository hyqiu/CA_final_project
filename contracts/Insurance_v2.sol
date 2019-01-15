pragma solidity ^0.5.2;

import "./BehaviourToken.sol";
import "./BikeSharing_v2.sol";

contract Insurance is BikeSharing, BehaviourToken {

	using SafeMath for uint256;

	// Constant
	uint constant public INSURANCE_RETENTION = 100 finney;
	uint256 constant public CLAIM_TOKEN_RATIO = 5;
	uint constant public PREMIUM_RATE = 10 finney;

	// Global Variables
	address insurer;
	uint premiumRate;
	uint retentionAmount;

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
		uint256 grossTokens; // Real counter of tokens (total)
		uint256 nbTokensOwned;
		// Count of paybacks
		uint256 nbPaybacks;
		uint256 paybackAmount;
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
	event ClaimsRepaid(uint256 count, uint256 totalAmount);

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

	modifier positiveInput (uint256 _input) {
		require(_input > 0);
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
    	retentionAmount = INSURANCE_RETENTION;
        
        // Initialize a BehaviourToken
        setBehaviourToken(new BehaviourToken());
        uint256 rideReward = _rideReward; // 1 by default
        setBehaviourTokenReward(rideReward);

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
        positiveInput(_rewardAmount)
    {
    	behaviourToken.approve(_riderAddress, _rewardAmount);
        behaviourToken.transferFrom(insurer, _riderAddress, _rewardAmount);
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
        		grossTokens: 0,
        		nbTokensOwned: 0,
        		nbPaybacks: 0,
        		paybackAmount: 0
        	}
    	);

        // Finally, include client in the mapping
        isClientInsured[msg.sender] = true;

        return isClientInsured[msg.sender];
    }

	function calculatePremium(address insuranceTaker) 
	    view
	    insuredClient(insuranceTaker)
	    returns (uint premium)
	{
	    InsuranceClient memory customer = insuranceMapping[insuranceTaker];
	    return mul((customer.netClaims + 1), premiumRate);
	}

	function viewApplicablePremium (uint256 nbRides)
		view
		public
		insuredClient(msg.sender)
		returns (uint applicablePremium)
	{
		return mul(nbRides, calculatePremium(msg.sender));
	}

	// Big function for the customer to update his/her account of claims, premium, tokens
	function regularizePayments ()
		public
		payable
		insuredClient(msg.sender)
		returns (bool success)
	{
		// Combien de nouveaux trajets ? 
		uint256 newRides = getNewRides(msg.sender);

		if (newRides == 0) return true;

		// Pour les newrides, payer la prime nécessaire
		uint256 pendingPremia = getPendingPremia(msg.sender, newRides);
		require (msg.value == pendingPremia);

		// Update Rides
		updateRides(msg.sender, newRides);
		// Update Paid Premium
		updatePremiumPaid(msg.sender, pendingPremia);

		// How many new claims ? 
		uint256 pendingBadRides = getPendingBadRides(msg.sender);
		require(pendingBadRides <= newRides);

		if (pendingBadRides != 0) {
			// Actualiser le nombre de claims
			updateClaims(msg.sender, pendingBadRides);
			uint paybackAmount = mul(pendingBadRides, getClaimAmount(BIKE_VALUE, retentionAmount));
			// Actualiser le payback
			if (paybackAmount != 0) {
				msg.sender.call.value(paybackAmount);
				emit ClaimsRepaid(pendingBadRides, paybackAmount);
				updatePayback(msg.sender, paybackAmount, pendingBadRides);
			}
		}

		InsuranceClient storage insured = insuranceMapping[msg.sender];	
		require(insured.grossClaims - insured.nbPaybacks == 0);

		// Distribuer les tokens
		uint256 pendingTokens = getPendingTokens(msg.sender);
		// Check : nbTokens = nbGoodRides
		require(insured.grossTokens + pendingTokens == clientMapping[msg.sender].goodRides);

		rewardRider(msg.sender, pendingTokens);
		updateTokenCount(msg.sender, pendingTokens);

		return true;

	}

	// 
	// ===================== View functions =====================
	//

	// @dev : View the Premium that is owed to Insurer
	function getPendingPremia (address insuredAddress, uint256 newRides)
		view
		positiveInput(newRides)
		returns (uint256 pendingPremia)
	{
		return mul(newRides, calculatePremium(insuredAddress));
	}

	// @dev: Retrive the claim amount that will be paid back to the client
	function getClaimAmount(uint grossAmount, uint retention)
		view
		returns (uint claimAmount)
	{
		return sub(grossAmount,retention);
	}

	// @dev: Reads the number of rides (difference between insurance and bike data) 
	function getNewRides (address insuredAddress)
		view
		returns (uint256 countNewRides) 
	{
		InsuranceClient memory insured = insuranceMapping[insuredAddress];
		uint256 ridesCount = clientMapping[insuredAddress].numberRides;

		if (ridesCount > insured.totalRides) {
			uint256 newRides = sub(ridesCount, insured.totalRides);
			return newRides;
		} else {
			return 0;
		}
	}

	// @dev : get the number of bad rides that is not taken into account by insurer 
	// Accounting check -- New claims : number rides - number good rides - number of rides already paid out

	function getPendingBadRides (address insuredAddress)
		view
		returns (uint256 countBadRides)
	{
		InsuranceClient memory insured = insuranceMapping[insuredAddress];
		uint256 numberBadRides = sub(clientMapping[insuredAddress].numberRides, clientMapping[insuredAddress].goodRides);
		return sub(numberBadRides, insured.nbPaybacks);
	}

	// @dev : Get number of tokens the user is eligible to but hasn't received yet

	function getPendingTokens (address insuredAddress)
		view
		returns (uint256 pendingTokens)
	{
		InsuranceClient memory insured = insuranceMapping[insuredAddress];
		uint256 tokenEligibleRides = clientMapping[insuredAddress].goodRides;
		return sub(tokenEligibleRides,insured.grossTokens);
	}

	// 
	// ===================== Updating functions =====================
	//

	// TODO : how to prevent the user to call the update functions ??

	function updatePayback (address insuredAddress, uint256 paybackAmount, uint256 pendingBadRides)
		internal
		positiveInput(paybackAmount)
	{
		InsuranceClient storage insured = insuranceMapping[insuredAddress];		
		insured.nbPaybacks += pendingBadRides;
		insured.paybackAmount += paybackAmount;
	}

	function updateRides (address insuredAddress, uint256 newRides)
		internal
		positiveInput(newRides)
	{
		InsuranceClient storage insured = insuranceMapping[insuredAddress];
		insured.totalRides += newRides;
	}

	function updatePremiumPaid (address insuredAddress, uint256 premiumAmount)
		internal
		positiveInput(premiumAmount)
	{
		InsuranceClient storage insured = insuranceMapping[insuredAddress];
		insured.totalPremiumPaid += premiumAmount;
	}

	// @dev : reconcile number of claims
	function updateClaims (address insuredAddress, uint256 pendingBadRides) 
		internal
		positiveInput(pendingBadRides)
	{
		InsuranceClient storage insured = insuranceMapping[insuredAddress];
		insured.grossClaims += pendingBadRides;
		insured.netClaims += pendingBadRides;
	}

	// @dev : update token count
	function updateTokenCount (address insuredAddress, uint256 pendingTokens)
		internal
		positiveInput(pendingTokens)
	{
		InsuranceClient storage insured = insuranceMapping[insuredAddress];
		insured.grossTokens += pendingTokens;
		insured.nbTokensOwned += pendingTokens;
	}

	// Regularize with number of tokens
	// Check : nbTokens = nbGoodRides

	event TokensClaimExchange (address from, uint256 nbTokens, uint256 claimsInvolved);

	// The insuree has the option to exchange tokens against a reduction of claims
	function tokenClaimReducer(uint256 nbTokens)
		public
		insuredClient(msg.sender)
		returns (bool success)
	{
		require(nbTokens >= CLAIM_TOKEN_RATIO);
		
		uint256 claimsToDecrease = nbTokens.div(CLAIM_TOKEN_RATIO);
		uint256 surplus = nbTokens.mod(CLAIM_TOKEN_RATIO);
		uint256 exchangedTokens = nbTokens.sub(surplus);

		InsuranceClient storage insured = insuranceMapping[msg.sender];
		
		// Give back tokens 
		behaviourToken.transferFrom(msg.sender, insurer, exchangedTokens);

		// Pay back client
		insured.nbTokensOwned -= exchangedTokens;
		insured.netClaims -= claimsToDecrease;

		emit TokensClaimExchange(msg.sender, nbTokens, claimsToDecrease);

		return true;

	}


}