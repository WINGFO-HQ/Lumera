#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' 

print_green() {
    echo -e "${GREEN}$1${NC}"
}

print_red() {
    echo -e "${RED}$1${NC}"
}

print_yellow() {
    echo -e "${YELLOW}$1${NC}"
}

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root"
  exit 1
fi

install_node() {
  clear
  print_green "==============================================="
  print_green "    WINGFO LUMERA NODE AUTO INSTALLER          "
  print_green "==============================================="

  print_yellow "Setting up your node configuration..."

  read -p "Enter your wallet name: " WALLET
  read -p "Enter your node moniker: " MONIKER
  read -p "Enter desired port (default is 26, recommended 30-40 if running multiple nodes): " LUMERA_PORT
  LUMERA_PORT=${LUMERA_PORT:-26}

  print_yellow "Updating system and installing dependencies..."
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y build-essential jq lz4 curl wget tar

  print_yellow "Installing Go..."
  ver="1.22.3"
  wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz"
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
  rm "go$ver.linux-amd64.tar.gz"
  echo "export PATH=\$PATH:/usr/local/go/bin:\$HOME/go/bin" >> ~/.bash_profile
  source ~/.bash_profile
  go version

  print_yellow "Setting up environment variables..."
  echo "export WALLET=\"$WALLET\"" >> $HOME/.bash_profile
  echo "export MONIKER=\"$MONIKER\"" >> $HOME/.bash_profile
  echo "export LUMERA_CHAIN_ID=\"lumera-testnet-1\"" >> $HOME/.bash_profile
  echo "export LUMERA_PORT=\"$LUMERA_PORT\"" >> $HOME/.bash_profile
  source $HOME/.bash_profile

  print_yellow "Downloading and installing Lumera binary..."
  cd $HOME
  curl -LO https://github.com/LumeraProtocol/lumera/releases/download/v1.0.1/lumera_v1.0.1_linux_amd64.tar.gz
  rm lumera_v1.0.1_linux_amd64.tar.gz
  [ -f install.sh ] && rm install.sh
  sudo mv libwasmvm.x86_64.so /usr/lib/
  chmod +x lumerad
  sudo mv lumerad $HOME/go/bin/

  print_yellow "Verifying installation..."
  lumerad version

  print_yellow "Configuring Lumera node..."
  lumerad config node tcp://localhost:${LUMERA_PORT}657
  lumerad config keyring-backend os
  lumerad config chain-id lumera-testnet-1
  lumerad init "$MONIKER" --chain-id lumera-testnet-1

  print_yellow "Downloading genesis and address book..."
  curl -Ls https://ss-t.lumera.nodestake.org/genesis.json > $HOME/.lumera/config/genesis.json 
  curl -Ls https://ss-t.lumera.nodestake.org/addrbook.json > $HOME/.lumera/config/addrbook.json 

  print_yellow "Setting up seeds and peers..."
  seed="327fb4151de9f78f29ff10714085e347a4e3c836@rpc-t.lumera.nodestake.org:666"
  sed -i.bak -e "s|^seeds *=.*|seeds = \"$seed\"|" $HOME/.lumera/config/config.toml

  peers=$(curl -s https://ss-t.lumera.nodestake.org/peers.txt)
  if [ -n "$peers" ]; then
    sed -i.bak -e "s|^persistent_peers *=.*|persistent_peers = \"$peers\"|" ~/.lumera/config/config.toml
  else
    echo "Failed to get the list of peers, persistent_peers is not modified."
  fi

  print_yellow "Configuring custom ports..."
  sed -i.bak -e "s%:26658%:${LUMERA_PORT}658%g; \
  s%:26657%:${LUMERA_PORT}657%g; \
  s%:6060%:${LUMERA_PORT}060%g; \
  s%:26656%:${LUMERA_PORT}656%g; \
  s%^external_address = \"\"%external_address = \"$(wget -qO- eth0.me):${LUMERA_PORT}656\"%; \
  s%:26660%:${LUMERA_PORT}660%g" $HOME/.lumera/config/config.toml

  print_yellow "Configuring pruning settings..."
  sed -i -e "s/^pruning =.*/pruning = \"custom\"/" $HOME/.lumera/config/app.toml
  sed -i -e "s/^pruning-keep-recent =.*/pruning-keep-recent = \"100\"/" $HOME/.lumera/config/app.toml
  sed -i -e "s/^pruning-interval =.*/pruning-interval = \"20\"/" $HOME/.lumera/config/app.toml

  print_yellow "Setting gas prices and disabling indexer..."
  sed -i 's|minimum-gas-prices =.*|minimum-gas-prices = "0.025ulume"|g' $HOME/.lumera/config/app.toml
  sed -i -e "s/^indexer *=.*/indexer = \"null\"/" $HOME/.lumera/config/config.toml

  print_yellow "Creating service file..."
  sudo tee /etc/systemd/system/lumerad.service > /dev/null <<EOF
[Unit]
Description=lumera
After=network-online.target

[Service]
User=$USER
ExecStart=$(which lumerad) start
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

  print_yellow "Downloading snapshot (this may take some time)..."
  curl "https://snapshot.nodevism.com/testnet/lumera/lumera-snapshot.tar.lz4" | lz4 -dc - | tar -xf - -C "$HOME/.lumera"

  print_yellow "Enabling and starting Lumera service..."
  sudo systemctl daemon-reload
  sudo systemctl enable lumerad
  sudo systemctl restart lumerad

  print_green "==============================================="
  print_green "            INSTALLATION COMPLETED             "
  print_green "==============================================="
  print_yellow "Check logs with:   sudo journalctl -u lumerad -f -o cat"
  print_yellow "Create wallet:     lumerad keys add $WALLET"
  print_yellow "Recover wallet:    lumerad keys add $WALLET --recover"
  print_yellow "Check node status: lumerad status 2>&1 | jq"
  print_yellow "Check sync status: lumerad status 2>&1 | jq .SyncInfo"
  print_green "==============================================="
  print_yellow "After your node is fully synced, you can create validator"
  print_yellow "Run this script again and select option 2 to create validator"
  print_green "==============================================="
  print_green "Thanks for using this script!"
  print_green "==============================================="
}

create_validator() {
  clear
  print_green "==============================================="
  print_green "     WINGFO LUMERA VALIDATOR CREATOR           "
  print_green "==============================================="
  
  source $HOME/.bash_profile
  
  if [ -z "$WALLET" ]; then
    print_red "Wallet not found in environment variables."
    read -p "Enter your wallet name: " WALLET
    echo "export WALLET=\"$WALLET\"" >> $HOME/.bash_profile
    source $HOME/.bash_profile
  fi
  
  if ! lumerad keys show "$WALLET" &>/dev/null; then
    print_yellow "Wallet '$WALLET' not found. Do you want to create a new wallet or recover existing one?"
    echo "1. Create new wallet"
    echo "2. Recover existing wallet"
    read -p "Select an option (1/2): " wallet_option
    
    if [ "$wallet_option" = "1" ]; then
      print_yellow "Creating new wallet..."
      lumerad keys add $WALLET
    elif [ "$wallet_option" = "2" ]; then
      print_yellow "Recovering wallet. Please enter your mnemonic phrase when prompted..."
      lumerad keys add $WALLET --recover
    else
      print_red "Invalid option. Exiting..."
      return 1
    fi
  fi
  
  print_yellow "Getting wallet and validator addresses..."
  WALLET_ADDRESS=$(lumerad keys show $WALLET -a)
  VALOPER_ADDRESS=$(lumerad keys show $WALLET --bech val -a)
  echo "export WALLET_ADDRESS=\"$WALLET_ADDRESS\"" >> $HOME/.bash_profile
  echo "export VALOPER_ADDRESS=\"$VALOPER_ADDRESS\"" >> $HOME/.bash_profile
  source $HOME/.bash_profile
  
  print_yellow "Checking node sync status..."
  sync_status=$(lumerad status 2>&1 | jq -r .SyncInfo.catching_up)
  
  if [ "$sync_status" = "true" ]; then
    print_red "Your node is still syncing. Please wait until it's fully synced before creating validator."
    print_yellow "Check sync status: lumerad status 2>&1 | jq .SyncInfo"
    return 1
  fi
  
  print_yellow "Checking wallet balance..."
  balance=$(lumerad query bank balances $WALLET_ADDRESS -o json | jq -r '.balances[] | select(.denom=="ulume") | .amount' 2>/dev/null)
  
  if [ -z "$balance" ] || [ "$balance" -lt 1000000 ]; then
    print_red "Your wallet doesn't have enough funds. You need at least 1 LUME (1000000 ulume)."
    print_yellow "Current balance: $([ -z "$balance" ] && echo "0" || echo "$balance") ulume"
    return 1
  else
    print_green "Balance: $balance ulume"
  fi
  
  print_yellow "Creating validator configuration..."
  pubkey=$(lumerad tendermint show-validator)
  
  read -p "Enter your validator amount in LUME (min 1 LUME, recommended at least 2): " amount_lume
  amount=$((amount_lume * 1000000))
  
  read -p "Enter your validator website (optional): " website
  read -p "Enter your validator identity (e.g., keybase ID, optional): " identity
  read -p "Enter security contact (optional): " security
  read -p "Enter validator details/description (optional): " details
  read -p "Enter commission rate (e.g., 0.05 for 5%, default 0.05): " commission_rate
  commission_rate=${commission_rate:-0.05}
  read -p "Enter commission max rate (e.g., 0.1 for 10%, default 0.1): " commission_max_rate
  commission_max_rate=${commission_max_rate:-0.1}
  read -p "Enter commission max change rate (e.g., 0.05 for 5%, default 0.05): " commission_max_change_rate
  commission_max_change_rate=${commission_max_change_rate:-0.05}
  
  cat > $HOME/.lumera/validator.json <<EOF
{
  "pubkey": $pubkey,
  "amount": "${amount}ulume",
  "moniker": "$MONIKER",
  "identity": "$identity",
  "website": "$website",
  "security": "$security",
  "details": "$details",
  "commission-rate": "$commission_rate",
  "commission-max-rate": "$commission_max_rate",
  "commission-max-change-rate": "$commission_max_change_rate",
  "min-self-delegation": "1"
}
EOF
  
  print_yellow "Validator configuration created:"
  cat $HOME/.lumera/validator.json
  
  read -p "Do you want to create this validator? (y/n): " confirm
  if [[ "$confirm" != [yY] && "$confirm" != [yY][eE][sS] ]]; then
    print_red "Validator creation cancelled."
    return 1
  fi
  
  print_yellow "Creating validator... This might take a moment."
  lumerad tx staking create-validator $HOME/.lumera/validator.json \
  --from $WALLET \
  --chain-id lumera-testnet-1 \
  --gas-prices=0.25ulume \
  --gas-adjustment=1.5 \
  --gas=auto -y
  
  print_green "==============================================="
  print_green "      VALIDATOR CREATION TRANSACTION SENT      "
  print_green "==============================================="
  print_yellow "Please wait a few moments for your validator to appear in the active set."
  print_yellow "Check your validator status: lumerad q staking validator $VALOPER_ADDRESS"
  print_green "==============================================="
}

restore_node() {
  clear
  print_green "==============================================="
  print_green "         WINGFOLUMERA NODE RESTORE             "
  print_green "==============================================="
  
  print_yellow "This will stop your node and download the latest snapshot."
  read -p "Do you want to continue? (y/n): " confirm
  if [[ "$confirm" != [yY] && "$confirm" != [yY][eE][sS] ]]; then
    print_red "Operation cancelled."
    return 1
  fi
  
  print_yellow "Stopping Lumera service..."
  sudo systemctl stop lumerad
  
  print_yellow "Backing up validator state..."
  cp $HOME/.lumera/data/priv_validator_state.json $HOME/.lumera/priv_validator_state.json.backup
  
  print_yellow "Removing old data..."
  rm -rf $HOME/.lumera/data
  
  print_yellow "Downloading latest snapshot (this may take some time)..."
  curl "https://snapshot.nodevism.com/testnet/lumera/lumera-snapshot.tar.lz4" | lz4 -dc - | tar -xf - -C $HOME/.lumera
  
  print_yellow "Restoring validator state..."
  mv $HOME/.lumera/priv_validator_state.json.backup $HOME/.lumera/data/priv_validator_state.json
  
  print_yellow "Starting Lumera service..."
  sudo systemctl restart lumerad
  
  print_green "==============================================="
  print_green "           NODE RESTORE COMPLETED             "
  print_green "==============================================="
  print_yellow "Check logs with: sudo journalctl -u lumerad -f -o cat"
  print_green "==============================================="
}

main_menu() {
  clear
  print_green "==============================================="
  print_green "       WINGGO LUMERA NODE MANAGER              "
  print_green "==============================================="
  print_yellow "1. Install Lumera Node"
  print_yellow "2. Create Validator"
  print_yellow "3. Restore/Reset Node (Download Latest Snapshot)"
  print_yellow "4. Exit"
  print_green "==============================================="
  read -p "Select an option: " option
  
  case $option in
    1) install_node ;;
    2) create_validator ;;
    3) restore_node ;;
    4) exit 0 ;;
    *) print_red "Invalid option" && sleep 2 && main_menu ;;
  esac
  
  read -p "Press Enter to return to the main menu..." dummy
  main_menu
}

main_menu