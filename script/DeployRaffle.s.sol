// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription} from "./Interactions.s.sol";

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
            CreateSubscription createSubscription = new CreateSubscription();
            (activeNetworkConfig.subscriptionId, activeNetworkConfig.vrfCoordinator) =
                createSubscription.createSubscriptionFromActiveNetworkConfig();
            helperConfig.setSubscriptionId(activeNetworkConfig.subscriptionId);
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

        return (raffle, helperConfig);
    }
}
