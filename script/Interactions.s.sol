// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "./HelperConfig.s.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script, CodeConstants {
    /**
     * @notice Creates a new Chainlink VRF subscription.
     * @param vrfCoordinator The address of the VRF coordinator.
     * @return subId The created subscription ID.
     * @return coordinator The address of the VRF coordinator.
     */
    function createSub(address vrfCoordinator) public returns (uint256 subId, address coordinator) {
        HelperConfig helperConfig = new HelperConfig();
        address account = helperConfig.getActiveNetworkConfig().account;
        return createSub(vrfCoordinator, account);
    }

    /**
     * @notice Creates a new Chainlink VRF subscription with a specific broadcasting account.
     * @param vrfCoordinator The address of the VRF coordinator.
     * @param account The account address to use for broadcasting.
     * @return subId The created subscription ID.
     * @return coordinator The address of the VRF coordinator.
     */
    function createSub(address vrfCoordinator, address account) public returns (uint256 subId, address coordinator) {
        console.log("Creating subscription with VRF Coordinator at:", vrfCoordinator);

        vm.startBroadcast(account);
        uint256 subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Subscription created with ID:", subscriptionId);
        console.log("Please update the subscription ID in the HelperConfig.s.sol file to:", subscriptionId);
        return (subscriptionId, vrfCoordinator);
    }

    /**
     * @notice Creates a VRF subscription using parameters from the HelperConfig.
     * @return subId The created subscription ID.
     * @return coordinator The address of the VRF coordinator.
     */
    function createSubscriptionFromActiveNetworkConfig() public returns (uint256 subId, address coordinator) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getActiveNetworkConfig().vrfCoordinator;
        address account = helperConfig.getActiveNetworkConfig().account;
        (uint256 subscriptionId,) = createSub(vrfCoordinator, account);
        return (subscriptionId, vrfCoordinator);
    }

    function run() public {
        createSubscriptionFromActiveNetworkConfig();
    }
}

/**
 * @title FundSubscription
 * @notice A script to fund Chainlink VRF subscriptions using helper configurations or specific parameters.
 */
contract FundSubscription is Script {
    uint256 constant FUND_AMOUNT = 6 ether; // 6 LINK

    /**
     * @notice Funds a VRF subscription using parameters loaded from the HelperConfig.
     */
    function fundSubscriptionUsingHelperConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory activeNetworkConfig = helperConfig.getActiveNetworkConfig();
        fundSubscription(
            activeNetworkConfig.vrfCoordinator,
            activeNetworkConfig.subscriptionId,
            activeNetworkConfig.link,
            activeNetworkConfig.account
        );
    }

    /**
     * @notice Funds a VRF subscription directly using a specific VRF Coordinator and Link Token.
     * @param vrfCoordinator The address of the Chainlink VRF Coordinator contract.
     * @param subId The ID of the subscription to fund.
     * @param link The address of the Link Token contract.
     */
    function fundSubscription(address vrfCoordinator, uint256 subId, address link) public {
        HelperConfig helperConfig = new HelperConfig();
        address account = helperConfig.getActiveNetworkConfig().account;
        fundSubscription(vrfCoordinator, subId, link, account);
    }

    /**
     * @notice Funds a VRF subscription directly with a specific VRF Coordinator, Link Token, and broadcasting account.
     * @param vrfCoordinator The address of the Chainlink VRF Coordinator contract.
     * @param subId The ID of the subscription to fund.
     * @param link The address of the Link Token contract.
     * @param account The address of the broadcasting account.
     */
    function fundSubscription(address vrfCoordinator, uint256 subId, address link, address account) public {
        console.log("Funding subscription with ID:", subId);
        console.log("Using VRF Coordinator at:", vrfCoordinator);
        console.log("On Chain ID:", block.chainid);
        console.log("Funding amount (in LINK):", FUND_AMOUNT / 1e18);

        HelperConfig helperConfig = new HelperConfig();
        if (block.chainid == helperConfig.LOCALHOST_CHAIN_ID()) {
            vm.startBroadcast(account);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
            LinkToken(link).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }
        console.log("Subscription funded with amount:", FUND_AMOUNT);
    }

    /**
     * @notice Execution entrypoint when running the script directly.
     */
    function run() public {
        fundSubscriptionUsingHelperConfig();
    }
}

/**
 * @title AddConsumer
 * @notice A script to register the Raffle contract as an authorized consumer on the VRF subscription.
 */
contract AddConsumer is Script {
    /**
     * @notice Automatically registers the Raffle contract as a consumer using helper config.
     * @param raffleAddress The deployed address of the Raffle contract.
     */
    function addConsumerUsingHelperConfig(address raffleAddress) public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory activeNetworkConfig = helperConfig.getActiveNetworkConfig();

        uint256 subId = activeNetworkConfig.subscriptionId;
        address vrfCoordinator = activeNetworkConfig.vrfCoordinator;
        addConsumer(raffleAddress, vrfCoordinator, subId, activeNetworkConfig.account);
    }

    /**
     * @notice Registers a consumer on a subscription directly via the VRF Coordinator.
     * @param raffleAddress The address of the consumer contract to register.
     * @param vrfCoordinator The address of the VRF Coordinator contract.
     * @param subId The ID of the subscription.
     */
    function addConsumer(address raffleAddress, address vrfCoordinator, uint256 subId) public {
        HelperConfig helperConfig = new HelperConfig();
        address account = helperConfig.getActiveNetworkConfig().account;
        addConsumer(raffleAddress, vrfCoordinator, subId, account);
    }

    /**
     * @notice Registers a consumer on a subscription directly with a specific VRF Coordinator and broadcasting account.
     * @param raffleAddress The address of the consumer contract to register.
     * @param vrfCoordinator The address of the VRF Coordinator contract.
     * @param subId The ID of the subscription.
     * @param account The address of the broadcasting account.
     */
    function addConsumer(address raffleAddress, address vrfCoordinator, uint256 subId, address account) public {
        console.log("Adding consumer with address:", raffleAddress, "to subscription with ID:", subId);
        console.log("Using VRF Coordinator at:", vrfCoordinator);
        console.log("On Chain ID:", block.chainid);

        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, raffleAddress);
        vm.stopBroadcast();
        console.log("Consumer with address:", raffleAddress, "added to subscription with ID:", subId);
    }

    /**
     * @notice Execution entrypoint when running the script directly.
     */
    function run() public {
        // Replace this with the address of your deployed Raffle contract
        address raffleAddress = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingHelperConfig(raffleAddress);
    }
}
