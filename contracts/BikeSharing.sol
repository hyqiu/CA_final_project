pragma solidity ^0.5.2;

contract BikeSharing {
    
    // Events
    event OnBikeRent(uint bikeId, address renter, bool status);
    
    // State variables
    address admin;
    uint256 deposit;
    uint256 hourlyFee;
    
    // Data structures
    struct Bike {
        address lastRenter;
        bool condition;
        bool currentlyInUse;
        uint usageTime;
    }
    
    // Modifiers
    /*
    modifier adminOnly() {
        if(msg.sender == _admin) _;
    }
    */
    
    Bike[] public bikes;
    
    constructor(uint bikeCount, uint256 _deposit, uint256 _hourlyFee) public {
        admin = msg.sender;
        deposit = _deposit;
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
    
    function rentBike(uint bikeId) public payable returns (bool) {
        require(bikeId >= 0 && bikeId < bikes.length);
        require(bikes[bikeId].currentlyInUse == false);
        require(msg.value == deposit);
    
        address userAddress = msg.sender;
        
        // Send deposit money to the contract
        admin.call.value(msg.value);
        
        // Change bike situation
        bikes[bikeId].lastRenter = userAddress;
        bikes[bikeId].currentlyInUse = true;
        bikes[bikeId].usageTime = now;
        
        return bikes[bikeId].currentlyInUse;
    }
    
    function calculateFee(uint duration) public view returns (uint) {
        uint num_hours = duration / 3600;
        if(num_hours > 24){
            return deposit;
        }
        uint toPay = num_hours * hourlyFee;
        return toPay;
    }
    
    function surrenderBike(uint bikeId) public payable returns (bool) {
        require(bikes[bikeId].currentlyInUse == true && 
            bikes[bikeId].lastRenter == msg.sender);
        
        uint rentalDuration = now - bikes[bikeId].usageTime; 
        uint split = deposit - calculateFee(rentalDuration);
        
        msg.sender.call.value(split);
        
        return true;
    }
    
    
}