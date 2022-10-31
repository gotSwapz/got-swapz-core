-include .env

all: clean remove install update build

# Remove the build artifacts and cache directories
clean:; forge clean

# Remove modules
remove:; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

# Install dependencies
install:; forge install smartcontractkit/chainlink-brownie-contracts --no-commit && forge install rari-capital/solmate --no-commit && forge install foundry-rs/forge-std --no-commit

# Update dependencies
update:; forge update

# Build the project's smart contracts
build:; forge build

# Run the project's tests
tests:; forge test

# Get tests coverage report
coverage:; forge coverage

# Run Slither static analysis for the contracts
slither:; slither src 

# Create a snapshot of each test's gas usage
snapshot:; forge snapshot

# Create flattened version of the contracts
flatten:; forge flatten --output flattened/GotSwapzCollection.flattened.sol src/GotSwapzCollection.sol && forge flatten --output flattened/GotSwapzFactory.flattened.sol src/GotSwapzFactory.sol

# Create inheritance graph of the contracts
inheritance:; slither src/GotSwapzFactory.sol --print inheritance-graph && dot src/GotSwapzFactory.sol.inheritance-graph.dot -Tsvg -o docs/inheritance-graph.png && xdg-open docs/inheritance-graph.png && rm src/GotSwapzFactory.sol.inheritance-graph.dot

# Show summary of the contracts
summary:; slither src/GotSwapzFactory.sol --print contract-summary && slither src/GotSwapzCollection.sol --print contract-summary

# Show dependencies of the contracts
dependencies:; slither src/GotSwapzFactory.sol --print data-dependency && slither src/GotSwapzCollection.sol --print data-dependency

# Create local testnet node
anvil:; anvil -m "${MNEMONIC}"

# Deploy GotSwapzFactory contract to Anvil
deploy-anvil:; @forge script script/Deploy.s.sol:Deploy --rpc-url http://localhost:8545  --private-key ${TEST_PRIVATE_KEY} --broadcast

# Deploy GotSwapzFactory contract to Mumbai
deploy-mumbai:; @forge script script/Deploy.s.sol:Deploy --rpc-url ${MUMBAI_RPC_URL} --private-key ${PRIVATE_KEY} --broadcast --verify --etherscan-api-key ${POLYGONSCAN_API_KEY} -vvvv

# Deploy GotSwapzFactory contract to Polygon
deploy-mainnet:; @forge script script/Deploy.s.sol:Deploy --rpc-url ${MAINNET_RPC_URL} --private-key ${PRIVATE_KEY} --broadcast --verify --etherscan-api-key ${POLYGONSCAN_API_KEY} -vvvv --legacy

