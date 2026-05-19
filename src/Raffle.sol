// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/* Errors */
error Raffle__SendMoreToEnterRaffle();

/**
 * @title A sample Raffle contract
 * @author Amit Prasad
 * @notice
 * @dev Implements Chainlink VRF-v2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint32 private immutable i_callbackGasLimit;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval; // Interval for Lottery in seconds
    uint256 private s_lastTimestamp;
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_keyHash;
    address payable[] private s_players; // Syntax for payable address array

    /* Events */
    event PlayerEnteredRaffle(address indexed player); // Make frontend indexing easier

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
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH sent");
        // require(msg.value >= i_entranceFee, SendMoreToEnterRaffle()); as of Solidity 0.8.24
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        s_players.push(payable(msg.sender));
        emit PlayerEnteredRaffle(msg.sender);
    }

    function pickWinner() external {
        if (block.timestamp - s_lastTimestamp < i_interval) {
            revert();
        }
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
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {

    }

    /* Getter func */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
