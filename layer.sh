#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo bash setup_light_node.sh"
    exit 1
fi

# Prompt for PRIVATE_KEY at the beginning
if [ -z "$PRIVATE_KEY" ]; then
    echo "Enter your PRIVATE_KEY:"
    read -r PRIVATE_KEY
fi

set -e  # Exit on any error

CHECKPOINT_FILE="/tmp/setup_checkpoint"
function set_checkpoint {
    echo "$1" > "$CHECKPOINT_FILE"
}
function get_checkpoint {
    if [ -f "$CHECKPOINT_FILE" ]; then
        cat "$CHECKPOINT_FILE"
    else
        echo "0"
    fi
}
CHECKPOINT=$(get_checkpoint)

if [ "$CHECKPOINT" -lt 1 ]; then
    echo "Updating system..."
    apt update || echo "apt update failed, continuing..."
    set_checkpoint 1
fi

if [ "$CHECKPOINT" -lt 2 ]; then
    echo "Installing nano and git..."
    apt install -y nano git || { echo "Failed to install nano and git"; exit 1; }
    set_checkpoint 2
fi

if [ "$CHECKPOINT" -lt 3 ]; then
    echo "Installing build-essential..."
    apt install -y build-essential || { echo "Failed to install build-essential"; exit 1; }
    set_checkpoint 3
fi

if [ "$CHECKPOINT" -lt 4 ]; then
    echo "Installing Rust..."
    curl --proto '=https' --tlsv1.3 https://sh.rustup.rs -sSf | sh -s -- -y || { echo "Failed to install Rust"; exit 1; }
    source $HOME/.cargo/env
    rustc --version || { echo "Rust installation verification failed"; exit 1; }
    set_checkpoint 4
fi

if [ "$CHECKPOINT" -lt 5 ]; then
    echo "Installing Go..."
    apt remove -y golang-go || { echo "Failed to remove old Go version"; exit 1; }
    cd ~
    curl -OL https://go.dev/dl/go1.23.1.linux-amd64.tar.gz || { echo "Failed to download Go"; exit 1; }
    sudo tar -C /usr/local -xvf go1.23.1.linux-amd64.tar.gz || { echo "Failed to extract Go"; exit 1; }
    rm go1.23.1.linux-amd64.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
    source ~/.profile
    go version || { echo "Go installation verification failed"; exit 1; }
    set_checkpoint 5
fi

if [ "$CHECKPOINT" -lt 6 ]; then
    echo "Cloning the light-node repository..."
    cd /home
    git clone https://github.com/Layer-Edge/light-node.git || { echo "Failed to clone light-node repository"; exit 1; }
    cd light-node
    set_checkpoint 6
fi

if [ "$CHECKPOINT" -lt 7 ]; then
    echo "Installing RZUP..."
    curl -L https://risczero.com/install | bash || echo "RZUP install script failed, continuing..."
    source "/root/.bashrc"
    if ! command -v rzup &> /dev/null; then
        echo "RZUP command not found, reloading shell environment..."
        source "/root/.bashrc"
    fi
    rzup install || echo "RZUP install failed, continuing..."
    set_checkpoint 7
fi

if [ "$CHECKPOINT" -lt 8 ]; then
    echo "Retrying RZUP installation..."
    source "/root/.bashrc"
    rzup install || echo "RZUP install still failing, continuing..."
    set_checkpoint 8
fi

if [ "$CHECKPOINT" -lt 9 ]; then
    echo "Creating .env file..."
    cat <<EOL > /home/light-node/.env
GRPC_URL=grpc.testnet.layeredge.io:9090
CONTRACT_ADDR=cosmos1ufs3tlq4umljk0qfe8k5ya0x6hpavn897u2cnf9k0en9jr7qarqqt56709
ZK_PROVER_URL=https://layeredge.mintair.xyz
API_REQUEST_TIMEOUT=100
POINTS_API=https://light-node.layeredge.io
PRIVATE_KEY=$PRIVATE_KEY
EOL
    set_checkpoint 9
fi

if [ "$CHECKPOINT" -lt 10 ]; then
    echo "Building risc0 server..."
    cd /home/light-node/risc0-merkle-service
    cargo build || { echo "Cargo build failed."; exit 1; }
    cargo run
    set_checkpoint 10
fi

echo "Setup completed successfully!"
