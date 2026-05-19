// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

/* Errors */
    error Raffle__SendMoreToEnterRaffle();

/**
 * @title A sample Raffle contract
 * @author Amit Prasad
 * @notice 
 * @dev Implements Chainlink VRF-v2.5
 */
contract Raffle {
    uint256 private immutable i_entranceFee;
    address payable[] private s_players; // Syntax for payable address array

    /* Events */
    event PlayerEnteredRaffle(address indexed player);

    constructor(uint256 entranceFee) {
        i_entranceFee = entranceFee;
    }

    function enterRaffle() public payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH sent");
        // require(msg.value >= i_entranceFee, SendMoreToEnterRaffle()); as of Solidity 0.8.24
        if(msg.value < i_entranceFee){
            revert Raffle__SendMoreToEnterRaffle();
        }
        s_players.push(payable(msg.sender));
        emit PlayerEnteredRaffle(msg.sender);
    }

    function pickWinner() public {

    }

    /* Getter func */
    function getEntranceFee() external view returns(uint256) {
        return i_entranceFee;
    }
}