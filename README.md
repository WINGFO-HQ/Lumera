# Lumera Node Setup Guide

This guide provides step-by-step instructions to set up a Lumera node and validator on the Lumera testnet. Source [Nodevism](https://docs.nodevism.com/testnet/lumera-protocol), [Nodestake](https://nodestake.org/lumera)

## Requirements

- Ubuntu 22.04 LTS or higher
- 8 cores, x86_64 architecture
- 32GB RAM
- 2 TB NVMe SSD
- Root access to the server

## Quick Installation

For a quick setup, run the following commands:

```bash
wget https://raw.githubusercontent.com/WINGFO-HQ/Lumera/refs/heads/main/lumera.sh && chmod +x lumera.sh && lumera.sh
```

## Features

The installation script provides:

1. **Automatic Node Installation** - Complete node setup with all dependencies
2. **Validator Creation** - Create and configure your validator
3. **Node Restoration** - Reset node with the latest snapshot

## Step-by-Step Usage Guide

### 1. Install Lumera Node

- Run the script and select option 1
- Enter your wallet name and node moniker
- Choose a custom port (recommended 30-40 if running multiple nodes)
- The script will automatically:
  - Install dependencies and Go
  - Download and install Lumera binaries
  - Configure your node
  - Download genesis and address book
  - Set up pruning and service configurations
  - Download the latest snapshot
  - Start your node service

### 2. Create Wallet

After installation, you'll need to either create a new wallet or recover an existing one:

- To create a new wallet:
  ```bash
  lumerad keys add <wallet-name>
  ```
- To recover an existing wallet:
  ```bash
  lumerad keys add <wallet-name> --recover
  ```

Save your mnemonic phrase in a secure location.

### 3. Get Testnet Tokens

Before creating a validator, you'll need testnet tokens:

1. Visit the [Lumera Testnet Faucet](https://faucet.testnet.lumera.io/)
2. Enter your wallet address and request tokens
3. Check your balance:
   ```bash
   lumerad query bank balances <wallet-address>
   ```

### 4. Create Validator

Once your node is fully synced and your wallet has funds:

- Run the script and select option 2
- The script will guide you through validator creation
- You'll need to provide:
  - Amount to stake (minimum 1 LUME)
  - Commission rate details
  - Validator information (website, identity, etc.)

### 5. Restore/Reset Node

If you need to reset your node or sync from a fresh snapshot:

- Run the script and select option 3
- Confirm restoration
- The script will download the latest snapshot and restore your node

## Useful Commands

### Check Node Status
```bash
lumerad status 2>&1 | jq .SyncInfo
```

### Check Logs
```bash
sudo journalctl -u lumerad -f -o cat
```

### Check Validator Status
```bash
lumerad q staking validator $(lumerad keys show <wallet-name> --bech val -a)
```

### Delegate Tokens
```bash
lumerad tx staking delegate <validator-address> <amount>ulume --from <wallet-name> --chain-id lumera-testnet-1 --gas-prices=0.25ulume --gas-adjustment=1.5 --gas=auto -y
```

### Withdraw Rewards
```bash
lumerad tx distribution withdraw-all-rewards --from <wallet-name> --chain-id lumera-testnet-1 --gas-prices=0.25ulume --gas-adjustment=1.5 --gas=auto -y
```

## Troubleshooting

If your node is not syncing properly:
1. Check connectivity to peers
2. Reset your node with a fresh snapshot (option 3)
3. Verify your system time is properly synchronized

## Support

For additional support, join the [Lumera Discord](https://discord.gg/qr9S5dHN)

## Disclaimer

This script is provided for testnet purposes only. Always verify commands before executing them on your system.