# CA_final_project

- Create a contract that manages the administration of the scooter-renting scheme : people rent a bike in a list, give it back and are charged accordingly
	- [x] Create a fault-less contract on Remix
	- [] Create a mapping, avoiding the constructor to loop and gas overflow
	- [] Allow usage of non-integer (division purposes)
- Create a contract that allows insurance mechanism
- Implement a token-based reward system, which allows for the insurer to handle the deficiency issue
|                     |                            User bought insurance                           |   User didn't buy insurance  |
|---------------------|:--------------------------------------------------------------------------:|:----------------------------:|
|       No claim      | Token rewarded to user                                                     | Nothing happens              |
|  Claim by last user | No token rewarded to user The insurer pays 80%, the user 20%               | User must redeem the deposit |
| Claim by other user | Token count is forced to 0 (dishonesty) The insurer pays 20%, the user 80% | User must redeem the deposit |