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




}