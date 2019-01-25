pragma solidity >=0.4.22 <0.6.0;

import "../installed_contracts/zeppelin/contracts/token/ERC20.sol";
import "../installed_contracts/zeppelin/contracts/token/ERC20Detailed.sol";

contract BehaviourToken is ERC20, ERC20Detailed {
    
    uint8 constant private NO_DECIMALS = 0;
    address private owner;
    
    constructor(string memory tokenName, string memory tokenSymbol)
        ERC20()
        ERC20Detailed(tokenName, tokenSymbol, NO_DECIMALS)
        public
    {
        owner = msg.sender;
    }
    
    function burn(address to, uint256 value) public returns (bool) {
        _burn(to, value);
        return true;
    }
    
    function mint(address to, uint256 value) public returns (bool) {
        _mint(to, value);
        return true;
    }
    
}
