pragma solidity >=0.4.22 <0.6.0;

import "../installed_contracts/zeppelin/contracts/math/SafeMath.sol";
import "./BehaviourToken.sol";
import "./BikeSharing.sol";

contract Insurance {

    using SafeMath for uint256;

    // Constant
    uint256 constant public INSURANCE_RETENTION = 100 finney;
    uint256 constant public CLAIM_TOKEN_RATIO = 5;
    uint256 constant public PREMIUM_RATE = 10 finney;
    uint256 constant public TOKEN_REWARD = 1;

    // Global Variables
    address insurer;
    uint256 premiumRate;
    uint256 retentionAmount;
    
    // InsuredList for count
    address[] insuredList;

    // Storage
    mapping(address => bool) isClientInsured;
    mapping(address => InsuranceClient) insuranceMapping;

    struct InsuranceClient {
        uint256 insuredListPointer;
        uint256 totalPremiumPaid;
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
    uint256 tokenRewardAmount;
    uint256 claimTokenRatio;

    // Create a storage for Bike Shop
    // BikeSharing bikeSharing;

    /*
    ================================================================
                                Events
    ================================================================
    */

    event TokenCreated(address indexed newTokenAddress);
    event TokenRewardSet(uint256 tokenReward);
    event TokenPaid(address indexed insuredAddress, uint256 amount);
    event ClaimsRepaid(uint256 count, uint256 totalAmount);
    event TokensClaimExchange (address indexed from, uint256 nbTokens, uint256 claimsInvolved);
    event Deposit(address indexed sender, uint256 value);
    event TokenApproved(address indexed _riderAddress, uint256 _rewardAmount);


    /*
    ================================================================
                                Modifiers
    ================================================================
    */

    modifier notNullAddress (address _address) {
        require(_address != address(0));
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

    BikeSharing bikeSharing;
    TryToken behaviourToken;
        
    ///@dev Build insurance contract after the bike shop contract

    constructor(address payable _shopAddress, string memory _name, string memory _tokenSymbol)
    //address _tokenAddress) 
        public 
    {
        insurer = msg.sender;
        claimTokenRatio = CLAIM_TOKEN_RATIO;
        premiumRate = PREMIUM_RATE;
        retentionAmount = INSURANCE_RETENTION;
        
        // Initialize a BehaviourToken --> ne marche pas
        //behaviourToken = new BehaviourToken();
        //emit TokenCreated(behaviourToken);
        
        // Version qui marche
        //behaviourToken = TryToken(_tokenAddress);
        //emit TokenCreated(address(behaviourToken));
        
        behaviourToken = new TryToken(_name, _tokenSymbol);
        tokenAddress = address(behaviourToken);
        
        uint256 rideReward = TOKEN_REWARD; // 1 by default
        setBehaviourTokenReward(rideReward);
        
        // CA MARCHE !
        bikeSharing = BikeSharing(_shopAddress);
    }

    /*
    ================================================================
                                Tokens
    ================================================================
    */

    ///@dev Set the reward 
    ///@param _tokenReward : reward attributed to each good ride
    
    function setBehaviourTokenReward(uint256 _tokenReward)
        private
        positiveReward(_tokenReward)
    {
        tokenRewardAmount = _tokenReward;
        emit TokenRewardSet(tokenRewardAmount);
    }

    /*
    ================================================================
                                Insurance
    ================================================================
    */

    ///@dev Public function to underwrite insurance for a client
    function underwriteInsurance()
        external
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

    ///@dev Check the premium applicable to one address
    ///@param insuranceTaker : address of the insurance buyer
    ///@return premium : the eligible amount
    
    function calculatePremium(address insuranceTaker) 
        internal
        view
        insuredClient(insuranceTaker)
        returns (uint256 premium)
    {
        InsuranceClient memory customer = insuranceMapping[insuranceTaker];
        return (customer.netClaims + 1).mul(premiumRate);
    }

    ///@dev Big function for the customer to update his/her account of claims, premium, tokens
    ///@return success : was the payment regularization a success ?

    function regularizePayments ()
        external
        payable
        insuredClient(msg.sender)
        returns (bool success)
    {
        // Combien de nouveaux trajets ? 
        uint256 newRides = getNewRides();
        if (newRides == 0) return true;

        // Pour les newrides, payer la prime nécessaire
        uint256 pendingPremia = getPendingPremia();
        require (msg.value == pendingPremia);

        // Update Rides
        updateRides();
        // Update Paid Premium
        updatePremiumPaid(pendingPremia);

        // How many new claims ? 
        uint256 pendingBadRides = getPendingBadRides();
        require(pendingBadRides <= newRides);

        if (pendingBadRides != 0) {
            // Actualiser le nombre de claims
            updateClaims(pendingBadRides);
            uint256 paybackAmount = pendingBadRides.mul(getClaimAmount(bikeSharing.getBikeValue(), retentionAmount));
            // Actualiser le payback
            if (paybackAmount != 0) {
                msg.sender.call.value(paybackAmount);
                emit ClaimsRepaid(pendingBadRides, paybackAmount);
                updatePayback(paybackAmount, pendingBadRides);
            }
        }

        InsuranceClient storage insured = insuranceMapping[msg.sender]; 
        require(insured.grossClaims - insured.nbPaybacks == 0);
        
        uint256 pendingTokens = getPendingTokens(msg.sender);
        require(insured.grossTokens + pendingTokens == bikeSharing.getGoodRides(msg.sender));
        emit TokenApproved(msg.sender, pendingTokens);
        
        behaviourToken.mint(msg.sender, pendingTokens);
        insured.grossTokens += pendingTokens;
        insured.nbTokensOwned += pendingTokens;
        emit TokenPaid(msg.sender, pendingTokens);

        return true;

    }

    // 
    // ===================== View functions =====================
    //

    /// @dev View the Premium that is owed to Insurer
    /// @return pendingPremia : the premia that are still due for the rides
    function getPendingPremia ()
        view
        public
        returns (uint256 pendingPremia)
    {   
        uint256 newRides = getNewRides();
        return newRides.mul(calculatePremium(msg.sender));
    }

    /// @dev Retrive the claim amount that will be paid back to the client
    /// @param grossAmount : The value of the claim to repay the client
    /// @param retention : the retention (portion of value not reimbursed to client)
    function getClaimAmount(uint256 grossAmount, uint256 retention)
        view
        internal
        returns (uint256 claimAmount)
    {
        return grossAmount.sub(retention);
    }

    /// @dev Reads the number of rides (difference between insurance and bike data) 
    function getNewRides ()
        internal
        view
        returns (uint256 countNewRides) 
    {
        address insuredAddress = msg.sender;
        InsuranceClient memory insured = insuranceMapping[insuredAddress];
        uint256 ridesCount = bikeSharing.getTotalRides(insuredAddress);

        if (ridesCount > insured.totalRides) {
            uint256 newRides = ridesCount.sub(insured.totalRides);
            return newRides;
        } else {
            return 0;
        }
    }

    // Accounting check -- New claims : number rides - number good rides - number of rides already paid out
    /// @dev get the number of bad rides that is not taken into account by insurer 

    function getPendingBadRides ()
        internal
        view
        returns (uint256 countBadRides)
    {
        address insuredAddress = msg.sender;
        InsuranceClient memory insured = insuranceMapping[insuredAddress];
        uint256 numberBadRides = bikeSharing.getTotalRides(insuredAddress).sub(bikeSharing.getGoodRides(insuredAddress));
        return numberBadRides.sub(insured.nbPaybacks);
    }

    /// @dev Get number of tokens the user is eligible to but hasn't received yet

    function getPendingTokens (address insuredAddress)
        private
        view
        returns (uint256 pendingTokens)
    {
        //address insuredAddress = msg.sender;
        InsuranceClient memory insured = insuranceMapping[insuredAddress];
        uint256 tokenEligibleRides = bikeSharing.getGoodRides(insuredAddress);
        return tokenEligibleRides.sub(insured.grossTokens);
    }

    function viewInsuranceStatus (address insuredAddress)
        public
        view
        returns (uint256 insuredListPointer, uint256 totalPremiumPaid, 
        uint256 totalRides, uint256 grossClaims, uint256 netClaims,
        uint256 grossTokens, uint256 nbTokensOwned, uint256 nbPaybacks, uint256 paybackAmount)
    {
        InsuranceClient memory client = insuranceMapping[insuredAddress];
        return (client.insuredListPointer, client.totalPremiumPaid, client.totalRides, 
        client.grossClaims, client.netClaims, client.grossTokens, client.nbTokensOwned, 
        client.nbPaybacks, client.paybackAmount);
    }
    
    // 
    // ===================== Updating functions =====================
    //

    function updatePayback (uint256 paybackAmount, uint256 pendingBadRides)
        internal
        positiveInput(paybackAmount)
    {
        address insuredAddress = msg.sender;
        InsuranceClient storage insured = insuranceMapping[insuredAddress];     
        insured.nbPaybacks += pendingBadRides;
        insured.paybackAmount += paybackAmount;
    }

    function updateRides ()
        internal
    {
        address insuredAddress = msg.sender;
        uint256 newRides = getNewRides();
        InsuranceClient storage insured = insuranceMapping[insuredAddress];
        insured.totalRides += newRides;
    }

    function updatePremiumPaid (uint256 premiumAmount)
        internal
        positiveInput(premiumAmount)
    {
        address insuredAddress = msg.sender;
        InsuranceClient storage insured = insuranceMapping[insuredAddress];
        insured.totalPremiumPaid += premiumAmount;
    }

    // @dev : reconcile number of claims
    function updateClaims (uint256 pendingBadRides) 
        internal
        positiveInput(pendingBadRides)
    {
        address insuredAddress = msg.sender;
        InsuranceClient storage insured = insuranceMapping[insuredAddress];
        insured.grossClaims += pendingBadRides;
        insured.netClaims += pendingBadRides;
    }

    // @dev : update token count
    function updateTokenCount (uint256 pendingTokens)
        internal
        positiveInput(pendingTokens)
    {
        address insuredAddress = msg.sender;
        InsuranceClient storage insured = insuranceMapping[insuredAddress];
        insured.grossTokens += pendingTokens;
        insured.nbTokensOwned += pendingTokens;
    }

    // Regularize with number of tokens
    // Check : nbTokens = nbGoodRides
    
    // The insuree has the option to exchange tokens against a reduction of claims
    function tokenClaimReducer(uint256 nbTokens)
        external
        insuredClient(msg.sender)
        returns (bool success)
    {
    
        InsuranceClient storage insured = insuranceMapping[msg.sender];
        require(insured.nbTokensOwned >= nbTokens);
        require(nbTokens >= CLAIM_TOKEN_RATIO);
        
        uint256 claimsToDecrease = nbTokens.div(CLAIM_TOKEN_RATIO);
        uint256 surplus = nbTokens.mod(CLAIM_TOKEN_RATIO);
        uint256 exchangedTokens = nbTokens.sub(surplus);
    
        // Burn tokens 
        behaviourToken.burn(msg.sender, exchangedTokens);
        // Keep accounting
        insured.nbTokensOwned -= exchangedTokens;
        insured.netClaims -= claimsToDecrease;
    
        emit TokensClaimExchange(msg.sender, nbTokens, claimsToDecrease);
    
        return true;

      }
      

    /* 
    ================================================================
                            Fallback function
    ================================================================
    */

    function ()
        external
        payable
    {
        if (msg.value > 0) {
            emit Deposit(msg.sender, msg.value);
        }
    }

}
