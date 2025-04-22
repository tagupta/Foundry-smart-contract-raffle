// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample raffle contract
 * @author Tanu Gupta
 * @notice This contract is for creating a sample raffle system using chainlink automation and randomization
 * @dev Implements Chainlink VRF2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__RaffleNotEndedYet();
    error Raffle__WinnerTransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpKeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);

    /* Type Declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* State variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint16 private constant NUM_WORDS = 1;

    bytes32 private immutable i_KeyHash;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval; //@dev the duration of the lottery in seconds
    uint256 private immutable i_subscriptionID;
    uint32 private immutable i_callbackGasLimit;

    uint256 private s_lastTimeStamp;
    address payable[] private s_players;
    address payable private s_recentWinner;
    RaffleState private s_raffleState;

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 _entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionID,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = _entranceFee;
        i_interval = interval;
        i_KeyHash = gasLane;
        i_subscriptionID = subscriptionID;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    /**
     * @dev Need users to enter this raffle by adding some entrance fee.
     * @dev Enter raffle if only the state is open, revert if the state is calculating;
     */
    modifier isRaffleOpen() {
        if (s_raffleState != RaffleState.OPEN) revert Raffle__RaffleNotOpen();
        _;
    }

    function enterRaffle() external payable isRaffleOpen {
        if (msg.value < i_entranceFee) revert Raffle__SendMoreToEnterRaffle();
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev Automating the process of picking up winners using Chainlink automation
     * @dev this function will be called by the Automation network nodes to see if lottery is ready to have a winner
     * @dev the following should be true in order for upkeepNeeded to be true:
     * 1. The time inetrval has passed bewteen raffle runs.
     * 2. The lottery is in OPEN state.
     * 3. The contract has ETH deposited.
     * 4. The contract has players entered the raffle
     * 5. Implicitly, your subscription has LINK.
     * @param - ignored
     * @return upkeepNeeded boolean to suggest when should the winner be picked.
     * @return - ignored
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool hasTimePassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = hasTimePassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    /**
     * @dev check whether the raffle has ended or not?
     * @dev Pick a random number to be less than the size of players array.
     * @dev Using that number, select that random winner.
     * @dev This function has to be called automatically.
     */
    function performUpkeep(bytes calldata /* performData */ ) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpKeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        //Getting the random numbers:
        //1. Request RNG -> chainlink coordinator automatically calls the fulfillRandomWords() as a callback function.
        //2. Get RNG.
        s_raffleState = RaffleState.CALCULATING;
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_KeyHash, //gas price
            subId: i_subscriptionID,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit, //gas limit
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(uint256, /*requestId */ uint256[] calldata randomWords) internal override {
        //Find the index of the random winner using the random number.

        // Effect (Internal contract state changes)
        uint256 indexOfwinner = randomWords[0] % s_players.length; //0 - (s_players.length - 1);
        address payable recentWinner = s_players[indexOfwinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(recentWinner);

        //Interaction (External contract changes)
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) revert Raffle__WinnerTransferFailed();
    }

    /**
     * Getter Functions
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayersArray() external view returns (address payable[] memory) {
        return s_players;
    }

    function getPlayer(uint256 index) external view returns (address payable) {
        return s_players[index];
    }

    function getTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
