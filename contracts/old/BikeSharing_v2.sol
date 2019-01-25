pragma solidity ^0.5.2;

import "../installed_contracts/zeppelin/contracts/math/SafeMath.sol";

contract BikeSharing {

    using SafeMath for uint256;

    uint256 constant public MAX_BIKE_COUNT = 1000;
    uint constant public BIKE_VALUE = 1 ether;
    uint256 constant public TIME_LIMIT = 1440; // in minutes
    uint256 constant public MINUTE_FACTOR = 60;

    // Hyperparameters

    address bikeAdmin;
    uint requiredDeposit;
    uint256 fee;

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
        require(msg.sender == bikeAdmin);
        _;
    }

    modifier adminExcluded() {
        require(msg.sender != bikeAdmin);
        _;
    }

    modifier bikeClientOnly(address clientAddress) {
        require(isBikeClient[clientAddress] == true);
        _;
    }

    modifier validParametersBike(uint256 bikeId) {
        require(bikeId >= 0 && bikeId < MAX_BIKE_COUNT);
        _;
    }

    modifier notNullAddress (address _address) {
        require(_address != address(0));
        _;
    }

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
    // Ban client event


    // Change of state events
    event BikeAvailable(uint256 bikeId);
    event ClientGoodToGo(address clientAddress);

    event BikeInRide(uint256 bikeId);
    event ClientInRide(address clientAddress);

    event BikeInitiated(uint256 bikeId);
    event BikeDeactivated(uint256 bikeId);
    
    event BikeUsageStart(uint256 bikeId);
    event BikeUsageStop(uint256 bikeId);

    /*
    ================================================================
                            Constructor
    ================================================================
    */ 

    /// @dev Contract constructor sets the bike Admin address, the fee (by minute) and the necessary deposit
    /// @param _fee , put 500 szabo by default
    constructor(uint256 _fee) public {
        bikeAdmin = msg.sender;
        requiredDeposit = BIKE_VALUE;
        fee = _fee;
    }

    /*
    ================================================================
                            Bike housekeeping
    ================================================================
    */ 

    /// @dev Check if the bike is being used for the first time
    /// @param bikeId the ID of a bike
    /// @return True if the bike has never been used, False otherwise
    function isBikeFirstUse(uint256 bikeId) 
        public 
        view 
        returns(bool isFirstTime) 
    {   
        return isBikeActive[bikeId] == false;
    }

    /// @dev Count the number of clients 
    /// @return Number of clients
    function getClientCount() 
        public 
        view 
        returns(uint clientCount)
    {
        return clientList.length;
    }

    /// @dev Check if some address is related to a client
    /// @param clientAdr the address of a client
    /// @return True if the address is a client address

    function isClient(address clientAdr) 
        public 
        view 
        returns (bool isIndeed)
    {
        return isBikeClient[clientAdr] == true;
    }

    /// @dev Check how much the contract carries value
    /// @return Contract balance
    function getBalance() 
        public 
        view
        adminOnly 
        returns(uint balance)
    {
        return address(this).balance;
    }

    /// @dev Check the fee amount for a certain duration (in minutes) for renting the bike
    /// @param duration length 
    /// @return Fee due 
    function calculateFee(uint256 duration) 
        public 
        view 
        returns (uint) 
    {
        uint256 num_minutes = duration.div(MINUTE_FACTOR);
         
        if(num_minutes > TIME_LIMIT){
            return requiredDeposit;
        }
        uint toPay = num_minutes.mul(fee);
        return toPay;
    }

    /// @dev Check Bike Data
    /// @param bikeId give bike's ID
    /// @return Bike data
    function checkBike (uint256 bikeId)
        public
        view
        returns (address lastRenter, bool condition, bool currentlyInUse, uint usageTime, BikeState state)
    {
        Bike memory bike = bikeMapping[bikeId];
        return (bike.lastRenter, bike.condition, bike.currentlyInUse, bike.usageTime, bike.state);
    }

    /// @dev Check Client Data
    /// @param Check client's address 
    /// @return Client Data
    function checkUser (address clientAdr)
        public
        view
        returns (uint clientListPointer, ClientState state, uint received, uint returned, uint256 numberRides, uint256 goodRides)
    {
        Client memory client = clientMapping[clientAdr];
        return (client.clientListPointer, client.state, client.received, client.returned, client.numberRides, client.goodRides);
    }


    /* 
    ================================================================
                        Rent and surrender bikes
    ================================================================
    */

    /// @dev Someone can rent a bike
    /// @param bikeId the client must input the bike id
    /// @return Did it succeed ? How many rides did the client make ? 
    function rentBike(uint256 bikeId) 
        public 
        payable
        validParametersBike(bikeId) 
        adminExcluded
        returns (bool success, uint256 nbRides) 
    {

        // Require that the user pays the right amount for the bike
        require(msg.value == requiredDeposit);

        // Check if the bike is activated
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
            emit BikeInitiated(bikeId);

            bikeMapping[bikeId].state = BikeState.AVAILABLE;
            emit BikeAvailable(bikeId);

        } else {
            
            // The bike must be unused, in good condition, activated, and not in ride already
            require(bikeMapping[bikeId].currentlyInUse == false);
            require(bikeMapping[bikeId].condition == true);
            require(bikeMapping[bikeId].state == BikeState.AVAILABLE);
        }

        // Check if the address is a client, if not create a struct 
        if(!isClient(msg.sender)){

            clientMapping[msg.sender] = Client(
                {
                    clientListPointer: 0,
                    state: ClientState.GOOD_TO_GO,
                    received: 0,
                    returned: 0,
                    numberRides: 0,
                    goodRides: 0
                }
            );

            clientMapping[msg.sender].clientListPointer = clientList.push(msg.sender) - 1;

            // Finally, the guy is made a client
            isBikeClient[msg.sender] = true;
            emit ClientCreated(msg.sender);

        } else {
            // The client must not be already using a scooter
            require(clientMapping[msg.sender].state == ClientState.GOOD_TO_GO);
        }

        // Accounting
        clientMapping[msg.sender].received += requiredDeposit;
        emit LogReceivedFunds(msg.sender, msg.value);

        // Change bike situation and state
        bikeMapping[bikeId].lastRenter = msg.sender;
        bikeMapping[bikeId].currentlyInUse = true;
        emit BikeUsageStart(bikeId);

        bikeMapping[bikeId].usageTime = now;
        bikeMapping[bikeId].state = BikeState.IN_USE;        
        emit BikeInRide(bikeId);

        // Change client state and number of rides
        clientMapping[msg.sender].state = ClientState.IN_RIDE;
        clientMapping[msg.sender].numberRides += 1;
        emit ClientInRide(msg.sender);

        return(bikeMapping[bikeId].currentlyInUse, clientMapping[msg.sender].numberRides);

    }
    
    /// @dev Someone can stop bike usage
    /// @param bikeId The client must input the bike id 
    /// @return Did it succeed ? 
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
        uint feeCharged = calculateFee(now.sub(bikeMapping[bikeId].usageTime));
        uint owedToClient = clientMapping[msg.sender].received.sub(feeCharged);

        bikeMapping[bikeId].currentlyInUse = false;
        emit BikeUsageStop(bikeId);

        if (newCondition == false) {
            owedToClient = 0;
            bikeMapping[bikeId].state = BikeState.DEACTIVATED;
            emit BikeDeactivated(bikeId);
        } else {
            clientMapping[msg.sender].goodRides += 1;
            clientMapping[msg.sender].returned += owedToClient;
            msg.sender.transfer(owedToClient);
            emit LogReturnedFunds(msg.sender, clientMapping[msg.sender].returned);                
            bikeMapping[bikeId].state = BikeState.AVAILABLE;
            emit BikeAvailable(bikeId);
        }

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
        external
        payable
    {
        if (msg.value > 0) {
            emit Deposit(msg.sender, msg.value);
        }
    }


}

