// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/* Errors */
error Raffle__SendMoreToEnterRaffle();
error Raffle__TransferFailed();
error Raffle__RaffleNotOpen();
error Raffle__UpkeepNotNeeded(uint256 balance, uint256 numOfPlayers, uint256 state);

/**
 * @title A sample Raffle contract
 * @author Amit Prasad
 * @notice
 * @dev Implements Chainlink VRF-v2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /* Enums */
    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1
    }

    /* State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint32 private immutable i_callbackGasLimit;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval; // Interval for Lottery in seconds
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_keyHash;
    address payable[] private s_players; // Syntax for payable address array
    address private s_recentWinner;
    uint256 private s_lastTimestamp;
    RaffleState private s_raffleState;

    /* Events */
    event PlayerEnteredRaffle(address indexed player); // Make frontend indexing easier
    event WinnerPicked(address indexed winner);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subID,
        uint32 gasLimit
    ) // VRFConsumerBaseV2Plus has a constructor, so we need to init that first
        VRFConsumerBaseV2Plus(vrfCoordinator)
    {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimestamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subID;
        i_callbackGasLimit = gasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH sent");
        // require(msg.value >= i_entranceFee, SendMoreToEnterRaffle()); as of Solidity 0.8.24
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit PlayerEnteredRaffle(msg.sender);
    }

    /**
     * @dev Checking Chainlink Automation upkeep to check if the lottery is to be ended
     * for upkeepNeeded to be true:
     * 1. Time interval has passed between raffle runs
     * 2. Lottery is open
     * 3. Contract has ETH
     * 4. Upkeep has LINK to remain active
     * 5. Number of participants is more than 0
     * @param - ignored
     * @return upkeepNeeded - true if it's time to restart
     * @return - ignored
     */
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        bool intervalEnded = (block.timestamp - s_lastTimestamp >= i_interval);
        bool isOpen = (s_raffleState == RaffleState.OPEN);
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = intervalEnded && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    function performUpkeep(
        bytes memory /* performData */
    )
        external
    {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        s_raffleState = RaffleState.CALCULATING;
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({ // Input the entire struct values
            keyHash: i_keyHash, // Gas price lane
            subId: i_subscriptionId, // Funding the VRF
            requestConfirmations: REQUEST_CONFIRMATIONS, // Number of confirmed blocks
            callbackGasLimit: i_callbackGasLimit, // Gas limit
            numWords: NUM_WORDS, // Number of Random words we need
            extraArgs: VRFV2PlusClient._argsToBytes(
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
        });
        s_vrfCoordinator.requestRandomWords(request);
        // This calls rawFulfillRandomWords, which checks if the request is from the vrfCoordinator, which then calls the fullfillRandomWords, which gets called through an interface to an existing contract that propagates the request to the DON to recieve a random number
    }

    // CEI: Checks, Effects, Interactions
    function fulfillRandomWords(
        uint256,
        /* requestId */
        uint256[] calldata randomWords
    )
        internal
        override
    {
        // Checks, like require();

        // Effects (Internal Contract State)
        uint256 indexOfWinner = randomWords[0] % s_players.length; // As the returned randomWord is large
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0); // Clear out previous players
        s_lastTimestamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);

        // Interactions
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /* Getter func */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }
}
