// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from '@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol';

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;
    address public PLAYER = makeAddr("player");
    uint256 entranceFee;
    uint256 interval;
    uint256 subscriptionID;
    bytes32 gasLane;
    address vrfCoordinator;
    uint32 callbackGasLimit;
    
    modifier raffleEntered() {
        uint256 startTime = block.timestamp;
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        //To make enough time pass simulate the new time interval
        vm.warp(startTime + interval + 1);
        vm.roll(block.number + 1);
        _;
    }
    /*//////////////////////////////////////////////////////////////
                               TEST SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        entranceFee = networkConfig.entranceFee;
        interval = networkConfig.interval;
        subscriptionID = networkConfig.subscriptionID;
        gasLane = networkConfig.gasLane;
        vrfCoordinator = networkConfig.vrfCoordinator;
        callbackGasLimit = networkConfig.callbackGasLimit;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }
    /*//////////////////////////////////////////////////////////////
                            INITIAL TESTING
    //////////////////////////////////////////////////////////////*/

    function testRaffleInitializesInOpenState() external view {
        assert(Raffle.RaffleState.OPEN == raffle.getRaffleState());
    }

    function test_RaffleStartsWithZeroBalance() external view {
        uint256 balance = address(raffle).balance;
        assertEq(balance, 0);
    }

    function test_RaffleStartsWithEmptyPlayers() external view {
        uint256 playersLength = raffle.getPlayersArray().length;
        assertEq(playersLength, 0);
    }

    /*//////////////////////////////////////////////////////////////
                              ENTER RAFFLE
    //////////////////////////////////////////////////////////////*/
    function test_RevertWhen_RaffleEnteredWithLessEntryFee() external {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function test_CheckEnterRaffleWithEnoughFunds() external {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        assertEq(raffle.getPlayersArray().length, 1);
        assertEq(PLAYER, raffle.getPlayer(0));
    }

    function test_EventIsEmittedOnEnteringRaffle() external {
        vm.expectEmit(true, false, false, false, address(raffle));
        emit Raffle.RaffleEntered(PLAYER);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: STARTING_PLAYER_BALANCE}();
    }

    function test_DontAllowPlayersToEnterWhileRaffleIsCalculating() external raffleEntered{

        raffle.performUpkeep(""); //<-
            // assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);

        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    /*//////////////////////////////////////////////////////////////
                              CHECKUPKEEP
    //////////////////////////////////////////////////////////////*/
    function test_CheckUpKeep_ReturnsFalseIfNoBalance() external {
        uint256 startTime = block.timestamp;
        vm.warp(startTime + interval + 1);
        vm.roll(block.number + 1);

        (bool upKeepNeeded,) = raffle.checkUpkeep("");
        assertEq(upKeepNeeded, false);
    }

    function test_CheckUpKeep_ReturnsFalseIfRaffleNotOpen() external raffleEntered{
        raffle.performUpkeep("");
        (bool upKeepNeeded,) = raffle.checkUpkeep("");
        assertEq(upKeepNeeded, false);
    }

    function test_CheckUpKeep_ReturnsFalseIfTimeNotPassed() external {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assertEq(upkeepNeeded, false);
    }

    function testCheckUpKeepReturnsTrueWhenParametersAreGood() external raffleEntered{
        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        //Assert
        assertEq(upkeepNeeded, true);
    }

    function testCheckUpKeepReturnsFalseIfEnoughTimeHasntPassed() external {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        //Assert
        assertEq(upkeepNeeded, false);
    }
    /*//////////////////////////////////////////////////////////////
                             PERFORMUPKEEP
    //////////////////////////////////////////////////////////////*/

    function test_PerformUpKeepRevertsIfCheckupKeepReturnsFalseFor_NotEnoughTimePassed() external {
        //Arrange
        uint256 balance = 0;
        uint256 playersLength = 0;
        uint256 raffleState = uint256(raffle.getRaffleState()); // closed state
        // Encode the expected error with parameters
        raffle.enterRaffle{value: entranceFee}();
        balance += address(raffle).balance;
        playersLength += raffle.getPlayersArray().length;

        bytes memory expectedError =
            abi.encodeWithSelector(Raffle.Raffle__UpKeepNotNeeded.selector, balance, playersLength, raffleState);

        //Act/Assert
        vm.expectRevert(expectedError);
        raffle.performUpkeep("");
    }

    function test_PerformUpKeepSelectsWinner() external raffleEntered{
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 eventSig = keccak256("WinnerPicked(address)");

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventSig) {
                address addr = abi.decode(logs[i].data, (address));
                assertEq(addr, PLAYER);
                return;
            }
        }
    }

    function test_PerformUpKeepUpdatesRaffleStateAndEmitsRequestId() external raffleEntered{
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 eventSig = keccak256("RequestedRaffleWinner(uint256)");
        uint256 raffleState = uint256(raffle.getRaffleState());
        uint256 calculatingState = uint256(Raffle.RaffleState.CALCULATING);

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventSig) {
                uint256 requestId = uint256(logs[i].topics[1]);
                // Use the requestId
                assertTrue(requestId > 0, "Invalid request ID");
                return;
            }
        }
        assertEq(raffleState, calculatingState);
    }    
    /*//////////////////////////////////////////////////////////////
                           FULFILLRANDOMWORDS
    //////////////////////////////////////////////////////////////*/
    
    //Stateless Fuzz test with random request id
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpKeep(uint256 randomRequestID) external raffleEntered{
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestID, address(raffle));
    }
}
