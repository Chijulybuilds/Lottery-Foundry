-include .env

.PHONY: dependency test coverage deploy

dependency:
	forge install smartcontractkit/chainlink-brownie-contracts

test:
	forge test -vvv && forge test -vvv --fork-url ${SEPOLIA_URL} && forge test -vvv --fork-url ${MAINNET_URL}

coverage:
	forge coverage && forge coverage --fork-url ${SEPOLIA_URL} && forge coverage --fork-url ${MAINNET_URL}

deploy:
	forge script script/DeployRaffle.s.sol --fork-url ${SEPOLIA_URL} --private-key ${KEY_PRIVATE} --broadcast







