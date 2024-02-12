////////////////////////////////
//// Preparation, tooling //////
////////////////////////////////


1. static analysis (does not run the code) tool Slither
   1. install it,
   2. add the installation directiory to PATH
   3. run it:
        slither .
2. install static analysis (does not run the code) tool Aderyn, then run it
   1. install it,
   2. add the installation directiory to PATH
   3. run it:
        aderyn .

3. run solidity metrics by right clicking on the contract file and selecting "solidity metrics" from the dropdown

4. install the add-on/extension "Solidity visual developer" to get different kinds of vars clearly sxntax-highlighted (immutable, constant, state var, args, etc)

////////////////////////////////
//// Static analysis ///////////
////////////////////////////////


1. Slither
    - To exclude dependencies, run `slither . --exclude-dependencies`   (excludes files from the lib folder)
    - To exlcude in-line assembly related stuff, use `slither . --exclude assembly`
    - By default, slither checks test files too, as well as imported stuff. To filter them out, use path filtering e.g. 
        `slither . --filter-paths /home/orgovaan/security/4-puppy-raffle-audit/test --filter-paths "openzeppelin"`
    - If the output with `slither .` is still too much, use 
        `slither . --exclude-informational` or
        `slither . --exclude-optimization`
    - If upon review, we think that what slither found is not an issue:
        1. Add `slither-disable-next-line <DETECTOR NAME` above the line of code in question
    - WHAT REALLY WORKED FOR ME HERE IS 
         `slither . --exclude-dependencies --filter-paths /home/orgovaan/security/4-puppy-raffle-audit/test` OR
         `slither . --filter-paths /home/orgovaan/security/4-puppy-raffle-audit/test --exclude assembly`


////////////////////////////////
//// Attack vectors ////////////
////////////////////////////////


1. DoS (Denial of service): 
A trx that is being prevented from being executed when it really needs to be. Slither most of the time catches these. Can be caused by a number of things:
   1. unbounded for loop (block gas limit reached)
   2. an external call failing and preventing the trx to go through. An external call can be as simple as sending ETH!
      1. sending eth to a contract that does not accept it
      2. calling a function that does not exist on the contract we are calling it on AND that contract has no fallback function
      3. the external call execution runs out of gas
      4. third-party contract/address acts maliciously
   
1. Reentrancy: 
When a contract makes an external call to another untrusted contract before it finishes its execution. Slither caught this. If an external function call is made, it can reenter the caller contract function before updating state. How to avoid:
   a. This is where CEI (checks, effects, interactions) is really important. 
   b. Or one can use OpenZeppelin's NonReentrancyGuard (basically performs a MUTEX LOCK that we can also easily implement).
   c. Static analysis tools help find these vulnaribilites (will be marked yellow).

1. Weak randomness exploit: 
      1. to some extent, miners can influence `now`, `block.timestamp`, `blockhash` (or `prevrandao` came in to replcae difficulty). If a semi-RNG is based on a modulo on these, that is a problem. These are manipulatable or we can anticipate them. 
      2. Basing randomness on `msg.sender` (hashed with some other values) also results in weak randomness, as ppl can mine for addresses that results in a random number favorable to them.
      3. Blockchain is a deterministic system. So randomness should not be based on values from the blockchain.
   Fixes:
   a. Chainlink VRF
   b. Commit Reveal Scheme


4. Mishandling ETH:
Broad subject, there are a lot of different ways to mishandle ETH.
   1. Using selfdescturct, force ETH to a smart contract that, lacking a fallback or receive function, would otherwise block incoming ETH.
    Forced ETH could mess up the contract logic if it is not prepared for such scenarios.
    2. Push over pull

5. Supply chain attack:
If a protocol is using some external library or external contracts, it is always a good idea to look into the security disclosures of the specific package!

6. Missing / wrong / manipulated events:
A lot of external tools read events. They have to be 100% correct. If not, that is at least a low severity issue.

   