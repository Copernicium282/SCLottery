# Raffle (A Chainlink-VRF and Automation based Lottery Project)

[![Foundry Version](https://img.shields.io/badge/foundry-v0.2.0-blue.svg)](https://book.getfoundry.sh/)
[![Solidity Version](https://img.shields.io/badge/solidity-^0.8.19-lightgrey.svg)](https://soliditylang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**A decentralized lottery smart contract utilizing Chainlink VRF V2.5.** Build on a secure foundation of community-approved oracle integration and test coverage.

This project is part of my journey learning Foundry fundamentals on Cyfrin Updraft. It showcases:
* Custom oracle integration via Chainlink VRF V2.5 (Verifiable Random Function) for secure, tamper-proof winner selection.
* Chainlink Automation (Upkeep) condition checking to determine when the lottery should run.
* Unit and integration testing suites separating smart contract states and script interactions.

**New to Foundry?** Read the official Foundry Book to understand compilation, testing, and script execution.

> [!IMPORTANT]
> SCLottery relies on active VRF subscription setups. When deploying or forking, ensure that the VRF Coordinator, Key Hash (Gas Lane), Subscription ID, and native payment preferences are correctly configured for your target network. Using incorrect or unverified coordinator addresses will compromise the randomness fulfillment. Learn more at the Chainlink VRF V2.5 Documentation.

## Overview

### Target Networks

The project is structured to deploy on local and testnet networks dynamically using environment-dependent helper scripts:

| Chain ID   | Network                 | Description                                                                                                                                                                   |
| :--------- | :---------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **11155111**| Sepolia Testnet         | Deployed Raffle Contract at [`0x39125d25B352F064B943Ea9DA9C229bA0D3a69c1`](https://sepolia.etherscan.io/address/0x39125d25b352f064b943ea9da9c229ba0d3a69c1). Test network mimicking production oracle behaviors with official Chainlink Sepolia VRF Coordinator. |
| **Local**  | Local Anvil Chain       | Local development network. The deploy scripts dynamically spawn a VRFCoordinatorV2_5Mock and create/fund subscriptions locally without external RPC calls.                   |

### Codebase Breakdown

#### 1. Core Contracts
* **src/Raffle.sol**: Core contract implementing lottery entry rules, Automation Upkeep checks, random word requests, and CEI-compliant winner selection logic with external balance payouts.

#### 2. Scripts
* **script/DeployRaffle.s.sol**: Automation deployment script that instantiates contracts, creates VRF subscriptions, funds them locally, and registers consumers.
* **script/HelperConfig.s.sol**: Dynamically defines network parameters for Sepolia testnets or deploys Mock coordinators on Anvil nodes.
* **script/Interactions.s.sol**: Script configurations to programmatically handle subscription creations, fund allocations, and consumer additions.

#### 3. Libraries & Dependencies
The codebase maps libraries inside `foundry.toml` using git submodules:
* `@chainlink/contracts` (`lib/chainlink-evm`): Inherits VRF consumer base interfaces and clients.
* `@openzeppelin/contracts` (`lib/openzeppelin-contracts`): Standard utility templates.
* `foundry-devops` (`lib/foundry-devops`): Tool to resolve deployed address lookups dynamically.

#### 4. Mocking Contracts
* **test/mocks/LinkToken.sol**: ERC677 mock token used to simulate non-local subscription funding flows.

### Installation

#### Submodule Dependencies

This repository utilizes git submodules for external libraries:

```bash
make install
```

Configure your directory remappings in your foundry.toml file:

```text
@chainlink/contracts/=lib/chainlink-evm/contracts/
@openzeppelin/contracts@4.9.6/=lib/openzeppelin-contracts/contracts/
@solmate/=lib/solmate/src/
```

### Usage

This repository contains a Makefile designed to simplify standard task execution. You can use simple make commands instead of invoking long forge commands manually.

Compile and build your smart contracts:

```bash
make build
```

Execute all local unit and integration tests:

```bash
make test
```

Execute unit tests only:

```bash
make test-unit
```

Execute integration tests only:

```bash
make test-integration
```

Generate the contract test coverage report:

```bash
make coverage
```

Start your local test blockchain (Anvil) with steps tracing configured:

```bash
make anvil
```

#### Local Deployment (Anvil)

Deploy the contract locally to Anvil using the deployment script (uses the default Anvil key and local RPC URL defined in the Makefile):

```bash
make deploy
```

#### Testnet Deployment (Sepolia)

Deploy the contract to Sepolia, dynamically loading environment variables and verifying on Etherscan using secure keystore accounts:

```bash
make deploy-sepolia
```

The contract has been successfully deployed and verified on the Sepolia testnet:
* **Raffle Contract Address**: [`0x39125d25B352F064B943Ea9DA9C229bA0D3a69c1`](https://sepolia.etherscan.io/address/0x39125d25b352f064b943ea9da9c229ba0d3a69c1)
* **VRF Coordinator V2.5**: `0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B`
* **VRF Subscription ID**: `93590248486924931070816542843925010346016264624122707241679032080805822934383`


## Testing Structure

This repository separates contract verification into two distinct testing folders:

### 1. Unit Tests (test/unit/RaffleTest.t.sol)
Validates core contract functionality under isolated local conditions:
* Initializing state checks.
* Entry validations (insufficient ETH, calculating state entry blocks).
* Events emission verifying player records.
* Upkeep verification checking timing, balance, and state intervals.
* Winner picked callbacks validating resets, prize pool distributions, and transfer failures (via Rejector contracts).

### 2. Integration Tests (test/integration/InteractionsTest.t.sol)
Verifies interactions between scripts, configs, and mocks:
* Unsupported chain reverting triggers on HelperConfig.
* End-to-end DeployRaffle scripts.
* VRF subscriptions, creations, and funding scripts.
* Simulated Sepolia execution using `vm.etch` to place compiled `LinkToken` mock bytecode at official addresses on local EVM.

## Learn More

The following topics will help guide you through the Cyfrin Updraft curriculum:

* VRF Subscription: Understand how subscriptions manage coordination fees and request funding.
* Automation Upkeep: Learn checking conditions (elapsed time intervals, active players, open states, and contract balances).
* Checks-Effects-Interactions (CEI): Explore how updating state variables before executing external transfers prevents reentrancy attacks.
* Custom Errors: Learn how custom errors reduce gas consumption compared to require strings.

## Security

Smart contracts are a nascent technology and carry a high level of technical risk. Using this baseline code serves as a learning sandbox and is not a substitute for a comprehensive smart contract security audit.

SCLottery is made available under the MIT License, which disclaims all warranties in relation to the project.

## License

This project is released under the MIT License.
