pragma solidity ^0.5.2;

import "../installed_contracts/zeppelin/contracts/math/SafeMath.sol";

contract BikeSharing {

	using SafeMath for uint256;

	uint constant public MAX_BIKE_COUNT = 1000;
	uint constant public BIKE_VALUE = 1 ether;

    // Hyperparameters

    address admin;
    uint requiredDeposit;
    uint256 hourlyFee;

    // Mappings
    mapping(address => Client) internal clientMapping;
    mapping(uint256 => Bike) bikeMapping; // not public 
    mapping(uint256 => bool) isBikeActive; // not public
    mapping(address => bool) isBikeClient; // notpublic

    // ClientLists for count

    address[] public clientList;

    /*
    ================================================================
                            Data structures
    ================================================================
    */ 

    enum BikeState {DEACTIVATED, AVAILABLE, IN_USE}
    enum ClientState {BANNED, GOOD_TO_GO, IN_RIDE}

    struct Bike {
        address lastRenter;
        bool condition;
        bool currentlyInUse;
        uint usageTime;
        BikeState state;
    }
    
    struct Client {
    	uint clientListPointer;
    	ClientState state;
    	// For 1 ride, how much received and returned
        uint received;
        uint returned;
    	// Count of number of rides, number of good rides
    	uint256 numberRides;
    	uint256 goodRides;
    }

    /*
    ================================================================
                            Modifiers
    ================================================================
    */ 

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

    modifier notNullAddress (address _address) {
        require(_address != 0);
        _;
    }

	// TODO : a customer cannot rent another bike while he's riding one

    modifier bikeInRide (uint bikeId) {
        require(bikeMapping[bikeId].state == BikeState.IN_USE);
        _;
    }

    modifier bikeUser (uint bikeId, address clientAdr) {
        require(bikeMapping[bikeId].lastRenter == clientAdr);
        _;
    }

    modifier clientInRide (address clientAdr) {
        require(clientMapping[clientAdr].state == ClientState.IN_RIDE);
        _;
    }


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

    // Client creation
    event ClientCreated(address clientAddress);

    // Change of state events
    event BikeAvailable(uint bikeId);
    event ClientGoodToGo(address clientAddress)

    event BikeInRide(uint bikeId);
    event ClientInRide(address clientAddress);

    event BikeDeactivated(uint bikeId);

    /*
    ================================================================
                            Constructor
    ================================================================
    */ 

    constructor(uint256 _hourlyFee) public {
    	bikeAdmin = msg.sender;
    	requiredDeposit = BIKE_VALUE;
    	hourlyFee = _hourlyFee;
    }

    /*
    ================================================================
                            Bike housekeeping
    ================================================================
    */ 


    // Check if a bike has been used, if not

    function isBikeFirstUse(uint256 bikeId) 
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
        returns (bool success, uint256 nbRides) 
    {

        // Require that the user pays the right amount for the bike
        require(msg.value == requiredDeposit);

        // Check if the bike is activated
        // TODO : Make function that says : "Make Bike Available"

        if(isBikeFirstUse(bikeId)) {
            bikeMapping[bikeId] = Bike(
                {
                    lastRenter: address(0),
                    condition: true,
                    currentlyInUse: false,
                    usageTime: 0,
                    state: BikeState.DEACTIVATED
                }
            );
            isBikeActive[bikeId] = true;
            bikeMapping[bikeId].state = BikeState.AVAILABLE;
            emit BikeAvailable(bikeId);

        } else {
            // The bike must be unused, in good condition, activated, and not in ride already
            require(bikeMapping[bikeId].currentlyInUse == false);
            require(bikeMapping[bikeId].condition == true);
            require(bikeMapping[bikeId].state == BikeState.AVAILABLE);
        }

        // Check if the address is a client, if not create a struct 
        // TODO : Make function that says : "Make client Good to Go"
        if(!isClient(msg.sender)){

            clientMapping[msg.sender] = Client(
                {
                    received: 0,
                    returned: 0,
                    clientListPointer: 0,
                    state: ClientState.GOOD_TO_GO
                }
            );

            clientMapping[msg.sender].clientListPointer = clientList.push(msg.sender) - 1;
            // Finally, the guy is made a client
            isBikeClient[msg.sender] = true;
            emit ClientCreated(msg.sender);
        } else {
            // The client must not be already using a scooter
            // TO TEST
            require(clientMapping[msg.sender].state == ClientState.GOOD_TO_GO);
        }

        // Accounting

        clientMapping[msg.sender].received += requiredDeposit;
        emit LogReceivedFunds(msg.sender, msg.value);

        // Change bike situation and state
        bikeMapping[bikeId].lastRenter = msg.sender;
        bikeMapping[bikeId].currentlyInUse = true;
        bikeMapping[bikeId].usageTime = now;
        bikeMapping[bikeId].state = BikeState.IN_USE;        
        emit BikeInRide(bikeId);

        // Change client state
        clientMapping[msg.sender].state = ClientState.IN_RIDE;         
        emit ClientInRide(msg.sender);

        // Change number of rides

        clientMapping[msg.sender].numberRides += 1;

        return bikeMapping[bikeId].currentlyInUse, clientMapping[msg.sender].numberRides;

    }

    function surrenderBike(uint bikeId, bool newCondition) 
        public 
        bikeClientOnly(msg.sender)
        validParametersBike(bikeId)
        bikeInRide(bikeId)
        clientInRide(msg.sender)
        bikeUser(bikeId, msg.sender)
        adminExcluded
        returns (bool success) 
    {

        // Compute the amount charged for the bike
        uint feeCharged = calculateFee(now - bikeMapping[bikeId].usageTime);
        uint owedToClient = clientMapping[msg.sender].received - feeCharged;

        if (newCondition == false) {
        	owedToClient = 0;
            bikeMapping[bikeId].state = BikeState.DEACTIVATED;
            emit BikeDeactivated(bikeId);
        } else {
        	clientMapping[msg.sender].goodRides += 1;
        	bikeMapping[bikeId].state = BikeState.AVAILABLE;
        	emit BikeAvailable(bikeId);
        }

        // Update the transaction
        clientMapping[msg.sender].returned += owedToClient;

        if(clientMapping[msg.sender].returned != 0) {
            msg.sender.call.value(owedToClient));    
        }

        emit LogReturnedFunds(msg.sender, clientMapping[msg.sender].returned);
        // Reset the accounting for the client
        clientMapping[msg.sender].received = 0;
        clientMapping[msg.sender].returned = 0;
        
        // Make the client good to go

        clientMapping[msg.sender].state = ClientState.GOOD_TO_GO;
        emit ClientGoodToGo(msg.sender);

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

