pragma solidity ^0.5.2;


import "./BehaviourToken.sol"

contract Insurance {

	// Storage

	mapping(address => InsuranceClient) public insuranceMapping;

	struct InsuranceClient {
		uint256 accidentCount;
		uint receivedPremiums;
		uint claimPayouts;
		uint256 tokenCount;
	}

	BehaviourToken public behaviourToken;
	
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


// grossClaims - nbPaybacks = pendingBadRides
    
//  function regularizePaybacks (address insuredAddress)
//      public
//  {
//      // Get the claim count from mapping
//      InsuranceClient storage insured = insuranceMapping[insuredAddress];
//      uint256 pendingBadRides = getPendingBadRides(insuredAddress);
//
//      require(pendingBadRides > 0);
//
//      if (insured.grossClaims - insured.nbPaybacks != pendingBadRides) {
//          updateClaims(insuredAddress, pendingBadRides);
//      } 
//      
//      // Compute payback
//      uint paybackAmount = mul(pendingBadRides, getClaimAmount(BIKE_VALUE, retentionAmount));
//      insuredAddress.call.value(paybackAmount);
//      emit ClaimsRepaid(pendingBadRides, paybackAmount);

        // Update accounting
//      insured.nbPaybacks += pendingBadRides;
//      insured.paybackAmount += paybackAmount;

//      require(insured.grossClaims - insured.nbPaybacks == 0);

//  }




}