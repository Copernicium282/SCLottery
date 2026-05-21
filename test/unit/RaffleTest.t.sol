// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";
import "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig, CodeConstants} from "../../script/HelperConfig.s.sol";
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

    function testfulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEntered skipFork {
        // Arrange & Act & Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    /**
     * @notice Verifies that fulfilling random words successfully selects a winner, resets state, and distributes funds.
     */
    function testfulfillRandomWordsPicksAWinnerResetsTheRaffleAndSendsMoney() public raffleEntered skipFork {
        // Arrange
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1; // We already have 1 entrant from the raffleEntered modifier
        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = makeAddr(string(abi.encodePacked("Player", vm.toString(i))));
            hoax(newPlayer, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 startingTimestamp = raffle.getLastTimeStamp();

        uint256 indexOfWinner = uint256(keccak256(abi.encode(1, 0))) % (additionalEntrants + 1);
        address expectedWinner = raffle.getPlayer(indexOfWinner);
        uint256 startingBalanceOfPlayer = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        address recentWinner = raffle.getRecentWinner();
        uint256 endTimestamp = raffle.getLastTimeStamp();
        uint256 endingBalanceOfPlayer = expectedWinner.balance;
        uint256 prizeMoney = entranceFee * (additionalEntrants + 1);

        assertEq(recentWinner, expectedWinner);
        assertEq(uint256(raffleState), uint256(Raffle.RaffleState.OPEN));
        assertEq(endingBalanceOfPlayer - startingBalanceOfPlayer, prizeMoney);
        assert(endTimestamp > startingTimestamp);
    }
}
