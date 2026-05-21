// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig, CodeConstants, HelperConfig__NoConfigForChainId} from "../../script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../../script/Interactions.s.sol";
import {LinkToken} from "../../test/mocks/LinkToken.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Raffle} from "../../src/Raffle.sol";

contract InteractionsTest is Test, CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("Copernicium282");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

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

    /* HelperConfig Tests */

    function testHelperConfigSepolia() public {
        vm.chainId(SEPOLIA_CHAIN_ID);
        HelperConfig config = new HelperConfig();
        HelperConfig.NetworkConfig memory activeConfig = config.getActiveNetworkConfig();
        assertEq(activeConfig.vrfCoordinator, 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B);
    }

    function testHelperConfigUnsupportedChainReverts() public {
        vm.chainId(999);
        HelperConfig config = new HelperConfig();
        vm.expectRevert(abi.encodeWithSelector(HelperConfig__NoConfigForChainId.selector, 999));
        config.getActiveNetworkConfig();
    }

    function testHelperConfigGetOrCreateAnvilConfigReturnsExisting() public {
        HelperConfig config = new HelperConfig();
        HelperConfig.NetworkConfig memory activeConfig = config.getOrCreateAnvilConfig();
        assertNotEq(activeConfig.vrfCoordinator, address(0));
    }

    /* DeployRaffle Tests */

    function testDeployRaffleRun() public {
        DeployRaffle deployer = new DeployRaffle();
        deployer.run();
    }

    /* Interactions Tests */

    function testInteractionsCreateSubscriptionRun() public {
        CreateSubscription createSubScript = new CreateSubscription();
        createSubScript.run();
    }

    function testInteractionsCreateSubOverload() public {
        CreateSubscription createSubScript = new CreateSubscription();
        createSubScript.createSub(vrfCoordinator);
    }

    function testInteractionsFundSubscriptionRun() public {
        FundSubscription fundSubScript = new FundSubscription();
        vm.expectRevert(bytes4(keccak256("InvalidSubscription()")));
        fundSubScript.run();
    }

    function testInteractionsFundSubscriptionOverload() public {
        FundSubscription fundSubScript = new FundSubscription();
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        fundSubScript.fundSubscription(vrfCoordinator, subId, address(0));
    }

    function testInteractionsFundSubscriptionNonLocal() public {
        // Arrange: Simulate being on Sepolia network
        vm.chainId(SEPOLIA_CHAIN_ID);
        FundSubscription fundSub = new FundSubscription();

        HelperConfig config = new HelperConfig();
        address link = config.getActiveNetworkConfig().link;
        address account = config.getActiveNetworkConfig().account;

        // Since we simulated Sepolia, the real LINK address has no bytecode on our local EVM.
        // We deploy a local LinkToken and use vm.etch to place its code at the Sepolia LINK address.
        LinkToken linkTokenMock = new LinkToken();
        vm.etch(link, address(linkTokenMock).code);

        // Tell the mock coordinator to recognize our newly etched Sepolia LINK token
        address coordinatorOwner = VRFCoordinatorV2_5Mock(vrfCoordinator).owner();
        vm.prank(coordinatorOwner);
        VRFCoordinatorV2_5Mock(vrfCoordinator).setLINKAndLINKNativeFeed(link, address(0));

        // Create subscription owned by the broadcaster account
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        // Mint LINK to the account on our etched LINK contract
        LinkToken(link).mint(account, 100 ether);

        // Act: Run the non-local funding process (which triggers transferAndCall on the etched contract)
        fundSub.fundSubscription(vrfCoordinator, subId, link, account);

        // Assert: Verify the subscription received the default 6 LINK funding amount
        (uint96 balance,,,,) = VRFCoordinatorV2_5Mock(vrfCoordinator).getSubscription(subId);
        assertEq(balance, 6 ether);
    }

    function testInteractionsAddConsumerOverload() public {
        AddConsumer addConsumerScript = new AddConsumer();

        HelperConfig config = new HelperConfig();
        address account = config.getActiveNetworkConfig().account;

        vm.prank(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();

        addConsumerScript.addConsumer(address(raffle), vrfCoordinator, subId);
    }

    function testAddConsumerRunRevertsNoDeployment() public {
        AddConsumer addConsumer = new AddConsumer();
        vm.expectRevert();
        addConsumer.run();
    }

    function testInteractionsAddConsumerUsingHelperConfigReverts() public {
        AddConsumer addConsumerScript = new AddConsumer();
        vm.expectRevert();
        addConsumerScript.addConsumerUsingHelperConfig(address(raffle));
    }
}
