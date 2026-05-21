// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";
import "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig, CodeConstants, HelperConfig__NoConfigForChainId} from "../../script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../../script/Interactions.s.sol";
import {LinkToken} from "../../test/mocks/LinkToken.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test, CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    // Raffle Config Variables
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("Copernicium282");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    /**
     * @notice Sets up the test environment by deploying the Raffle contract and loading configs.
     */
    function setUp() public {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();

        HelperConfig.NetworkConfig memory activeNetworkConfig = helperConfig.getActiveNetworkConfig();
        entranceFee = activeNetworkConfig.entranceFee;
        interval = activeNetworkConfig.interval;
        vrfCoordinator = activeNetworkConfig.vrfCoordinator;
        gasLane = activeNetworkConfig.gasLane;
        subscriptionId = activeNetworkConfig.subscriptionId;
        callbackGasLimit = activeNetworkConfig.callbackGasLimit;
    }

    /**
     * @notice Enters a default player into the raffle and warps the block timestamp past the interval.
     */
    modifier raffleEntered() {
        hoax(PLAYER, STARTING_USER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testRaffleInitializesInOpenState() public view {
        assertEq(uint256(raffle.getRaffleState()), uint256(Raffle.RaffleState.OPEN));
    }

    function testRaffleRevertsWhenNotEnoughETH() public {
        // Arrange
        vm.prank(PLAYER);

        // Act & Assert
        vm.expectRevert(Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        // Arrange
        hoax(PLAYER, STARTING_USER_BALANCE);

        // Act
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);

        // Assert
        assertEq(playerRecorded, PLAYER);
    }

    function testRaffleEmitsEventOnEntrance() public {
        // Arrange
        hoax(PLAYER, STARTING_USER_BALANCE);

        // Assert
        vm.expectEmit(true, false, false, false, address(raffle)); // 3 indexed parameters, 1 non-indexed parameter, and the address of the contract emitting the event, but we have only 1 indexed parameter, so we set the first parameter to true and the rest to false
        emit Raffle.PlayerEnteredRaffle(PLAYER);

        // Act
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowEntranceWhenRaffleIsCalculating() public raffleEntered {
        // Arrange
        raffle.performUpkeep("");

        // Act & Assert
        vm.expectRevert(Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckUpkeepReturnsFalseIfNotEnoughTimeHasPassed() public {
        // Arrange
        vm.warp(block.timestamp + interval - 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsNotOpen() public raffleEntered {
        // Arrange
        raffle.performUpkeep("");
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assertEq(uint256(raffleState), uint256(Raffle.RaffleState.CALCULATING));
        assert(!upkeepNeeded);
    }

    function testPerformUpkeepWorksOnlyWhenCheckUpkeepIsTrue() public raffleEntered {
        // Act & Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsWhenCheckUpkeepIsFalse() public {
        // Arrange
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        hoax(PLAYER, STARTING_USER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();

        uint256 currentBalance = address(raffle).balance;
        uint256 numberOfPlayers = 1;

        // Act & Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle__UpkeepNotNeeded.selector, currentBalance, numberOfPlayers, uint256(raffleState)
            )
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsEvents() public raffleEntered {
        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assertEq(uint256(raffleState), uint256(Raffle.RaffleState.CALCULATING));
        assert(requestId > 0);
    }

    modifier skipFork() {
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            return;
        }
        _;
    }

    function testfulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId)
        public
        raffleEntered
        skipFork
    {
        // Arrange & Act & Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    /**
     * @notice Verifies that fulfilling random words successfully selects a winner, resets state, and distributes funds.
     */
    function testfulfillRandomWordsPicksAWinnerResetsTheRaffleAndSendsMoney() public raffleEntered skipFork {
        // Arrange: Generate 5 additional entrants to join the raffle
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1; // 1 entrant is already added by the raffleEntered modifier
        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = makeAddr(string(abi.encodePacked("Player", vm.toString(i))));
            hoax(newPlayer, STARTING_USER_BALANCE); // hoax sets up the prank and funds the address
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 startingTimestamp = raffle.getLastTimeStamp();

        // Calculate expected winner: the VRFCoordinatorV2_5Mock uses keccak256(abi.encode(requestId, wordIndex)) to mock random words.
        // We calculate this locally and modulo by total players to identify which player will be picked.
        uint256 indexOfWinner = uint256(keccak256(abi.encode(1, 0))) % (additionalEntrants + 1);
        address expectedWinner = raffle.getPlayer(indexOfWinner);
        uint256 startingBalanceOfPlayer = expectedWinner.balance;

        // Act: Request random words and fulfill them
        vm.recordLogs(); // Begin recording events emitted by the EVM
        raffle.performUpkeep(""); // performUpkeep requests randomness from the mock coordinator
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; // Extract the requestId from the emitted event log

        // Feed the mock random words callback into the consumer (raffle)
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert: Verify state resets, winner gets funds, and timestamp updates
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        address recentWinner = raffle.getRecentWinner();
        uint256 endTimestamp = raffle.getLastTimeStamp();
        uint256 endingBalanceOfPlayer = expectedWinner.balance;
        uint256 prizeMoney = entranceFee * (additionalEntrants + 1);

        assertEq(recentWinner, expectedWinner); // Winner must match our calculated expected winner
        assertEq(uint256(raffleState), uint256(Raffle.RaffleState.OPEN)); // Raffle must reset to OPEN state
        assertEq(endingBalanceOfPlayer - startingBalanceOfPlayer, prizeMoney); // Winner must receive the prize pool
        assert(endTimestamp > startingTimestamp); // Last timestamp must be updated / advanced
    }

    function testGetEntranceFee() public view {
        assertEq(raffle.getEntranceFee(), entranceFee);
    }

    function testFulfillRandomWordsRevertsOnTransferFailure() public skipFork {
        // Arrange: Deploy the Rejector contract (which has no receive/fallback payable function)
        Rejector rejector = new Rejector();
        hoax(address(rejector), STARTING_USER_BALANCE); // Set up prank and fund rejector with ETH
        rejector.enter{value: entranceFee}(raffle); // Enter the raffle under the rejector contract

        // Warp past the interval to satisfy checkUpkeep conditions
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act & Record: Trigger upkeep request and record request ID
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Prepare mock random words callback. Since the rejector is the only entrant,
        // any number returned as the random word moduloed by 1 (entrants count) will select index 0 (rejector).
        uint256[] memory words = new uint256[](1);
        words[0] = 123;

        // Act & Assert: Call rawFulfillRandomWords directly as the coordinator
        // Expect the transaction to revert with Raffle__TransferFailed because the Rejector won't accept the payout.
        vm.expectRevert(Raffle__TransferFailed.selector);
        vm.prank(vrfCoordinator);
        raffle.rawFulfillRandomWords(uint256(requestId), words);
    }
}

contract Rejector {
    function enter(Raffle raffle) external payable {
        raffle.enterRaffle{value: msg.value}();
    }
}
