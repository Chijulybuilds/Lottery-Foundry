-include .env

.PHONY: dependency test coverage gas deploy payentrancefee-sepolia performupkeep-sepolia

dependency:
	forge install smartcontractkit/chainlink-brownie-contracts && forge install Cyfrin/foundry-devops@0.4.0

test:
	forge test -vvv && forge test -vvv --fork-url ${SEPOLIA_URL}  && forge test -vvv --fork-url ${MAINNET_URL}

coverage:
	forge coverage && forge coverage --fork-url ${SEPOLIA_URL} && forge coverage --fork-url ${MAINNET_URL}

gas:
	forge test -vvv --gas-report

deploy:
	forge script script/DeployRaffle.s.sol --fork-url ${SEPOLIA_URL} --private-key ${KEY_PRIVATE} --broadcast

payentrancefee-sepolia:
	forge script script/Transactions.s.sol:FundRaffle --rpc-url ${SEPOLIA_URL} --private-key ${KEY_PRIVATE} --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvv

performupkeep-sepolia:
	forge script script/Transactions.s.sol:PerformUpkeepRaffle --rpc-url ${SEPOLIA_URL} --private-key ${KEY_PRIVATE} --broadcast -vvv

 




