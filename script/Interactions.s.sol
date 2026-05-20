// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "./HelperConfig.s.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract CreateSubscription is Script, CodeConstants {
    function createSub(
        address vrfCoordinator
    ) public returns (uint256 subId, address coordinator) {
        console.log(
            "Creating subscription with VRF Coordinator at:",
            vrfCoordinator
        );

        vm.startBroadcast();
        uint256 subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();

        console.log("Subscription created with ID:", subscriptionId);
        console.log(
            "Please update the subscription ID in the HelperConfig.s.sol file to:",
            subscriptionId
        );
        return (subscriptionId, vrfCoordinator);
    }

    function createSubscriptionFromActiveNetworkConfig()
        public
        returns (uint256 subId, address coordinator)
    {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig
            .getActiveNetworkConfig()
            .vrfCoordinator;
        (uint256 subscriptionId, ) = createSub(vrfCoordinator);
        return (subscriptionId, vrfCoordinator);
    }

    function run() public {
        createSubscriptionFromActiveNetworkConfig();
    }
}

contract fundSubscription is Script {
    uint256 constant FUND_AMOUNT = 6 ether; // 6 LINK

    function fundSubscriptionUsingHelperConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory activeNetworkConfig = helperConfig
            .getActiveNetworkConfig();

        console.log(
            "Funding subscription with ID:",
            activeNetworkConfig.subscriptionId
        );
        console.log(
            "Using VRF Coordinator at:",
            activeNetworkConfig.vrfCoordinator
        );
        console.log("On Chain ID:", block.chainid);
        console.log("Funding amount (in LINK):", FUND_AMOUNT / 1e18);

        if (block.chainid != helperConfig.LOCALHOST_CHAIN_ID()) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(activeNetworkConfig.vrfCoordinator)
                .fundSubscription(
                    activeNetworkConfig.subscriptionId,
                    FUND_AMOUNT
                );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            // For local testing, we need to fund the subscription using the LinkToken mock, transferAndCall does the same thing as fundSubscription in the VRFCoordinatorV2_5Mock.
            LinkToken(activeNetworkConfig.link).transferAndCall(
                activeNetworkConfig.vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(activeNetworkConfig.subscriptionId)
            );
            vm.stopBroadcast();
        }
        console.log("Subscription funded with amount:", FUND_AMOUNT);
    }

    function run() public {
        fundSubscriptionUsingHelperConfig();
    }
}
