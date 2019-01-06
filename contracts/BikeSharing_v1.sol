pragma solidity ^0.5.2;

import "../installed_contracts/zeppelin/contracts/math/SafeMath.sol";
import "./BehaviourToken.sol"

contract BikeSharing {

    using SafeMath for uint256;
    
    // CONSTANTS

    uint constant public MAX_BIKE_COUNT = 1000;
    uint constant public DAMAGE_PAYMENT = 1 ether;
    uint constant public INSURANCE_RETENTION = 500 finney; 

    /*
    ================================================================
                            State variables
    ================================================================
    */ 

    // Hyperparameters

    address admin;
    uint256 requiredDeposit;
    uint256 hourlyFee;
    uint256 premiumRate;

    // Bike sharing 

    mapping(address => Client) public clientMapping;
    mapping(uint256 => Bike) public bikeMapping;
    mapping(uint256 => bool) public isBikeActive;
    mapping(address => bool) public isBikeClient;

    address[] public clientList;
    uint256 public toRepair; 

    // Insurance

    mapping(address => bool) public isClientInsured;
    mapping(address => InsuranceClient) public insuranceMapping;

    /*
    ================================================================
                            Data structures
    ================================================================
    */ 

    struct Bike {
        address lastRenter;
        bool condition;
        bool currentlyInUse;
        uint usageTime;
    }
    
    struct Client {
        uint received;
        uint returned;
        uint clientListPointer;
    }

    struct InsuranceClient {
        uint accidentCount;
        uint receivedPremiums; 
        uint claimPayouts;
        uint tokenCount;
    }

    /*
    ================================================================
                            Modifiers
    ================================================================
    */ 

    /*
    modifier adminOnly() {
        if(msg.sender == _admin) _;
    }
    */
    
    // Modifier not disallow the admin to rent bike 

    modifier adminOnly() {
        require(msg.sender == admin);
        _;
    }

    modifier adminExcluded() {
        require(msg.sender != admin);
        _;
    }

    modifier bikeClientOnly(address clientAddress) {
        require(isBikeClient[clientAddress] == true);
        _;
    }

    modifier validParametersBike(uint bikeId) {
        require(bikeId >= 0 && bikeId < MAX_BIKE_COUNT);
        _;
    }

    // TODO : a customer cannot rent another bike while he's riding one


    /*
    ================================================================
                            Events
    ================================================================
    */ 

    event LogBikeRent(uint bikeId, address renter, bool status);
    event LogReceivedFunds(address sender, uint amount);
    event LogReturnedFunds(address recipient, uint amount);

    // Fallback event
    event Deposit(address indexed sender, uint256 value);

    /*
    ================================================================
                            Constructor
    ================================================================
    */ 

    constructor(uint256 _hourlyFee, uint256 _premiumRate) public {
        admin = msg.sender;
        requiredDeposit = DAMAGE_PAYMENT;
        hourlyFee = _hourlyFee;
        premiumRate = _premiumRate;
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

    function payToken(address insured)
        public
        returns (bool success)
    {

    }

    /*
    ================================================================
                            Bike housekeeping
    ================================================================
    */ 

    // Check if a bike has been used, if not

    function bikeFirstUse(uint256 bikeId) 
        public 
        view 
        returns(bool isFirstTime) 
    {   
        return isBikeActive[bikeId] == false;
    }

    function getClientCount() public view returns(uint clientCount){
        return clientList.length;
    }

    function isClient(address client) 
        public 
        view 
        returns (bool isIndeed)
    {
        return isBikeClient[client] == true;
    }

    function getBalance() public view returns(uint){
        return address(this).balance;
    }

    function calculateFee(uint duration) public view returns (uint) {
        uint num_hours = div(duration, 3600);
        if(num_hours > 24){
            return requiredDeposit;
        }
        uint toPay = num_hours * hourlyFee;
        return toPay;
    }

    /* 
    ================================================================
                        Rent and surrender bikes
    ================================================================
    */

    function rentBike(uint bikeId) 
        public 
        payable
        validParametersBike(bikeId) 
        adminExcluded
        returns (bool) 
    {
        
        // Require that the bikeId remains in the desired interval
        require(bikeId >= 0 && bikeId < MAX_BIKE_COUNT);

        // Check if the bike is activated

        if(bikeFirstUse(bikeId)) {
            bikeMapping[bikeId] = Bike(
                {
                    lastRenter: address(0),
                    condition: true,
                    currentlyInUse: false,
                    usageTime: 0
                }
            );
            isBikeActive[bikeId] = true;
        } else {
            // The bike must be unused and in good condition
            require(bikeMapping[bikeId].currentlyInUse == false);
            require(bikeMapping[bikeId].condition == true);
        }

        // Check if the address is a client, if not create a struct 
        if(!isClient(msg.sender)){
            clientMapping[msg.sender].clientListPointer = clientList.push(msg.sender) - 1;
            clientMapping[msg.sender].received = 0;
            clientMapping[msg.sender].returned = 0;
            // Finally, the guy is made a client
            isBikeClient[msg.sender] = true;
        }
        
        // Check if the client is insured
        if(isClientInsured[msg.sender]==true) {
            
            uint256 premium = calculatePremium(msg.sender);
            require(msg.value == requiredDeposit + premium);
            InsuranceClient memory policyholder = insuranceMapping[msg.sender];

            // TODO : the premium has to be transferred to the insurance company !!
            policyholder.receivedPremiums += premium;

        } else {
            // Require that the requiredDeposit is paid in full
            require(msg.value == requiredDeposit);
        }

        clientMapping[msg.sender].received += requiredDeposit;

        /* Make sure that the client has insurance */

        emit LogReceivedFunds(msg.sender, msg.value);

        // Change bike situation

        bikeMapping[bikeId].lastRenter = msg.sender;
        bikeMapping[bikeId].currentlyInUse = true;
        bikeMapping[bikeId].usageTime = now;

        emit LogBikeRent(bikeId, msg.sender, bikeMapping[bikeId].currentlyInUse);

        return bikeMapping[bikeId].currentlyInUse;

    }
     
    function surrenderBike(uint bikeId, bool newCondition) 
        public 
        bikeClientOnly(msg.sender)
        validParametersBike(bikeId)
        adminExcluded
        returns (bool success) {
        
        require(bikeMapping[bikeId].currentlyInUse == true);
        require(bikeMapping[bikeId].lastRenter == msg.sender);

        /* ============== Bike ============== */

        // Compute the amount charged for the bike
        uint feeCharged = calculateFee(now - bikeMapping[bikeId].usageTime);
        uint owedToClient = clientMapping[msg.sender].received - feeCharged;
        
        /* ============== Insurance ============== */

        if (isClientInsured[msg.sender] == true) {

            InsuranceClient storage policyholder = insuranceMapping[msg.sender];

            if (newCondition == false) {
                // The dude will not be charged (or a little extra)
                // TODO :  How is the insurer going to pay the charge ?? 
                owedToClient = 0;

                // His count of accident changes
                policyholder.accidentCount += 1;

                // His payout also. THIS IS A NET VALUE, NORMALLY THE CLIENT IS OWED NOTHING
                policyholder.claimPayouts += DAMAGE_PAYMENT;
                // The insurance will pay for the deposit. 

                // Eventually, the guy will be paid back by the insurer. 
                owedToClient += DAMAGE_PAYMENT - INSURANCE_RETENTION;


                // TODO : MAKE THE SCOOTER UNRENTABLE


            } else {
                // Good shape : will gain a token

                policyholder.tokenCount += 1;
                // TODO : implement a TOKEN
            }

        } else {
            // If bad condition, then the guy is owed nothing
            if (newCondition == false) {
                owedToClient = 0;

                // TODO : MAKE THE SCOOTER UNRENTABLE

            }
        }

        /* ============== Accounting / Housekeeping ============== */

        // Update the transaction
        clientMapping[msg.sender].returned += owedToClient;
        
        // Pay back the remainder

        if(clientMapping[msg.sender].returned != 0) {
            msg.sender.call.value(owedToClient));    
        }

        emit LogReturnedFunds(msg.sender, clientMapping[msg.sender].returned);

        // Reset the accounting for the client
        clientMapping[msg.sender].received = 0;
        clientMapping[msg.sender].returned = 0;
        
        return true;
    }
    
    /* 
    ================================================================
                            Fallback function
    ================================================================
    */

    function ()
        public
        payable
    {
        if (msg.value > 0) {
            emit Deposit(msg.sender, msg.value);
        }
    }


    
}