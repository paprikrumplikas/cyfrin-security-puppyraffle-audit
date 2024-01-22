<p align="center">
<img src="./images/puppy-raffle.svg" width="400" alt="puppy-raffle">
<br/>

# Puppy Raffle


The purpose of the Puppy Raffle Protocol is to facilitate a raffle system, where participants can win a unique dog-themed Non-Fungible Token (NFT). The protocol's core functionalities are outlined as follows:

1. Raffle Entry Process: Participants enter the raffle by invoking the enterRaffle function. This function requires an array of addresses, address[] participants, as a parameter. It allows for a single user to enter multiple times, either individually or as part of a group, by submitting multiple addresses.
2. Address Uniqueness: The protocol is designed to ensure that duplicate addresses within a single raffle entry are not permitted. This mechanism upholds the integrity of each entry.
3. Refund Mechanism: Participants have the option to request a refund for their raffle ticket. This is accomplished by calling the refund function, which returns the ticket's cost (value) to the user.
4. Winner Selection and NFT Minting: The raffle is programmed to automatically select a winner at predetermined intervals (every X seconds). Upon selection, a random puppy NFT is minted and awarded to the winner.
5. Fee Allocation: The protocol's owner is responsible for setting a feeAddress. A portion of the raffle's collected value (value) is allocated to this address as a fee. The remainder of the funds is distributed to the raffle winner.


- [Puppy Raffle](#puppy-raffle)
- [Getting Started](#getting-started)
  - [Requirements](#requirements)
  - [Quickstart](#quickstart)
    - [Optional Gitpod](#optional-gitpod)
- [Usage](#usage)
  - [Testing](#testing)
    - [Test Coverage](#test-coverage)
- [Audit Scope Details](#audit-scope-details)
  - [Compatibilities](#compatibilities)
- [Roles](#roles)
- [Known Issues](#known-issues)

# Getting Started

## Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [foundry](https://getfoundry.sh/)
  - You'll know you did it right if you can run `forge --version` and you see a response like `forge 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)`

## Quickstart

```
git clone https://github.com/Cyfrin/4-puppy-raffle-audit
cd 4-puppy-raffle-audit
make
```

### Optional Gitpod

If you can't or don't want to run and install locally, you can work with this repo in Gitpod. If you do this, you can skip the `clone this repo` part.

[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/#github.com/Cyfrin/3-passwordstore-audit)

# Usage

## Testing

```
forge test
```

### Test Coverage

```
forge coverage
```

and for coverage based testing:

```
forge coverage --report debug
```

# Audit Scope Details

- Commit Hash: 22bbbb2c47f3f2b78c1b134590baf41383fd354f
- In Scope:

```
./src/
└── PuppyRaffle.sol
```

## Compatibilities

- Solc Version: 0.7.6
- Chain(s) to deploy contract to: Ethereum

# Roles

Owner - Deployer of the protocol, has the power to change the wallet address to which fees are sent through the `changeFeeAddress` function.
Player - Participant of the raffle, has the power to enter the raffle with the `enterRaffle` function and refund value through `refund` function.

# Known Issues

None
