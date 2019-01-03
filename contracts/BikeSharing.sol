pragma solidity ^0.5.2;

contract BikeSharing {
        
    // State variables
    address admin;
    uint256 requiredDeposit;
    uint256 hourlyFee;
    
    mapping(address => Client) public clientStructs;
    address[] public clientList;

    // Data structures
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

    // Modifiers
    /*
    modifier adminOnly() {
        if(msg.sender == _admin) _;
    }
    */
    
    // Events
    event LogBikeRent(uint bikeId, address renter, bool status);
    event LogReceivedFunds(address sender, uint amount);
    event LogReturnedFunds(address recipient, uint amount);

    Bike[] public bikes;
    
    constructor(uint bikeCount, uint256 _requiredDeposit, uint256 _hourlyFee) public {
        admin = msg.sender;
        requiredDeposit = _requiredDeposit;
        hourlyFee = _hourlyFee;
        
        for (uint i=0; i<bikeCount; i++) {
            bikes.push(Bike({
                lastRenter: address(0),
                condition: true,
                currentlyInUse: false,
                usageTime: 0
            }));
        }
    } 
    
    function getClientCount() public view returns(uint clientCount){
        return clientList.length;
    }

    function isClient(address client) public view returns (bool isIndeed){
        if (clientList.length == 0) return false;
        return clientList[clientStructs[client].clientListPointer] == client;
    }

    function getBalance() public view returns(uint){
        return address(this).balance;
    }

    function rentBike(uint bikeId) public payable returns (bool) {
        require(msg.sender.balance >= requiredDeposit && msg.value >= requiredDeposit);
        require(bikeId >= 0 && bikeId < bikes.length);
        require(bikes[bikeId].currentlyInUse == false);
        
        // If client is not yet a client

        if(!isClient(msg.sender)){
            clientStructs[msg.sender].clientListPointer = clientList.push(msg.sender) - 1;
        }
        
        clientStructs[msg.sender].received += msg.value;

        emit LogReceivedFunds(msg.sender, msg.value);

        // Change bike situation
        bikes[bikeId].lastRenter = msg.sender;
        bikes[bikeId].currentlyInUse = true;
        bikes[bikeId].usageTime = now;
        
        emit LogBikeRent(bikeId, msg.sender, bikes[bikeId].currentlyInUse);

        return bikes[bikeId].currentlyInUse;

    }
    
    function calculateFee(uint duration) public view returns (uint) {
        uint num_hours = duration / 3600;
        if(num_hours > 24){
            return requiredDeposit;
        }
        uint toPay = num_hours * hourlyFee;
        return toPay;
    }
    
    function surrenderBike(uint bikeId) public returns (bool success) {
        require(bikes[bikeId].currentlyInUse == true && 
            bikes[bikeId].lastRenter == msg.sender);
        
        if(!isClient(msg.sender)) revert();

        uint feeCharged = calculateFee(now - bikes[bikeId].usageTime);

        uint owedToClient = clientStructs[msg.sender].received - feeCharged;

        clientStructs[msg.sender].returned += owedToClient;
        
        msg.sender.call.value(owedToClient));

        emit LogReturnedFunds(msg.sender, owedToClient);
        
        return true;
    }
    
    
}