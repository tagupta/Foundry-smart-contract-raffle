// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title A sample raffle contract
 * @author Tanu Gupta
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRF2.5
 */
contract Raffle{
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();

    uint private immutable i_entranceFee;
    address payable [] private s_players;
    
    /* Events */
    event RaffleEntered(address indexed player);

    constructor(uint _entranceFee) {
        i_entranceFee = _entranceFee;
    }
    
    /**
     * dev: Need users to enter this raffle by adding some entrance fee.
     */
    function enterRaffle() payable external{
        if(msg.value < i_entranceFee) revert Raffle__SendMoreToEnterRaffle();
        //Adding custom error to require statements
        // require(msg.value >= i_entranceFee, SendMoreToEnterRaffle());
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    function pickWinners() external {
    }

    /**Getter Functions */
    function getEntranceFee() external view returns(uint){
        return i_entranceFee;
    }

}