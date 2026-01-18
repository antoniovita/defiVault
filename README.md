# DeFi Vault (ERC-4626) — From Scratch

This repo implements a minimal ERC-4626-style vault and a mock ERC-20 asset using Foundry. The goal is to show the core mechanics without relying on OpenZeppelin base contracts. Share accounting, allowances, and asset transfers are written manually.

## What's inside

- `src/ERC4626Token.sol`: Vault + share token logic (ERC-4626 behavior + ERC-20-like shares).
- `src/MockERC20.sol`: Simple mintable ERC-20 used for testing.
- `test/ERC4626Token.t.sol`: Forge tests covering deposit, withdraw, redeem, and rounding.

## Design notes

- Share token is implemented directly (balances/allowances/transfer/approve/transferFrom).
- Assets are pulled/pushed via low-level calls to avoid ERC-20 return-value quirks.
- `previewWithdraw` rounds up shares to protect the vault.
- This code is for learning and experimentation; it is not audited.

## Install

```bash
forge install
```

## Build

```bash
forge build
```

## Test

```bash
forge test
```

## Usage overview

Deposit assets and mint shares:

```solidity
uint256 shares = vault.deposit(100 ether, alice);
```

Withdraw assets by burning shares:

```solidity
uint256 sharesBurned = vault.withdraw(10 ether, alice, alice);
```

Redeem shares for assets:

```solidity
uint256 assetsOut = vault.redeem(25 ether, alice, alice);
```

## Security and limitations

- No access control, fees, or strategy logic.
- No ERC-4626 hooks or advanced accounting (e.g., yield, performance fees).
- No reentrancy protection.
- Intended for local testing and learning only.

## License

MIT
