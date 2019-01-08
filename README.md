# CA_final_project

- Create a contract that manages the administration of the scooter-renting scheme : people rent a bike in a list, give it back and are charged accordingly
	- [x] Create a fault-less contract on Remix
	- [] Create a mapping, avoiding the constructor to loop and gas overflow
	- [] Allow usage of non-integer (division purposes)
	- [] The deposit can only be redeemed 2 days later (2 days are sufficient for another one to make a claim)
- Create a contract that allows insurance mechanism
- Implement a token-based reward system, which allows for the insurer to handle the deficiency issue

|                     |                            User bought insurance                           |   User didn't buy insurance  |
|---------------------|:--------------------------------------------------------------------------:|:----------------------------:|
|       No claim      | Token rewarded to user                                                     | Nothing happens              |
|  Claim by last user | No token rewarded to user The insurer pays 80%, the user 20%               | User must redeem the deposit |
| Claim by other user | Token count is forced to 0 (dishonesty) The insurer pays 20%, the user 80% | User must redeem the deposit |

What can an insurance contract do ? 
- Record keeping for the token
- Keep a balance of premia and claim fees for auditability
- Receives the subscription money

Workflow : 
- Buy insurance.
	- The client buys insurance (pays a premium upfront)
	- Then, will pay small premium every time they rent a bike
- Rent bike. 
	- The client rents a bike
	- The admin checks on public insurance record if the guy is insured. 
		- The premium is paid according to past accident count if insured
	- The deposit will be the same for everyone.
- At end of ride, the renter : 
	- Can file a claim if the scooter is not in good shape any more. 
	- Communicates with insurer to have the guy gain extra points.
	- If there is an accident : 
		* The bike sharing contract can modify the count of accident. 
		* The insurance contract will automate payment of one bike

Ideas : 
- Customer can reduce their accident count by redeeming a token --> TO IMPLEMENT
- Ban client (last resort, after fake declaration) --> TO IMPLEMENT
- A Proof-of-Existence contract where you must prove the bike still looks good. 
- Send to repair shop the broken ones if it falls below a certain threshold ? 
- Add IPFS geolocation ? 

===========

- Initialize a number of deployed. 
- When it is used for the first time, push it into the array !

- IF THE BIKE IS BROKEN, DEACTIVATE IT

===========

Possible tests : 
- How much does the insured pay ? 
- 5 tokens = -1 accidentCount

===========

- Security issue : what if the guy rents another one ? OK --> added enums
