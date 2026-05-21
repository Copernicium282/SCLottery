# -include .env
SEPOLIA_RPC_URL := $(shell [ -f .env ] && grep SEPOLIA_RPC_URL .env | cut -d' ' -f3)
ETHERSCAN_API_KEY := $(shell [ -f .env ] && grep ETHERSCAN_API_KEY .env | cut -d' ' -f3)

.PHONY: all clean remove install update build test test-unit test-integration coverage snapshot format anvil deploy help

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
ACCOUNT := sepoliaKey

help:
	@echo "Usage:"
	@echo "  make build             - Compile the contracts"
	@echo "  make test              - Run all tests"
	@echo "  make test-unit         - Run unit tests only"
	@echo "  make test-integration  - Run integration tests only"
	@echo "  make coverage          - Run tests coverage report"
	@echo "  make format            - Run forge fmt"
	@echo "  make clean             - Clean the cache and out directory"
	@echo "  make anvil             - Start local Anvil node"
	@echo "  make deploy            - Deploy Raffle locally to Anvil"
	@echo "  make deploy-sepolia    - Deploy Raffle to Sepolia (requires SEPOLIA_RPC_URL and PRIVATE_KEY)"

clean:
	forge clean

remove:
	rm -rf .gitmodules .git/modules/* lib/

install:
	forge install foundry-rs/forge-std
	forge install Cyfrin/foundry-devops
	forge install transmissions11/solmate@v6
	forge install OpenZeppelin/openzeppelin-contracts@v4.9.6
	forge install smartcontractkit/chainlink-evm@contracts-v1.5.1-beta.0

update:
	forge update

build:
	forge build

test:
	forge test

test-unit:
	forge test --match-path "test/unit/*"

test-integration:
	forge test --match-path "test/integration/*"

coverage:
	forge coverage

snapshot:
	forge snapshot

format:
	forge fmt

anvil:
	anvil --host 0.0.0.0

deploy:
	@forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

deploy-sepolia:
	@forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA_RPC_URL) --account $(ACCOUNT) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
