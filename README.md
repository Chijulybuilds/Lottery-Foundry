# Lottery Foundry

A Foundry-based Chainlink VRF raffle project that demonstrates how to build, test, and deploy a lottery smart contract using `forge`, mocks, and network configuration.

Repo: https://github.com/Chijulybuilds/Lottery-Foundry.git

## Quick Start

### Fork and clone

1. Fork the repository on GitHub from:
   - `https://github.com/Chijulybuilds/Lottery-Foundry.git`
2. Clone your fork locally:
   ```bash
   git clone https://github.com/<your-username>/Lottery-Foundry.git
   cd Lottery-Foundry
   ```
3. Create a new branch for your changes:
   ```bash
   git checkout -b feature/my-update
   ```

### Contribute

1. Make changes in your branch.
2. Run tests locally:
   ```bash
   make test
   ```
3. Add and commit your work:
   ```bash
   git add .
   git commit -m "Describe your change"
   ```
4. Push your branch:
   ```bash
   git push origin feature/my-update
   ```
5. Open a pull request on GitHub.

## Project Overview

This repository contains:

- `src/Raffle.sol` — the raffle contract that requests randomness from Chainlink VRF.
- `test/unitMain/Raffletest.t.sol` — unit tests for raffle behavior and VRF integration.
- `script/DeployRaffle.s.sol` — deployment script for the raffle contract.
- `script/HelperConfig.s.sol` — network configuration helper that selects the correct VRF coordinator or deploys mocks locally.
- `Makefile` — common commands for test, gas report, and deploy.

## Requirements

- Foundry installed (`forge`, `cast`, `anvil`)
- Node/npm is not required unless you use extra tools, but Foundry is the main toolchain.
- `.env` file with network variables when running remote tests or deploys.

## Setup

Install dependencies:

```bash
forge install
```

## Common Commands

### Build

```bash
forge build
```

### Test

Run all tests locally and on configured forks:

```bash
make test
```

If you want only the local tests:

```bash
forge test -vvv
```

### Gas report

```bash
make gas
```

Or directly:

```bash
forge test -vvv --gas-report
```

### Deploy to Sepolia

```bash
make deploy
```

### Fund raffle on Sepolia

```bash
make payentrancefee-sepolia
```

## How to Use This Project

- `src/Raffle.sol` is the raffle contract that uses Chainlink VRF v2.5.
- `script/HelperConfig.s.sol` returns network-specific addresses or deploys a local mock coordinator.
- `script/DeployRaffle.s.sol` deploys the raffle with the configured subscription ID.
- The test suite uses mocks so Chainlink behavior can be tested locally without real LINK or live network dependency.

## Notes for Chainlink VRF

- If you use a real Chainlink subscription, the contract must be added as a consumer using `addConsumer(subId, raffleAddress)`.
- `gaslane` is the Chainlink VRF key hash / gas lane for the network.
- `callbackGasLimit` controls the gas allowance for the randomness callback.

## Project Structure

```text
foundry.toml
Makefile
README.md
script/
  DeployRaffle.s.sol
  HelperConfig.s.sol
src/
  Raffle.sol
test/
  unitMain/
    Raffletest.t.sol
lib/
  chainlink-brownie-contracts/
```

## Notes

- Use `forge fmt` to format Solidity files.
- Use `forge coverage` for coverage reports.
- Keep constructor parameters aligned with network-specific VRF settings for flexibility.

## License

This project is released under the MIT License.
