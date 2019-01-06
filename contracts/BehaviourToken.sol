pragma solidity ^0.5.2;

import "../installed_contracts/zeppelin/contracts/token/StandardToken.sol";
import "../installed_contracts/zeppelin/contracts/ownership/Ownable.sol";

contract BehaviourToken is StandardToken, Ownable {

	string public constant name = "BehaviourToken";
	string public constant symbol = "BHT";
	uint8 public constant decimals = 18;

	uint256 public constant INITIAL_SUPPLY = 10000 * (10 ** uint256(decimals));

	constructor() public {
		totalSupply_ = INITIAL_SUPPLY;
		balances[msg.sender] = INITIAL_SUPPLY;
		emit Transfer(0x0, msg.sender, INITIAL_SUPPLY);
	}

}