// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

error HelperConfig__NoConfigForChainId(uint256 chainId);

abstract contract CodeConstants {
    /* VRF Mock Values */
    uint96 public constant BASE_FEE = 0.1 ether;
    uint96 public constant GAS_PRICE_LINK = 1e9; // 0.000000001 LINK per gas
    /* LINK/ETH price */
    int256 public constant MOCK_WEI_PER_LINK = 1e18; // 1 LINK = 1 ETH

    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCALHOST_CHAIN_ID = 31337;
}

contract HelperConfig is Script, CodeConstants {
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
    }

    NetworkConfig public activeNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
        networkConfigs[LOCALHOST_CHAIN_ID] = getOrCreateAnvilConfig();
    }

    
    function getActiveNetworkConfig() public returns (NetworkConfig memory) {
        if (networkConfigs[block.chainid].vrfCoordinator != address(0)) {
            return networkConfigs[block.chainid];
        } else if (block.chainid == LOCALHOST_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        } else {
            revert HelperConfig__NoConfigForChainId(block.chainid);
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 30 seconds,
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                subscriptionId: 0,
                callbackGasLimit: 500000
            });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        // If we already have a config, let's just return it
        if (networkConfigs[LOCALHOST_CHAIN_ID].vrfCoordinator != address(0)) {
            return networkConfigs[LOCALHOST_CHAIN_ID];
        }

        // Deploy a VRFCoordinatorV2Mock
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock = new VRFCoordinatorV2_5Mock(BASE_FEE, GAS_PRICE_LINK, MOCK_WEI_PER_LINK);
        vm.stopBroadcast();

        // localNetworkConfig
        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 3 seconds,
                vrfCoordinator: (address(1)),
                gasLane: bytes32(uint256(1)),
                subscriptionId: 0,
                callbackGasLimit: 500000
            });
    }
}