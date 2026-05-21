// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

error HelperConfig__NoConfigForChainId(uint256 chainId);

/**
 * @title CodeConstants
 * @notice Abstract contract defining key environment constants, chain IDs, and Mock VRF values.
 */
abstract contract CodeConstants {
    /* VRF Mock Values */
    uint96 public constant BASE_FEE = 0.1 ether;
    uint96 public constant GAS_PRICE_LINK = 1e9; // 0.000000001 LINK per gas
    /* LINK/ETH price */
    int256 public constant MOCK_WEI_PER_LINK = 1e18; // 1 LINK = 1 ETH

    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCALHOST_CHAIN_ID = 31337;
}

/**
 * @title HelperConfig
 * @notice Handles environment-specific deployment configurations (Sepolia, Anvil / Localhost).
 */
contract HelperConfig is Script, CodeConstants {
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        address account;
    }

    NetworkConfig public activeNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
        networkConfigs[LOCALHOST_CHAIN_ID] = getOrCreateAnvilConfig();
        activeNetworkConfig = networkConfigs[block.chainid];
    }

    /**
     * @notice Retrieves the active network configuration based on the current chain ID.
     */
    function getActiveNetworkConfig() public returns (NetworkConfig memory) {
        if (networkConfigs[block.chainid].vrfCoordinator != address(0)) {
            return networkConfigs[block.chainid];
        } else if (block.chainid == LOCALHOST_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        } else if (block.chainid == SEPOLIA_CHAIN_ID) {
            return getSepoliaEthConfig();
        } else {
            revert HelperConfig__NoConfigForChainId(block.chainid);
        }
    }

    /**
     * @notice Allows external scripts to set/persist a newly created VRF subscription ID in state.
     * @param _subscriptionId The subscription ID to persist.
     */
    function setSubscriptionId(uint256 _subscriptionId) public {
        networkConfigs[block.chainid].subscriptionId = _subscriptionId;
        activeNetworkConfig.subscriptionId = _subscriptionId;
    }

    /**
     * @notice Allows external scripts to set/persist the deployed VRF coordinator address in state.
     * @param _vrfCoordinator The address of the deployed VRF coordinator.
     */
    function setVrfCoordinator(address _vrfCoordinator) public {
        networkConfigs[block.chainid].vrfCoordinator = _vrfCoordinator;
        activeNetworkConfig.vrfCoordinator = _vrfCoordinator;
    }


    /**
     * @notice Returns the hardcoded configurations for the Sepolia Ethereum testnet.
     */
    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30 seconds,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 93590248486924931070816542843925010346016264624122707241679032080805822934383,
            callbackGasLimit: 500000,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0x7F99f10684e4F70051f3de5Ceb9fDC71a38aF0Fd
        });
    }

    /**
     * @notice Returns or deploys a new local/mock network configuration on Anvil/Localhost.
     */
    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        // If we already have a config, let's just return it
        if (networkConfigs[LOCALHOST_CHAIN_ID].vrfCoordinator != address(0)) {
            return networkConfigs[LOCALHOST_CHAIN_ID];
        }

        // Deploy a VRFCoordinatorV2Mock
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock =
            new VRFCoordinatorV2_5Mock(BASE_FEE, GAS_PRICE_LINK, MOCK_WEI_PER_LINK);
        LinkToken linkTokenMock = new LinkToken();
        vm.stopBroadcast();

        // localNetworkConfig
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 3 seconds,
            vrfCoordinator: address(vrfCoordinatorV2_5Mock),
            gasLane: bytes32(uint256(1)),
            subscriptionId: 0,
            callbackGasLimit: 500000,
            link: address(linkTokenMock),
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        });
    }
}
