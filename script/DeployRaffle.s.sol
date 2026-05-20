// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() public {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        // Local -> Deploy Mock, get subscriptionId, fund subscription
        // Sepolia -> Get the real values from the active network config
        HelperConfig.NetworkConfig memory activeNetworkConfig = helperConfig.getActiveNetworkConfig();

        if (activeNetworkConfig.subscriptionId == 0) {
            // Create Subscription
            CreateSubscription createSubscription = new CreateSubscription();
            (activeNetworkConfig.subscriptionId, activeNetworkConfig.vrfCoordinator) =
                createSubscription.createSubscriptionFromActiveNetworkConfig();
            helperConfig.setSubscriptionId(activeNetworkConfig.subscriptionId);

            // Fund Subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscriptionUsingHelperConfig(activeNetworkConfig.vrfCoordinator, activeNetworkConfig.subscriptionId, activeNetworkConfig.link);
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            activeNetworkConfig.entranceFee,
            activeNetworkConfig.interval,
            activeNetworkConfig.vrfCoordinator,
            activeNetworkConfig.gasLane,
            activeNetworkConfig.subscriptionId,
            activeNetworkConfig.callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        // NO broadcast required as the deployment is already wrapped in broadcast in the original code
        addConsumer.addConsumer(address(raffle), activeNetworkConfig.vrfCoordinator, activeNetworkConfig.subscriptionId);

        return (raffle, helperConfig);
    }
}
